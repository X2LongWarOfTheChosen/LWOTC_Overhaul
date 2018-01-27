class Mission_X2StrategyElement_Propaganda extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int PROPAGANDA_REGIONAL_COOLDOWN_HOURS_MIN;
var config int PROPAGANDA_REGIONAL_COOLDOWN_HOURS_MAX;

var config int XCOM_WIN_PROPAGANDA_VIGILANCE_GAIN;
var config int PROPAGANDA_ADJACENT_VIGILANCE_BASE;
var config int PROPAGANDA_ADJACENT_VIGILANCE_RAND;


var name PropagandaName;

defaultProperties
{
    PropagandaName="Propaganda";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreatePropagandaTemplate());

	return AlienActivities;
}

// CreatePropagandaTemplate()
static function X2DataTemplate CreatePropagandaTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.PropagandaName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier
	//Template.ActivityCategory = 'GeneralOps';

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	//Template.ActivityCreation.Conditions.AddItem(default.GeneralOpsCondition);				// Can't trigger if region already has two general ops running
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());
	//Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_GeneralOpsCap');

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.PROPAGANDA_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.PROPAGANDA_REGIONAL_COOLDOWN_HOURS_MAX - default.PROPAGANDA_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.FirstMonthPossible = 2;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = none;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = PropagandaRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = PropagandaComplete;

	return Template;
}

// PropagandaComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function PropagandaComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI	RegionalAI;
	local XComGameState_WorldRegion					RegionState;

	`LWTrace ('Propaganda Complete');
	if (!bAlienSuccess)
	{
		RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if (RegionState == none)
		{
			RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
			if (RegionState == none)
			{
				`REDSCREEN("PropagandaComplete: ActivityState has no primary region");
			}
		}
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
		RegionalAI.AddVigilance(NewGameState, default.XCOM_WIN_PROPAGANDA_VIGILANCE_GAIN);
		`LWTrace ("Propaganda XCOM Win: Adding Vigilance");
		AddVigilanceNearby (NewGameState, RegionState, default.PROPAGANDA_ADJACENT_VIGILANCE_BASE, default.PROPAGANDA_ADJACENT_VIGILANCE_RAND);
	}
}

// PropagandaRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> PropagandaRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	if (MissionFamily == 'Neutralize_LW')
	{
		if (CanAddPOI())
		{
			RewardArray[0] = 'Reward_POI_LW'; // this will only be granted if captured
			RewardArray[1] = 'Reward_Dummy_POI'; // The first POI rewarded on any mission doesn't display in rewards, so this corrects for that
			RewardArray[2] = 'Reward_Intel';
		}
		else
		{
			RewardArray[0] = 'Reward_Supplies';
			RewardArray[1] = 'Reward_Intel';
		}
	}
	else
	{
		RewardArray[0] = 'Reward_Intel';
	}
	return RewardArray;
}