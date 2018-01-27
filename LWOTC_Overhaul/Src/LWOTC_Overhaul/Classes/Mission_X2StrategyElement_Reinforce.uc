class Mission_X2StrategyElement_Reinforce extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER;
var config int REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE;
var config int REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE;
var config int REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_RAND;

var name ReinforceName;

defaultProperties
{
    ReinforceName="ReinforceActivity";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateReinforceTemplate());
	
	return AlienActivities;
}

// CreateReinforceTemplate()
static function X2DataTemplate CreateReinforceTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.ReinforceName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_Reinforce';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetAnyAlienRegion());

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.FirstMonthPossible = 1;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	//this defines the requirements for discovering each activity
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	// required delegates
	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = none;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetReinforceAlertLevel; // Custom increased AlertLevel because of reinforcements

	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetReinforceRewards;
	Template.OnActivityUpdateFn = none;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnReinforceActivityComplete; // transfer of regional alert/force levels

	return Template;
}

// GetReinforceAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
// uses the higher alert level
static function int GetReinforceAlertLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	local XComGameState_WorldRegion OriginRegionState, DestinationRegionState;
	local WorldRegion_XComGameState_AlienStrategyAI OriginAIState, DestinationAIState;

	OriginRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	if(OriginRegionState == none)
		OriginRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	DestinationRegionState =  XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	if(DestinationRegionState == none)
		DestinationRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));


	OriginAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(OriginRegionState, NewGameState);
	DestinationAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(DestinationRegionState, NewGameState);

	//if(default.ACTIVITY_LOGGING_ENABLED)
	//{
	//	`LWTRACE("Activity " $ ActivityState.GetMyTemplateName $ ": Mission Alert Level =" $ Max (OriginAIState.LocalAlertLevel, DestinationAIState.LocalAlertLevel) + ActivityState.GetMyTemplate().AlertLevelModifier );
	//}
	return Max (OriginAIState.LocalAlertLevel, DestinationAIState.LocalAlertLevel) + ActivityState.GetMyTemplate().AlertLevelModifier;
}

// GetReinforceRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetReinforceRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> Rewards;

	Rewards[0] = 'Reward_Dummy_Materiel';
	return Rewards;
}

// OnReinforceActivityComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnReinforceActivityComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_WorldRegion DestRegionState, OrigRegionState;
	local WorldRegion_XComGameState_AlienStrategyAI DestRegionalAI, OrigRegionalAI;

	History = `XCOMHISTORY;
	DestRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(DestRegionState == none)
		DestRegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	DestRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(DestRegionState, NewGameState, true);

	OrigRegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));
	if(OrigRegionState == none)
		OrigRegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.SecondaryRegions[0].ObjectID));

	OrigRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(OrigRegionState, NewGameState, true);

	if(bAlienSuccess)
	{
		`LWTRACE("ReinforceRegion : Alien Success, moving force/alert levels");

		// reinforcements arrive, boost primary (destination) alert and force levels
		// also make sure the origin didn't lose somebody in the meantime
		if (OrigRegionalAI.LocalAlertLevel > 1)
		{
			DestRegionalAI.LocalAlertLevel += 1;
			OrigRegionalAI.LocalAlertLevel -= 1;
		}
		if(DestRegionalAI.LocalVigilanceLevel - DestRegionalAI.LocalAlertLevel > default.REINFORCE_DIFFERENCE_REQ_FOR_FORCELEVEL_TRANSFER)
		{
			if(OrigRegionalAI.LocalForceLevel > 2)
			{
				DestRegionalAI.LocalForceLevel += 1;
				OrigRegionalAI.LocalForceLevel -= 1;
			}
		}
	}
	else
	{
		`LWTRACE("ReinforceRegion : XCOM Success, reducing alert level, increasing vigilance");
		//reinforcements destroyed, increase orig vigilance and it loses the AlertLevel
		OrigRegionalAI.LocalAlertLevel = Max(OrigRegionalAI.LocalAlertLevel - 1, 1);
		OrigRegionalAI.AddVigilance (NewGameState, default.REINFORCEMENTS_STOPPED_ORIGIN_VIGILANCE_INCREASE);
		AddVigilanceNearby (NewGameState, DestRegionState, default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_BASE, default.REINFORCEMENTS_STOPPED_ADJACENT_VIGILANCE_RAND);
	}
}
