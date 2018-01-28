//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_LW_Overhaul.uc
//
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the
//  player creates a new campaign or loads a saved game.
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class X2DownloadableContentInfo_LW_Overhaul extends X2DownloadableContentInfo config(LW_Overhaul);

struct ArchetypeToHealth
{
	var name ArchetypeName;
	var int Health;
	var int Difficulty;
	structDefaultProperties
	{
		Difficulty = -1;
	}
};

var config array<ArchetypeToHealth> DestructibleActorHealthOverride;
var config array<bool> DISABLE_REINFORCEMENT_FLARES;
var config array<float> SOUND_RANGE_DIFFICULTY_MODIFIER;

var bool bDebugPodJobs;

//disable tutorial for mod
static function bool DLCDisableTutorial(UIShellDifficulty Screen)
{
	return true;
}

// make coilgun-tech weapons use the magnetic tier targeting reticle
static function bool SelectTargetingReticle(out int ReturnReticleIndex, XComGameState_Ability Ability, X2AbilityTemplate AbilityTemplate, XComGameState_Item Weapon)
{
	local name WeaponTech;
	local name WeaponCategory;

	if (Weapon != none && AbilityTemplate.Hostility != eHostility_Defensive)
	{
		WeaponTech = Weapon.GetWeaponTech();
		WeaponCategory = Weapon.GetWeaponCategory();
		if (WeaponTech == 'coilgun_lw' && WeaponCategory != 'sword')
		{
			ReturnReticleIndex = eUIReticle_Advent;
			return true;
		}
	}
	return false;
}

// add in activity sources of doom
static function int AddDoomModifier(XComGameState_HeadquartersAlien AlienHQ, bool bIgnorePending)
{
	local XComGameStateHistory History;
	local XComGameState_LWAlienActivity ActivityState;
	local XComGameState_MissionSite MissionState;
	local int DoomMod;

	if( class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('S0_RevealAvatarProject') ) // only show activity doom if AVATAR project revealed
	{
		History = `XCOMHISTORY;
		foreach History.IterateByClassType(class'XComGameState_LWAlienActivity', ActivityState)
		{
			if(ActivityState.Doom > 0)
				DoomMod += ActivityState.Doom;

			// base game only adds doom for visible missions, so add doom for hidden missions here
			if (ActivityState.CurrentMissionRef.ObjectID > 0)
			{
				MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
				if (MissionState != none && !MissionState.Available)
				{
					if (MissionState.Doom > 0)
						DoomMod += MissionState.Doom;
				}
			}
		}
	}
	return DoomMod;
}

//allow overriding of objective Health values
	//relevant bits:
	// the simple way is to check the ObjectArchetype.name
	// ARC_AlienRestrictorSpike_Anim -- for avenger defense and invasion
	// ARC_RelayTransmitter_Anim_T1/T2/T3 -- for DestroyRelay
	// ARC_IA_SignalInterceptDevice_T1/T2/T3 -- for ProtectDevice
	// others may be in Missions.ini arrObjectiveSpawnInfo

static function bool OverrideDestructibleInitialHealth(out int NewHealth, XComGameState_Destructible DestructibleState, XComDestructibleActor Visualizer)
{
	local ArchetypeToHealth Override;
	local int CurrentDifficulty;

	`LWTRACE("In Toughness of actor : " $ Visualizer.ObjectArchetype.name $ " (" $ DestructibleState.ActorId.ActorName $ ") = " $ DestructibleState.Health);
	CurrentDifficulty = `DIFFICULTYSETTING;
	foreach default.DestructibleActorHealthOverride (Override)
	{
		if (Visualizer.ObjectArchetype.name == Override.ArchetypeName)
		{
			if (Override.Difficulty == -1 || Override.Difficulty == CurrentDifficulty)
			{
				NewHealth = Override.Health;
				`LWTRACE("Out Toughness of actor : " $ Visualizer.ObjectArchetype.name $ " (" $ DestructibleState.ActorId.ActorName $ ") = " $ NewHealth);
				return true;
			}
		}
	}

	return false;
}

