class Mission_X2StrategyElement_OffworldReinforcements extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array<int> FORCE_UFO_LAUNCH;

var config int RESCUE_SCIENTIST_WEIGHT;
var config int RESCUE_SOLDIER_WEIGHT;
var config int RESCUE_ENGINEER_WEIGHT;
var config int RESCUE_REBEL_CONDITIONAL_WEIGHT;

var config int EMERGENCY_REINFORCEMENT_PRIMARY_REGION_ALERT_BONUS;
var config int EMERGENCY_REINFORCEMENT_ADJACENT_REGION_ALERT_BONUS;
var config int ADJACENT_REGIONS_REINFORCED_BY_REGULAR_ALERT_UFO;

var config int SUPEREMERGENCY_REINFORCEMENT_PRIMARY_REGION_ALERT_BONUS;
var config int SUPEREMERGENCY_REINFORCEMENT_ADJACENT_REGION_ALERT_BONUS;
var config int ADJACENT_REGIONS_REINFORCED_BY_SUPEREMERGENCY_ALERT_UFO;
var config int SUPEREMERGENCY_ALERT_UFO_GLOBAL_COOLDOWN_DAYS;

var name ScheduledOffworldReinforcementsName;
var name EmergencyOffworldReinforcementsName;
var name SuperEmergencyOffworldReinforcementsName;

defaultProperties
{
	ScheduledOffworldReinforcementsName="ScheduledOffworldReinforcements";
    EmergencyOffworldReinforcementsName="EmergencyOffworldReinforcements";
    SuperEmergencyOffworldReinforcementsName="SuperEmergencyOffworldReinforcements";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateScheduledOffworldReinforcementsTemplate());
	AlienActivities.AddItem(CreateEmergencyOffworldReinforcementsTemplate());
	AlienActivities.AddItem(CreateSuperEmergencyOffworldReinforcementsTemplate());
	
	return AlienActivities;
}

// CreateScheduledOffworldReinforcementsTemplate()
// increases forcelevel in all regions by 1
static function X2DataTemplate CreateScheduledOffworldReinforcementsTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_UFO Cooldown;
	local ActivityCondition_Days DaysRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ScheduledOffworldReinforcementsName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_SafestRegion';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());

	DaysRestriction = new class'X2LWActivityCondition_Days';
	DaysRestriction.FirstDayPossible[0] = default.FORCE_UFO_LAUNCH[0];
	DaysRestriction.FirstDayPossible[1] = default.FORCE_UFO_LAUNCH[1];
	DaysRestriction.FirstDayPossible[2] = default.FORCE_UFO_LAUNCH[2];
	DaysRestriction.FirstDayPossible[3] = default.FORCE_UFO_LAUNCH[3];
	Template.ActivityCreation.Conditions.AddItem(DaysRestriction);

	//Cooldown
	Cooldown = new class'ActivityCooldown_UFO';
	Cooldown.UseForceTable = true;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalEndActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = none;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // configurable offset
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetUFOMissionRewards;
	Template.OnActivityUpdateFn = none;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnScheduledOffworldReinforcementsComplete;

	return Template;
}

// OnScheduledOffworldReinforcementsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnScheduledOffworldReinforcementsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	History = `XCOMHISTORY;

	if (bAlienSuccess)
	{
		foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
		{
			RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
			RegionalAI.LocalForceLevel += 1;
			`LWTRACE("ScheduledOffworldReinforcements : Activity Complete, Alien Win, Increasing ForceLevel by 1 in " $ RegionState.GetMyTemplate().DisplayName );
		}
	}
	else
	{
		`LWTRACE("ScheduledOffworldReinforcementsComplete : XCOM Success, boosting vigilance by 2 in " $ RegionState.GetMyTemplate().DisplayName);
		RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		if(RegionState == none)
			RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
		RegionalAI.AddVigilance (NewGameState, 2);
	}
}

