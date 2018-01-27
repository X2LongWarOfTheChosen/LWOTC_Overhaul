class Mission_X2StrategyElement_ProtectResearch extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int PROTECT_RESEARCH_REGIONAL_COOLDOWN_HOURS_MIN;
var config int PROTECT_RESEARCH_REGIONAL_COOLDOWN_HOURS_MAX;

var name ProtectResearchName;

defaultProperties
{
    ProtectResearchName="ProtectResearch";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateProtectResearchTemplate());

	return AlienActivities;
}

// CreateProtectResearchTemplate()
static function X2DataTemplate CreateProtectResearchTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_ResearchFacility ResearchFacility;
	local ActivityCooldown_LWOTC Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ProtectResearchName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	Template.DetectionCalc = new class'X2LWActivityDetectionCalc_ProtectResearch';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_ProtectResearch';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AvatarRevealed');
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.PROTECT_RESEARCH_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.PROTECT_RESEARCH_REGIONAL_COOLDOWN_HOURS_MAX - default.PROTECT_RESEARCH_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	ResearchFacility = new class'ActivityCondition_ResearchFacility';
	ResearchFacility.bRequiresHiddenAlienResearchFacilityInWorld = true;
	ResearchFacility.bRequiresAlienResearchFacilityInRegion = false;
	Template.ActivityCreation.Conditions.AddItem(ResearchFacility);

	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_FacilityLeadItem'); // prevents creation if would create more items than there are facilities

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = none;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetProtectResearchRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = ProtectResearchComplete;

	return Template;
}

// GetProtectResearchRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetProtectResearchRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	switch (MissionFamily)
	{
		case 'Hack_LW':
		case 'Recover_LW': RewardArray[0] = 'Reward_Intel'; break;
		case 'Rescue_LW':
		case 'Extract_LW': RewardArray[0] = 'Reward_Scientist'; break;
		default: break;
	}
	RewardArray[1] = 'Reward_FacilityLead';
	return RewardArray;
}

// ProtectResearchComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function ProtectResearchComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
}