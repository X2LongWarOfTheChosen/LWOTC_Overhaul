class X2DownloadableContentInfo_LWOTC_Overhaul extends X2DownloadableContentInfo;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{
	class'XComGameState_LWListenerManager'.static.CreateListenerManager(StartState);
	class'SquadManager_XComGameState'.static.CreateSquadManager(StartState);

	//class'XComGameState_LWOutpostManager'.static.CreateOutpostManager(StartState);
	class'AlienActivity_XComGameState_Manager'.static.CreateAlienActivityManager(StartState);
	class'WorldRegion_XComGameState_AlienStrategyAI_Con'.static.InitializeRegionalAIs(StartState);
	//class'XComGameState_LWOverhaulOptions'.static.CreateModSettingsState_NewCampaign(class'XComGameState_LWOverhaulOptions', StartState);


	SetStartingLocationToStartingRegion(StartState);
	class'Override_HookCreation'.static.UnlockBlackMarket(StartState);
	class'Override_Storage'.static.UpdateStartingSoldiers(StartState); // update starting soldier utility slot count and items
	class'Override_CountryBonus'.static.UpdateLockAndLoadBonus(StartState);  // update XComHQ and Continent states to remove LockAndLoad bonus if it was selected
	LimitStartingSquadSize(StartState); // possibly limit the starting squad size to something smaller than the maximum

	class'SquadManager_XComGameState'.static.CreateFirstMissionSquad(StartState);
}

// SetStartingLocationToStartingRegion(XComGameState StartState)
static function SetStartingLocationToStartingRegion(XComGameState StartState)
{
	local XComGameState_HeadquartersXCom XComHQ;

	foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}

	XComHQ.CurrentLocation = XComHQ.StartingRegion;
}

// LimitStartingSquadSize(XComGameState StartState)
static function LimitStartingSquadSize(XComGameState StartState)
{
	local XComGameState_HeadquartersXCom XComHQ;

	if (class'SquadManager_XComGameState'.default.MAX_FIRST_MISSION_SQUAD_SIZE <= 0) // 0 or less means unlimited
		return;

	foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ.Squad.Length > class'SquadManager_XComGameState'.default.MAX_FIRST_MISSION_SQUAD_SIZE)
	{
		XComHQ.Squad.Length = class'SquadManager_XComGameState'.default.MAX_FIRST_MISSION_SQUAD_SIZE;
	}
}

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{
	class'XComGameState_LWListenerManager'.static.CreateListenerManager();
	class'SquadManager_XComGameState'.static.CreateSquadManager();
	//class'XComGameState_LWOutpostManager'.static.CreateOutpostManager();
	class'AlienActivity_XComGameState_Manager'.static.CreateAlienActivityManager();
	class'WorldRegion_XComGameState_AlienStrategyAI_Con'.static.InitializeRegionalAIs();
	//class'XComGameState_LWOverhaulOptions'.static.CreateModSettingsState_ExistingCampaign(class'XComGameState_LWOverhaulOptions');

	class'Override_HookCreation'.static.UpdateBlackMarket();
	class'Override_Storage'.static.UpdateStorage(); // add any infinite starting items we should have had
	class'Override_Storage'.static.UpdateAllSoldiers(); // update starting soldier utility slot count
	class'Override_CountryBonus'.static.UpdateLockAndLoadBonus();  // update XComHQ and Continent states to remove LockAndLoad bonus if it was selected
	class'Override_Tech'.static.UpdateTechs();
}

