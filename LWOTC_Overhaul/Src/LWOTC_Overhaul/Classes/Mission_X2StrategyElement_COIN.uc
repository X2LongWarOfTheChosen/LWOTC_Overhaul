class Mission_X2StrategyElement_COIN extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int COIN_RESEARCH_GLOBAL_COOLDOWN;
var config int COIN_OPS_GLOBAL_COOLDOWN;

var name COINResearchName;
var name COINOpsName;

defaultProperties
{
    COINResearchName="COINResearch";
	COINOpsName="COINOps";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateCOINResearchTemplate());
	AlienActivities.AddItem(CreateCOINOpsTemplate());
	
	return AlienActivities;
}

// CreateCOINResearchTemplate()
static function X2DataTemplate CreateCOINResearchTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_ResearchFacility ResearchFacility;
	local ActivityCondition_RestrictedActivity RestrictedActivity;
	local ActivityCooldown_Global Cooldown;
	local ActivityCondition_Month MonthRestriction;
	local ActivityCondition_RegionStatus RegionStatus;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.COINResearchName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	RegionStatus = new class'ActivityCondition_RegionStatus';
	RegionStatus.bAllowInContactedOrAdjacentToContacted=true;
	RegionStatus.bAllowInContacted=true;
	RegionStatus.bAllowInUncontacted=true;
	RegionStatus.bAllowInLiberated=false;
	RegionStatus.bAllowInAlien=true;
	Template.ActivityCreation.Conditions.AddItem(RegionStatus);

	ResearchFacility = new class'ActivityCondition_ResearchFacility';
 	ResearchFacility.bAllowedAlienResearchFacilityInRegion = false;
	Template.ActivityCreation.Conditions.AddItem(ResearchFacility);

	RestrictedActivity = new class'ActivityCondition_RestrictedActivity';
	RestrictedActivity.ActivityNames.AddItem(class'Mission_X2StrategyElement_BuildResearchFacility'.default.BuildResearchFacilityName);
	RestrictedActivity.ActivityNames.AddItem(default.COINOpsName);
	Template.ActivityCreation.Conditions.AddItem(RestrictedActivity);

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//Cooldown
	Cooldown = new class'ActivityCooldown_Global';
	Cooldown.Cooldown_Hours = default.COIN_RESEARCH_GLOBAL_COOLDOWN;
	Template.ActivityCooldown = Cooldown;

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.UseDarkEventDifficultyTable = true;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	// required delegates
	Template.OnMissionSuccessFn = COINDarkEventSuccess; //TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = COINDarkEventFailure; // TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = ChooseDarkEventForCoinResearch;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none; //Must be none for activities that spawn dark events
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = COINResearchRewards;
	Template.OnActivityUpdateFn = none;
	Template.GetMissionDarkEventFn = GetTypicalMissionDarkEvent;  // Dark Event attached to last mission in chain

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnCOINResearchComplete;

	return Template;
}

// ChooseDarkEventForCoinResearch(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
//select a dark event for the activity and add it to the chosen list in AlienHQ -- this replaces the existing deck system
static function ChooseDarkEventForCoinResearch(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	ChooseDarkEvent(true, ActivityState, NewGameState);
}

// OnCOINResearchComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnCOINResearchComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_DarkEvent DarkEventState;

	if(bAlienSuccess)
	{
		//if(default.ACTIVITY_LOGGING_ENABLED)
		//{
		//	`LWTRACE("COINResearchComplete : Alien Success, marking for immediate DarkEvent Activation");
		//}
		// research complete, mark for immediate DarkEvent activation
		DarkEventState = XComGameState_DarkEvent(NewGameState.CreateStateObject(class'XComGameState_DarkEvent', ActivityState.DarkEvent.ObjectID));
		NewGameState.AddStateObject(DarkEventState);
		DarkEventState.EndDateTime = `STRATEGYRULES.GameTime;
		class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, DarkEventState.GetPostMissionText(false), true);

	}
	else
	{
		//if(default.ACTIVITY_LOGGING_ENABLED)
		//{
		//	`LWTRACE("COINResearchComplete : XCOM Success, cancelling DarkEvent");
		//}
		//research halted, cancel dark event
		CancelActivityDarkEvent(ActivityState, NewGameState);
	}
}

// COINResearchRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> COINResearchRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> Rewards;

	Rewards[0] = 'Reward_Intel'; // for Neutralize, this will be granted only if captured
	if (MissionFamily == 'Rescue_LW')
	{
		Rewards[1] = RescueReward(false, false);
	}
	else
	{
		if (CanAddPOI())
		{
			Rewards[1] = 'Reward_POI_LW'; // for Neutralize, this will always be granted
			Rewards[2] = 'Reward_Dummy_POI';
		}
		else
		{
			Rewards[1] = 'Reward_Supplies';
		}
	}

	return Rewards;
}

