class Mission_X2StrategyElement_PoliticalPrisoner extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int POLITICAL_PRISONERS_REGIONAL_COOLDOWN_HOURS_MIN;
var config int POLITICAL_PRISONERS_REGIONAL_COOLDOWN_HOURS_MAX;

var config int POLITICAL_PRISONERS_REBEL_REWARD_MIN;
var config int POLITICAL_PRISONERS_REBEL_REWARD_MAX;

var name PoliticalPrisonersName;

defaultProperties
{
    PoliticalPrisonersName="PoliticalPrisoners";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreatePoliticalPrisonersTemplate());

	return AlienActivities;
}

// CreatePoliticalPrisonersTemplate()
static function X2DataTemplate CreatePoliticalPrisonersTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCooldown_LWOTC Cooldown;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.PoliticalPrisonersName);
	Template.iPriority = 50; // 50 is default, lower priority gets created earlier
	Template.ActivityCategory = 'GeneralOps';

	Template.DetectionCalc = new class'ActivityDetectionCalc_LWOTC';

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetGeneralOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetTwoActivitiesInWorld());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_GeneralOpsCap');

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.POLITICAL_PRISONERS_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.POLITICAL_PRISONERS_REGIONAL_COOLDOWN_HOURS_MAX - default.POLITICAL_PRISONERS_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalAdvanceActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = StartGeneralOp;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = none; // just remove the mission
	Template.GetMissionRewardsFn = GetPoliticalPrisonersReward;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = none;

	return Template;

}

// GetPoliticalPrisonersReward(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
function array<Name> GetPoliticalPrisonersReward(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
    local array<Name> Rewards;
    local int NumRebels, Roll, RebelChance, MaxRebels;
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState_WorldRegion							Region;
	//local XComGameState_LWOutpost							Outpost;
	local XComGameState_HeadquartersResistance ResistanceHQ;

    switch(MissionFamily)
    {
		/*
	    case 'Jailbreak_LW':
			ResistanceHQ = XComGameState_HeadquartersResistance(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
			// This limits the number of rescues early to smooth out starts
			MaxRebels = Min (default.POLITICAL_PRISONERS_REBEL_REWARD_MAX, default.POLITICAL_PRISONERS_REBEL_REWARD_MAX - (3 - ResistanceHQ.NumMonths));
			NumRebels = `SYNC_RAND(MaxRebels - default.POLITICAL_PRISONERS_REBEL_REWARD_MIN + 1) + default.POLITICAL_PRISONERS_REBEL_REWARD_MIN;
			AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
			if (NumRebels > 0 && AlienHQ.CapturedSoldiers.Length > 0)
			{
				Rewards.AddItem('Reward_SoldierCouncil');
				--NumRebels;
			}

			Region = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
			//Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);

			RebelChance = class'LWRebelJob_DefaultJobSet'.default.RECRUIT_REBEL_BAR;
			if (Outpost.GetRebelCount() > Outpost.GetMaxRebelCount())
			{
				RebelChance -= class'LWRebelJob_DefaultJobSet'.default.RECRUIT_SOLDIER_BIAS_IF_FULL;
			}
			while (NumRebels > 0)
			{
				roll = `SYNC_RAND(class'LWRebelJob_DefaultJobSet'.default.RECRUIT_REBEL_BAR + class'LWRebelJob_DefaultJobSet'.default.RECRUIT_SOLDIER_BAR);
				if (roll < RebelChance)
				{
					Rewards.AddItem(class'X2StrategyElement_DefaultRewards_LW'.const.REBEL_REWARD_NAME);
				}
				else
				{
					Rewards.AddItem('Reward_Rookie');
				}
				--NumRebels;
			}
			return Rewards;
		*/
		default:
			return Rewards;
    }
}

