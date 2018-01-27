class Mission_X2StrategyElement_ProtectRegion extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int PROTECTREGION_RESET_LEVEL;
var config int LIBERATE_ADJACENT_VIGILANCE_INCREASE_BASE;
var config int LIBERATE_ADJACENT_VIGILANCE_INCREASE_RAND;
var config int LIBERATION_ALERT_LEVELS_KILLED;							// Number of ADVENT strength destroyed when liberating a region
var config int LIBERATION_ALERT_LEVELS_KILLED_RAND;

var config array<float> INFILTRATION_BONUS_ON_LIBERATION;

var name ProtectRegionEarlyName;
var name ProtectRegionMidName;
var name ProtectRegionName;

defaultProperties
{
	ProtectRegionEarlyName="ProtectRegionEarly";
	ProtectRegionMidName="ProtectRegionMid";
    ProtectRegionName="ProtectRegion";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateProtectRegionEarlyTemplate());
	AlienActivities.AddItem(CreateProtectRegionMidTemplate());
	AlienActivities.AddItem(CreateProtectRegionTemplate());
	
	return AlienActivities;
}

// CreateProtectRegionEarlyTemplate()
static function X2DataTemplate CreateProtectRegionEarlyTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_LiberationStage LiberationStageCondition;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ProtectRegionEarlyName);
	Template.ActivityCategory = 'LiberationSequence';

	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetLiberationCondition());

	LiberationStageCondition = new class 'ActivityCondition_LiberationStage';
	LiberationStageCondition.NoStagesComplete = true;
	LiberationStageCondition.Stage1Complete = false;
	LiberationStageCondition.Stage2Complete = false;
	Template.ActivityCreation.Conditions.AddItem(LiberationStageCondition);

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.UseLiberateDifficultyTable = true;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = none;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = ProtectRegionMissionRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnLiberateStage1Complete;

	return Template;
}

// OnLiberateStage1Complete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnLiberateStage1Complete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion PrimaryRegionState;
	local WorldRegion_XComGameState_AlienStrategyAI PrimaryRegionalAI;

	if(!bAlienSuccess)
	{
		PrimaryRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if(PrimaryRegionState == none)
			PrimaryRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

		if(PrimaryRegionState == none)
		{
			`REDSCREEN("OnProtectRegionActivityComplete -- no valid primary region");
			return;
		}

		PrimaryRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(PrimaryRegionState, NewGameState, true);
		PrimaryRegionalAI.LiberateStage1Complete = true;

		`XEVENTMGR.TriggerEvent('LiberateStage1Complete', , , NewGameState); // this is needed to advance objective LW_T2_M0_S2
	}
}

//CreateProtectRegionMidTemplate()
static function X2DataTemplate CreateProtectRegionMidTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_LiberationStage LiberationStageCondition;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ProtectRegionMidName);
	Template.ActivityCategory = 'LiberationSequence';

	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetLiberationCondition());

	LiberationStageCondition = new class 'ActivityCondition_LiberationStage';
	LiberationStageCondition.NoStagesComplete = false;
	LiberationStageCondition.Stage1Complete = true;
	LiberationStageCondition.Stage2Complete = false;
	Template.ActivityCreation.Conditions.AddItem(LiberationStageCondition);

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.UseLiberateDifficultyTable = true;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = none;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = ProtectRegionMissionRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnLiberateStage2Complete;

	return Template;
}