/// <summary>
/// This method is run when the player loads a saved game directly into Strategy while this DLC is installed
/// </summary>
static event OnLoadedSavedGameToStrategy()
{
	local XComGameStateHistory History;
	local XComGameState_Objective ObjectiveState;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState, UpdatedUnitState;
	local XComGameState_MissionSite Mission, UpdatedMission;
	local string TemplateString, NewTemplateString;
	local name TemplateName;
	local bool bAnyClassNameChanged;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local XComGameState_HeadquartersAlien AlienHQ;
	local X2StrategyElementTemplateManager	StratMgr;
	local MissionDefinition MissionDef;

	//this method can handle case where RegionalAI components already exist
	class'WorldRegion_XComGameState_AlienStrategyAI_Con'.static.InitializeRegionalAIs();
	class'XComGameState_LWListenerManager'.static.RefreshListeners();

	class'Override_HookCreation'.static.UpdateBlackMarket();
	RemoveDarkEventObjectives();

	//make sure that critical narrative moments are active
	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Objective', ObjectiveState)
	{
		if(ObjectiveState.GetMyTemplateName() == 'N_GPCinematics')
		{
			if (ObjectiveState.ObjState != eObjectiveState_InProgress)
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Forcing N_GPCinematics active");
				ObjectiveState = XComGameState_Objective(NewGameState.CreateStateObject(class'XComGameState_Objective', ObjectiveState.ObjectID));
				NewGameState.AddStateObject(ObjectiveState);
				ObjectiveState.StartObjective(NewGameState, true);
				History.AddGameStateToHistory(NewGameState);
			}
			break;
		}
	}

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	//patch in new AlienAI actions if needed
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	if (AlienHQ != none && AlienHQ.Actions.Find('AlienAI_PlayerInstantLoss') == -1)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add new Alien AI Actions");
		AlienHQ = XComGameState_HeadquartersAlien(NewGameState.CreateStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));
		NewGameState.AddStateObject(AlienHQ);
		AlienHQ.Actions.AddItem('AlienAI_PlayerInstantLoss');
		History.AddGameStateToHistory(NewGameState);
	}

	//update for name changes
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update for name changes");

	//patch for changing class template names
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		TemplateString = string(UnitState.GetSoldierClassTemplateName());
		if (UnitState.GetSoldierClassTemplate() == none && Left(TemplateString, 2) == "LW")
		{
			bAnyClassNameChanged = true;
			UpdatedUnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			NewGameState.AddStateObject(UpdatedUnitState);

			NewTemplateString = "LWS_" $ GetRightMost(TemplateString);
			UpdatedUnitState.SetSoldierClassTemplate(name(NewTemplateString));
		}
	}

	foreach History.IterateByClassType(class'XComGameState_MissionSite', Mission)
	{
		TemplateName = Mission.Source;
		TemplateString = string(TemplateName);
		//patch for changing mission source template name
		if (StratMgr.FindStrategyElementTemplate(TemplateName) == none && Right(TemplateString, 20) == "GenericMissionSource")
		{
			UpdatedMission = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', Mission.ObjectID));
			NewGameState.AddStateObject(UpdatedMission);

			NewTemplateString = "MissionSource_LWSGenericMissionSource";
			UpdatedMission.Source = name(NewTemplateString);
		}
		//patch for mod adjustments made to final mission mid-campaign
		if (TemplateString == "MissionSource_Final")
		{
			UpdatedMission = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', Mission.ObjectID));
			NewGameState.AddStateObject(UpdatedMission);

			// refresh to current MissionDef
			`TACTICALMISSIONMGR.GetMissionDefinitionForType("GP_Fortress_LW", MissionDef);
			Mission.GeneratedMission.Mission = MissionDef;
		}
	}

	if (bAnyClassNameChanged)
	{
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', `XCOMHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
		XComHQ.SoldierClassDeck.Length = 0; // reset deck for selecting more soldiers
		XComHQ.SoldierClassDistribution.Length = 0; // reset class distribution
		XComHQ.BuildSoldierClassForcedDeck();

		ResistanceHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
		ResistanceHQ = XComGameState_HeadquartersResistance(NewGameState.CreateStateObject(class'XComGameState_HeadquartersResistance', ResistanceHQ.ObjectID));
		NewGameState.AddStateObject(ResistanceHQ);
		ResistanceHQ.SoldierClassDeck.Length = 0; // reset class deck for selecting reward soldiers
		ResistanceHQ.BuildSoldierClassDeck();
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
		History.AddGameStateToHistory(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);

	CleanupObsoleteTacticalGamestate();
}

// OnExitPostMissionSequence()
static event OnExitPostMissionSequence()
{
	CleanupObsoleteTacticalGamestate();
}

// RemoveDarkEventObjectives()
static function RemoveDarkEventObjectives()
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_ObjectivesList ObjListState;
	local int idx;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating HQ Storage to add items");
	foreach History.IterateByClassType(class'XComGameState_ObjectivesList', ObjListState)
	{
		break;
	}

	if (ObjListState != none)
	{
		ObjListState = XComGameState_ObjectivesList(NewGameState.CreateStateObject(ObjListState.class, ObjListState.ObjectID));
		NewGameState.AddStateObject(ObjListState);
		for (idx = ObjListState.ObjectiveDisplayInfos.Length - 1; idx >= 0; idx--)
		{
			if (ObjListState.ObjectiveDisplayInfos[idx].bIsDarkEvent)
				ObjListState.ObjectiveDisplayInfos.Remove(idx, 1);
		}
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);
}