// RescueReward(bool IncludeRebel, bool IncludePrisoner)
static function name RescueReward(bool IncludeRebel, bool IncludePrisoner)
{
	local int iRoll, Rescue_Soldier_Modified_Weight, Rescue_Engineer_Modified_Weight, Rescue_Scientist_Modified_Weight, Rescue_Rebel_Modified_Weight;
	local XComGameStateHistory History;
    local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_HeadquartersXCom XCOMHQ;
	local name Reward;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	XCOMHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	Rescue_Soldier_Modified_Weight = default.RESCUE_SOLDIER_WEIGHT;
	Rescue_Engineer_Modified_Weight = default.RESCUE_SCIENTIST_WEIGHT;
	Rescue_Scientist_Modified_Weight = default.RESCUE_ENGINEER_WEIGHT;
	Rescue_Rebel_Modified_Weight = default.RESCUE_REBEL_CONDITIONAL_WEIGHT;

	// force an engineeer if you have none
	if (XCOMHQ.GetNumberOfEngineers() == 0)
	{
		Rescue_Soldier_Modified_Weight = 0;
		Rescue_Scientist_Modified_Weight = 0;
		Rescue_Rebel_Modified_Weight = 0;
	}
	else
	{
		// force a scientist if you have an engineer but no scientist
		if (XCOMHQ.GetNumberOfScientists() == 0)
		{
			Rescue_Soldier_Modified_Weight = 0;
			Rescue_Rebel_Modified_Weight = 0;
			Rescue_Engineer_Modified_Weight = 0;
		}
	}

	iRoll = `SYNC_RAND_STATIC(Rescue_Scientist_Modified_Weight + Rescue_Engineer_Modified_Weight + (IncludeRebel ? Rescue_Rebel_Modified_Weight : 0) + Rescue_Soldier_Modified_Weight);
	if (Rescue_Scientist_Modified_Weight > 0 && iRoll < Rescue_Scientist_Modified_Weight)
	{
		Reward = 'Reward_Scientist';
		return Reward;
	}
	else
	{
		iRoll -= Rescue_Scientist_Modified_Weight;
	}
	if (Rescue_Engineer_Modified_Weight > 0 && iRoll < Rescue_Engineer_Modified_Weight)
	{
		Reward = 'Reward_Engineer';
		return Reward;
	}
	else
	{
		iRoll -= Rescue_Engineer_Modified_Weight;
	}
	if (IncludeRebel && Rescue_Rebel_Modified_Weight > 0 && iRoll < Rescue_Rebel_Modified_Weight)
	{
		Reward='Reward_Rebel';
		return Reward;
	}
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	if (AlienHQ.CapturedSoldiers.Length > 0 && IncludePrisoner)
	{
		Reward = 'Reward_SoldierCouncil';
	}
	else
	{
		Reward = 'Reward_Soldier';
	}
	return Reward;
}

// GetUFOMissionRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetUFOMissionRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	if (MissionFamily == 'SecureUFO_LW')
	{
		RewardArray[0] = 'Reward_Dummy_Materiel';
		RewardArray[1] = 'Reward_AvengerPower';
		return RewardArray;
	}
	if (MissionFamily == 'Rescue_LW')
	{
		RewardArray[0] = RescueReward(true, true);
		if (instr(RewardArray[0], "Soldier") != -1 && CanAddPOI())
		{
			RewardArray[1] = 'Reward_POI_LW';
			RewardArray[2] = 'Reward_Dummy_POI'; // The first POI rewarded on any mission doesn't display in rewards, so this corrects for that
		}
		return RewardArray;
	}
	RewardArray[0] = 'Reward_Intel';
	return RewardArray;
}

// CreateEmergencyOffworldReinforcementsTemplate()
static function X2DataTemplate CreateEmergencyOffworldReinforcementsTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_UFO Cooldown;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.EmergencyOffworldReinforcementsName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	Template.DetectionCalc = new class'X2LWActivityDetectionCalc';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_AlertUFOLandingRegion';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.FirstMonthPossible = 1;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	//Cooldown
	Cooldown = new class'ActivityCooldown_UFO';
	Cooldown.UseForceTable = false;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalEndActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = none;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // configurable offset
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetUFOMissionRewards;
	//Template.GetNextMissionDurationSecondsFn = GetTypicalMissionDuration;
	Template.OnActivityUpdateFn = none;

	Template.CanBeCompletedFn = none;  // can always be completed
	//Template.GetTimeCompletedFn = TypicalActivityTimeCompleted;
	Template.OnActivityCompletedFn = OnEmergencyOffworldReinforcementsComplete;

	return Template;
}

// OnEmergencyOffworldReinforcementsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnEmergencyOffworldReinforcementsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState, AdjacentRegion;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local WorldRegion_XComGameState_AlienStrategyAI AdjacentRegionalAI;
	local int k, RandIndex;
	local array<StateObjectReference> RegionLinks;

	History = `XCOMHISTORY;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
	if(bAlienSuccess)
	{
		`LWTRACE("EmergencyOffworldReinforcementsComplete : Alien Success, adding AlertLevel to primary and some surrounding regions");
		// reinforcements have arrived
		RegionalAI.LocalAlertLevel += default.EMERGENCY_REINFORCEMENT_PRIMARY_REGION_ALERT_BONUS;
		RegionLinks = RegionState.LinkedRegions;

		for (k=0; k < default.ADJACENT_REGIONS_REINFORCED_BY_REGULAR_ALERT_UFO; k++)
		{
			RandIndex = `SYNC_RAND_STATIC(RegionState.LinkedRegions.Length);
			AdjacentRegion = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(RegionLinks[RandIndex].ObjectID));
			if (AdjacentRegion==none)
				AdjacentRegion = XComGameState_WorldRegion(History.GetGameStateForObjectID(RegionLinks[RandIndex].ObjectID));
			RegionLinks.Remove(RandIndex, 1);
			if (AdjacentRegion != none)
			{
				AdjacentRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(AdjacentRegion, NewGameState, true);
				AdjacentRegionalAI.LocalAlertLevel += default.EMERGENCY_REINFORCEMENT_ADJACENT_REGION_ALERT_BONUS;
			}
		}
	}
	else
	{
		//if(default.ACTIVITY_LOGGING_ENABLED)
		//{
		//	`LWTRACE("EmergencyOffworldReinforcementsComplete : XCOM Success, boosting vigilance");
		//}
		RegionalAI.AddVigilance (NewGameState, 2);
	}
}

