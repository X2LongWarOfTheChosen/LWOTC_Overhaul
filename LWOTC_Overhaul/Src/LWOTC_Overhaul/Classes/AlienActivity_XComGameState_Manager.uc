//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWAlienActivityManager.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: This is the singleton, overall alien strategic manager for generating/managing activities
//---------------------------------------------------------------------------------------
class AlienActivity_XComGameState_Manager extends XComGameState_GeoscapeEntity dependson(AlienActivity_X2StrategyElementTemplate) config(LW_Activities);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int AVATAR_DELAY_HOURS_PER_NET_GLOBAL_VIG;

var TDateTime NextUpdateTime;
var array<ActivityCooldownTimer> GlobalCooldowns;

//#############################################################################################
//----------------   INITIALIZATION   ---------------------------------------------------------
//#############################################################################################

// OnInit(XComGameState NewGameState)
function OnInit(XComGameState NewGameState)
{
	NextUpdateTime = class'UIUtilities_Strategy'.static.GetGameTime().CurrentTime;
}

// GetStrategyTemplateManager()
static function X2StrategyElementTemplateManager GetStrategyTemplateManager()
{
	return class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
}

// GetAlienActivityManager(optional bool AllowNULL = false)
static function AlienActivity_XComGameState_Manager GetAlienActivityManager(optional bool AllowNULL = false)
{
    return AlienActivity_XComGameState_Manager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'AlienActivity_XComGameState_Manager', AllowNULL));
}

// CreateAlienActivityManager(optional XComGameState StartState)
static function CreateAlienActivityManager(optional XComGameState StartState)
{
	local AlienActivity_XComGameState_Manager ActivityMgr;
	local XComGameState NewGameState;

	//first check that there isn't already a singleton instance of the squad manager
	if(GetAlienActivityManager(true) != none)
		return;

	if(StartState != none)
	{
		ActivityMgr = AlienActivity_XComGameState_Manager(StartState.CreateStateObject(class'AlienActivity_XComGameState_Manager'));
		StartState.AddStateObject(ActivityMgr);
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating LW Alien Activity Manager Quasi-singleton");
		ActivityMgr = AlienActivity_XComGameState_Manager(NewGameState.CreateStateObject(class'AlienActivity_XComGameState_Manager'));
		ActivityMgr.OnInit(NewGameState);
		NewGameState.AddStateObject(ActivityMgr);
		`XCOMHISTORY.AddGameStateToHistory(NewGameState);
	}
}

//#############################################################################################
//----------------   UPDATE   -----------------------------------------------------------------
//#############################################################################################

// Update(XComGameState NewGameState)
function bool Update(XComGameState NewGameState)
{
	local bool bUpdated;
	local array<X2StrategyElementTemplate> ActivityTemplates;
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local int idx, NumActivities, ActivityIdx;
	local AlienActivity_XComGameState NewActivityState;
	local AlienActivity_XComGameState_Manager UpdatedActivityMgr;
	local ActivityCooldownTimer Cooldown;
	local array<ActivityCooldownTimer> CooldownsToRemove;
	local StateObjectReference PrimaryRegionRef;

	bUpdated = false;
	
	if (class'X2StrategyGameRulesetDataStructures'.static.LessThan(NextUpdateTime, `STRATEGYRULES.GameTime))
	{
		//`LOG("Alien Activity Manager : Updating, CurrentTime=" $ 
			//class'X2StrategyGameRulesetDataStructures'.static.GetTimeString(`STRATEGYRULES.GameTime) $ ":" $ class'X2StrategyGameRulesetDataStructures'.static.GetDateString(`STRATEGYRULES.GameTime) $
			//", NextUpdateTime=" $ class'X2StrategyGameRulesetDataStructures'.static.GetTimeString(NextUpdateTime) $ ":" $ class'X2StrategyGameRulesetDataStructures'.static.GetDateString(NextUpdateTime));

		ValidatePendingDarkEvents(NewGameState);

		//Update Global Cooldowns
		foreach GlobalCooldowns(Cooldown)
		{
			if(class'X2StrategyGameRulesetDataStructures'.static.LessThan(Cooldown.CooldownDateTime, class'XComGameState_GeoscapeEntity'.static.GetCurrentTime()))
			{
				CooldownsToRemove.AddItem(Cooldown);
			}
		}
		if(CooldownsToRemove.Length > 0)
		{
			foreach CooldownsToRemove(Cooldown)
			{
				GlobalCooldowns.RemoveItem(Cooldown);
			}
			bUpdated = true;
		}

		//AlienActivity Creation
		ActivityTemplates = GetStrategyTemplateManager().GetAllTemplatesOfClass(class'AlienActivity_X2StrategyElementTemplate');
		ActivityTemplates = RandomizeOrder(ActivityTemplates);
		ActivityTemplates.Sort(ActivityPrioritySort);
		for(idx = 0; idx < ActivityTemplates.Length; idx++)
		{
			ActivityTemplate = AlienActivity_X2StrategyElementTemplate(ActivityTemplates[idx]);
			if(GlobalCooldowns.Find('ActivityName', ActivityTemplate.DataName) == -1)
			{
				if(ActivityTemplate == none)
				{
					bUpdated = bUpdated;
				}
				ActivityTemplate.ActivityCreation.InitActivityCreation(ActivityTemplate, NewGameState);
				NumActivities = ActivityTemplate.ActivityCreation.GetNumActivitiesToCreate(NewGameState);
				for(ActivityIdx = 0 ; ActivityIdx < NumActivities; ActivityIdx++)
				{
					PrimaryRegionRef = ActivityTemplate.ActivityCreation.GetBestPrimaryRegion(NewGameState);
					if(PrimaryRegionRef.ObjectID > 0)
					{
						bUpdated = true;
						NewActivityState = ActivityTemplate.CreateInstanceFromTemplate(PrimaryRegionRef, NewGameState);
						NewGameState.AddStateObject(NewActivityState);
					}
				}
			}
		}

		//update activity creation timer
		UpdatedActivityMgr = AlienActivity_XComGameState_Manager(NewGameState.CreateStateObject(Class, ObjectID));
		if(class'X2StrategyGameRulesetDataStructures'.static.DifferenceInHours(class'XComGameState_GeoscapeEntity'.static.GetCurrentTime(), NextUpdateTime) > 20 * class'AlienActivity_X2StrategyElementTemplate'.default.HOURS_BETWEEN_ALIEN_ACTIVITY_MANAGER_UPDATES)
		{
			NextUpdateTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();

		}
		class'X2StrategyGameRulesetDataStructures'.static.AddDay(UpdatedActivityMgr.NextUpdateTime);
		NewGameState.AddStateObject(UpdatedActivityMgr);
		bUpdated = true;
	}

	return bUpdated;
}