// CleanupObsoleteTacticalGamestate()
static function CleanupObsoleteTacticalGamestate()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	local XComGameState_BaseObject BaseObject;
	local int idx, idx2;
	local XComGameState ArchiveState;
	local int LastArchiveStateIndex;
	local XComGameInfo GameInfo;
	local array<XComGameState_Item> InventoryItems;
	local XComGameState_Item Item;

	History = `XCOMHISTORY;
	//mark all transient tactical gamestates as removed
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Test remove all ability gamestates");
	// grab the archived strategy state from the history and the headquarters object
	LastArchiveStateIndex = History.FindStartStateIndex() - 1;
	ArchiveState = History.GetGameStateFromHistory(LastArchiveStateIndex, eReturnType_Copy, false);
	GameInfo = `XCOMGAME;
	idx = 0;
	foreach ArchiveState.IterateByClassType(class'XComGameState_BaseObject', BaseObject)
	{
		if (GameInfo.TransientTacticalClassNames.Find( BaseObject.Class.Name ) != -1)
		{
			NewGameState.RemoveStateObject(BaseObject.ObjectID);
			idx++;
		}
	}
	`LWTRACE("REMOVED " $ idx $ " tactical transient gamestates when loading into strategy");
	if (default.ShouldCleanupObsoleteUnits)
	{
		idx = 0;
		idx2 = 0;
		foreach ArchiveState.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if (UnitTypeShouldBeCleanedUp(UnitState))
			{
				InventoryItems = UnitState.GetAllInventoryItems(ArchiveState);
				foreach InventoryItems (Item)
				{
					NewGameState.RemoveStateObject (Item.ObjectID);
					idx2++;
				}
				NewGameState.RemoveStateObject (UnitState.ObjectID);
				idx++;
			}
		}
	}
	`LWTRACE("REMOVED " $ idx $ " obsolete enemy unit gamestates when loading into strategy");
	`LWTRACE("REMOVED " $ idx2 $ " obsolete enemy item gamestates when loading into strategy");

	History.AddGameStateToHistory(NewGameState);
}

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// Allows dlcs/mods to modify the start state before launching into the mission
/// </summary>
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	local XComGameStateHistory History;
	local XComGameState_PointOfInterest POIState;
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_MissionCalendar CalendarState;

	`ACTIVITYMGR.UpdatePreMission (StartGameState, MissionState);
	ResetDelayedEvac(StartGameState);
	ResetReinforcements(StartGameState);
	InitializePodManager(StartGameState);

	// Test Code to see if DLC POI replacement is working
	if (MissionState.POIToSpawn.ObjectID > 0)
	{
		POIState = XComGameState_PointOfInterest(StartGameState.GetGameStateForObjectID(MissionState.POIToSpawn.ObjectID));
		if (POIState == none)
		{
			POIState = XComGameState_PointOfInterest(`XCOMHISTORY.GetGameStateForObjectID(MissionState.POIToSpawn.ObjectID));
		}
	}
	`LWTRACE("PreMission : MissonPOI ObjectID = " $ MissionState.POIToSpawn.ObjectID);
	if (POIState != none)
	{
		`LWTRACE("PreMission : MissionPOI name = " $ POIState.GetMyTemplateName());
	}

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	CalendarState = XComGameState_MissionCalendar(History.GetSingleGameStateObjectForClass(class'XComGameState_MissionCalendar'));
	//log some info relating to the AH POI 2 replacement conditions to see what might be causing it to not spawn
	`LWTRACE("============= POI_AlienNest Debug Info ========================");
	`LWTRACE("Mission POI to Replace                  : " $ string(MissionState.POIToSpawn.ObjectID > 0));
	foreach History.IterateByClassType(class'XComGameState_PointOfInterest', POIState)
	{
	`LWTRACE("     XCGS_PointOfInterest found : " $ POIState.GetMyTemplateName());
		if (POIState.GetMyTemplateName() == 'POI_AlienNest')
		{
			break;
		}
	}
	if (POIState != none && POIState.GetMyTemplateName() == 'POI_AlienNest')
	{
		`LWTRACE("XCGS_PointOfInterest for POI_AlienNest  : found");
	}
	else
	{
		`LWTRACE("XCGS_PointOfInterest for POI_AlienNest  : NOT found");
	}
	`LWTRACE("DLC_HunterWeapons objective complete    : " $ string(`XCOMHQ.IsObjectiveCompleted('DLC_HunterWeapons')));
	`LWTRACE("Time Test Passed                        : " $ string(class'X2StrategyGameRulesetDataStructures'.static.LessThan(AlienHQ.ForceLevelIntervalEndTime, CalendarState.CurrentMissionMonth[0].SpawnDate)));
	`LWTRACE("     AlienHQ       ForceLevelIntervalEndTime        : " $ class'X2StrategyGameRulesetDataStructures'.static.GetDateString(AlienHQ.ForceLevelIntervalEndTime) $ ", " $ class'X2StrategyGameRulesetDataStructures'.static.GetTimeString(AlienHQ.ForceLevelIntervalEndTime));
	`LWTRACE("     CalendarState CurrentMissionMonth[0] SpawnDate : " $ class'X2StrategyGameRulesetDataStructures'.static.GetDateString(CalendarState.CurrentMissionMonth[0].SpawnDate) $ ", " $ class'X2StrategyGameRulesetDataStructures'.static.GetTimeString(CalendarState.CurrentMissionMonth[0].SpawnDate));
	`LWTRACE("ForceLevel Test Passed                  : " $ string(AlienHQ.GetForceLevel() + 1 >= 4));
	`LWTRACE("     AlienHQ ForceLevel  : " $ AlienHQ.GetForceLevel());
	`LWTRACE("     Required ForceLevel : 4");
	`LWTRACE("===============================================================");
}

// ResetDelayedEvac(XComGameState StartGameState)
// Clean up any stale delayed evac spawners that may be left over from a previous mission that ended while
// a counter was active.
static function ResetDelayedEvac(XComGameState StartGameState)
{
	local EvacZone_XComGameState_EvacSpawner EvacState;

	EvacState = EvacZone_XComGameState_EvacSpawner(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'EvacZone_XComGameState_EvacSpawner', true));

	if (EvacState != none && EvacState.GetCountdown() >= 0)
	{
		EvacState = EvacZone_XComGameState_EvacSpawner(StartGameState.CreateStateObject(class'EvacZone_XComGameState_EvacSpawner', EvacState.ObjectID));
		EvacState.ResetCountdown();
		StartGameState.AddStateObject(EvacState);
	}
}

// ResetReinforcements(XComGameState StartGameState)
// Reset the reinforcements system for the new mission.
static function ResetReinforcements(XComGameState StartGameState)
{
	local XComGameState_LWReinforcements Reinforcements;

	Reinforcements = XComGameState_LWReinforcements(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_LWReinforcements', true));

	if (Reinforcements == none)
	{
		Reinforcements = XComGameState_LWReinforcements(StartGameState.CreateStateObject(class'XComGameState_LWReinforcements'));
	}
	else
	{
		Reinforcements = XComGameState_LWReinforcements(StartGameState.CreateStateObject(class'XComGameState_LWReinforcements', Reinforcements.ObjectID));
	}

	Reinforcements.Reset();
	StartGameState.AddStateObject(Reinforcements);
}

// InitializePodManager(XComGameState StartGameState)
static function InitializePodManager(XComGameState StartGameState)
{
	local XComGameState_LWPodManager PodManager;

	PodManager = XComGameState_LWPodManager(StartGameState.CreateStateObject(class'XComGameState_LWPodManager'));
	`LWTrace("Created pod manager");
	StartGameState.AddStateObject(PodManager);
}

