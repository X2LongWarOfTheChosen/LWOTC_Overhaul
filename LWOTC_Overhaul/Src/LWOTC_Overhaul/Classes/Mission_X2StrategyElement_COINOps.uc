class Mission_X2StrategyElement_COINOps extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int COIN_OPS_GLOBAL_COOLDOWN;

var name COINOpsName;

defaultProperties
{
    COINOpsName="COINOps";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateCOINOpsTemplate());

	return AlienActivities;
}

// CreateCOINOpsTemplate()
static function X2DataTemplate CreateCOINOpsTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_ResearchFacility ResearchFacility;
	local ActivityCondition_RestrictedActivity RestrictedActivity;
	local ActivityCooldown_Global Cooldown;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.COINOpsName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	ResearchFacility = new class'ActivityCondition_ResearchFacility';
 	ResearchFacility.bAllowedAlienResearchFacilityInRegion = false;
	Template.ActivityCreation.Conditions.AddItem(ResearchFacility);

	RestrictedActivity = new class'ActivityCondition_RestrictedActivity';
	RestrictedActivity.ActivityNames.AddItem(default.BuildResearchFacilityName);
	RestrictedActivity.ActivityNames.AddItem(default.COINResearchName);
	Template.ActivityCreation.Conditions.AddItem(RestrictedActivity);

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.UseDarkEventDifficultyTable = true;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//Cooldown
	Cooldown = new class'ActivityCooldown_Global';
	Cooldown.Cooldown_Hours = default.COIN_OPS_GLOBAL_COOLDOWN;
	Template.ActivityCooldown = Cooldown;

	// required delegates
	Template.OnMissionSuccessFn = COINDarkEventSuccess; //TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = COINDarkEventFailure; // TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = ChooseDarkEventForCoinOps;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none;  //Must be none for activities that spawn dark events
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = COINOpsRewards;
	Template.OnActivityUpdateFn = none;
	Template.GetMissionDarkEventFn = GetTypicalMissionDarkEvent;  // Dark Event attached to last mission in chain

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnCOINOpsComplete;

	return Template;
}

// ChooseDarkEventForCoinOps(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
//select a dark event for the activity and add it to the chosen list in AlienHQ -- this replaces the existing deck system
static function ChooseDarkEventForCoinOps(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	ChooseDarkEvent(false, ActivityState, NewGameState);
}

// OnCOINOpsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnCOINOpsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_DarkEvent DarkEventState;

	if(bAlienSuccess)
	{
		`LWTRACE("COINOpsComplete : Alien Success, marking for immediate DarkEvent Activation");
		// research complete, mark for immediate DarkEvent activation
		DarkEventState = XComGameState_DarkEvent(NewGameState.CreateStateObject(class'XComGameState_DarkEvent', ActivityState.DarkEvent.ObjectID));
		NewGameState.AddStateObject(DarkEventState);
		DarkEventState.EndDateTime = `STRATEGYRULES.GameTime;
		class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, DarkEventState.GetPostMissionText(false), true);

	}
	else
	{
		`LWTRACE("COINOpsComplete : XCOM Success, cancelling DarkEvent");
		//research halted, cancel dark event
		CancelActivityDarkEvent(ActivityState, NewGameState);
	}
}

// COINOpsRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> COINOpsRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> Rewards;

	Rewards[0] = 'Reward_Intel';
	return Rewards;
}