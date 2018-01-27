class Mission_X2StrategyElement_TroopManeuvers extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config float TROOP_MANEUVERS_BONUS_DETECTION_PER_DAY_PER_ALERT;
var config int TROOP_MANEUVERS_REGIONAL_COOLDOWN_HOURS_MIN;
var config int TROOP_MANEUVERS_REGIONAL_COOLDOWN_HOURS_MAX;

var config int TROOP_MANEUVERS_VIGILANCE_GAIN;
var config array<int> TROOP_MANEUVERS_CHANCE_KILL_ALERT;
var config int TROOP_MANEUVERS_NEIGHBOR_VIGILANCE_BASE;
var config int TROOP_MANEUVERS_NEIGHBOR_VIGILANCE_RAND;

var name TroopManeuversName;

defaultProperties
{
	TroopManeuversName="TroopManeuvers";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateTroopManeuversTemplate());

	return AlienActivities;
}

// CreateTroopManeuversTemplate()
static function X2DataTemplate CreateTroopManeuversTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;
	local ActivityDetectionCalc_TroopManeuvers DetectionCalc;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.TroopManeuversName);
	Template.ActivityCategory = 'GeneralOps';

	DetectionCalc = new class'ActivityDetectionCalc_TroopManeuvers';
	DetectionCalc.DetectionChancePerLocalAlert = default.TROOP_MANEUVERS_BONUS_DETECTION_PER_DAY_PER_ALERT;
	Template.DetectionCalc = DetectionCalc;

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetGeneralOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_GeneralOpsCap');

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.TROOP_MANEUVERS_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.TROOP_MANEUVERS_REGIONAL_COOLDOWN_HOURS_MAX - default.TROOP_MANEUVERS_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = StartGeneralOp;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetTroopManeuversRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = TroopManeuversComplete;

	return Template;
}

// TroopManeuversComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function TroopManeuversComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI	RegionalAI;
	local XComGameState_WorldRegion					RegionState;

	if (!bAlienSuccess)
	{
		RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if(RegionState == none)
			RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if (RegionState == none)
		{
			`LWTRACE ("Error: Can't find region post Troop Maneuvers");
		}
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
		if (RegionalAI == none)
		{
			`LWTRACE ("Error: Can't find regional AI post Troop Maneuvers");
		}
		RegionalAI.AddVigilance(NewGameState, default.TROOP_MANEUVERS_VIGILANCE_GAIN);

		if (`SYNC_RAND_STATIC(100) < default.TROOP_MANEUVERS_CHANCE_KILL_ALERT[`CAMPAIGNDIFFICULTYSETTING])
		{
			`LWTRACE ("TROOP MANEUVERS WIN, Old:" @ string (RegionalAI.LocalAlertLevel) @ "New:" @ string (Max(RegionalAI.LocalAlertLevel - 1, 1)));
			RegionalAI.LocalAlertLevel = Max(RegionalAI.LocalAlertLevel - 1, 1);
			AddVigilanceNearby (NewGameState, RegionState, default.TROOP_MANEUVERS_NEIGHBOR_VIGILANCE_BASE, default.TROOP_MANEUVERS_NEIGHBOR_VIGILANCE_RAND);
		}
	}
}

// GetTroopManeuversRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetTroopManeuversRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	RewardArray[0] = 'Reward_Dummy_Materiel';
	return RewardArray;
}