/// <summary>
/// Called when the player completes a mission while this DLC / Mod is installed.
/// </summary>
static event OnPostMission()
{
	class'XComGameState_LWListenerManager'.static.RefreshListeners();
	class'Override_HookCreation'.static.UpdateBlackMarket();
	`SQUADMGR.UpdateSquadPostMission(, true); // completed mission
	// `LWOUTPOSTMGR.UpdateOutpostsPostMission();
}

/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated()
{
	local XComParcelManager ParcelMgr;
	local int i;
	local int j;
	local int k;

	//`LWDEBUG("Starting OnPostTemplatesCreated");
	class'LWTemplateMods_Utilities'.static.UpdateTemplates();

	// Go over the plot list and add new objectives to certain plots.
	ParcelMgr = `PARCELMGR;
	if (ParcelMgr != none)
	{
		`LWTrace("Modding plot objectives");
		for (i = 0; i < default.PlotObjectiveMods.Length; ++i)
		{
			for (j = 0; j < ParcelMgr.arrPlots.Length; ++j)
			{
				if (ParcelMgr.arrPlots[j].MapName == default.PlotObjectiveMods[i].MapName)
				{
					for (k = 0; k < default.PlotObjectiveMods[i].ObjectiveTags.Length; ++k)
					{
						ParcelMgr.arrPlots[j].ObjectiveTags.AddItem(default.PlotObjectiveMods[i].ObjectiveTags[k]);
						`LWTrace("Adding objective " $ default.PlotObjectiveMods[i].ObjectiveTags[k] $ " to plot " $ ParcelMgr.arrPlots[j].MapName);
					}
					break;
				}
			}
		}

		// Remove a mod-specified set of parcels (e.g. to replace them with modded versions).
		for (i = 0; i < default.ParcelsToRemove.Length; ++i)
		{
			j = ParcelMgr.arrAllParcelDefinitions.Find('MapName', default.ParcelsToRemove[i]);
			if (j >= 0)
			{
				`LWTrace("Removing parcel definition " $ default.ParcelsToRemove[i]);
				ParcelMgr.arrAllParcelDefinitions.Remove(j, 1);
			}
		}
	}
}

/// <summary>
/// Called when viewing mission blades with the Shadow Chamber panel, used primarily to modify tactical tags for spawning
/// Returns true when the mission's spawning info needs to be updated
/// Force regeneration of final Fortress mission so it collects any changes made since campaign start
/// </summary>
static function bool UpdateShadowChamberMissionInfo(StateObjectReference MissionRef)
{
	local XComGameState_MissionSite MissionSiteState;

	if (MissionRef.ObjectID <= 0)
	{
		return false;
	}
	MissionSiteState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));
	if (MissionSiteState == none)
	{
		return false;
	}
	switch(MissionSiteState.GeneratedMission.Mission.sType)
	{
		case "GP_Fortress":
		case "GP_Fortress_LW":
			`LWTRACE("UpdateShadowChamgerMissionInfo : Fortress mission detected - returning true to force mission schedule regeneration.");
			return true;
		default:
			break;
	}
	return false;
}

/// <summary>
/// Called from X2AbilityTag:ExpandHandler after processing the base game tags. Return true (and fill OutString correctly)
/// to indicate the tag has been expanded properly and no further processing is needed.
/// </summary>
static function bool AbilityTagExpandHandler(string InString, out string OutString)
{
	class'Override_AbilityTag'.static.AbilityTagExpandHandler(InString, OutString);
}

/// <summary>
/// Called from XComGameState_Unit:GatherUnitAbilitiesForInit after the game has built what it believes is the full list of
/// abilities for the unit based on character, class, equipment, et cetera. You can add or remove abilities in SetupData.
/// Use SLG hook to add infiltration modifiers to alien units
/// </summary>
static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay)
{
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateMan;
	local name AbilityName;
	local AbilitySetupData Data, EmptyData;
	local X2CharacterTemplate CharTemplate;

	if (`XENGINE.IsMultiplayerGame()) { return; }

	CharTemplate = UnitState.GetMyTemplate();
	if (CharTemplate == none)
		return;
	if (ShouldApplyInfiltrationModifierToCharacter(CharTemplate))
	{
		AbilityName = 'InfiltrationTacticalModifier_LW';
		if (SetupData.Find('TemplateName', AbilityName) == -1)
		{
			AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
			AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(AbilityName);

			if(AbilityTemplate != none)
			{
				Data = EmptyData;
				Data.TemplateName = AbilityName;
				Data.Template = AbilityTemplate;
				SetupData.AddItem(Data);  // return array -- we don't have to worry about additional abilities for this simple ability
			}
		}
	}
}

