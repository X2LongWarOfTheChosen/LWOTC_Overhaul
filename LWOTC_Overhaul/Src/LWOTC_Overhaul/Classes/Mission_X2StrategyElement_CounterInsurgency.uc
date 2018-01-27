class Mission_X2StrategyElement_CounterInsurgency extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

var config int ATTEMPT_COUNTERINSURGENCY_MIN_REBELS;
var config int ATTEMPT_COUNTERINSURGENCY_MIN_WORKING_REBELS;
var config int COIN_MIN_COOLDOWN_HOURS;
var config int COIN_MAX_COOLDOWN_HOURS;

var config int VIGILANCE_DECREASE_ON_ADVENT_RETAL_WIN;
var config int VIGILANCE_CHANGE_ON_XCOM_RETAL_WIN;

var config int COIN_BUCKET;

var name CounterinsurgencyName;

defaultProperties
{
    CounterinsurgencyName="Counterinsurgency";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateCounterinsurgencyTemplate());
	
	return AlienActivities;
}

// CreateCounterinsurgencyTemplate()
static function X2DataTemplate CreateCounterinsurgencyTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;
	local ActivityCondition_MinRebels RebelCondition1;
	local ActivityCondition_MinWorkingRebels RebelCondition2;
	local ActivityCondition_FullOutpostJobBuckets BucketFill;
	local ActivityCondition_RetalMixer RetalMixer;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.CounterinsurgencyName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier
	Template.ActivityCategory = 'RetalOps';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_RetalMixer');

	RetalMixer = new class'ActivityCondition_RetalMixer';
	RetalMixer.UseSpecificJob = false;
	Template.ActivityCreation.Conditions.AddItem(RetalMixer);

	// This makes sure there are enough warm bodies for the mission to be meaningful
	RebelCondition1 = new class 'ActivityCondition_MinRebels';
	RebelCondition1.MinRebels = default.ATTEMPT_COUNTERINSURGENCY_MIN_REBELS;
	Template.ActivityCreation.Conditions.AddItem(RebelCondition1);

	// This lets you hide rebels to avoid the mission
	RebelCondition2 = new class 'ActivityCondition_MinWorkingRebels';
	RebelCondition2.MinWorkingRebels = default.ATTEMPT_COUNTERINSURGENCY_MIN_WORKING_REBELS;
	Template.ActivityCreation.Conditions.AddItem(RebelCondition2);

	BucketFill = new class 'ActivityCondition_FullOutpostJobBuckets';
	BucketFill.FullRetal = true;
	BucketFill.RequiredDays = default.COIN_BUCKET;
	Template.ActivityCreation.Conditions.AddItem(BucketFill);

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	Template.DetectionCalc = new class'ActivityDetectionCalc_Terror';

	//REgional Cooldown
	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.COIN_MIN_COOLDOWN_HOURS;
	Cooldown.RandCooldown_Hours = default.COIN_MAX_COOLDOWN_HOURS - default.COIN_MIN_COOLDOWN_HOURS;
	Template.ActivityCooldown = Cooldown;

	// required delegates
	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = class'Mission_X2StrategyElement_Raid'.static.EmptyRetalBucket;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // use regional AlertLevel

	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = GetCounterinsurgencyRewards;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnCounterInsurgencyComplete;

	return Template;
}

// OnCounterInsurgencyComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnCounterInsurgencyComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
    //local XComGameState_LWOutpost Outpost;
    local XComGameState_WorldRegion Region;
    local XComGameStateHistory History;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

    History = `XCOMHISTORY;

    Region = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if (Region == none)
	    Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

    //Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState, true);

	if (bAlienSuccess)
	{
		//Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));
		//NewGameState.AddStateObject(Outpost);
		//Outpost.WipeOutOutpost(NewGameState);
		RegionalAI.AddVigilance (NewGameState, -default.VIGILANCE_DECREASE_ON_ADVENT_RETAL_WIN);
	}
	else
	{
		// This counteracts base vigilance increase on an xcom win to prevent vigilance spiralling out of control
		RegionalAI.AddVigilance (NewGameState, default.VIGILANCE_CHANGE_ON_XCOM_RETAL_WIN);
	}
}

// GetCounterinsurgencyRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> GetCounterinsurgencyRewards (AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> RewardArray;

	if (MissionFamily == 'DestroyObject_LW')
	{
		RewardArray[0] = 'Reward_Intel';
	}
	else
	{
		RewardArray[0] = 'Reward_Dummy_Unhindered';
	}
	return RewardArray;
}