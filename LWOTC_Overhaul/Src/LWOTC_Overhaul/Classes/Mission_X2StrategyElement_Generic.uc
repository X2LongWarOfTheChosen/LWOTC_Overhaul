class Mission_X2StrategyElement_Generic extends X2StrategyElement config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int XCOM_WIN_VIGILANCE_GAIN;
var config int XCOM_LOSE_VIGILANCE_GAIN;

var config int RAID_MISSION_MIN_REBELS;
var config int RAID_MISSION_MAX_REBELS;

// StartGeneralOp (AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function StartGeneralOp (AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local XComGameState_WorldRegion Region;

	Region = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if (Region == none)
	   Region = XComGameState_WorldRegion(`XCOMHistory.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState, true);
	RegionalAI.GeneralOpsCount += 1;
}

// GetTypicalMissionForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetTypicalMissionForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;

	RegionState = MissionSite.GetWorldRegion();
	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);

	`LWTRACE("Activity " $ ActivityState.GetMyTemplateName $ ": Mission Force Level =" $ RegionalAIState.LocalForceLevel + ActivityState.GetMyTemplate().ForceLevelModifier );
	return RegionalAIState.LocalForceLevel + ActivityState.GetMyTemplate().ForceLevelModifier;
}

// GetTypicalMissionAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetTypicalMissionAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;

	RegionState = MissionSite.GetWorldRegion();
	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);

	`LWTRACE("Activity " $ ActivityState.GetMyTemplateName $ ": Mission Alert Level =" $ RegionalAIState.LocalAlertLevel + ActivityState.GetMyTemplate().AlertLevelModifier );
	return RegionalAIState.LocalAlertLevel + ActivityState.GetMyTemplate().AlertLevelModifier;
}

// TypicalAdvanceActivityOnMissionSuccess(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function TypicalAdvanceActivityOnMissionSuccess(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local XComGameState_WorldRegion RegionState;
	local array<int> ExcludeIndices;

	if(ActivityState == none)
		`REDSCREEN("AlienActivities : TypicalAdvanceActivityOnMissionSuccess -- no ActivityState");

	ActivityTemplate = ActivityState.GetMyTemplate();
	NewGameState.AddStateObject(ActivityState);


    // We need to apply the rewards immediately, but don't want to run them twice if we need to also defer the
    // activity update until we're back at the geoscape.
    if (!ActivityState.bNeedsUpdateMissionSuccess)
    {
	    if (MissionState != none)
	    {
			ExcludeIndices = GetRewardExcludeIndices(ActivityState, MissionState, NewGameState);
		    GiveRewards(NewGameState, MissionState, ExcludeIndices);
		    RecordResistanceActivity(true, ActivityState, MissionState, NewGameState);

		    MissionState.RemoveEntity(NewGameState);
	    }
    }

    if(MissionState.GeneratedMission.Mission.MissionName == 'AssaultNetworkTower_LW')
	{
		`XEVENTMGR.TriggerEvent('LiberateStage2Complete', , , NewGameState); // this is needed to advance objective LW_T2_M0_S3 -- THIS IS A BACKUP, IT SHOULD HAVE BEEN TRIGGERED EARLIER
		`XEVENTMGR.TriggerEvent('NetworkTowerDefeated', ActivityState, ActivityState, NewGameState); // this is needed to advance objective LW_T2_M0_S3_CompleteActivity
	}

	if(ActivityTemplate.DataName == class'X2StrategyElement_DefaultAlienActivities'.default.ProtectRegionEarlyName && ActivityState.CurrentMissionLevel == 0)
	{
		`XEVENTMGR.TriggerEvent('OnProtectRegionActivityDiscovered', , , NewGameState); // this is needed to advance objective LW_T2_M0_S2_FindActivity
	}

	//check to see if we are back in geoscape yet
	if (`HQGAME == none || `HQPRES == none || `HQPRES.StrategyMap2D == none)
	{
		//not there, so mark the activity to update next time we are back in geoscape
		ActivityState.bNeedsUpdateMissionSuccess = true;
		return;
	}


	//advance to the next mission in the chain
	ActivityState.CurrentMissionLevel++;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	//when a region is liberated, activities can no longer be advanced
	if(RegionState != none && RegionIsLiberated(RegionState, NewGameState) && !ActivityTemplate.CanOccurInLiberatedRegion)
	{
		if(MissionState != none)
		{
			if (MissionState.POIToSpawn.ObjectID > 0)
			{
				class'XComGameState_HeadquartersResistance'.static.DeactivatePOI(NewGameState, MissionState.POIToSpawn);
			}
			MissionState.RemoveEntity(NewGameState);
		}
		if(ActivityTemplate.OnActivityCompletedFn != none)
			ActivityTemplate.OnActivityCompletedFn(false /* alien failure */, ActivityState, NewGameState);
		NewGameState.RemoveStateObject(ActivityState.ObjectID);
	}
	else if(ActivityState.SpawnMission(NewGameState)) //try and spawn the next mission
	{
		if (ActivityState.bDiscovered)
		{
			ActivityState.bNeedsAppearedPopup = true;
		}
		ActivityState.bMustLaunch = false;
	}
	else // we've reached the end of the chain
	{
		if(ActivityTemplate.OnActivityCompletedFn != none)
			ActivityTemplate.OnActivityCompletedFn(false /* not alien success*/, ActivityState, NewGameState);

		ActivityState.bNeedsAppearedPopup = false;
		ActivityState.bMustLaunch = false;

		NewGameState.RemoveStateObject(ActivityState.ObjectID);
	}
	//record success
}