// ShouldApplyInfiltrationModifierToCharacter(X2CharacterTemplate CharTemplate)
static function bool ShouldApplyInfiltrationModifierToCharacter(X2CharacterTemplate CharTemplate)
{
	// Specific character types should never have an infiltration modifier applied.
	if (default.CharacterTypesExceptFromInfiltrationModifiers.Find(CharTemplate.DataName) >= 0)
	{
		return false;
	}

	// Otherwise anything that's alien or advent gets one
	return CharTemplate.bIsAdvent || CharTemplate.bIsAlien;
}

/// <summary>
/// Called from XComUnitPawn.DLCAppendSockets
/// append sockets to the human skeletal meshes for the new secondary weapons
/// </summary>
static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	local SocketReplacementInfo SocketReplacement;
	local name TorsoName;
	local bool bIsFemale;
	local string DefaultString, ReturnString;
	local XComHumanPawn HumanPawn;

	HumanPawn = XComHumanPawn(Pawn);
	if (HumanPawn == none) { return ""; }

	TorsoName = HumanPawn.m_kAppearance.nmTorso;
	bIsFemale = HumanPawn.m_kAppearance.iGender == eGender_Female;

	//`LWTRACE("DLCAppendSockets: Torso= " $ TorsoName $ ", Female= " $ string(bIsFemale));

	foreach default.SocketReplacements(SocketReplacement)
	{
		if (TorsoName != 'None' && TorsoName == SocketReplacement.TorsoName && bIsFemale == SocketReplacement.Female)
		{
			ReturnString = SocketReplacement.SocketMeshString;
			break;
		}
		else
		{
			if (SocketReplacement.TorsoName == 'Default' && SocketReplacement.Female == bIsFemale)
			{
				DefaultString = SocketReplacement.SocketMeshString;
			}
		}
	}
	if (ReturnString == "")
	{
		// did not find, so use default
		ReturnString = DefaultString;
	}
	//`LWTRACE("Returning mesh string: " $ ReturnString);
	return ReturnString;
}

