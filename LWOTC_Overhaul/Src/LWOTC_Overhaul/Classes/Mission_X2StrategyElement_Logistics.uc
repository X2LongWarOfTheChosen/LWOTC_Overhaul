class Mission_X2StrategyElement_Logistics extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int LOGISTICS_REGIONAL_COOLDOWN_HOURS_MIN;
var config int LOGISTICS_REGIONAL_COOLDOWN_HOURS_MAX;

var name LogisticsName;

defaultProperties
{
	LogisticsName="Logistics";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateLogisticsTemplate());

	return AlienActivities;
}

// CreateLogisticsTemplate()
static function X2DataTemplate CreateLogisticsTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.LogisticsName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier
	Template.ActivityCategory = 'GeneralOps';

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetGeneralOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_GeneralOpsCap');

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.LOGISTICS_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.LOGISTICS_REGIONAL_COOLDOWN_HOURS_MAX - default.LOGISTICS_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = StartGeneralOp;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetLogisticsReward;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = none;

	return Template;

}

// GetLogisticsReward(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
function array<Name> GetLogisticsReward(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
    local array<Name> Rewards;

	Rewards[0] = 'Reward_Dummy_Materiel';
	return Rewards;
}