// UpdateGameBoard()
function UpdateGameBoard()
{
	local XComGameState NewGameState;
	local AlienActivity_XComGameState_Manager AAMState;
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	History = `XCOMHISTORY;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Regional AIs");
	foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);

		if (!RegionalAI.UpdateRegionalAI(NewGameState))
			NewGameState.PurgeGameStateForObjectID(RegionalAI.ObjectID);
	}
	if (NewGameState.GetNumGameStateObjects() > 0)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);


	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update/Create Alien Activities");
	AAMState = AlienActivity_XComGameState_Manager(NewGameState.CreateStateObject(class'AlienActivity_XComGameState_Manager', ObjectID));
	NewGameState.AddStateObject(AAMState);

	if (!AAMState.Update(NewGameState))
		NewGameState.PurgeGameStateForObjectID(AAMState.ObjectID);

	if (NewGameState.GetNumGameStateObjects() > 0)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);
}

//#############################################################################################
//----------------   UTILITY   ----------------------------------------------------------------
//#############################################################################################

// UpdatePreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
// for now, just setting based on liberation status. if finer control is needed, consider adding an activity template delegate
function UpdatePreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_BattleData BattleData;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;

	foreach StartGameState.IterateByClassType (class'XComGameState_BattleData', BattleData)
	{
		break;
	}
	if (BattleData == none)
	{
		`REDSCREEN ("OnPreMission called by cannot retrieve BattleData");
		return;
	}
	RegionState = MissionState.GetWorldRegion();
	if (RegionState == none) { return; }
	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
	if (RegionalAIState != none && RegionalAIState.bLiberated)
	{
		// set the popular support high so that civs won't be hostile
		BattleData.SetPopularSupport(1000);
		BattleData.SetMaxPopularSupport(1000);
	}
}