// allow overriding of EnvironmentDamage Preview for flamethrower Abilities
static function int OverrideItemEnvironmentDamagePreview(XComGameState_Ability AbilityState)
{

	local XComGameState_Item SourceItemState;
	local X2AbilityTemplate AbilityTemplate;
	local X2MultiWeaponTemplate WeaponTemplate;

	AbilityTemplate = AbilityState.GetMyTemplate();
	switch (AbilityTemplate.DataName)
	{
		case 'LWFlamethrower':
		case 'Roust':
		case 'Firestorm':
			SourceItemState = XComGameState_Item( `XCOMHISTORY.GetGameStateForObjectID(  AbilityState.SourceWeapon.ObjectID ) );
			if (SourceItemState != none)
			{
				WeaponTemplate = X2MultiWeaponTemplate(SourceItemState.GetMyTemplate());
				if (WeaponTemplate != none)
				{
					return WeaponTemplate.iAltEnvironmentDamage;
				}
			}
			break;
	}

	return -1;
}

// override how fire deals environment damage to the world so it isn't burning down alloy walls, UFOs, trains, etc
static function bool OverrideWorldFireTickEvent(X2Effect_ApplyFireToWorld Effect, XComGameState_WorldEffectTileData TickingWorldEffect, XComGameState NewGameState)
{
	local int Index, CurrentIntensity;
	local TTile Tile;
	local XComGameState_EnvironmentDamage DamageEvent;
	local array<int> FireEndingIndices;
	local int NumTurns, NumTurnEnvDamIdx;

	// Retrieve the intensity (will have been reduced already for current turn)
	for (Index = 0; Index < TickingWorldEffect.StoredTileData.Length; ++Index)
	{
		if (TickingWorldEffect.StoredTileData[Index].Data.LDEffectTile)
		{
			continue;
		}

		CurrentIntensity = TickingWorldEffect.StoredTileData[Index].Data.Intensity;
		if (CurrentIntensity == 0)
		{
			FireEndingIndices.AddItem(Index);
		}
	}

	//alt code that doesn't insta-destroy but instead deals environment damage
	// it instead generates three separate DamageEvents, bin sorting the affected tiles into each
	// each DamageEvent deals a different amount of environment damage, based on the NumTurns the fire burned
	if (FireEndingIndices.Length > 0)
	{
		for (NumTurns = 1; NumTurns <=3; NumTurns++)
		{
			DamageEvent = XComGameState_EnvironmentDamage( NewGameState.CreateStateObject(class'XComGameState_EnvironmentDamage') );

			DamageEvent.DEBUG_SourceCodeLocation = "UC: X2Effect_ApplyFireToWorld:AddWorldEffectTickEvents()";

			DamageEvent.DamageTypeTemplateName = 'Fire';
			DamageEvent.bRadialDamage = false;
			if (NumTurns >= class'Helpers_LW'.default.FireEnvironmentDamageAfterNumTurns.Length)
			{
				DamageEvent.DamageAmount = 5; // default to some low value
				`REDSCREEN("ApplyFireToWorld: Could not find configured EnvironmentDamage for NumTurns= " $ NumTurns); // this indicates a config error, so throw a redscreen
			}
			else
			{
				NumTurnEnvDamIdx = Clamp(NumTurns, 0, class'Helpers_LW'.default.FireEnvironmentDamageAfterNumTurns.Length);
				DamageEvent.DamageAmount = class'Helpers_LW'.default.FireEnvironmentDamageAfterNumTurns[NumTurnEnvDamIdx];
			}
			DamageEvent.bAffectFragileOnly = Effect.bDamageFragileOnly;
			//loop over indices of all tiles with fire terminating this turn
			foreach FireEndingIndices( Index )
			{
				//select only tiles with appropriate total turns the burned to be submitted with this damage event
				if (Clamp(TickingWorldEffect.StoredTileData[Index].Data.NumTurns, 1, 3) == NumTurns)
				{
					DamageEvent.DamageTiles.AddItem( Tile );
				}
			}
			NewGameState.AddStateObject( DamageEvent );
		}
	}

	return true;
}

// set up alternate Mission Intro for infiltration missions
static function bool UseAlternateMissionIntroDefinition(MissionDefinition ActiveMission, out MissionIntroDefinition MissionIntro)
{
	local XComGameState_LWSquadManager SquadMgr;

	SquadMgr = `LWSQUADMGR;

	if(SquadMgr.IsValidInfiltrationMission(`XCOMHQ.MissionRef) || class'Utilities_LW'.static.CurrentMissionType() == "Rendezvous_LW")
	{
		MissionIntro = SquadMgr.default.InfiltrationMissionIntroDefinition;
		return true;
	}
	return false;
}

// always allow removal of weapon upgrades
static function bool CanRemoveWeaponUpgrade(XComGameState_Item Weapon, X2WeaponUpgradeTemplate UpgradeTemplate, int SlotIndex)
{
	if (UpgradeTemplate == none)
		return false;
	else
		return true;
}

// prevent removal of unlimited quanity items when making items available
static function bool CanRemoveItemFromInventory(out int bCanRemoveItem,  XComGameState_Item Item, XComGameState_Unit UnitState, XComGameState CheckGameState)
{
	if (Item.GetMyTemplate().bInfiniteItem && !Item.HasBeenModified())
	{
		bCanRemoveItem = 0;
		return true;
	}
	return false;
}

// give all soldiers 3 utility slots
static function bool GetNumUtilitySlotsOverride(out int NumSlots, XComGameState_Item Item, XComGameState_Unit UnitState, XComGameState CheckGameState)
{
	switch (UnitState.GetMyTemplateName())
	{
		case 'Soldier':
			NumSlots = class'XComGameState_LWListenerManager'.default.OverrideNumUtilitySlots;
			//`LWTRACE("GetNumUtilitySlotsOverride Override : working. Set to " $ NumSlots);
			break;
		default:
			break;
	}

	return false;
}

//set minimum required utility items to 0 -- fixes ID 989
static function GetMinimumRequiredUtilityItems(out int Value, XComGameState_Unit UnitState, XComGameState NewGameState)
{
	Value = 0;
}

static function int CountMembers (name CountItem, array<name> ArrayToScan)
{
	local int idx, k;

	k = 0;
	for (idx = 0; idx < ArrayToScan.Length; idx++)
	{
		if (ArrayToScan[idx] == CountItem)
		{
			k += 1;
		}
	}
	return k;
}

static function name FindMostCommonMember (array<name>ArrayToScan)
{
	local int idx, highest, highestidx;
	local array<int> kount;

	kount.length = 0;
	for (idx = 0; idx < ArrayToScan.Length; idx++)
	{
		kount.AddItem(CountMembers(ArrayToScan[idx], ArrayToScan));
	}
	highest = 1;
	for (idx = 0; idx < kount.length; idx ++)
	{
		if (kount[idx] > highest)
		{
			Highest = kount[idx];
			HighestIdx = Idx;
		}
	}
	return ArrayToScan[highestidx];
}

