class Mission_X2StrategyElement_RegionalAvatarResearch extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array<int> REGIONAL_AVATAR_RESEARCH_TIME_MIN;
var config array<int> REGIONAL_AVATAR_RESEARCH_TIME_MAX;
var config array<float> CHANCE_TO_GAIN_DOOM_IN_SUPER_EMERGENCY;
var config array<float> CHANCE_PER_LOCAL_DOOM_TRANSFER_TO_ALIEN_HQ;

var name RegionalAvatarResearchName;

defaultProperties
{
    RegionalAvatarResearchName="RegionalAvatarResearch";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateRegionalAvatarResearchTemplate());

	return AlienActivities;
}

// CreateRegionalAvatarResearchTemplate()
static function X2DataTemplate CreateRegionalAvatarResearchTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_ResearchFacility ResearchFacility;
	local ActivityDetectionCalc_LWOTC Detection;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.RegionalAvatarResearchName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());

	ResearchFacility = new class'ActivityCondition_ResearchFacility';
 	ResearchFacility.bRequiresAlienResearchFacilityInRegion = true;
	Template.ActivityCreation.Conditions.AddItem(ResearchFacility);

	Template.CanOccurInLiberatedRegion = true;

	Detection = new class'ActivityDetectionCalc_LWOTC';
	Detection.SetNeverDetected(true);		// ONLY DETECTED IF A LEAD REWARD IS OBTAINED. CANNOT BE DETECTED BY INTEL PERSONNEL.
	//Detection.SetAlwaysDetected(true);		// FOR TESTING ONLY !!
	Template.DetectionCalc =  Detection;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalNoActionOnMissionFailure; // facility keeps on going (1.3 fix)
	// update timer used to spawn doom
	Template.GetTimeUpdateFn = RegionalAvatarResearchTimer;
	Template.UpdateModifierHoursFn = RegionalAvatarResearchTimeModifier;
	Template.OnActivityUpdateFn = OnRegionalAvatarResearchUpdate;
	Template.OnMissionCreatedFn = OnAlienResearchMissionCreated;
	Template.OnActivityCompletedFn = DisableAlienResearch;

	return Template;
}