// ValidatePendingDarkEvents(optional XComGameState NewGameState)
function ValidatePendingDarkEvents(optional XComGameState NewGameState)
{
	local array<StateObjectReference> InvalidDarkEvents, ValidDarkEvents;
	local StateObjectReference DarkEventRef;
	local array<AlienActivity_XComGameState> AllActivities;
	local AlienActivity_XComGameState Activity;
	local XComGameState_HeadquartersAlien UpdateAlienHQ;
	local bool bNeedsUpdate;

	//History = `XCOMHISTORY;
	bNeedsUpdate = NewGameState == none;
	if (bNeedsUpdate)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Validating Pending Dark Events");
	}
	
	UpdateAlienHQ = GetAlienHQ(NewGameState);

	AllActivities = GetAllActivities();
	foreach AllActivities(Activity)
	{
		if (Activity.DarkEvent.ObjectID > 0)
		{
			ValidDarkEvents.AddItem(Activity.DarkEvent);
		}
	}
	foreach UpdateAlienHQ.ChosenDarkEvents (DarkEventRef)
	{
		if (ValidDarkEvents.Find ('ObjectID', DarkEventRef.ObjectID) == -1)
		{
			InvalidDarkEvents.AddItem(DarkEventRef);
		}
	}
	if (InvalidDarkEvents.length > 0)
	{
		`LWTRACE("------------------------------------------");
		`LWTRACE ("Found invalid dark events when validating.");
		`LWTRACE("------------------------------------------");
		foreach InvalidDarkEvents(DarkEventRef)
		{
			UpdateAlienHQ.ChosenDarkEvents.RemoveItem(DarkEventRef);
		}
	}

	if (bNeedsUpdate)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
}

// GetAllActivities(optional XComGameState NewGameState)
static function array<AlienActivity_XComGameState> GetAllActivities(optional XComGameState NewGameState)
{
	local array<AlienActivity_XComGameState> arrActivities;
	local array<StateObjectReference> arrActivityRefs;
	local AlienActivity_XComGameState ActivityState;
	local XComGameStateHistory History;
	
	History = `XCOMHISTORY;
	if(NewGameState != none)
	{
		foreach NewGameState.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
		{
			arrActivities.AddItem(ActivityState);
			arrActivityRefs.AddItem(ActivityState.GetReference());
		}
	}
	foreach History.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
	{
		if(arrActivityRefs.Find('ObjectID', ActivityState.ObjectID) == -1)
		{
			arrActivities.AddItem(ActivityState);
		}
	}

	return arrActivities;
}

// FindAlienActivityByMission(XComGameState_MissionSite MissionSite)
static function AlienActivity_XComGameState FindAlienActivityByMission(XComGameState_MissionSite MissionSite)
{
	return FindAlienActivityByMissionRef(MissionSite.GetReference());
}