static function name SelectNewPodLeader (PodSpawnInfo SpawnInfo, int ForceLevel, bool AlienAllowed, bool AdventAllowed, bool TerrorAllowed)
{
	local X2CharacterTemplateManager CharacterTemplateMgr;
	local X2DataTemplate Template;
	local X2CharacterTemplate CharacterTemplate;
	local array<name> PossibleChars, RestrictedChars;
	local array<float> PossibleWeights;
	local float TotalWeight, TestWeight, RandomWeight;
	local int k;
	local XComGameState_HeadquartersXCom XCOMHQ;

	`LWTRACE ("Initiating SelectNewPodLeader" @ ForceLevel @ AlienAllowed @ AdventAllowed @ TerrorAllowed);

	PossibleChars.length = 0;
	XCOMHQ = XComGameState_HeadquartersXCom(`XCOMHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));

	CharacterTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	foreach CharacterTemplateMgr.IterateTemplates (Template, None)
	{
		CharacterTemplate = X2CharacterTemplate(Template);
		if (CharacterTemplate == none)
			continue;
		if (!(CharacterTemplate.bIsAdvent || CharacterTemplate.bIsAlien))
			continue;
		if (CharacterTemplate.bIsTurret)
			continue;
		if (!AlienAllowed && CharacterTemplate.bIsAlien)
			continue;
		if (!AdventAllowed && CharacterTemplate.bIsAdvent)
			continue;
		if (CharacterTemplate.DataName == 'Cyberus' && XCOMHQ.GetObjectiveStatus('T1_M2_S3_SKULLJACKCaptain') != eObjectiveState_Completed)
			continue;
		if (CharacterTemplate.DataName == 'AdvPsiWitchM3' && XCOMHQ.GetObjectiveStatus ('T1_M5_SKULLJACKCodex') != eObjectiveState_Completed)
			continue;

		if (!TerrorAllowed)
		{
			for (k = 0; k < class'XComTacticalMissionManager'.default.InclusionExclusionLists.length; k++)
			{
				if (class'XComTacticalMissionManager'.default.InclusionExclusionLists[k].ListID == 'NoTerror_LW')
				{
					RestrictedChars = class'XComTacticalMissionManager'.default.InclusionExclusionLists[k].TemplateName;
				}
			}
			if (RestrictedChars.Find(CharacterTemplate.DataName) != -1)
			{
				continue;
			}
		}
		TestWeight = GetLeaderSpawnWeight(CharacterTemplate, ForceLevel);
		// this is a valid character type, so store off data for later random selection
		if (TestWeight > 0.0)
		{
			PossibleChars.AddItem (CharacterTemplate.DataName);
			PossibleWeights.AddItem (TestWeight);
			TotalWeight += TestWeight;
		}
	}

	if (PossibleChars.length == 0)
	{
		return 'AdvCaptainM1';
	}

	RandomWeight = `SYNC_FRAND_STATIC() * TotalWeight;
	TestWeight = 0.0;
	for (k = 0; k < PossibleChars.length; k++)
	{
		TestWeight += PossibleWeights[k];
		if (RandomWeight < TestWeight)
		{
			return PossibleChars[k];
		}
	}
	return PossibleChars[PossibleChars.length - 1];
}

static function float GetLeaderSpawnWeight(X2CharacterTemplate CharacterTemplate, int ForceLevel)
{
	local int k;
	local float ReturnWeight;
	for (k = 0; k < CharacterTemplate.default.LeaderLevelSpawnWeights.length; k++)
	{
		if (ForceLevel >= CharacterTemplate.default.LeaderLevelSpawnWeights[k].MinForceLevel && ForceLevel <= CharacterTemplate.default.LeaderLevelSpawnWeights[k].MaxForceLevel && CharacterTemplate.default.LeaderLevelSpawnWeights[k].SpawnWeight > 0)
		{
			ReturnWeight += CharacterTemplate.default.LeaderLevelSpawnWeights[k].SpawnWeight;
		}
	}
	return ReturnWeight;
}

static function name SelectRandomPodFollower (PodSpawnInfo SpawnInfo, array<name> SupportedFollowers, int ForceLevel, bool AlienAllowed, bool AdventAllowed, bool TerrorAllowed)
{
	local X2CharacterTemplateManager CharacterTemplateMgr;
	local X2DataTemplate Template;
	local X2CharacterTemplate CharacterTemplate;
	local array<name> PossibleChars, RestrictedChars;
	local array<float> PossibleWeights;
	local float TotalWeight, TestWeight, RandomWeight;
	local int k;
	local XComGameState_HeadquartersXCom XCOMHQ;

	PossibleChars.length = 0;
	//`LWTRACE ("Initiating SelectRandomPodFollower" @ ForceLevel @ AlienAllowed @ AdventAllowed @ TerrorAllowed);
	CharacterTemplateMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	foreach CharacterTemplateMgr.IterateTemplates (Template, None)
	{
		CharacterTemplate = X2CharacterTemplate(Template);
		if (CharacterTemplate == none)
			continue;
		if (!(CharacterTemplate.bIsAdvent || CharacterTemplate.bIsAlien))
			continue;
		if (CharacterTemplate.bIsTurret)
			continue;
		if (SupportedFollowers.Find(CharacterTemplate.DataName) == -1)
			continue;
		if (!AlienAllowed && CharacterTemplate.bIsAlien)
			continue;
		if (!AdventAllowed && CharacterTemplate.bIsAdvent)
			continue;

		if (!TerrorAllowed)
		{
			for (k = 0; k < class'XComTacticalMissionManager'.default.InclusionExclusionLists.length; k++)
			{
				if (class'XComTacticalMissionManager'.default.InclusionExclusionLists[k].ListID == 'NoTerror_LW')
				{
					RestrictedChars = class'XComTacticalMissionManager'.default.InclusionExclusionLists[k].TemplateName;
				}
			}
			if (RestrictedChars.Find(CharacterTemplate.DataName) != -1)
			{
				continue;
			}
		}

		if (CountMembers (CharacterTemplate.DataName, SpawnInfo.SelectedCharacterTemplateNames) >= CharacterTemplate.default.MaxCharactersPerGroup)
			continue;

		XCOMHQ = XComGameState_HeadquartersXCom(`XCOMHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));

		// don't let cyberuses in yet
		if (CharacterTemplate.DataName == 'Cyberus' && XCOMHQ.GetObjectiveStatus('T1_M2_S3_SKULLJACKCaptain') != eObjectiveState_Completed)
			continue;

		// don't let Avatars in yet
		if (CharacterTemplate.DataName == 'AdvPsiWitchM3' && XCOMHQ.GetObjectiveStatus ('T1_M5_SKULLJACKCodex') != eObjectiveState_Completed)
			continue;

		TestWeight = GetCharacterSpawnWeight(CharacterTemplate, ForceLevel);
		if (TestWeight > 0.0)
		{
			// this is a valid character type, so store off data for later random selection
			PossibleChars.AddItem (CharacterTemplate.DataName);
			PossibleWeights.AddItem (TestWeight);
			TotalWeight += TestWeight;
		}
	}
	if (PossibleChars.length == 0)
	{
		return 'AdvTrooperM1';
	}
	RandomWeight = `SYNC_FRAND_STATIC() * TotalWeight;
	TestWeight = 0.0;
	for (k = 0; k < PossibleChars.length; k++)
	{
		TestWeight += PossibleWeights[k];
		if (RandomWeight < TestWeight)
		{
			return PossibleChars[k];
		}
	}
	return PossibleChars[PossibleChars.length - 1];
}

static function float GetCharacterSpawnWeight(X2CharacterTemplate CharacterTemplate, int ForceLevel)
{
	local int k;
	local float ReturnWeight;
	for (k = 0; k < CharacterTemplate.default.FollowerLevelSpawnWeights.length; k++)
	{
		if (ForceLevel >= CharacterTemplate.default.FollowerLevelSpawnWeights[k].MinForceLevel && ForceLevel <= CharacterTemplate.default.FollowerLevelSpawnWeights[k].MaxForceLevel  && CharacterTemplate.default.FollowerLevelSpawnWeights[k].SpawnWeight > 0)
		{
			ReturnWeight += CharacterTemplate.default.FollowerLevelSpawnWeights[k].SpawnWeight;
		}
	}
	return ReturnWeight;
}

// diversify pods, in particular all-alien pods of all the same type
static function PostEncounterCreation(out name EncounterName, out PodSpawnInfo SpawnInfo, int ForceLevel, int AlertLevel, optional XComGameState_BaseObject SourceObject)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local name								CharacterTemplateName, FirstFollowerName;
	local int								idx, Tries, PodSize, k;
	local X2CharacterTemplateManager		TemplateManager;
	local X2CharacterTemplate				LeaderCharacterTemplate, FollowerCharacterTemplate, CurrentCharacterTemplate;
	local bool								Swap, Satisfactory;
	local XComGameState_MissionSite			MissionState;
	local XComGameState_AIReinforcementSpawner	RNFSpawnerState;
	local XComGameState_HeadquartersXCom XCOMHQ;

	`LWTRACE("Parsing Encounter : " $ EncounterName);

	History = `XCOMHISTORY;
	MissionState = XComGameState_MissionSite(SourceObject);
	if (MissionState == none)
	{
		BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
		if (BattleData == none)
		{
			`LWTRACE("Could not detect mission type. Aborting with no mission variations applied.");
			return;
		}
		else
		{
			MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
		}
	}

	`LWTRACE("Mission type = " $ MissionState.GeneratedMission.Mission.sType $ " detected.");
	switch(MissionState.GeneratedMission.Mission.sType)
	{
		case "GP_Fortress":
		case "GP_Fortress_LW":
			`LWTRACE("Fortress mission detected. Aborting with no mission variations applied.");
			return;
		case "AlienNest":
		case "LastGift":
		case "LastGiftB":
		case "LastGiftC":
			`LWTRACE("DLC mission detected. Aborting with no mission variations applied.");
			return;
		default:
			break;
	}
	if (Left(string(EncounterName), 11) == "GP_Fortress")
	{
		`LWTRACE("Fortress mission detected. Aborting with no mission variations applied.");
		return;
	}
	switch (EncounterName)
	{
		case 'LoneAvatar':
		case 'LoneCodex':
			return;
		default:
			break;
	}

	if (InStr (EncounterName,"PROTECTED") != -1)
	{
		return;
	}

	//`LWTRACE("PE1");
	RNFSpawnerState = XComGameState_AIReinforcementSpawner(SourceObject);

	//	`LWTRACE ("PE2");
	if (RNFSpawnerState != none)
	{
		`LWTRACE("Called from AIReinforcementSpawner.OnReinforcementSpawnerCreated -- modifying reinforcement spawninfo");
	}
	else
	{
		if (MissionState != none)
		{
			`LWTRACE("Called from MissionSite.CacheSelectedMissionData -- modifying preplaced spawninfo");
		}
	}

	//`LWTRACE ("PE3");

	`LWTRACE("Encounter composition:");
	foreach SpawnInfo.SelectedCharacterTemplateNames (CharacterTemplateName, idx)
	{
		`LWTRACE("Character[" $ idx $ "] = " $ CharacterTemplateName);
	}

	PodSize = SpawnInfo.SelectedCharacterTemplateNames.length;

	TemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	LeaderCharacterTemplate = TemplateManager.FindCharacterTemplate(SpawnInfo.SelectedCharacterTemplateNames[0]);

	swap = false;

	// override native insisting every mission have a codex while certain tactical options are active
	XCOMHQ = XComGameState_HeadquartersXCom(`XCOMHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));

	// Swap out forced Codices on regular encounters
	if (SpawnInfo.SelectedCharacterTemplateNames[0] == 'Cyberus' && InStr (EncounterName,"PROTECTED") == -1 && EncounterName != 'LoneCodex')
	{
		swap = true;
		SpawnInfo.SelectedCharacterTemplateNames[0] = SelectNewPodLeader (SpawnInfo, ForceLevel, true, true, InStr(EncounterName,"TER") != -1);
		`LWTRACE ("Swapping Codex leader for" @ SpawnInfo.SelectedCharacterTemplateNames[0]);
	}

	// forces special conditions for avatar to pop
	if (SpawnInfo.SelectedCharacterTemplateNames[0] == 'AdvPsiWitchM3')
	{
		if (XCOMHQ.GetObjectiveStatus('T1_M5_SKULLJACKCodex') != eObjectiveState_Completed)
		{
			switch (EncounterName)
			{
				case 'LoneAvatar' :
				case 'GP_Fortress_AvatarGroup_First_LW' :
				case 'GP_Fortress_AvatarGroup_First' :
					break;
				default:
					swap = true;
					SpawnInfo.SelectedCharacterTemplateNames[0] = SelectNewPodLeader (SpawnInfo, ForceLevel, true, true, InStr(EncounterName,"TER") != -1);
					`LWTRACE ("Swapping Avatar leader for" @ SpawnInfo.SelectedCharacterTemplateNames[0]);
					break;
			}
		}
	}

	// reroll advent captains when the game is forcing captains
	if (RNFSpawnerState != none && InStr(SpawnInfo.SelectedCharacterTemplateNames[0],"Captain") != -1)
	{
		if (XCOMHQ.GetObjectiveStatus('T1_M3_KillCodex') == eObjectiveState_InProgress ||
			XCOMHQ.GetObjectiveStatus('T1_M5_SKULLJACKCodex') == eObjectiveState_InProgress ||
			XCOMHQ.GetObjectiveStatus('T1_M6_KillAvatar') == eObjectiveState_InProgress ||
			XCOMHQ.GetObjectiveStatus('T1_M2_S3_SKULLJACKCaptain') == eObjectiveState_InProgress)
		swap = true;
		SpawnInfo.SelectedCharacterTemplateNames[0] = SelectNewPodLeader (SpawnInfo, ForceLevel, true, true, InStr(EncounterName,"TER") != -1);
		`LWTRACE ("Swapping Reinf Captain leader for" @ SpawnInfo.SelectedCharacterTemplateNames[0]);
	}

	if (PodSize > 1)
	{
		TemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
		LeaderCharacterTemplate = TemplateManager.FindCharacterTemplate(SpawnInfo.SelectedCharacterTemplateNames[0]);
		// Find whatever the pod has the most of
		FirstFollowerName = FindMostCommonMember (SpawnInfo.SelectedCharacterTemplateNames);
		FollowerCharacterTemplate = TemplateManager.FindCharacterTemplate(FirstFollowerName);

		`LWTRACE ("Pod Leader:" @ SpawnInfo.SelectedCharacterTemplateNames[0]);
		`LWTRACE ("Pod Follower:" @ FirstFollowerName);

		if (LeaderCharacterTemplate.bIsTurret)
			return;

		if (InStr(EncounterName,"LIST_BOSSx") != -1 && InStr(EncounterName,"_LW") == -1)
		{
			`LWTRACE ("Don't Edit certain vanilla Boss pods");
			return;
		}
		if (Instr(EncounterName,"Chryssalids") != -1)
		{
			`LWTRACE ("Don't edit Chryssypods");
			return;
		}

		// Handle vanilla pod construction of one type of alien follower;
		if (!swap && LeaderCharacterTemplate.bIsAlien && FollowerCharacterTemplate.bIsAlien && CountMembers (FirstFollowerName, SpawnInfo.SelectedCharacterTemplateNames) > 1)
		{
			`LWTRACE ("Mixing up alien-dominant pod");
			swap = true;
		}

		// Check for pod members that shouldn't appear yet for plot reaons
		if (CountMembers ('Cyberus', SpawnInfo.SelectedCharacterTemplateNames) >= 1 && XCOMHQ.GetObjectiveStatus('T1_M2_S3_SKULLJACKCaptain') != eObjectiveState_Completed)
		{
			`LWTRACE ("Removing Codex for objective reasons");
			swap = true;
		}

		if (CountMembers ('AdvPsiWitch', SpawnInfo.SelectedCharacterTemplateNames) >= 1 && XCOMHQ.GetObjectiveStatus('T1_M5_SKULLJACKCodex') != eObjectiveState_Completed)
		{
			`LWTRACE ("Exicising Avatar for objective reasons");
			swap = true;
		}

		if (!swap)
		{
			for (k = 0; k < SpawnInfo.SelectedCharacterTemplateNames.length; k++)
			{
				FollowerCharacterTemplate = TemplateManager.FindCharacterTemplate (SpawnInfo.SelectedCharacterTemplateNames[k]);
				if (CountMembers (SpawnInfo.SelectedCharacterTemplateNames[k], SpawnInfo.SelectedCharacterTemplateNames) > FollowerCharacterTemplate.default.MaxCharactersPerGroup)
				{
					swap = true;
				}
			}
			if (swap)
			{
				`LWTRACE ("Mixing up pod that violates MCPG setting");
			}
		}

		// if size 4 && at least 3 are the same
		if (!swap && (PodSize == 4 || PodSize == 5))
		{
			if (CountMembers (FirstFollowerName, SpawnInfo.SelectedCharacterTemplateNames) >= PodSize - 1)
			{
				`LWTRACE ("Mixing up undiverse 4/5-enemy pod");
				swap = true;
			}
		}

		// if larger && at least size - 2 are the same
		if (!swap && PodSize >= 6)
		{
			// if a max of one guy is different
			if (!swap && CountMembers (FirstFollowerName, SpawnInfo.SelectedCharacterTemplateNames) >= PodSize - 2)
			{
				`LWTRACE ("Mixing up undiverse 5+ enemy pod");
				swap = true;
			}
		}

		if (swap)
		{
			Satisfactory = false;
			Tries = 0;
			While (!Satisfactory && Tries < 12)
			{
				// let's look at
				foreach SpawnInfo.SelectedCharacterTemplateNames(CharacterTemplateName, idx)
				{
					if (idx <= 2)
						continue;

					if (SpawnInfo.SelectedCharacterTemplateNames[idx] != FirstFollowerName)
						continue;

					CurrentCharacterTemplate = TemplateManager.FindCharacterTemplate(SpawnInfo.SelectedCharacterTemplateNames[idx]);
					if (CurrentCharacterTemplate.bIsTurret)
						continue;

					SpawnInfo.SelectedCharacterTemplateNames[idx] = SelectRandomPodFollower (SpawnInfo, LeaderCharacterTemplate.SupportedFollowers, ForceLevel, InStr(EncounterName,"ADVx") == -1, InStr(EncounterName,"Alien") == -1 && InStr(EncounterName,"ALNx") == -1, InStr(EncounterName,"TER") != -1);
				}
				//`LWTRACE ("Try" @ string (tries) @ CountMembers (FirstFollowerName, SpawnInfo.SelectedCharacterTemplateNames) @ string (PodSize));
				// Let's look over our outcome and see if it's any better
				if ((PodSize == 4 || PodSize == 5) && CountMembers (FirstFollowerName, SpawnInfo.SelectedCharacterTemplateNames) >= Podsize - 1)
				{
					Tries += 1;
				}
				else
				{
					if (PodSize >= 6 && CountMembers (FirstFollowerName, SpawnInfo.SelectedCharacterTemplateNames) >= PodSize - 2)
					{
						Tries += 1;
					}
					else
					{
						Satisfactory = true;
					}
				}
			}
			`LWTRACE("Attempted to edit Encounter to add more enemy diversity! Satisfactory:" @ string(satisfactory) @ "New encounter composition:");
			foreach SpawnInfo.SelectedCharacterTemplateNames (CharacterTemplateName, idx)
			{
				`LWTRACE("Character[" $ idx $ "] = " $ CharacterTemplateName);
			}
		}
	}
	return;
}

// use new infiltration loading screens when loading into tactical missions
static function bool LoadingScreenOverrideTransitionMap(optional out string OverrideMapName, optional X2TacticalGameRuleset Ruleset, optional XComGameState_Unit UnitState)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_MissionSite MissionSiteState;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionSiteState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));

	if (`LWSQUADMGR.IsValidInfiltrationMission(MissionSiteState.GetReference()) || class'Utilities_LW'.static.CurrentMissionType() == "Rendezvous_LW")
	{
		if (`TACTICALGRI != none )  // only pre tactical
		{
			switch (MissionSiteState.GeneratedMission.Plot.strType)
			{
				case "CityCenter" :
				case "Rooftops" :
				case "Slums" :
				case "Facility" :
					OverrideMapName = "CIN_Loading_Infiltration_CityCenter";
					break;
				case "Shanty" :
				case "SmallTown" :
				case "Wilderness" :
					OverrideMapName = "CIN_Loading_Infiltration_SmallTown";
					break;
				default :
					OverrideMapName = "CIN_Loading_Infiltration_CityCenter";
					break;
			}
			return true;
		}
	}

	return false;
}

