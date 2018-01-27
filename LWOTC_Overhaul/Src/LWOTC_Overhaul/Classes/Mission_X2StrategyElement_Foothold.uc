class Mission_X2StrategyElement_Foothold extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int FOOTHOLD_GLOBAL_COOLDOWN_HOURS_MIN;
var config int FOOTHOLD_GLOBAL_COOLDOWN_HOURS_MAX;
var config int ATTEMPT_FOOTHOLD_MAX_ALIEN_REGIONS;

var name FootholdName;

defaultProperties
{
	FootholdName="Foothold";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateFootholdTemplate());

	return AlienActivities;
}

// CreateFootholdTemplate()
static function X2DataTemplate CreateFootholdTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_RegionStatus RegionStatus;
	local ActivityCooldown_LWOTC Cooldown;
	local ActivityCondition_MinLiberatedRegions WorldStatus;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.FootholdName);

	Template.CanOccurInLiberatedRegion = true;

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());

	RegionStatus = new class'ActivityCondition_RegionStatus';
	RegionStatus.bAllowInLiberated = true;
	RegionStatus.bAllowInAlien = false;
	RegionStatus.bAllowInContacted = true;
	Template.ActivityCreation.Conditions.AddItem(RegionStatus);

	WorldStatus = new class 'ActivityCondition_MinLiberatedRegions';
	WorldStatus.MaxAlienRegions = default.ATTEMPT_FOOTHOLD_MAX_ALIEN_REGIONS;
	Template.ActivityCreation.Conditions.AddItem(WorldStatus);

	Cooldown = new class'ActivityCooldown_Global';
	Cooldown.Cooldown_Hours = default.FOOTHOLD_GLOBAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.FOOTHOLD_GLOBAL_COOLDOWN_HOURS_MAX - default.FOOTHOLD_GLOBAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetFootholdForceLevel;
	Template.GetMissionAlertLevelFn = GetFootholdAlertLevel;

	Template.GetTimeUpdateFn = none; //TypicalSecondMissionSpawnTimeUpdate;
	Template.OnActivityUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = none;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnFootholdComplete; // transfer of regional alert/force levels

	return Template;
}

// GetFootholdForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetFootholdForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	if (ActivityState.GetMyTemplate().ForceLevelModifier > 0)
		return ActivityState.GetMyTemplate().ForceLevelModifier;

	return 18;
}

// GetFootholdAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetFootholdAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	if (ActivityState.GetMyTemplate().AlertLevelModifier > 0)
		return ActivityState.GetMyTemplate().AlertLevelModifier;

	return 15;
}

// OnFootholdComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnFootholdComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion							PrimaryRegionState;
	local WorldRegion_XComGameState_AlienStrategyAI			PrimaryRegionalAI;
	//local XComGameState_LWOutpost							Outpost;

	if(bAlienSuccess)
	{
		PrimaryRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if(PrimaryRegionState == none)
			PrimaryRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		PrimaryRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(PrimaryRegionState, NewGameState, true);

		PrimaryRegionalAI.bLiberated = false;
		PrimaryRegionalAI.LiberateStage1Complete = false;
		PrimaryRegionalAI.LiberateStage2Complete = false;
		PrimaryRegionalAI.AddVigilance (NewGameState, PrimaryRegionalAI.LocalVigilanceLevel - PrimaryRegionalAI.LocalVigilanceLevel + 10);
		PrimaryRegionalAI.LocalAlertLevel = 10;

		//Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(PrimaryRegionState);
		//Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));
		//NewGameState.AddStateObject(Outpost);
		//Outpost.WipeOutOutpost(NewGameState);
	}
}