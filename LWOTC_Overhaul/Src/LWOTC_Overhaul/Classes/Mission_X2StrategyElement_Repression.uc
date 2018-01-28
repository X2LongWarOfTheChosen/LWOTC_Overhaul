class Mission_X2StrategyElement_Repression extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int REPRESSION_REGIONAL_COOLDOWN_HOURS_MIN;
var config int REPRESSION_REGIONAL_COOLDOWN_HOURS_MAX;
var config int REPRESSION_ADVENT_LOSS_CHANCE;
var config int REPRESSION_RECRUIT_REBEL_CHANCE;
var config int REPRESSION_VIGILANCE_INCREASE_CHANCE;
var config int REPRESSION_REBEL_LOST_CHANCE;
var config int REPRESSION_CLONES_RELEASED_CHANCE;
var config int REPRESSION_2ND_REBEL_LOST_CHANCE;

var name RepressionName;

defaultProperties
{
    RepressionName="Repression";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateRepressionTemplate());

	return AlienActivities;
}

// CreateRepressionTemplate()
static function X2DataTemplate CreateRepressionTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityDetectionCalc_LWOTC DetectionCalc;
	local ActivityCondition_RegionStatus RegionStatus;
	local ActivityCooldown_LWOTC Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.RepressionName);

	//no missions

	DetectionCalc = new class'ActivityDetectionCalc_LWOTC';
	DetectionCalc.SetNeverDetected(true);
	Template.DetectionCalc = DetectionCalc;

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.REPRESSION_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.REPRESSION_REGIONAL_COOLDOWN_HOURS_MAX - default.REPRESSION_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	RegionStatus = new class'ActivityCondition_RegionStatus';
	RegionStatus.bAllowInUncontacted = true;
	Template.ActivityCreation.Conditions.AddItem(RegionStatus);

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = none;
	Template.WasMissionSuccessfulFn = none;
	Template.GetMissionForceLevelFn = none;
	Template.GetMissionAlertLevelFn = none;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none;
	Template.GetMissionRewardsFn = none;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;
	Template.OnActivityCompletedFn = RepressionComplete;

	return Template;
}

// InvisibleActivity (AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function bool InvisibleActivity (AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	return false;
}

// RepressionComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function RepressionComplete (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI	NewRegionalAI;
	local XComGameState_WorldRegion					RegionState;
    //local XComGameState_LWOutpost					Outpoststate, NewOutpostState;
	//local XComGameState_LWOutpostManager			OutPostManager;
	local int										iRoll;//, RebelToRemove;
	//local StateObjectReference						NewUnitRef;
	local bool										AIchange;//, OPChange;

	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	If (RegionState == none)
	{
		`LWTRACE ("Repression activity created and ended with no primary region!");
		return;
	}

	if (RegionState.HaveMadeContact() || RegionIsLiberated(RegionState, NewGameState))
		return;

	NewRegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);
	//OutpostManager = class'XComGameState_LWOutpostManager'.static.GetOutpostManager();
	//OutpostState = OutpostManager.GetOutpostForRegion(RegionState);
	//NewOutpostState = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', OutPostState.ObjectID));

	AIChange = false;
	// OPChange = false;

	iRoll == `SYNC_RAND_STATIC (100);
	if (iRoll < default.REPRESSION_ADVENT_LOSS_CHANCE)
	{
		NewRegionalAI.AddVigilance (NewGameState, 1);
		NewRegionalAI.LocalAlertLevel = Max (NewRegionalAI.LocalAlertLevel - 1, 1);
		AIChange = true;
	}

	iRoll == `SYNC_RAND_STATIC (100);
	if (iRoll < default.REPRESSION_RECRUIT_REBEL_CHANCE)
	{
		//NewUnitRef = NewOutpostState.CreateRebel(NewGameState, RegionState, true);
		//NewOutpostState.AddRebel(NewUnitRef, NewGameState);
		//OPChange = true;
	}

	iRoll == `SYNC_RAND_STATIC (100);
	if (iRoll < default.REPRESSION_VIGILANCE_INCREASE_CHANCE)
	{
		NewRegionalAI.AddVigilance (NewGameState, 1);
		AIChange = true;
	}

	iRoll == `SYNC_RAND_STATIC (100);
	if (iRoll > default.REPRESSION_REBEL_LOST_CHANCE)
	{
		/*
		if (OutPostState.Rebels.length > 1)
		{
			RebeltoRemove = `SYNC_RAND_STATIC(NewOutPostState.Rebels.length);
			if (!OutPostState.Rebels[RebelToRemove].IsFaceless)
			{
				NewOutPostState.RemoveRebel (OutPostState.Rebels[RebeltoRemove].Unit, NewGameState);
				NewRegionalAI.AddVigilance (NewGameState, -1);
				AIChange = true;
				OPChange = true;
			}
		}
		*/
	}

	iRoll == `SYNC_RAND_STATIC (100);
	if (iRoll < default.REPRESSION_CLONES_RELEASED_CHANCE)
	{
		NewRegionalAI.LocalAlertLevel += 1;
		AIChange = true;
	}

	iRoll == `SYNC_RAND_STATIC (100);
	if (iRoll < default.REPRESSION_2ND_REBEL_LOST_CHANCE)
	{
		/*
		if (OutPostState.Rebels.length > 1)
		{
			if (!NewOutPostState.Rebels[RebelToRemove].IsFaceless)
			{
				RebeltoRemove = `SYNC_RAND_STATIC(NewOutPostState.Rebels.length);
				NewOutPostState.RemoveRebel (OutPostState.Rebels[RebeltoRemove].Unit, NewGameState);
				NewRegionalAI.AddVigilance (NewGameState, -1);
				AIChange = true;
				OPChange = true;
			}
		}
		*/
	}
	//If (OPChange)
	//	NewGameState.AddStateObject(NewOutpostState);
	if (AIChange)
		NewGameState.AddStateObject(NewRegionalAI);

	`LWTRACE("Repression Finished" @ RegionState.GetMyTemplate().DisplayName @ "Roll:" @ string (iRoll) @ "Rebels left:" /*@ string (NewOutPostState.Rebels.length)*/);

}