// FindAlienActivityByMissionRef(StateObjectReference MissionRef)
static function AlienActivity_XComGameState FindAlienActivityByMissionRef(StateObjectReference MissionRef)
{
	local XComGameStateHistory History;
	local AlienActivity_XComGameState ActivityState;
	local XComGameState StrategyState;
	local int LastStrategyStateIndex;
	
	History = `XCOMHISTORY;
	
	if (`TACTICALRULES != none && `TACTICALRULES.TacticalGameIsInPlay())
	{
		// grab the archived strategy state from the history and the headquarters object
		LastStrategyStateIndex = History.FindStartStateIndex() - 1;
		StrategyState = History.GetGameStateFromHistory(LastStrategyStateIndex, eReturnType_Copy, false);
		foreach StrategyState.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
		{
			if(ActivityState.CurrentMissionRef.ObjectID == MissionRef.ObjectID)
				return ActivityState;
		}
	}
	else
	{
		foreach History.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
		{
			if(ActivityState.CurrentMissionRef.ObjectID == MissionRef.ObjectID)
				return ActivityState;
		}
	}
	return none;
}

// UpdateMissionData(XComGameState_MissionSite MissionSite)
static function UpdateMissionData(XComGameState_MissionSite MissionSite)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;
	local int ForceLevel, AlertLevel, i;
	local Squad_XComGameState InfiltratingSquad;
	local SquadManager_XComGameState SquadMgr;
	local AlienActivity_XComGameState ActivityState;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;
	local array<X2DownloadableContentInfo> DLCInfos;
	local MissionDefinition MissionDef;
	local name NewMissionFamily;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	SquadMgr = `SQUADMGR;
	InfiltratingSquad = SquadMgr.Squads.GetSquadOnMission(MissionSite.GetReference());
	ActivityState = FindAlienActivityByMission(MissionSite);
	RegionState = MissionSite.GetWorldRegion();
	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);

	//ForceLevel : what types of aliens are present
	if(ActivityState != none && ActivityState.GetMyTemplate().GetMissionForceLevelFn != none)
	{
		ForceLevel = ActivityState.GetMyTemplate().GetMissionForceLevelFn(ActivityState, MissionSite, none);
	}
	else
	{
		if(RegionalAIState != none)
			ForceLevel = RegionalAIState.LocalForceLevel;
		else
			ForceLevel = AlienHQ.GetForceLevel();
	}
	ForceLevel = Clamp(ForceLevel, class'XComGameState_HeadquartersAlien'.default.AlienHeadquarters_StartingForceLevel, class'XComGameState_HeadquartersAlien'.default.AlienHeadquarters_MaxForceLevel);

	//AlertLevel : how many pods, how many aliens in each pod, types of pods, etc (from MissionSchedule)
	AlertLevel = GetMissionAlertLevel(MissionSite);

	//modifiers
	if (InfiltratingSquad != none && !MissionSite.GetMissionSource().bGoldenPath)
		AlertLevel += InfiltratingSquad.InfiltrationState.GetAlertnessModifierForCurrentInfiltration(); // this submits its own gamestate update
	AlertLevel = Max(AlertLevel, 1); // clamp to be no less than 1

	`LWTRACE("Updating Mission Difficulty: ForceLevel=" $ ForceLevel $ ", AlertLevel=" $ AlertLevel);

	// add explicit hook so that DLCs can update (e.g. AlienHunters to add Rulers) -- these are assumed to submit their own gamestate updates
	DLCInfos = `ONLINEEVENTMGR.GetDLCInfos(false);
	for(i = 0; i < DLCInfos.Length; ++i)
	{
		if (DLCInfos[i].UpdateShadowChamberMissionInfo(MissionSite.GetReference()))
		{
			`LWTRACE("UpdateShadowChamberMissionInfo substituted in something -- probably an alien ruler");
		}
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Mission Data");
	MissionSite = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', MissionSite.ObjectID));
	NewGameState.AddStateObject (MissionSite);

	//update the mission encounters in case they were updated (e.g. mod update)
	if (`TACTICALMISSIONMGR.GetMissionDefinitionForType(MissionSite.GeneratedMission.Mission.sType, MissionDef))
	{
		// get here if the mission wasn't removed in the update
		MissionSite.GeneratedMission.Mission = MissionDef;
	}
	else
	{
		//the whole mission in the current save was removed, so we need to get a new one
		`REDSCREEN ("Mission type " $ MissionSite.GeneratedMission.Mission.sType $ " removed in update. Attempting to recover.");
		NewMissionFamily = ActivityState.GetNextMissionFamily(none);
		MissionSite.GeneratedMission.Mission = ActivityState.GetMissionDefinitionForFamily(NewMissionFamily);
	}

	//cache the difficulty
	MissionSite.CacheSelectedMissionData(ForceLevel, AlertLevel);

	if (NewGameState.GetNumGameStateObjects() > 0)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);

}

// GetMissionAlertLevel(XComGameState_MissionSite MissionSite)
static function int GetMissionAlertLevel(XComGameState_MissionSite MissionSite)
{
	local AlienActivity_XComGameState ActivityState;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;
	local int AlertLevel;
	
	ActivityState = FindAlienActivityByMission(MissionSite);
	RegionState = MissionSite.GetWorldRegion();
	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
	if(ActivityState != none && ActivityState.GetMyTemplate().GetMissionAlertLevelFn != none)
	{
		AlertLevel = ActivityState.GetMyTemplate().GetMissionAlertLevelFn(ActivityState, MissionSite, none);
	}
	else if (MissionSite.GetMissionSource().bGoldenPath)
	{
		AlertLevel = `CAMPAIGNDIFFICULTYSETTING + 1;
	}
	else if(RegionalAIState != none)
	{
		AlertLevel = RegionalAIState.LocalAlertLevel;
	}
	else
	{
		AlertLevel = MissionSite.GetMissionDifficulty(); // this should basically never happen
	}
	if(`XCOMHQ.TacticalGameplayTags.Find('DarkEvent_ShowOfForce') != INDEX_NONE)
	{
		AlertLevel ++;
	}
	return AlertLevel;
}

// ActivityPrioritySort(AlienActivity_X2StrategyElementTemplate TemplateA, AlienActivity_X2StrategyElementTemplate TemplateB)
private function int ActivityPrioritySort(AlienActivity_X2StrategyElementTemplate TemplateA, AlienActivity_X2StrategyElementTemplate TemplateB)
{
	return (TemplateB.iPriority - TemplateA.iPriority);
}

// RandomizeOrder(const array<X2StrategyElementTemplate> InputActivityTemplates)
static function array<X2StrategyElementTemplate> RandomizeOrder(const array<X2StrategyElementTemplate> InputActivityTemplates)
{
	local array<X2StrategyElementTemplate> Templates;
	local array<X2StrategyElementTemplate> RemainingTemplates;
	local int ArrayLength, idx, Selection;

	ArrayLength = InputActivityTemplates.Length;
	RemainingTemplates = InputActivityTemplates;

	for(idx = 0; idx < ArrayLength; idx++)
	{
		Selection = `SYNC_RAND_STATIC(RemainingTemplates.Length);
		Templates.AddItem(RemainingTemplates[Selection]);
		RemainingTemplates.Remove(Selection, 1);
	}

	return Templates;
}