// choose alternative spawn locations for certain mission types
static function XComGroupSpawn OverrideSoldierSpawn(vector ObjectiveLocation, array<XComGroupSpawn> arrSpawns)
{
	local float ClosestSpawnDistance, TmpSpawnDistance;
	local XComGroupSpawn SpawnPoint, BestSpawnPoint;

	// We only care about defend missions.
	if (class'Utilities_LW'.static.CurrentMissionType() != "Defend_LW")
	{
		return none;
	}

	// Determine the closest spawn point to the objective.
	foreach arrSpawns(SpawnPoint)
	{
		if (SpawnPoint.HasValidFloorLocations())
		{
			TmpSpawnDistance = VSizeSq2D(ObjectiveLocation - SpawnPoint.Location);
			if (TmpSpawnDistance < ClosestSpawnDistance || BestSpawnPoint == none)
			{
				BestSpawnPoint = SpawnPoint;
				ClosestSpawnDistance = TmpSpawnDistance;
			}
		}
	}

	// Return the best spawn point if there is one
	if (BestSpawnPoint != none)
	{
		`LWTrace("Choosing closest spawn point: " $ BestSpawnPoint.Location);
		return BestSpawnPoint;
	}
	return none;
}

// override number of objectives for specific mission types
static function int GetNumObjectivesToSpawn(XComGameState_BattleData BattleData)
{
	local XComGameState_MissionSite MissionSite;

	if (BattleData == none)
	{
		// Doesn't look like something we understand.
		return -1;
	}

	MissionSite = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(BattleData.m_iMissionID));
	if (MissionSite == none)
	{
		`Log("GetNumObjectivesToSpawn: Failed to fetch mission site for battle.");
		return -1;
	}

	// If this is a Jailbreak_LW mission (Political Prisoners activity) then we need to use the number of rebels we generated as rewards
	// as the number of objectives.
	if (MissionSite.GeneratedMission.Mission.sType == "Jailbreak_LW")
	{
		`LWTRACE("Jailbreak mission overriding NumObjectivesToSpawn = " $ MissionSite.Rewards.Length);
		return MissionSite.Rewards.Length;
	}
	return -1;
}

// Allow disabling of the AI reinforcement flare.
static function bool DisableAIReinforcementFlare(XComGameState_AIReinforcementSpawner SpawnerState)
{
	`LWTRACE ("Disable Reinforcement Flares" @ default.DISABLE_REINFORCEMENT_FLARES[`DIFFICULTYSETTING]);
	return default.DISABLE_REINFORCEMENT_FLARES[`DIFFICULTYSETTING];
}

function DrawDebugLabel(Canvas kCanvas)
{
	if (bDebugPodJobs)
	{
		`LWPODMGR.DrawDebugLabel(kCanvas);
	}
}

static function int ModifySoundRange(XComGameState_Unit SourceUnit, XComGameState_Item Weapon, XComGameState_Ability Ability, XComGameState GameState)
{
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local float SoundRangeModifier;
	local int k;
	local X2WeaponTemplate WeaponTemplate;
	local X2MultiWeaponTemplate MultiWeaponTemplate;
	local X2AbilityTemplate AbilityTemplate;
	local X2Effect AbilityEffect;
	local bool UseAltWeaponSoundRange;

	SoundRangeModifier = 0.0;
	WeaponTemplate = X2WeaponTemplate(Weapon.GetMyTemplate());

	// Is it a multiweapon?
	MultiWeaponTemplate = X2MultiWeaponTemplate(WeaponTemplate);

	if (MultiWeaponTemplate != none)
	{
		AbilityTemplate = Ability.GetMyTemplate();
		foreach AbilityTemplate.AbilityTargetEffects(AbilityEffect)
		{
			if (AbilityEffect.IsA('X2Effect_ApplyAltWeaponDamage'))
			{
				UseAltWeaponSoundRange = true;
				break;
			}
		}

		foreach AbilityTemplate.AbilityMultiTargetEffects(AbilityEffect)
		{
			if (AbilityEffect.IsA('X2Effect_ApplyAltWeaponDamage'))
			{
				UseAltWeaponSoundRange = true;
				break;
			}
		}

		if (UseAltWeaponSoundRange)
		{
			// This ability is using the secondary effect of a multi-weapon. We need to apply a mod to use the alt sound
			// range in place of the primary range.
			SoundRangeModifier += (MultiWeaponTemplate.iAltSoundRange - MultiWeaponTemplate.iSoundRange);
		}
	}

	if (WeaponTemplate != none)
	{
		WeaponUpgrades = Weapon.GetMyWeaponUpgradeTemplates();
		for (k = 0; k < WeaponUpgrades.Length; k++)
		{
			switch (WeaponUpgrades[k].DataName)
			{
				case 'FreeKillUpgrade_Bsc':
					SoundRangeModifier = -class'X2Item_DefaultWeaponMods_LW'.default.BASIC_SUPPRESSOR_SOUND_REDUCTION_METERS;
					break;
				case 'FreeKillUpgrade_Adv':
					SoundRangeModifier = -class'X2Item_DefaultWeaponMods_LW'.default.ADVANCED_SUPPRESSOR_SOUND_REDUCTION_METERS;
					break;
				case 'FreeKillUpgrade_Sup':
					SoundRangeModifier = -class'X2Item_DefaultWeaponMods_LW'.default.ELITE_SUPPRESSOR_SOUND_REDUCTION_METERS;
					break;
				default: break;
			}
		}
	}

	SoundRangeModifier += default.SOUND_RANGE_DIFFICULTY_MODIFIER[`DIFFICULTYSETTING];

	return int (FMax (SoundRangeModifier, 0.0));
}

// Sorting units for tab order: all soldiers should appear earlier in the tab order than non-soldiers. Helpful on missions
// like retaliations and recruit raids where many unarmed rebels may be controlled.
static function SortTabOrder(out array<XComGameState_Unit> Units, XComGameState_Unit CurrentUnit, bool TabbingForward)
{
	local int i, j;
	local XComGameState_Unit tmp;

	j = Units.Length - 1;
	while (i < j)
	{
		// Keep moving i forward until we find a non-soldier
		while (Units[i].IsASoldier() && i < j)
		{
			++i;
		}

		// Move j backward until we find a soldier
		while (!Units[j].IsASoldier() && i < j)
		{
			--j;
		}

		// Swap em.
		if (i < j)
		{
			tmp = Units[i];
			Units[i] = Units[j];
			Units[j] = tmp;
		}
	}
}

static function int GetScienceScoreMod(bool bAddLabBonus)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameStateHistory History;
	local int Modifier;
	local int idx;
	local XComGameState_Unit Scientist;
	local XComGameState_StaffSlot StaffSlot;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	// If bAddLabBonus is true, we're computing science scores, so we should remove the contribution from any scientist assigned
	// to a facility that isn't the lab. If it's false, we're checking a science gate and should consider all scientists regardless
	// of their location.
	if (bAddLabBonus)
	{
		for (idx = 0; idx < XComHQ.Crew.Length; ++idx)
		{
			Scientist = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Crew[idx].ObjectID));

			// Only worry about living scientists, and skip Tygan.
			if (Scientist.IsAScientist() && !Scientist.IsDead() && Scientist.GetMyTemplateName() != 'HeadScientist')
			{
				// This scientist was counted by the base game. If they are in a staff slot that is not the lab,
				// remove their score.
				StaffSlot = Scientist.GetStaffSlot();
				if (StaffSlot != none && StaffSlot.GetMyTemplateName() != 'LaboratoryStaffSlot')
				{
					Modifier -= Scientist.GetSkillLevel(bAddLabBonus);
				}
			}
		}

		return Modifier;
	}

	return 0;
}