/// <summary>
/// Calls DLC specific handlers to override spawn location
/// enlarge the deployable area so can spawn more units
/// </summary>
static function bool GetValidFloorSpawnLocations(out array<Vector> FloorPoints, XComGroupSpawn SpawnPoint)
{
	local TTile RootTile, Tile;
	local array<TTile> FloorTiles;
	local XComWorldData World;
	local int Length, Width, Height, NumSoldiers, Iters;
	local bool Toggle;

	Length = 3;
	Width = 3;
	Height = 1;
	Toggle = false;
	if(`XCOMHQ != none)
		NumSoldiers = `XCOMHQ.Squad.Length;
	else
		NumSoldiers = class'X2StrategyGameRulesetDataStructures'.static.GetMaxSoldiersAllowedOnMission();

	// For TQL, etc, where the soldier are coming from the Start State, always reserve space for 8 soldiers
	if (NumSoldiers == 0)
		NumSoldiers = 8;

	// On certain mission types we need to reserve space for more units in the spawn area.
	switch (class'Utilities_LW'.static.CurrentMissionType())
	{
	case "RecruitRaid_LW":
		// Recruit raid spawns rebels with the squad, so we need lots of space for the rebels + liaison.
		NumSoldiers += class'X2StrategyElement_DefaultAlienActivities'.default.RAID_MISSION_MAX_REBELS + 1;
		break;
	case "Terror_LW":
	case "Defend_LW":
	case "Invasion_LW":
	case "IntelRaid_LW":
	case "SupplyConvoy_LW":
	case "Rendezvous_LW":
		// Reserve space for the liaison
		++NumSoldiers;
		break;
	}

	if (NumSoldiers >= 6)
	{
		Length = 4;
		Iters--;
	}
	if (NumSoldiers >= 9)
	{
		Width = 4;
		Iters--;
	}
	if (NumSoldiers >= 12)
	{
		Length = 5;
		Width = 5;
	}
	World = `XWORLD;
	RootTile = SpawnPoint.GetTile();
	while(FloorPoints.Length < NumSoldiers && Iters++ < 8)
	{
		FloorPoints.Length = 0;
		FloorTiles.Length = 0;
		RootTile.X -= Length/2;
		RootTile.Y -= Width/2;

		World.GetSpawnTilePossibilities(RootTile, Length, Width, Height, FloorTiles);

		foreach FloorTiles(Tile)
		{
			// Skip any tile that is going to be destroyed on tactical start.
			if (IsTilePositionDestroyed(Tile))
				continue;
			FloorPoints.AddItem(World.GetPositionFromTileCoordinates(Tile));
		}
		if(Toggle)
			Width ++;
		else
			Length ++;

		Toggle = !Toggle;
	}

	`LWTRACE("GetValidFloorSpawnLocations called from : " $ GetScriptTrace());
	`LWTRACE("Found " $ FloorPoints.Length $ " Valid Tiles to place units around location : " $ string(SpawnPoint.Location));
	for (Iters = 0; Iters < FloorPoints.Length; Iters++)
	{
		`LWTRACE("Point[" $ Iters $ "] = " $ string(FloorPoints[Iters]));
	}

	return true;
}