// CreateCOINOpsTemplate()
static function X2DataTemplate CreateCOINOpsTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_ResearchFacility ResearchFacility;
	local ActivityCondition_RestrictedActivity RestrictedActivity;
	local ActivityCooldown_Global Cooldown;
	local ActivityCondition_Month MonthRestriction;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.COINOpsName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	ResearchFacility = new class'ActivityCondition_ResearchFacility';
 	ResearchFacility.bAllowedAlienResearchFacilityInRegion = false;
	Template.ActivityCreation.Conditions.AddItem(ResearchFacility);

	RestrictedActivity = new class'ActivityCondition_RestrictedActivity';
	RestrictedActivity.ActivityNames.AddItem(class'Mission_X2StrategyElement_BuildResearchFacility'.default.BuildResearchFacilityName);
	RestrictedActivity.ActivityNames.AddItem(default.COINResearchName);
	Template.ActivityCreation.Conditions.AddItem(RestrictedActivity);

	MonthRestriction = new class'ActivityCondition_Month';
	MonthRestriction.UseDarkEventDifficultyTable = true;
	Template.ActivityCreation.Conditions.AddItem(MonthRestriction);

	//these define the requirements for discovering each activity, based on the RebelJob "Missions"
	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//Cooldown
	Cooldown = new class'ActivityCooldown_Global';
	Cooldown.Cooldown_Hours = default.COIN_OPS_GLOBAL_COOLDOWN;
	Template.ActivityCooldown = Cooldown;

	// required delegates
	Template.OnMissionSuccessFn = COINDarkEventSuccess; //TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = COINDarkEventFailure; // TypicalAdvanceActivityOnMissionFailure;

	//optional delegates
	Template.OnActivityStartedFn = ChooseDarkEventForCoinOps;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel; // configurable offset to mission difficulty

	Template.GetTimeUpdateFn = none;  //Must be none for activities that spawn dark events
	Template.OnMissionExpireFn = none; // just remove the mission, handle in failure
	Template.GetMissionRewardsFn = COINOpsRewards;
	Template.OnActivityUpdateFn = none;
	Template.GetMissionDarkEventFn = GetTypicalMissionDarkEvent;  // Dark Event attached to last mission in chain

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = OnCOINOpsComplete;

	return Template;
}

// ChooseDarkEventForCoinOps(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
//select a dark event for the activity and add it to the chosen list in AlienHQ -- this replaces the existing deck system
static function ChooseDarkEventForCoinOps(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	ChooseDarkEvent(false, ActivityState, NewGameState);
}

// OnCOINOpsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function OnCOINOpsComplete(bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_DarkEvent DarkEventState;

	if(bAlienSuccess)
	{
		`LWTRACE("COINOpsComplete : Alien Success, marking for immediate DarkEvent Activation");
		// research complete, mark for immediate DarkEvent activation
		DarkEventState = XComGameState_DarkEvent(NewGameState.CreateStateObject(class'XComGameState_DarkEvent', ActivityState.DarkEvent.ObjectID));
		NewGameState.AddStateObject(DarkEventState);
		DarkEventState.EndDateTime = `STRATEGYRULES.GameTime;
		class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, DarkEventState.GetPostMissionText(false), true);

	}
	else
	{
		`LWTRACE("COINOpsComplete : XCOM Success, cancelling DarkEvent");
		//research halted, cancel dark event
		CancelActivityDarkEvent(ActivityState, NewGameState);
	}
}

// COINOpsRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function array<name> COINOpsRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	local array<name> Rewards;

	Rewards[0] = 'Reward_Intel';
	return Rewards;
}

// StateObjectReference GetMissionDarkEvent(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
//select the DarkEvent for the associated mission
static function  StateObjectReference GetMissionDarkEvent(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	//if(default.ACTIVITY_LOGGING_ENABLED)
	//{
	//	`LWTRACE("COIN Research : Retrieving DarkEvent ");
	//}
	return ActivityState.DarkEvent;
}