// TypicalEndActivityOnMissionSuccess(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function TypicalEndActivityOnMissionSuccess(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local array<int> ExcludeIndices;

	if(ActivityState == none)
		`REDSCREEN("AlienActivities : TypicalEndActivityOnMissionSuccess -- no ActivityState");

	ActivityTemplate = ActivityState.GetMyTemplate();
	NewGameState.AddStateObject(ActivityState);

	if (MissionState != none)
	{
		ExcludeIndices = GetRewardExcludeIndices(ActivityState, MissionState, NewGameState);

		GiveRewards(NewGameState, MissionState, ExcludeIndices);
		RecordResistanceActivity(true, ActivityState, MissionState, NewGameState);

		MissionState.RemoveEntity(NewGameState);
	}

	if(ActivityTemplate.OnActivityCompletedFn != none)
		ActivityTemplate.OnActivityCompletedFn(false /* not alien success*/, ActivityState, NewGameState);

	NewGameState.RemoveStateObject(ActivityState.ObjectID);

	//record success
}

// TypicalEndActivityOnMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function TypicalEndActivityOnMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;

	if(ActivityState == none)
		`REDSCREEN("AlienActivities : TypicalEndActivityOnMissionFailure -- no ActivityState");
	ActivityTemplate = ActivityState.GetMyTemplate();
	NewGameState.AddStateObject(ActivityState);
	if (MissionState != none)
	{
		RecordResistanceActivity(false, ActivityState, MissionState, NewGameState);
		MissionState.RemoveEntity(NewGameState);
	}
	if(ActivityTemplate.OnActivityCompletedFn != none)
		ActivityTemplate.OnActivityCompletedFn(true, ActivityState, NewGameState);
	NewGameState.RemoveStateObject(ActivityState.ObjectID);
}

// TypicalNoActionOnMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
//handles the case where mission failure simply doesn't advance the chain -- there's no other consequence
static function TypicalNoActionOnMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	// The caller created this, but all delegates need to add the object.
	NewGameState.AddStateObject(ActivityState);

	//don't do anything here -- player can still undertake the mission

	//record failure
	if (MissionState != none)
		RecordResistanceActivity(false, ActivityState, MissionState, NewGameState);
}

// TypicalAdvanceActivityOnMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
//handles the case where mission failure advances the chain to the next mission
static function TypicalAdvanceActivityOnMissionFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local XComGameState_WorldRegion RegionState;
	local bool ForceDetection;

	if(ActivityState == none)
		`REDSCREEN("AlienActivities : TypicalContinueOnMissionSuccess -- no ActivityState");

	ActivityTemplate = ActivityState.GetMyTemplate();
	NewGameState.AddStateObject(ActivityState);

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	if (MissionState != none)
	{
		RecordResistanceActivity(false, ActivityState, MissionState, NewGameState);
		if (MissionState.POIToSpawn.ObjectID > 0)
		{
			// This mission had a POI, deactivate it.
			class'XComGameState_HeadquartersResistance'.static.DeactivatePOI(NewGameState, MissionState.POIToSpawn);
		}
	}

	//when a region is liberated, activities can no longer be lost
	if(RegionState != none && RegionIsLiberated(RegionState, NewGameState) && !ActivityTemplate.CanOccurInLiberatedRegion)
	{
		if(MissionState != none)
			MissionState.RemoveEntity(NewGameState);
		if(ActivityTemplate.OnActivityCompletedFn != none)
			ActivityTemplate.OnActivityCompletedFn(false /* alien failure */, ActivityState, NewGameState);
		NewGameState.RemoveStateObject(ActivityState.ObjectID);
	}

	if (ActivityTemplate.MissionTree.length > ActivityState.CurrentMissionLevel+1)
	{
		ForceDetection = ActivityTemplate.MissionTree[ActivityState.CurrentMissionLevel+1].ForceActivityDetection;
	}
	//check to see if we are back in geoscape yet
	if (`HQGAME == none || `HQPRES == none || `HQPRES.StrategyMap2D == none)
	{
		//not there, so mark the activity to update next time we are back in geoscape
		ActivityState.bNeedsUpdateMissionFailure = true;
		if (ForceDetection)
			ActivityState.bNeedsUpdateDiscovery = true;

		return;
	}

	if (ForceDetection)
		ActivityState.bDiscovered = true;

	if(MissionState != none)
		MissionState.RemoveEntity(NewGameState);

	//advance to the next mission in the chain
	ActivityState.CurrentMissionLevel++;

	//try and spawn the next mission
	if(ActivityState.SpawnMission(NewGameState))
	{
		if (ActivityState.bDiscovered)
		{
			ActivityState.bNeedsAppearedPopup = true;
		}
	}
	else // we've reached the end of the chain
	{
		if(ActivityTemplate.OnActivityCompletedFn != none)
			ActivityTemplate.OnActivityCompletedFn(true /* alien success*/, ActivityState, NewGameState);

		NewGameState.RemoveStateObject(ActivityState.ObjectID);
	}
	//record failure
}

// GetTypicalMissionDarkEvent(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function StateObjectReference GetTypicalMissionDarkEvent(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local StateObjectReference DarkEventRef;
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;

	ActivityTemplate = ActivityState.GetMyTemplate();
	//default is to add the dark event to the last mission in the mission chain
	if(ActivityState.CurrentMissionLevel == ActivityTemplate.MissionTree.Length-1)
	{
		DarkEventRef = ActivityState.DarkEvent;
	}

	return DarkEventRef;
}