// OnLiberateStage2Complete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnLiberateStage2Complete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion PrimaryRegionState;
	local WorldRegion_XComGameState_AlienStrategyAI PrimaryRegionalAI;

	if(!bAlienSuccess)
	{
		PrimaryRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if(PrimaryRegionState == none)
			PrimaryRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

		if(PrimaryRegionState == none)
		{
			`REDSCREEN("OnProtectRegionActivityComplete -- no valid primary region");
			return;
		}

		PrimaryRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(PrimaryRegionState, NewGameState, true);
		PrimaryRegionalAI.LiberateStage2Complete = true;
		`LWTRACE("ProtectRegionMid Complete");
		`LWTRACE("PrimaryRegionalAI.LiberateStage1Complete = " $ PrimaryRegionalAI.LiberateStage1Complete);
		`LWTRACE("PrimaryRegionalAI.LiberateStage2Complete = " $ PrimaryRegionalAI.LiberateStage2Complete);

		`XEVENTMGR.TriggerEvent('LiberateStage2Complete', , , NewGameState); // this is needed to advance objective LW_T2_M0_S3
	}
}

// CreateProtectRegionTemplate()
static function X2DataTemplate CreateProtectRegionTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_LiberationStage LiberationStageCondition;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ProtectRegionName);
	Template.ActivityCategory = 'LiberationSequence';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetLiberationCondition());

	LiberationStageCondition = new class 'ActivityCondition_LiberationStage';
	LiberationStageCondition.NoStagesComplete = false;
	LiberationStageCondition.Stage1Complete = true;
	LiberationStageCondition.Stage2Complete = true;
	Template.ActivityCreation.Conditions.AddItem(LiberationStageCondition);

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.UseLiberateDifficultyTable = true;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	//they can be overridden by template config values
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	// required delegates
	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = ProtectRegionMissionFailure;  //  Reset activity if one of the first PROTECTREGION_RESET_LEVEL missions is failed

	//optional delegates
	Template.OnActivityStartedFn = none;   // nothing special on startup

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel;
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // use regional AlertLevel

	Template.GetTimeUpdateFn = none;		// never updates
	Template.OnMissionExpireFn = none;  // nothing special, just remove mission and trigger failure
	Template.OnActivityUpdateFn = none;  // never updates
	Template.GetMissionRewardsFn = ProtectRegionMissionRewards;

	Template.CanBeCompletedFn = none;  // can't ever complete
	Template.OnActivityCompletedFn = OnProtectRegionActivityComplete;  // mark liberated, grant rewards, adjust Force/AlertLevel

	return Template;
}

// ProtectRegionMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
// adds extra logic so that chain is reset if one of the first PROTECTREGION_RESET_LEVEL missions is failed
static function ProtectRegionMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local StateObjectReference EmptyRef;

	if (ActivityState.CurrentMissionLevel < default.PROTECTREGION_RESET_LEVEL)
	{
		// failed an early mission, hide the activity and reset it back to beginning
		ActivityState.CurrentMissionLevel = 0; // reset mission level back to beginning
		ActivityState.bDiscovered = false;  // hide the activity so it has to be discovered again
		ActivityState.bNeedsUpdateDiscovery = false;
		ActivityState.MissionResourcePool = 0; // reset the mission resource pool so it isn't instantly discovered again
		ActivityState.bNeedsUpdateMissionFailure = false;
		ActivityState.CurrentMissionRef = EmptyRef;

		if(MissionState != none)
		{
			RecordResistanceActivity(false, ActivityState, MissionState, NewGameState);  //record failure
			MissionState.RemoveEntity(NewGameState);		// remove the mission
		}
	}
	else
	{
		//missions higher up in the chain just don't advance
		TypicalNoActionOnMissionFailure (ActivityState, MissionState, NewGameState);
	}
}

// ProtectRegionMissionRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> ProtectRegionMissionRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;
	local int NumRebels;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local XComGameState_WorldRegion PrimaryRegionState;
	local XComGameState_HeadquartersAlien AlienHQ;
	local int k;

	PrimaryRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));


	Switch (MissionFamily)
	{
		case 'Recover_LW':
		case 'Hack_LW': RewardArray[0] = 'Reward_Intel'; break;
		case 'Extract_LW':
		case 'Rescue_LW': RewardArray[0] = RescueReward(false, false); break;
		case 'DestroyObject_LW':
			RewardArray[0] = 'Reward_Intel';
			break;
		case 'Neutralize_LW':
			RewardArray[0] = 'Reward_AvengerResComms'; // give if capture
			RewardArray[1] = 'Reward_Intel'; // given if success (kill or capture)
			break;
		case 'AssaultNetworkTower_LW':
			RewardArray[0] = 'Reward_Dummy_RegionalTower';
			k = 1;
			if (PrimaryRegionState.ResistanceLevel < eResLevel_Outpost && !PrimaryRegionState.IsStartingRegion())
			{
				RewardArray[k] = 'Reward_Radio_Relay';
				k += 1;
			}
			RewardArray[k] = 'Reward_Intel';
			break;
		case 'AssaultAlienBase_LW':
			RewardArray[0] = 'Reward_Dummy_Materiel';
			RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(PrimaryRegionState, NewGameState, true);
			if (RegionalAI.NumTimesLiberated == 0)
			{
				if (CanAddPOI())
				{
					RewardArray[1] = 'Reward_POI_LW';
					RewardArray[2] = 'Reward_Dummy_POI'; // The first POI rewarded on any mission doesn't display in rewards, so this corrects for that
				}
			}
			break;
		case 'Jailbreak_LW':
			NumRebels = `SYNC_RAND_STATIC(class'Mission_X2StrategyElement_PoliticalPrisoner'.default.POLITICAL_PRISONERS_REBEL_REWARD_MAX - class'Mission_X2StrategyElement_PoliticalPrisoner'.default.POLITICAL_PRISONERS_REBEL_REWARD_MIN + 1) + class'Mission_X2StrategyElement_PoliticalPrisoner'.default.POLITICAL_PRISONERS_REBEL_REWARD_MIN;
			AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
			if (NumRebels > 0 && AlienHQ.CapturedSoldiers.Length > 0)
			{
				RewardArray.AddItem('Reward_SoldierCouncil');
				--NumRebels;
			}
			while (NumRebels > 0)
			{
				RewardArray.AddItem(class'X2StrategyElement_DefaultRewards_LW'.const.REBEL_REWARD_NAME);
				--NumRebels;
			}
			break;
		default: break;
	}
	return RewardArray;
}

// OnProtectRegionActivityComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnProtectRegionActivityComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion PrimaryRegionState, RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI PrimaryRegionalAI, RegionalAI;
	local WorldRegion_XComGameState_AlienStrategyAI AdjacentRegionalAI;
	local int AlertLevelsKilled, RemainderAlertLevel, idx;
	local StateObjectReference LinkedRegionRef;
	local array<XComGameState_WorldRegion> ControlledLinkedRegions;
	local array<int> ControlledLinkedAlertLevelIncreases;

	if(!bAlienSuccess)
	{
		PrimaryRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if(PrimaryRegionState == none)
			PrimaryRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

		if(PrimaryRegionState == none)
		{
			`REDSCREEN("OnProtectRegionActivityComplete -- no valid primary region");
			return;
		}

		RemoveOrAdjustExistingActivitiesFromRegion(PrimaryRegionState, NewGameState);

		PrimaryRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(PrimaryRegionState, NewGameState, true);
		PrimaryRegionalAI.bLiberated = true;

		if (PrimaryRegionalAI.NumTimesLiberated == 0)
		{
			RemoveLiberatedDoom(class'Mission_X2StrategyElement_LWOTC'.default.ALIEN_BASE_DOOM_REMOVAL, NewGameState);
		}

		PrimaryRegionalAI.NumTimesLiberated += 1;
		PrimaryRegionalAI.LastLiberationTime = GetCurrentTime();
		`XEVENTMGR.TriggerEvent('RegionLiberatedFlagSet', ActivityState, ActivityState, NewGameState); // this is needed to advance objective LW_T2_M0_S3_CompleteActivity
		PrimaryRegionalAI.LocalVigilanceLevel = 1;

		AlertLevelsKilled = default.LIBERATION_ALERT_LEVELS_KILLED + `SYNC_RAND_STATIC (default.LIBERATION_ALERT_LEVELS_KILLED_RAND);
		RemainderAlertLevel = Max (0, PrimaryRegionalAI.LocalAlertLevel - AlertLevelsKilled);
		PrimaryRegionalAI.LocalAlertLevel = 1;

		//distribute the RemainderAlertLevel amongst adjacent regions that haven't been liberated
		foreach PrimaryRegionState.LinkedRegions(LinkedRegionRef)
		{
			RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(LinkedRegionRef.ObjectID));
			if(RegionState == none)
				RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(LinkedRegionRef.ObjectID));
			if(RegionState != none && !RegionIsLiberated(RegionState, NewGameState))
			{
				ControlledLinkedRegions.AddItem(RegionState);
			}
		}

		if(ControlledLinkedRegions.Length > 0)
			AddVigilanceNearby (NewGameState, PrimaryRegionState, default.LIBERATE_ADJACENT_VIGILANCE_INCREASE_BASE, default.LIBERATE_ADJACENT_VIGILANCE_INCREASE_RAND);

		foreach `XCOMHistory.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
		{
			RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
			if (!RegionalAI.bLiberated)
			{
				RegionalAI.AddVigilance(NewGameState, 1);
			}
		}

		if(ControlledLinkedRegions.Length > 0 && RemainderAlertLevel > 0)
		{
			ControlledLinkedAlertLevelIncreases.Add(ControlledLinkedRegions.Length);

			//determine which adjacent regions are getting the AlertLevel increases
			for(idx = 0; idx < RemainderAlertLevel; idx++)
			{
				ControlledLinkedAlertLevelIncreases[`SYNC_RAND_STATIC(ControlledLinkedRegions.Length)] += 1;
			}

			//update the regional AI states with the AlertLevel increases
			for(idx = 0; idx < ControlledLinkedAlertLevelIncreases.Length; idx++)
			{
				if(ControlledLinkedAlertLevelIncreases[idx] > 0)
				{
					RegionState = ControlledLinkedRegions[idx];
					AdjacentRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
					AdjacentRegionalAI.LocalAlertLevel += ControlledLinkedAlertLevelIncreases[idx];
				}
			}
		}
	}
}

// RemoveOrAdjustExistingActivitiesFromRegion(XComGameState_WorldRegion RegionState, XComGameState NewGameState)
static function RemoveOrAdjustExistingActivitiesFromRegion(XComGameState_WorldRegion RegionState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local AlienActivity_XComGameState ActivityState, UpdatedActivity;
	local array<AlienActivity_XComGameState> ActivitiesToDelete, InfiltratedActivities;
	local SquadManager_XComGameState SquadMgr;
	local Squad_XComGameState SquadState;
	local XComGameState_MissionSite MissionState;

	History = `XCOMHISTORY;
	SquadMgr = `SQUADMGR;

	foreach History.IterateByClassType(class'XComGameState_LWAlienActivity', ActivityState)
	{
		if (ActivityState.GetMyTemplateName() == default.ProtectRegionName || ActivityState.PrimaryRegion.ObjectID != RegionState.ObjectID || ActivityState.GetMyTemplate().CanOccurInLiberatedRegion)
			continue;

		if (ActivityState.CurrentMissionRef.ObjectID == 0)
			ActivitiesToDelete.AddItem(ActivityState);
		else if (SquadMgr.Squads.GetSquadOnMission(ActivityState.CurrentMissionRef) == none)
			ActivitiesToDelete.AddItem(ActivityState);
		else
			InfiltratedActivities.AddItem(ActivityState);
	}

	foreach ActivitiesToDelete(ActivityState)
	{
		MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
		if (MissionState == none)
			MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));

		if (MissionState != none)
		{
			if (MissionState.POIToSpawn.ObjectID > 0)
			{
				class'XComGameState_HeadquartersResistance'.static.DeactivatePOI(NewGameState, MissionState.POIToSpawn);
			}
			MissionState.RemoveEntity(NewGameState);
		}
		NewGameState.RemoveStateObject(ActivityState.ObjectID);
	}
	foreach InfiltratedActivities(ActivityState)
	{
		UpdatedActivity = XComGameState_LWAlienActivity(NewGameState.GetGameStateForObjectID(ActivityState.ObjectID));
		if (UpdatedActivity == none)
		{
			UpdatedActivity = XComGameState_LWAlienActivity(NewGameState.CreateStateObject(class'XComGameState_LWAlienActivity', ActivityState.ObjectID));
			NewGameState.AddStateObject(UpdatedActivity);
		}
		SquadState = SquadMgr.Squads.GetSquadOnMission(ActivityState.CurrentMissionRef);
		SquadState = XComGameState_LWPersistentSquad(NewGameState.CreateStateObject(class'Squad_XComGameState', SquadState.ObjectID));
		NewGameState.AddStateObject(SquadState);

		SquadState.InfiltrationState.CurrentInfiltration += default.INFILTRATION_BONUS_ON_LIBERATION[`CAMPAIGNDIFFICULTYSETTING] / 100.0;
		If (SquadState.InfiltrationState.CurrentInfiltration > 2.0)
			SquadState.InfiltrationState.CurrentInfiltration=2.0;

		SquadState.InfiltrationState.GetAlertnessModifierForCurrentInfiltration(NewGameState, true); // force an update on the alertness modifier

		UpdatedActivity.DateTimeActivityComplete = GetCurrentTime();

		MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
		if (MissionState == none)
		{
			MissionState = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', ActivityState.CurrentMissionRef.ObjectID));
			NewGameState.AddStateObject(MissionState);
		}
		MissionState.ExpirationDateTime = GetCurrentTime();
	}
}

// RemoveLiberatedDoom(int DoomToRemove, XComGameState NewGameState)
static function RemoveLiberatedDoom(int DoomToRemove, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersAlien AlienHQ;

	History = `XCOMHISTORY;
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	AlienHQ = XComGameState_HeadquartersAlien(NewGameState.GetGameStateForObjectID(AlienHQ.ObjectID));
	if (AlienHQ == none)
	{
		AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
		AlienHQ = XComGameState_HeadquartersAlien(NewGameState.CreateStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));
		NewGameState.AddStateObject(AlienHQ);
	}

	AlienHQ.RemoveDoomFromFortress(NewGameState, DoomToRemove, class'UIStrategyMapItem_Region_LW'.default.m_strLiberatedRegion);
}