// ******** HANDLE UPDATING STORAGE ************* //
static function RemoveHavensFromStartState(XComGameState StartState)
{
	local XComGameState_Haven HavenState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_WorldRegion RegionState;
	local StateObjectReference EmptyRef;

	foreach StartState.IterateByClassType(class'XComGameState_Haven', HavenState)
	{
		StartState.RemoveStateObject(HavenState.ObjectID);
		RegionState = XComGameState_WorldRegion(StartState.GetGameStateForObjectID(HavenState.Region.ObjectID));
		RegionState.Haven = EmptyRef;
	}
	foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	XComHQ.StartingHaven = EmptyRef;

	SetStartingLocationToStartingRegion(StartState);
}

// Return an array of RegionalAvatarResearch activities, with one entry per doom point
// associated with those activities. That is, a facility is repeated N times in the array
// if they have N doom.
static function array<XComGameState_LWAlienActivity> GetFacilitiesWithDoom()
{
	local XComGamestate_LWAlienActivity ActivityState;
	local array<XComGameState_LWAlienActivity> Facilities;
	local XComGameState_MissionSite MissionState;
	local XComGameStateHistory History;
	local int i;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_LWAlienActivity', ActivityState)
	{
		if(ActivityState.GetMyTemplateName() == class'X2StrategyElement_DefaultAlienActivities'.default.RegionalAvatarResearchName)
		{
			for (i = 0; i < ActivityState.Doom; ++i)
				Facilities.AddItem(ActivityState);

			// Check for doom attached to the mission
			if (ActivityState.CurrentMissionRef.ObjectID > 0)
			{
				MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
				if (MissionState != none && !MissionState.Available)
				{
					for (i = 0; i < MissionState.Doom; ++i)
						Facilities.AddItem(ActivityState);
				}
			}
		}
	}

	return Facilities;
}