// AddVigilanceNearby (XComGameState NewGameState, XComGameState_WorldRegion CoreRegionState, int BaseNearbyIncrease, int RandNearbyIncrease)
static function AddVigilanceNearby (XComGameState NewGameState, XComGameState_WorldRegion CoreRegionState, int BaseNearbyIncrease, int RandNearbyIncrease)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local StateObjectReference LinkedRegionRef;

	foreach CoreRegionState.LinkedRegions(LinkedRegionRef)
	{
		RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(LinkedRegionRef.ObjectID));
		if(RegionState == none)
			RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(LinkedRegionRef.ObjectID));
		if(RegionState != none && !RegionIsLiberated(RegionState, NewGameState))
		{
			RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
			if (RegionalAI != none)
				RegionalAI.AddVigilance(NewGameState, BaseNearbyIncrease + `SYNC_RAND_STATIC(RandNearbyIncrease));
		}
	}
}

// RecordResistanceActivity(bool Success, AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function RecordResistanceActivity(bool Success, AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local name ActivityTemplateName;
	local int DoomToRemove;
	local string MissionFamily;

	History = `XCOMHISTORY;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
	if(Success)
	{
		RegionalAI.AddVigilance(NewGameState, default.XCOM_WIN_VIGILANCE_GAIN);
	}
	else
	{
		RegionalAI.AddVigilance(NewGameState, default.XCOM_LOSE_VIGILANCE_GAIN);
	}

	// Golden Path missions are handled by their MissionSource templates, which are still in-use

	MissionFamily = MissionState.GeneratedMission.Mission.MissionFamily;
	if (Success)
	{
		switch (MissionFamily) {
		case "Hack_LW":
		case "Recover_LW":
		case "Rescue_LW":
		case "Extract_LW":
		case "DestroyObject_LW":
		case "Jailbreak_LW":
		case "TroopManeuvers_LW":
		case "ProtectDevice_LW":
		case "SabotageCC":
		case "SabotageCC_LW":
		case "AssaultNetworkTower_LW":
		case "SmashnGrab_LW":
			ActivityTemplateName='ResAct_GuerrillaOpsCompleted';
			break;
		case "SecureUFO_LW":
			ActivityTemplateName='ResAct_LandedUFOsCompleted';
			break;
		case "Terror_LW":
        case "Defend_LW":
			ActivityTemplateName='ResAct_RetaliationsStopped';
			break;
		case "Invasion_LW":
			ActivityTemplateName='ResAct_RegionsLiberated';
			break;
		case "SupplyLineRaid_LW":
			ActivityTemplateName='ResAct_SupplyRaidsCompleted';
			break;
		case "Sabotage_LW":
			ActivityTemplateName='ResAct_AlienFacilitiesDestroyed';
			DoomToRemove = MissionState.Doom;
			break;
        case "Rendezvous_LW":
			ActivityTemplateName='ResAct_FacelessUncovered';
            break;
		case "AssaultAlienBase_LW":
			ActivityTemplateName='ResAct_RegionsLiberated';
			if (RegionalAI.NumTimesLiberated <= 0)
			{
				`LWTRACE ("Removing one doom for capturing a region!");
				DoomToRemove = default.ALIEN_BASE_DOOM_REMOVAL;
			}
			break;
		case "RecruitRaid_LW":
		case "IntelRaid_LW":
		case "SupplyConvoy_LW":
			ActivityTemplateName='ResAct_RaidsDefeated';
			break;
		default:
			ActivityTemplateName='ResAct_GuerrillaOpsCompleted';
			break;
		}
	}
	else
	{
		switch (MissionFamily) {
		case "Hack_LW":
		case "Recover_LW":
		case "Rescue_LW":
		case "Extract_LW":
		case "DestroyObject_LW":
		case "Jailbreak_LW":
		case "TroopManeuvers_LW":
		case "ProtectDevice_LW":
		case "SabotageCC":
		case "SabotageCC_LW":
		case "Rendezvous_LW":
		case "AssaultNetworkTower_LW":
		case "Sabotage_LW":
		case "SmashnGrab_LW":
		case "AssaultAlienBase_LW":
			if (!ActivityState.bFailedFromMissionExpiration)
			{
				ActivityTemplateName='ResAct_GuerrillaOpsFailed';
			}
			break;
		case "SecureUFO_LW":
			if (!ActivityState.bFailedFromMissionExpiration)
			{
				ActivityTemplateName='ResAct_LandedUFOsFailed';
			}
			break;
		case "Terror_LW":
        case "Defend_LW":
			ActivityTemplateName='ResAct_RetaliationsFailed';
			break;
		case "Invasion_LW":
			ActivityTemplateName='ResAct_RegionsLost';
			break;
		case "SupplyLineRaid_LW":
			if (!ActivityState.bFailedFromMissionExpiration)
			{
				ActivityTemplateName='ResAct_SupplyRaidsFailed';
			}
		case "Rendezvous_LW":
			if (!ActivityState.bFailedFromMissionExpiration)
			{
				ActivityTemplateName='ResAct_FacelessUncovered';
			}
			break;
		case "RecruitRaid_LW":
		case "IntelRaid_LW":
		case "SupplyConvoy_LW":
			ActivityTemplateName='ResAct_RaidsLost';
			break;
		default:
			break;
		}
	}

	/// DID NOT USE: ResAct_CouncilMissionsCompleted

	//only record for missions that were ever visible
	if (MissionState.Available)
	{
		class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, ActivityTemplateName);
		if (DoomToRemove > 0)
		{
			class'XComGameState_HeadquartersResistance'.static.RecordResistanceActivity(NewGameState, 'ResAct_AvatarProgressReduced', DoomToRemove);
		}
	}
}

// SelectPOI(XComGameState NewGameState, XComGameState_MissionSite MissionState)
static function SelectPOI(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_HeadquartersResistance ResHQ;

	ResHQ = class'UIUtilities_Strategy'.static.GetResistanceHQ();
	ResHQ.ChoosePOI(NewGameState, true);
}

// GiveRewards(XComGameState NewGameState, XComGameState_MissionSite MissionState, optional array<int> ExcludeIndices)
static function GiveRewards(XComGameState NewGameState, XComGameState_MissionSite MissionState, optional array<int> ExcludeIndices)
{
	local XComGameStateHistory History;
	local XComGameState_PointOfInterest POIState;
	local XComGameState_Reward RewardState;
	local int idx;

	History = `XCOMHISTORY;

	`LWTRACE ("GiveRewards 1");

	// First Check if we need to exclude some rewards
	for(idx = 0; idx < MissionState.Rewards.Length; idx++)
	{
		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(MissionState.Rewards[idx].ObjectID));
		if(RewardState != none)
		{
			if(ExcludeIndices.Find(idx) != INDEX_NONE)
			{
				RewardState.CleanUpReward(NewGameState);
				NewGameState.RemoveStateObject(RewardState.ObjectID);
                // Don't remove the reward from the list: this will shift the indices and cause ExcludeIndices to
                // match rewards it shouldn't. Note: This is a vanilla bug that still exists in DefaultMissionSources,
                // but we aren't using that code for LW Overhaul.
				//MissionState.Rewards.Remove(idx, 1);
				//idx--;
			}
		}
	}

	`LWTRACE ("GiveRewards 2");

	class'XComGameState_HeadquartersResistance'.static.SetRecapRewardString(NewGameState, MissionState.GetRewardAmountString());

	// @mnauta: set VIP rewards string is deprecated, leaving blank
	class'XComGameState_HeadquartersResistance'.static.SetVIPRewardString(NewGameState, "" /*REWARDS!*/);

	// add the hard-coded POIToSpawn in MissionState, which we are keeping so that existing DLC/Mods can alter it
	if (MissionState.POIToSpawn.ObjectID > 0)
	{
		POIState = XComGameState_PointOfInterest(History.GetGameStateForObjectID(MissionState.POIToSpawn.ObjectID));

		if (POIState != none)
		{
			POIState = XComGameState_PointOfInterest(NewGameState.CreateStateObject(class'XComGameState_PointOfInterest', POIState.ObjectID));
			NewGameState.AddStateObject(POIState);
			POIState.Spawn(NewGameState);
		}
	}

	`LWTRACE ("GiveRewards 3");

	for(idx = 0; idx < MissionState.Rewards.Length; idx++)
	{
		`LWTRACE ("GiveRewards LOOP 1");

        // Skip excluded rewards.
    	if(ExcludeIndices.Find(idx) != INDEX_NONE)
		{
            continue;
        }

		`LWTRACE ("GiveRewards LOOP 2");

		RewardState = XComGameState_Reward(History.GetGameStateForObjectID(MissionState.Rewards[idx].ObjectID));

		// Give rewards
		if(RewardState != none)
		{
			`LWTRACE ("GiveReward Loop Applying Reward" @ RewardState.GetMyTemplateName());
			switch (RewardState.GetMyTemplateName())
			{
				case 'Reward_POI_LW':
					`LWTRACE("TRIGGER POI REWARD");
					SelectPOI(NewGameState, MissionState);
					break;
				case 'Reward_FacilityLead':
					AddItemRewardToLoot(RewardState, NewGameState);
					break;
				default:
					`LWTRACE("GiveRewards: Giving" @ RewardState.GetMyTemplateName());
					RewardState.GiveReward(NewGameState, MissionState.Region);
				break;
			}
		}
		// Remove the reward state objects
		NewGameState.RemoveStateObject(RewardState.ObjectID);
	}

	MissionState.Rewards.Length = 0;
}

// AddItemRewardToLoot(XComGameState_Reward RewardState, XComGameState NewGameState)
static function AddItemRewardToLoot(XComGameState_Reward RewardState, XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Item ItemState;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	ItemState = XComGameState_Item(History.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));

	if(!XComHQ.PutItemInInventory(NewGameState, ItemState, true /* loot */))
	{
		NewGameState.PurgeGameStateForObjectID(XComHQ.ObjectID);
	}
	else
	{
		NewGameState.AddStateObject(XComHQ);
	}
}

// GetRewardExcludeIndices(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function array<int> GetRewardExcludeIndices(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local array<int> ExcludeIndices;
    local XComGameState_Unit Unit;
    local XComGameState_Reward Reward;
    local int i;

	History = `XCOMHISTORY;


	// remove and dead or left-behind reward units
    for (i = 0; i < MissionState.Rewards.Length; ++i)
    {
        Reward = XComGameState_Reward(History.GetGameStateForObjectID(MissionState.Rewards[i].ObjectID));
        Unit = XComGameState_Unit(History.GetGameStateForObjectID(Reward.RewardObjectReference.ObjectID));
		if (Unit != none)
		{
			if (Unit.IsDead() || !Unit.bRemovedFromPlay)
			{
				`LWTRACE ("Excluding Reward" @ Reward.GetMyTemplateName());
				ExcludeIndices.AddItem(i);
			}
		}
    }

	// give one or the other reward
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	for(i = 0; i < BattleData.MapData.ActiveMission.MissionObjectives.Length; i++)
	{
		if(BattleData.MapData.ActiveMission.MissionObjectives[i].ObjectiveName == 'Capture' &&
		   !BattleData.MapData.ActiveMission.MissionObjectives[i].bCompleted)
		{
			`LWTRACE ("Excluding Reward index 0 because VIP not captured");
			ExcludeIndices.AddItem(0);
		}
	}

	return ExcludeIndices;
}

// MeetsAlertAndVigilanceReqs(AlienActivity_X2StrategyElementTemplate Template, WorldRegion_XComGameState_AlienStrategyAI RegionalAI)
static function bool MeetsAlertAndVigilanceReqs(AlienActivity_X2StrategyElementTemplate Template, WorldRegion_XComGameState_AlienStrategyAI RegionalAI)
{

	if (RegionalAI == none)
	{
		`LOG (Template.Dataname @ "No Regional AI found!");
	}

	if(Template.MaxVigilance > 0 && RegionalAI.LocalVigilanceLevel > Template.MaxVigilance)
		return false;

	if(Template.MinVigilance > 0 && RegionalAI.LocalVigilanceLevel < Template.MinVigilance)
		return false;

	if(Template.MaxAlert > 0 && RegionalAI.LocalAlertLevel > Template.MaxAlert)
		return false;

	if(Template.MinAlert > 0 && RegionalAI.LocalAlertLevel < Template.MinAlert)
		return false;

	return true;
}

// RegionIsLiberated(XComGameState_WorldRegion RegionState, optional XComGameState NewGameState)
static function bool RegionIsLiberated(XComGameState_WorldRegion RegionState, optional XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);
	if(RegionalAI != none)
	{
		return RegionalAI.bLiberated;
	}
	//`REDSCREEN("RegionIsLiberated : Supplied Region " $ RegionState.GetMyTemplate().DataName $ " has no regional AI info");
	return false;

}

// GetCurrentTime()
static function TDateTime GetCurrentTime()
{
	return class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
}

// GetAndAddAlienHQ(XComGameState NewGameState)
static function XComGameState_HeadquartersAlien GetAndAddAlienHQ(XComGameState NewGameState)
{
	local XComGameState_HeadquartersAlien AlienHQ;

	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersAlien', AlienHQ)
	{
		break;
	}

	if(AlienHQ == none)
	{
		AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
		AlienHQ = XComGameState_HeadquartersAlien(NewGameState.CreateStateObject(class'XComGameState_HeadquartersAlien', AlienHQ.ObjectID));
		NewGameState.AddStateObject(AlienHQ);
	}

	return AlienHQ;
}