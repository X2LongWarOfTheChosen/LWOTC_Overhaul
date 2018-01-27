class Mission_X2StrategyElement_HighValuePrisoner extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int HIGH_VALUE_PRISONER_REGIONAL_COOLDOWN_HOURS_MIN;
var config int HIGH_VALUE_PRISONER_REGIONAL_COOLDOWN_HOURS_MAX;

var name HighValuePrisonerName;

defaultProperties
{
	HighValuePrisonerName="HighValuePrisoner";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateHighValuePrisonerTemplate());

	return AlienActivities;
}

// CreateHighValuePrisonerTemplate()
static function X2DataTemplate CreateHighValuePrisonerTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.HighValuePrisonerName);
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
	Cooldown.Cooldown_Hours = default.HIGH_VALUE_PRISONER_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.HIGH_VALUE_PRISONER_REGIONAL_COOLDOWN_HOURS_MAX - default.HIGH_VALUE_PRISONER_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = StartGeneralOp;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetHVPRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = none;

	return Template;
}

// CanAddPOI()
static function bool CanAddPOI()
{
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local array<XComGameState_PointOfInterest> POIDeck;

	ResistanceHQ = XComGameState_HeadquartersResistance(`XCOMHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	POIDeck = ResistanceHQ.BuildPOIDeck(false);
	if (POIDeck.length > 0)
	{
		return true;
	}
	return false;
}

// GetHVPRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetHVPRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	RewardArray[0] = RescueReward(false, true);
	if (instr(RewardArray[0], "Soldier") != -1 && CanAddPOI())
	{
		RewardArray[1] = 'Reward_POI_LW';
		RewardArray[2] = 'Reward_Dummy_POI'; // The first POI rewarded on any mission doesn't display in rewards, so this corrects for that
	}
	return RewardArray;
}