// IsTilePositionDestroyed(TTile Tile)
// The XComTileDestructionActor contains a list of positions that it will destroy before the mission starts.
// These will report as valid floor tiles at the point we are searching for valid spawn tiles (because they
// are, now) but after the mission starts their tile will disappear and they will be unable to move.
//
// Given a potential spawn floor tile, check to see if this tile will be destroyed on mission start, so we
// can exclude them as candidates.
static function bool IsTilePositionDestroyed(TTile Tile)
{
	local XComTileDestructionActor TileDestructionActor;
	local Vector V;
	local IntPoint ParcelBoundsMin, ParcelBoundsMax;
	local XComGameState_BattleData BattleData;
	local XComParcelManager ParcelManager;
	local XComWorldData World;
	local XComParcel Parcel;
	local int i;
	local TTile DestroyedTile;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	ParcelManager = `PARCELMGR;
	World = `XWORLD;

	// Find the parcel containing this tile.
	for (i = 0; i < BattleData.MapData.ParcelData.Length; ++i)
	{
		Parcel = ParcelManager.arrParcels[BattleData.MapData.ParcelData[i].ParcelArrayIndex];

		// Find the parcel this tile is in.
		Parcel.GetTileBounds(ParcelBoundsMin, ParcelBoundsMax);
		if (Tile.X >= ParcelBoundsMin.X && Tile.X <= ParcelBoundsMax.X &&
			Tile.Y >= ParcelBoundsMin.Y && Tile.Y <= ParcelBoundsMax.Y)
		{
			break;
		}
	}

	foreach `BATTLE.AllActors(class'XComTileDestructionActor', TileDestructionActor)
	{
		foreach TileDestructionActor.PositionsToDestroy(V)
		{
			// The vectors within the XComTileDestructionActor are relative to the origin
			// of the associated parcel itself. So each destroyed position needs to be rotated
			// and translated based on the location of the destruction actor before we look up
			// the tile position to account for the particular map layout.
			V = V >> TileDestructionActor.Rotation;
			V += TileDestructionActor.Location;
			DestroyedTile = World.GetTileCoordinatesFromPosition(V);
			if (DestroyedTile == Tile)
			{
				return true;
			}
		}
	}

	return false;
}