static function int RemoveDoomFromFortress(XComGameState_HeadquartersAlien AlienHQ, XComGameState NewGameState, int DoomToRemove, String DoomMessage, bool bCreatePendingDoom)
{
	local XComGameState_MissionSite MissionState;
	local int DoomRemoved;
	local array<XComGameState_LWAlienActivity> Facilities;
	local XComGameState_LWAlienActivity Facility, NewFacility;
	local int FacilityIdx;
	local PendingDoom DoomPending;

	MissionState = AlienHQ.GetAndAddFortressMission(NewGameState);

	// Start by removing doom from the fortress.
	DoomRemoved = Clamp(DoomToRemove, 0, MissionState.Doom);

	if(MissionState != none)
	{
		MissionState.Doom -= DoomRemoved;
		AlienHQ.PendingDoomEntity = MissionState.GetReference();
	}

	DoomToRemove -= DoomRemoved;
	if (DoomToRemove > 0)
	{
		// We still have doom left to get rid of, but none left in the fortress. Remove the remaining doom from available facilities.
		Facilities = GetFacilitiesWithDoom();

		while (DoomToRemove > 0 && Facilities.Length > 0)
		{
			// Facilities contains 1 entry per doom point, so we can simply choose one at random with all doom points
			// being equally likely to be removed, rather than all facilities equally likely to be chosen.
			FacilityIdx = `SYNC_RAND_STATIC(Facilities.Length);
			Facility = Facilities[FacilityIdx];
			Facilities.Remove(FacilityIdx, 1);

			NewFacility = XComGameState_LWAlienActivity(NewGameState.GetGameStateForObjectID(Facility.ObjectID));
			if (NewFacility == none)
			{
				NewFacility = XComGameState_LWAlienActivity(NewGameState.CreateStateObject(class'XComGameState_LWAlienActivity', Facility.ObjectID));
				NewGameState.AddStateObject(NewFacility);
			}

			if (Facility.Doom > 0)
			{
				--Facility.Doom;
				--DoomToRemove;
				++DoomRemoved;
			}
			else
			{
				// None left on this facility either, but it might be on the mission.
				if (Facility.CurrentMissionRef.ObjectID > 0)
				{
					MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(Facility.CurrentMissionRef.ObjectID));
					if (MissionState == none)
					{
						MissionState = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', Facility.CurrentMissionRef.ObjectID));
						NewGameState.AddStateObject(MissionState);
					}
					if (MissionState.Doom > 0)
					{
						--MissionState.Doom;
						--DoomToRemove;
						++DoomRemoved;
					}
				}
			}
		}
	}

	if (bCreatePendingDoom)
	{
		DoomPending.Doom = -DoomRemoved;

		if(DoomMessage != "")
		{
			DoomPending.DoomMessage = DoomMessage;
		}
		else
		{
			DoomPending.DoomMessage = class'XComGameState_HeadquartersAlien'.default.HiddenDoomLabel;
		}

		AlienHQ.PendingDoomData.AddItem(DoomPending);
	}

	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvatarProgress', DoomRemoved);
	return DoomRemoved;
}