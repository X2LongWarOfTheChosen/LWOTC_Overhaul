class Mission_X2StrategyElement_ProtectData extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int PROTECT_DATA_REGIONAL_COOLDOWN_HOURS_MIN;
var config int PROTECT_DATA_REGIONAL_COOLDOWN_HOURS_MAX;

var name ProtectDataName;

defaultProperties
{
    ProtectDataName="ProtectData";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateProtectDataTemplate());

	return AlienActivities;
}

// CreateProtectDataTemplate()
static function X2DataTemplate CreateProtectDataTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ProtectDataName);
	Template.iPriority = 50;
	Template.ActivityCategory = 'GeneralOps';

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetGeneralOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_POIAvailable');
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_GeneralOpsCap');

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.PROTECT_DATA_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.PROTECT_DATA_REGIONAL_COOLDOWN_HOURS_MAX - default.PROTECT_DATA_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = StartGeneralOp;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetProtectDataRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = ProtectDataComplete;

	return Template;
}

// GetProtectDataRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetProtectDataRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	switch (MissionFamily)
	{
		case 'DestroyObject_LW':
		case 'Hack_LW':
		case 'Recover_LW': RewardArray[0] = 'Reward_Intel'; break;
		case 'Rescue_LW': RewardArray[0] = RescueReward (true, true); break;
		case 'Extract_LW': RewardArray[0] = RescueReward (true, true); break;
		default: break;
	}
	if (CanAddPOI())
	{
		RewardArray[1] = 'Reward_POI_LW';
		RewardArray[2] = 'Reward_Dummy_POI';
	}
	else
	{
		RewardArray[1] = 'Reward_Supplies';
	}
	return RewardArray;
}

// ProtectDataComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function ProtectDataComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
}