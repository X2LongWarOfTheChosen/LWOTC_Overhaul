class Mission_X2StrategyElement_Snare extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int SNARE_GLOBAL_COOLDOWN_HOURS_MIN;
var config int SNARE_GLOBAL_COOLDOWN_HOURS_MAX;

var name SnareName;

defaultProperties
{
	SnareName="Snare";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateSnareTemplate());

	return AlienActivities;
}

// CreateSnareTemplate()
static function X2DataTemplate CreateSnareTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.SnareName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier
	Template.ActivityCategory = 'GeneralOps';

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_GeneralOpsCap');

	Cooldown = new class'ActivityCooldown_Global';
	Cooldown.Cooldown_Hours = default.SNARE_GLOBAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.SNARE_GLOBAL_COOLDOWN_HOURS_MAX - default.SNARE_GLOBAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.FirstMonthPossible = 2;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_HasFaceless');

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = StartGeneralOp;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetSnareReward;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = none;

	return Template;
}

// GetSnareReward(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
function array<Name> GetSnareReward(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
    local array<Name> Rewards;

	Rewards[0] = 'Reward_Intel';
	Rewards[1] = 'Reward_Dummy_POI';
	return Rewards;
}