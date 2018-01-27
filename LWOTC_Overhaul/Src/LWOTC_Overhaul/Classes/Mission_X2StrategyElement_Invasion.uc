class Mission_X2StrategyElement_Invasion extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int INVASION_REGIONAL_COOLDOWN_HOURS_MIN;
var config int INVASION_REGIONAL_COOLDOWN_HOURS_MAX;
var config int INVASION_MIN_LIBERATED_DAYS;

var name InvasionName;

defaultProperties
{
	InvasionName="Invasion";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateInvasionTemplate());

	return AlienActivities;
}

// CreateInvasionTemplate()
static function X2DataTemplate CreateInvasionTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_RegionStatus RegionStatus;
	local ActivityCooldown_LWOTC Cooldown;
	local ActivityCondition_LiberatedDays FreedomDuration;
	local ActivityCondition_RNG_Region AlienSearchCondition;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.InvasionName);

	Template.CanOccurInLiberatedRegion = true;

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_Invasion';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());

	RegionStatus = new class'ActivityCondition_RegionStatus';
	RegionStatus.bAllowInLiberated = true;
	RegionStatus.bAllowInAlien = false;
	RegionStatus.bAllowInContacted = true;
	Template.ActivityCreation.Conditions.AddItem(RegionStatus);

	FreedomDuration = new class 'ActivityCondition_LiberatedDays';
	FreedomDuration.MinLiberatedDays = default.INVASION_MIN_LIBERATED_DAYS;
	Template.ActivityCreation.Conditions.AddItem(FreedomDuration);

	AlienSearchCondition = new class 'ActivityCondition_RNG_Region';
	AlienSearchCondition.Invasion = true;
	AlienSearchCondition.Multiplier = 1.0;
	AlienSearchCondition.UseFaceless = true;
	Template.ActivityCreation.Conditions.AddItem(AlienSearchCondition);

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.INVASION_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.INVASION_REGIONAL_COOLDOWN_HOURS_MAX - default.INVASION_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = none;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetInvasionForceLevel;
	Template.GetMissionAlertLevelFn = GetOriginAlertLevel;

	Template.GetTimeUpdateFn = none; //TypicalSecondMissionSpawnTimeUpdate;
	Template.OnActivityUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetInvasionRewards;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnInvasionComplete; // transfer of regional alert/force levels

	return Template;
}

// GetInvasionForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetInvasionForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);

	`LWTRACE("Activity " $ ActivityState.GetMyTemplateName $ ": Mission Force Level =" $ RegionalAIState.LocalForceLevel + ActivityState.GetMyTemplate().ForceLevelModifier );
	return RegionalAIState.LocalForceLevel + ActivityState.GetMyTemplate().ForceLevelModifier;
}

// GetOriginAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetOriginAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);

	`LWTRACE("Activity " $ ActivityState.GetMyTemplateName $ ": Mission Alert Level =" $ RegionalAIState.LocalAlertLevel + ActivityState.GetMyTemplate().AlertLevelModifier );
	return RegionalAIState.LocalAlertLevel + ActivityState.GetMyTemplate().AlertLevelModifier;
}

// GetInvasionRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetInvasionRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> Rewards;

	if (MissionFamily == 'SupplyLineRaid_LW')
	{
		Rewards[0] = 'Reward_Dummy_Materiel';
	}
	else
	{
		Rewards[0] = 'Reward_Dummy_Unhindered';
	}
	return Rewards;
}

// OnInvasionComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnInvasionComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion							PrimaryRegionState, OriginRegionState;
	local WorldRegion_XComGameState_AlienStrategyAI			PrimaryRegionalAI, OriginRegionalAI;
	//local XComGameState_LWOutpost							Outpost;

	OriginRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	if(OriginRegionState == none)
		OriginRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	OriginRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(OriginRegionState, NewGameState, true);

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
		PrimaryRegionalAI.LocalAlertLevel = Max (OriginRegionalAI.LocalAlertLevel / 2, 1);
		OriginRegionalAI.LocalAlertLevel = Max (OriginRegionalAI.LocalAlertLevel / 2 + OriginRegionalAI.LocalAlertLevel % 2, 1);

	    //Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(PrimaryRegionState);
		//Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));
		//NewGameState.AddStateObject(Outpost);
		//Outpost.WipeOutOutpost(NewGameState);
	}
	else
	{
		OriginRegionalAI.LocalAlertLevel = Max (OriginRegionalAI.LocalAlertLevel - 2, 1);
		OriginRegionalAI.AddVigilance (NewGameState, 3);
	}
}