// DisableAlienResearch(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
//disable the regional AI research facility flag when activity completes
static function DisableAlienResearch(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	History = `XCOMHISTORY;
	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
	RegionalAI.bHasResearchFacility = false;

}

// FacilityLeadCompleted(XComGameState NewGameState, XComGameState_Tech TechState)
// detection code -- called when Tech_AlienFacilityLead completes
static function FacilityLeadCompleted(XComGameState NewGameState, XComGameState_Tech TechState)
{
	local XComGameStateHistory History;
	local AlienActivity_XComGameState ActivityState, UpdatedActivity;
	local array<AlienActivity_XComGameState> PossibleActivities;
	local XComGameState_MissionSite MissionState;
	local int k;
	History = `XCOMHISTORY;

	//find the specified activity in the specified region
	foreach History.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
	{
		if(ActivityState.GetMyTemplateName() == default.RegionalAvatarResearchName)
		{
			if (!ActivityState.bDiscovered) // not yet detected
			{
				PossibleActivities.AddItem(ActivityState);
				if(ActivityState.CurrentMissionRef.ObjectID > 0) // has a mission
				{
					MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
					if (MissionState == none)
					{
						MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
						// add a chance per doom
						//`LWTRACE ("MissionState.Doom" @ string (MissionState.Doom));
						for (k = 0; k < MissionState.Doom; k++)
						{
							PossibleActivities.AddItem(ActivityState);
						}
					}
				}
			}
		}
	}
	if (PossibleActivities.Length == 0)
	{
		`REDSCREEN("No valid activities of type: " $ default.RegionalAvatarResearchName);
		return;
	}
	ActivityState = PossibleActivities[`SYNC_RAND_STATIC(PossibleActivities.Length)];

	UpdatedActivity = AlienActivity_XComGameState(NewGameState.CreateStateObject(class'AlienActivity_XComGameState', ActivityState.ObjectID));
	NewGameState.AddStateObject(UpdatedActivity);

	if (ActivityState.CurrentMissionRef.ObjectID > 0)
	{
		MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
		if (MissionState == none)
		{
			MissionState = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', ActivityState.CurrentMissionRef.ObjectID));
			NewGameState.AddStateObject(MissionState);
		}
		MissionState.Available = true;
		UpdatedActivity.bDiscovered = true;
		UpdatedActivity.bNeedsAppearedPopup = true;
		UpdatedActivity.bNeedsUpdateDiscovery = false;
	}
	else // this shouldn't ever happen, but is included for error handling
	{
		//check to see if we are back in geoscape yet
		if (`HQGAME == none || `HQPRES == none || `HQPRES.StrategyMap2D == none)
		{
			//not there, so mark the activity to be detected the next time we are back in geoscape
			UpdatedActivity.bNeedsUpdateDiscovery = true;
		}
		else
		{
			if(UpdatedActivity.SpawnMission(NewGameState))
			{
				UpdatedActivity.bDiscovered = true;
				UpdatedActivity.bNeedsAppearedPopup = true;
			}
		}
	}

	TechState.RegionRef = ActivityState.PrimaryRegion;
}

// OnAlienResearchMissionCreated(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
//transfer any activity doom to the mission
static function OnAlienResearchMissionCreated(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	if(MissionState.GeneratedMission.Mission.MissionName == 'SabotageAlienFacility_LW')
	{
		MissionState.Doom = ActivityState.Doom;
		ActivityState.Doom = 0;
	}
}

// RegionalAvatarResearchTimer(AlienActivity_XComGameState ActivityState, optional XComGameState NewGameState)
//Setting up timer to add doom / transfer doom to AlienHQ
static function TDateTime RegionalAvatarResearchTimer(AlienActivity_XComGameState ActivityState, optional XComGameState NewGameState)
{
	local TDateTime UpdateTime;
	local int HoursToAdd;
    local XComGameState_HeadquartersAlien AlienHQ;

	class'X2StrategyGameRulesetDataStructures'.static.CopyDateTime(class'XComGameState_GeoscapeEntity'.static.GetCurrentTime(), UpdateTime);

	AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	if (AlienHQ.GetCurrentDoom(true) >= AlienHQ.GetMaxDoom()) // player is in the lose state
	{
		// add one day, check again then in case player has dropped doom counter down
		HoursToAdd = 24;
	}
	else
	{
		//use configured times, based on difficulty;
		HoursToAdd = default.REGIONAL_AVATAR_RESEARCH_TIME_MIN[`CAMPAIGNDIFFICULTYSETTING];
		HoursToAdd += `SYNC_RAND_STATIC(default.REGIONAL_AVATAR_RESEARCH_TIME_MAX[`CAMPAIGNDIFFICULTYSETTING] - default.REGIONAL_AVATAR_RESEARCH_TIME_MIN[`CAMPAIGNDIFFICULTYSETTING] + 1);
	}
	class'X2StrategyGameRulesetDataStructures'.static.AddHours(UpdateTime, HoursToAdd);

	return UpdateTime;
}

// RegionalAvatarResearchTimeModifier(AlienActivity_XComGameState ActivityState, optional XComGameState NewGameState)
// compute modifier to all regional AVATAR research doom ticks, based on current vigiliance, etc
static function int RegionalAvatarResearchTimeModifier(AlienActivity_XComGameState ActivityState, optional XComGameState NewGameState)
{
	return `ACTIVITYMGR.GetDoomUpdateModifierHours(ActivityState, NewGameState);
}

// OnRegionalAvatarResearchUpdate(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
//handles updating of the regional research project, adding doom and possibly transfer doom to AlienHQ
static function OnRegionalAvatarResearchUpdate(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local float TransferChance;
	local int idx, FacilityDoom;
	local bool bTransferDoom;
	local XComGameState_MissionSite MissionState;
	local XComGameState_WorldRegion Region;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local int AlertVigilanceDiff;
	local bool AliensHaveOneRegion;
	local AlienActivity_XComGameState ActivityLooper;

	AlertVigilanceDiff = `ACTIVITYMGR.GetGlobalAlert() - `ACTIVITYMGR.GetGlobalVigilance();

	// Disabled by config, superceded by other mechanics
	if (AlertVigilanceDiff < -class'Mission_X2StrategyElement_LWOTC'.default.SUPER_EMERGENCY_GLOBAL_VIG)
	{
		if(`SYNC_FRAND_STATIC() >= default.CHANCE_TO_GAIN_DOOM_IN_SUPER_EMERGENCY[`CAMPAIGNDIFFICULTYSETTING] / 100.0)
			return;
	}

	// If aliens have lost most of their territory and are trying to land foothold UFOs, research stops
	foreach `XCOMHISTORY.IterateByClassType(class'AlienActivity_XComGameState', ActivityLooper)
	{
		if(ActivityLooper.GetMyTemplateName() == default.FootholdName)
			return;
	}

	// ALso halt if aliens have no regions
	AliensHaveOneRegion = false;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', Region)
	{
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
		if (!RegionalAI.bLiberated)
		{
			AliensHaveOneRegion = true;
		}
	}

	if (!AliensHaveOneRegion)
		return;

	if(ActivityState.CurrentMissionRef.ObjectID > 0) // has a mission
	{
		MissionState = XComGameState_MissionSite(NewGameState.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
		if (MissionState == none)
		{
			MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.CurrentMissionRef.ObjectID));
		}
		FacilityDoom = MissionState.Doom;
	}

	FacilityDoom += ActivityState.Doom;

	TransferChance = default.CHANCE_PER_LOCAL_DOOM_TRANSFER_TO_ALIEN_HQ[`CAMPAIGNDIFFICULTYSETTING] / 100.0;
	for (idx = 0; idx < FacilityDoom; idx++)
	{
		if (`SYNC_FRAND_STATIC() < TransferChance)
		{
			bTransferDoom = true;
			break;
		}
	}

	if(bTransferDoom)
	{
		class'AlienActivity_XComGameState_Manager'.static.AddDoomToFortress(NewGameState, 1);
	}
	else // add a point of doom to the local facility
	{
		class'AlienActivity_XComGameState_Manager'.static.AddDoomToFacility(ActivityState, NewGameState, 1);
	}
	//ActivityState.bNeedsPause = true;

}