class Mission_X2StrategyElement_BuildResearchFacility extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var name BuildResearchFacilityName;

defaultProperties
{
    BuildResearchFacilityName="BuildResearchFacility";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateBuildResearchFacilityTemplate());

	return AlienActivities;
}

// CreateBuildResearchFacilityTemplate()
static function X2DataTemplate CreateBuildResearchFacilityTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_ResearchFacility ResearchFacility;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.BuildResearchFacilityName);

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'X2LWActivityCreation_FurthestAway';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAlertAtLeastEqualtoVigilance());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	ResearchFacility = new class'ActivityCondition_ResearchFacility';
 	ResearchFacility.bAllowedAlienResearchFacilityInRegion = false;
	ResearchFacility.bBuildingResearchFacility = true;
	Template.ActivityCreation.Conditions.AddItem(ResearchFacility);

	// required delegates
	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = none;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetBuildResearchFacilityRewards;
	//Template.GetNextMissionDurationSecondsFn = GetTypicalMissionDuration;
	Template.OnActivityUpdateFn = none;

	Template.CanBeCompletedFn = none;  // can always be completed
	//Template.GetTimeCompletedFn = TypicalActivityTimeCompleted;
	Template.OnActivityCompletedFn = OnBuildResearchFacilityComplete;

	return Template;
}

// GetBuildResearchFacilityRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetBuildResearchFacilityRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> Rewards;

	Rewards[0] = 'Reward_Dummy_Materiel';
	Rewards[1] = 'Reward_Intel';
	return Rewards;
}

// OnBuildResearchFacilityComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnBuildResearchFacilityComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	History = `XCOMHISTORY;
	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);

	if(bAlienSuccess)
	{
		`LWTRACE("BuildResearchFacilityComplete : Alien Success, marking region for research base creation");
		// construction complete, mark for follow-up activity
		RegionalAI.bHasResearchFacility = true;
	}
	else
	{
		`LWTRACE("BuildResearchFacilityComplete : XCOM Success, increasing vigilance");
		//activity halted, boost vigilance by an extra point over the typical +1
		RegionalAI.AddVigilance (NewGameState, 1);
	}
}