// AddDoomToFortress(XComGameState NewGameState, int DoomToAdd, optional string DoomMessage, optional bool bCreatePendingDoom = true)
static function AddDoomToFortress(XComGameState NewGameState, int DoomToAdd, optional string DoomMessage, optional bool bCreatePendingDoom = true)
{
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_MissionSite MissionState;
	local PendingDoom DoomPending;
	local int DoomDiff;

	AlienHQ = GetAlienHQ(NewGameState);
	if (AlienHQ == none)
		return;

	DoomDiff = AlienHQ.GetMaxDoom() - AlienHQ.GetCurrentDoom(true);
	DoomToAdd = Clamp(DoomToAdd, 0, DoomDiff);

	if (DoomToAdd <= 0)
		return; // don't set up event, etc for no doom

	MissionState = AlienHQ.GetAndAddFortressMission(NewGameState);

	if(MissionState != none)
	{
		MissionState.Doom += DoomToAdd;

		if(bCreatePendingDoom && class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('LW_T2_M1_N2_RevealAvatarProject'))
		{
			DoomPending.Doom = DoomToAdd;

			if(DoomMessage != "")
			{
				DoomPending.DoomMessage = DoomMessage;
			}
			else
			{
				DoomPending.DoomMessage = class'XComGameState_HeadquartersAlien'.default.HiddenDoomLabel;
			}

			AlienHQ.PendingDoomData.AddItem(DoomPending);
		
			AlienHQ.PendingDoomEntity = MissionState.GetReference();

			if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T5_M1_AutopsyTheAvatar'))
				AlienHQ.PendingDoomEvent = 'OnFortressAddsDoomEndgame';
			else
				AlienHQ.PendingDoomEvent = 'OnFortressAddsDoom';
		}

		class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvatarProgress', DoomToAdd);
	}
}