// ChooseDarkEvent(bool bTactical, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function ChooseDarkEvent(bool bTactical, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_HeadquartersAlien AlienHQ;
	local array<XComGameState_DarkEvent> DarkEventDeck;
	local XComGameState_DarkEvent DarkEventState;
	local int idx;

	AlienHQ = GetAndAddAlienHQ(NewGameState);
	DarkEventDeck = AlienHQ.BuildDarkEventDeck();
	DarkEventState = AlienHQ.DrawFromDarkEventDeck(DarkEventDeck);

	while(DarkEventState.GetMyTemplate().bTactical != bTactical && idx++ < 30)
	{
		DarkEventState = AlienHQ.DrawFromDarkEventDeck(DarkEventDeck);
	}
	if(DarkEventState != none)
	{
		DarkEventState = XComGameState_DarkEvent(NewGameState.CreateStateObject(class'XComGameState_DarkEvent', DarkEventState.ObjectID));
		NewGameState.AddStateObject(DarkEventState);
		DarkEventState.TimesPlayed++;
		DarkEventState.Weight += DarkEventState.GetMyTemplate().WeightDeltaPerPlay;
		DarkEventState.Weight = Clamp(DarkEventState.Weight, DarkEventState.GetMyTemplate().MinWeight, DarkEventState.GetMyTemplate().MaxWeight);

		// Dark Events initiated through activities will not fire on their own independently from the activity, rather it completes
		// when the activity does unless stopped. So do not initiate the timer for this DE and instead set the end date to some time
		// in the future. The InstantiateActivityTimeline will set the expiry time based on the configured timer settings for this DE,
		// so as long as the end time in the DE state itself is beyond this time it won't accidentally trigger before the activity expires.
		DarkEventState.StartDateTime = `STRATEGYRULES.GameTime;
		DarkEventState.EndDateTime = DarkEventState.StartDateTime;
		// Arbitrarily pick a year in the future - this is longer than any DE-triggering activity can run.
		class'X2StrategyGameRulesetDataStructures'.static.AddHours(DarkEventState.EndDateTime, 24 * 28 * 12);
		DarkEventState.TimeRemaining = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInSeconds(DarkEventState.EndDateTime,
			DarkEventState.StartDateTime);
		AlienHQ.ChosenDarkEvents.AddItem(DarkEventState.GetReference());

		if(!bTactical)
		{
			DarkEventState.bSecretEvent = true;
			DarkEventState.SetRevealCost();
		}
		else
		{
			DarkEventState.bSecretEvent = false;
		}
		//if(default.ACTIVITY_LOGGING_ENABLED)
		//{
		//	`LWTRACE("COIN Research : Choosing DarkEvent " $ DarkEventState.GetMyTemplateName());
		//}
		ActivityState.DarkEvent = DarkEventState.GetReference();
	}
	else
	{
		`REDSCREEN("Unable to find valid Dark Event for Activity");
	}
}

// COINDarkEventSuccess(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function COINDarkEventSuccess(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	if(MissionState.HasDarkEvent())
	{
		class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, MissionState.GetDarkEvent().GetPostMissionText(true), false);
	}
	TypicalEndActivityOnMissionSuccess(ActivityState, MissionState, NewGameState);
}

// COINDarkEventFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function COINDarkEventFailure(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	if(MissionState.HasDarkEvent())
	{
		class'XComGameState_HeadquartersResistance'.static.AddGlobalEffectString(NewGameState, MissionState.GetDarkEvent().GetPostMissionText(false), false);
	}
	TypicalAdvanceActivityOnMissionFailure(ActivityState, MissionState, NewGameState);
}

// CancelActivityDarkEvent(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function CancelActivityDarkEvent(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_HeadquartersAlien AlienHQ;
	local StateObjectReference DarkEventRef;
	local XComGameState_DarkEvent DarkEventState;

	AlienHQ = GetAndAddAlienHQ(NewGameState);
	//validate the dark event trying to be removed
	// 1) Make sure the reference is valid
	DarkEventRef = ActivityState.DarkEvent;
	if (DarkEventRef.ObjectID <= 0)
	{
		`REDSCREEN ("Attempting to cancel dark event, but activity has invalid dark event reference");
		`LWTRACE("------------------------------------------");
		`LWTRACE("Attempted to cancel dark event for activity " $ string(ActivityState.GetMyTemplateName()) $ ", but the activity's dark event reference has ObjectID of 0.");
		`LWTRACE("------------------------------------------");
		return;
	}
	// 2) Make sure the reference is on the AlienHQ ChosenDarkEvents list
	if (AlienHQ.ChosenDarkEvents.Find('ObjectID', DarkEventRef.ObjectID) == -1)
	{
		`REDSCREEN ("Attempting to cancel dark event, but dark event is not on AlienHQ.ChosenDarkEvents list");
		`LWTRACE("------------------------------------------");
		`LWTRACE("Attempted to cancel dark event for activity " $ string(ActivityState.GetMyTemplateName()) $ ", but the Alien HQ does not have the DE on the ChosenDarkEvents list.");
		`LWTRACE("------------------------------------------");
		return;
	}
	// 3) Check the referenced dark event has a retrievable state
	DarkEventState =  XComGameState_DarkEvent(`XCOMHISTORY.GetGameStateForObjectID(DarkEventRef.ObjectID));
	if (DarkEventState == none)
	{
		`REDSCREEN ("Attempting to cancel dark event, but dark event has no valid gamestate");
		`LWTRACE("------------------------------------------");
		`LWTRACE("Attempted to cancel dark event for activity " $ string(ActivityState.GetMyTemplateName()) $ ", with ObjectID=" $ string(DarkEventRef.ObjectID) $ " but there is no such DE in the history.");
		`LWTRACE("------------------------------------------");
		return;
	}

	//remove the dark event from the AlienHQ ChosenDarkEvent list
	AlienHQ.CancelDarkEvent(NewGameState, DarkEventRef);
}