// CreateSuperEmergencyOffworldReinforcementsTemplate()
static function X2DataTemplate CreateSuperEmergencyOffworldReinforcementsTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_RestrictedActivity RestrictedActivity;
	local ActivityCondition_AlertVigilance AlertVigilance;
	local ActivityCooldown_Global Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.SuperEmergencyOffworldReinforcementsName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_AlertUFOLandingRegion';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());

	RestrictedActivity = new class'ActivityCondition_RestrictedActivity';
	RestrictedActivity.ActivityNames.AddItem(default.EmergencyOffworldReinforcementsName);
	Template.ActivityCreation.Conditions.AddItem(RestrictedActivity);

	AlertVigilance = new class'ActivityCondition_AlertVigilance';
	AlertVigilance.MaxAlertVigilanceDiff_Global = -class'Mission_X2StrategyElement_LWOTC'.default.SUPER_EMERGENCY_GLOBAL_VIG;
	Template.ActivityCreation.Conditions.AddItem(AlertVigilance);

	//Cooldown -- not difficulty specific here
	Cooldown = new class'ActivityCooldown_Global';
	Cooldown.Cooldown_Hours = default.SUPEREMERGENCY_ALERT_UFO_GLOBAL_COOLDOWN_DAYS * 24.0;
	Template.ActivityCooldown = Cooldown;

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	// required delegates
	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalEndActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = none;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // configurable offset
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetUFOMissionRewards;
	Template.OnActivityUpdateFn = none;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnSuperEmergencyOffworldReinforcementsComplete;

	return Template;
}

// OnSuperEmergencyOffworldReinforcementsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnSuperEmergencyOffworldReinforcementsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameStateHistory							History;
	local XComGameState_WorldRegion						RegionState, AdjacentRegion;
	local WorldRegion_XComGameState_AlienStrategyAI		RegionalAI;
	local WorldRegion_XComGameState_AlienStrategyAI		AdjacentRegionalAI;
	local int k, RandIndex;
	local array<StateObjectReference> RegionLinks;

	History = `XCOMHISTORY;
	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);

	if(bAlienSuccess)
	{
		`LWTRACE("SuperEmergencyOffworldReinforcementsComplete : Alien Success, adding AlertLevel to primary and some surrounding regions");
		RegionalAI.LocalAlertLevel += default.SUPEREMERGENCY_REINFORCEMENT_PRIMARY_REGION_ALERT_BONUS;
		RegionLinks = RegionState.LinkedRegions;
		for (k=0; k < default.ADJACENT_REGIONS_REINFORCED_BY_SUPEREMERGENCY_ALERT_UFO; k++)
		{
			RandIndex = `SYNC_RAND_STATIC(RegionState.LinkedRegions.Length);
			AdjacentRegion = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(RegionLinks[RandIndex].ObjectID));
			if (AdjacentRegion==none)
				AdjacentRegion = XComGameState_WorldRegion(History.GetGameStateForObjectID(RegionLinks[RandIndex].ObjectID));
			RegionLinks.Remove(RandIndex, 1);
			if (AdjacentRegion != none)
			{
				AdjacentRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(AdjacentRegion, NewGameState, true);
				AdjacentRegionalAI.LocalAlertLevel += default.SUPEREMERGENCY_REINFORCEMENT_ADJACENT_REGION_ALERT_BONUS;
			}
		}
	}
	else
	{
		`LWTRACE("SuperEmergencyOffworldReinforcementsComplete : XCOM Success, boosting vigilance");
		//activity halted, boost vigilance by an extra two points over the typical +1
		RegionalAI.AddVigilance (NewGameState, 2);
	}
}