// AddDoomToRandomFacility(XComGameState NewGameState, int DoomToAdd, optional string DoomMessage)
static function AddDoomToRandomFacility(XComGameState NewGameState, int DoomToAdd, optional string DoomMessage)
{
	local XComGameStateHistory History;
	local AlienActivity_XComGameState ActivityState;
	local array<AlienActivity_XComGameState> ResearchFacilities;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
	{
		if(ActivityState.GetMyTemplateName() == class'Mission_X2StrategyElement_RegionalAvatarResearch'.default.RegionalAvatarResearchName)
		{
			ResearchFacilities.AddItem(ActivityState);
		}
	}
	if(ResearchFacilities.Length > 0)
	{
		ActivityState = ResearchFacilities[`SYNC_RAND_STATIC(ResearchFacilities.Length)];
		AddDoomToFacility(ActivityState, NewGameState, DoomToAdd, DoomMessage);
	}
	else
	{
		AddDoomToFortress(NewGameState, DoomToAdd, DoomMessage);
	}
}

// AddDoomToFacility(AlienActivity_XComGameState ActivityState, XComGameState NewGameState, int DoomToAdd, optional string DoomMessage)
static function AddDoomToFacility(AlienActivity_XComGameState ActivityState, XComGameState NewGameState, int DoomToAdd, optional string DoomMessage)
{
	local XComGameState_MissionSite MissionState;
	local XComGameState_WorldRegion RegionState;
	local PendingDoom DoomPending;
	local XGParamTag ParamTag;
	local int DoomDiff;
	local XComGameState_HeadquartersAlien UpdateAlienHQ;

	UpdateAlienHQ = GetAlienHQ(NewGameState);
	if(UpdateAlienHQ == none)
		return;

	DoomDiff = UpdateAlienHQ.GetMaxDoom() - UpdateAlienHQ.GetCurrentDoom(true);
	DoomToAdd = Clamp(DoomToAdd, 0, DoomDiff);

	if (DoomToAdd <= 0)
		return; // don't set up event, etc for no doom

	if(ActivityState.CurrentMissionRef.ObjectID > 0) // is detected and has a mission
	{
		MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
		if (MissionState == none)
		{
			MissionState = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', ActivityState.CurrentMissionRef.ObjectID));
			NewGameState.AddStateObject(MissionState);
		}
	}
	if(MissionState != none)
		MissionState.Doom += DoomToAdd;
	else
		ActivityState.Doom += DoomToAdd;

	DoomPending.Doom = DoomToAdd;

	if(DoomMessage != "")
	{
		DoomPending.DoomMessage = DoomMessage;
	}
	else
	{
		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		ParamTag.StrValue0 = RegionState.GetDisplayName();
		DoomPending.DoomMessage = `XEXPAND.ExpandString(class'XComGameState_HeadquartersAlien'.default.FacilityDoomLabel);
	}
		
	if (UpdateAlienHQ.bHasSeenDoomMeter && class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('LW_T2_M1_N2_RevealAvatarProject'))
	{
		UpdateAlienHQ.PendingDoomData.AddItem(DoomPending);
		if(MissionState != none)
		{
			UpdateAlienHQ.PendingDoomEntity = MissionState.GetReference();
		}
		UpdateAlienHQ.PendingDoomEvent = 'OnFacilityAddsDoom';
		ActivityState.bNeedsPause = true;
	}
	class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvatarProgress', DoomToAdd);
}

// GetAlienHQ(XComGameState NewGameState)
static function XComGameState_HeadquartersAlien GetAlienHQ(XComGameState NewGameState)
{
	local XComGameState_HeadquartersAlien AlienHQ, UpdateAlienHQ;

	AlienHQ = class'UIUtilities_Strategy'.static.GetAlienHQ(true);
	if(AlienHQ == none)
		return none;

	UpdateAlienHQ = XComGameState_HeadquartersAlien(NewGameState.GetGameStateForObjectID(AlienHQ.ObjectID));
	if(UpdateAlienHQ == none)
	{
		UpdateAlienHQ = XComGameState_HeadquartersAlien(NewGameState.CreateStateObject(AlienHQ.Class, AlienHQ.ObjectID));
		NewGameState.AddStateObject(UpdateAlienHQ);
	}
	return UpdateAlienHQ;
}

// GetDoomUpdateModifierHours(optional AlienActivity_XComGameState ActivityState, optional XComGameState NewGameState)
// compute modifiers to Doom update timers for both facility doom generation and alien hq doom generation
// facility doom will pass in the optional arguments, while the static-timer based alien hq doom will not
static function int GetDoomUpdateModifierHours(optional AlienActivity_XComGameState ActivityState, optional XComGameState NewGameState)
{
	return Max (0, GetNetVigilance() * default.AVATAR_DELAY_HOURS_PER_NET_GLOBAL_VIG);
}

// GetNetVigilance()
static function int GetNetVigilance()
{
	return GetGlobalVigilance() - GetNumAlienRegions() - GetGlobalAlert();
}

// GetGlobalVigilance()
static function int GetGlobalVigilance()
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local int SumVigilance;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
		if(!RegionalAI.bLiberated)
		{
			SumVigilance += RegionalAI.LocalVigilanceLevel;
		}
	}
	return SumVigilance;
}

// GetGlobalAlert()
static function int GetGlobalAlert()
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local int SumAlert;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
		if(!RegionalAI.bLiberated)
		{
			SumAlert += RegionalAI.LocalAlertLevel;
		}
	}
	return SumAlert;
}

// GetNumAlienRegions()
static function int GetNumAlienRegions()
{
	local int kount;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	foreach `XCOMHistory.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
		if(!RegionalAI.bLiberated)
		{
			kount += 1;
		}
	}
	return kount;
}

// GetUIClass()
// We need a UI class for all strategy elements (but they'll never be visible)
function class<UIStrategyMapItem> GetUIClass()
{
    return class'UIStrategyMapItem';
}

// ShouldBeVisible()
// Never show these on the map.
function bool ShouldBeVisible()
{
    return false;
}

