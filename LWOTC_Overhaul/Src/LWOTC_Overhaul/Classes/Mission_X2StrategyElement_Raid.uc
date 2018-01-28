class Mission_X2StrategyElement_Raid extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int INTEL_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
var config int INTEL_RAID_REGIONAL_COOLDOWN_HOURS_MAX;
var config int MIN_REBELS_TO_TRIGGER_INTEL_RAID;
var config int INTEL_RAID_BUCKET;

var config int SUPPLY_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
var config int SUPPLY_RAID_REGIONAL_COOLDOWN_HOURS_MAX;
var config int MIN_REBELS_TO_TRIGGER_SUPPLY_RAID;
var config int SUPPLY_RAID_BUCKET;

var config int RECRUIT_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
var config int RECRUIT_RAID_REGIONAL_COOLDOWN_HOURS_MAX;
var config int MIN_REBELS_TO_TRIGGER_RECRUIT_RAID;
var config int RECRUIT_RAID_BUCKET;

var config int VIGILANCE_DECREASE_ON_ADVENT_RAID_WIN;
var config int VIGILANCE_CHANGE_ON_XCOM_RAID_WIN;

var config int PROHIBITED_JOB_DURATION;

var name IntelRaidName;
var name SupplyConvoyName;
var name RecruitRaidName;

defaultProperties
{
	IntelRaidName="IntelRaid";
	SupplyConvoyName="SupplyConvoy";
	RecruitRaidName="RecruitRaid";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;

	AlienActivities.AddItem(CreateIntelRaidTemplate());
	AlienActivities.AddItem(CreateSupplyConvoyTemplate());
	AlienActivities.AddItem(CreateRecruitRaidTemplate());

	return AlienActivities;
}

// CreateIntelRaidTemplate()
static function X2DataTemplate CreateIntelRaidTemplate()
{
	local AlienActivity_X2StrategyElementTemplate					Template;
	local ActivityCooldown_LWOTC						Cooldown;
	//local ActivityCondition_MinRebelsOnJob		RebelCondition;
	local ActivityDetectionCalc_LWOTC					AlwaysDetect;
	//local ActivityCondition_FullOutpostJobBuckets BucketFill;
	//local ActivityCondition_RetalMixer				RetalMixer;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.IntelRaidName);
	Template.ActivityCategory = 'RetalOps';

	AlwaysDetect = new class'ActivityDetectionCalc_LWOTC';
	AlwaysDetect.SetAlwaysDetected(true);
	Template.DetectionCalc = AlwaysDetect;

	//these define the requirements for creating each activity
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetRetalOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	//This makes certain regions more or less likely
	//RetalMixer = new class'ActivityCondition_RetalMixer';
	//RetalMixer.UseSpecificJob = true;
	//RetalMixer.SpecificJob = class'LWRebelJob_DefaultJobSet'.const.INTEL_JOB;
	//Template.ActivityCreation.Conditions.AddItem(RetalMixer);

	//RebelCondition = new class 'ActivityCondition_MinRebelsOnJob';
	//RebelCondition.MinRebelsOnJob = default.MIN_REBELS_TO_TRIGGER_INTEL_RAID;
	//RebelCondition.FacelessReduceMinimum=true;
	//RebelCondition.Job = class'LWRebelJob_DefaultJobSet'.const.INTEL_JOB;
	//Template.ActivityCreation.Conditions.AddItem(RebelCondition);

	//BucketFill = new class 'ActivityCondition_FullOutpostJobBuckets';
	//BucketFill.FullRetal = false;
	//BucketFill.Job = class'LWRebelJob_DefaultJobSet'.const.INTEL_JOB;
	//BucketFill.RequiredDays = default.INTEL_RAID_BUCKET;
	//Template.ActivityCreation.Conditions.AddItem(BucketFill);

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.INTEL_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.INTEL_RAID_REGIONAL_COOLDOWN_HOURS_MAX - default.INTEL_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = EmptyRetalBucket;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = OnRaidExpired; // just remove the mission
	Template.GetMissionRewardsFn = GetAnyRaidRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = IntelRaidCompleted;
    Template.GetMissionSiteFn = GetRebelRaidMissionSite;

	return Template;
}

// IntelRaidCompleted (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function IntelRaidCompleted (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local XComGameState_WorldRegion Region;

	Region = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if (Region == none)
	   Region = XComGameState_WorldRegion(`XCOMHistory.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState, true);
	if (bAlienSuccess)
	{
		ProhibitJob (ActivityState, NewGameState, 'Intel');
		RegionalAI.AddVigilance (NewGameState, -default.VIGILANCE_DECREASE_ON_ADVENT_RAID_WIN);
	}
	else
	{
		// This counteracts base vigilance increase on an xcom win to prevent vigilance spiralling up in vig->retal cycle
		RegionalAI.AddVigilance (NewGameState, default.VIGILANCE_CHANGE_ON_XCOM_RAID_WIN);
	}
}

// CreateSupplyConvoyTemplate()
static function X2DataTemplate CreateSupplyConvoyTemplate()
{
	local AlienActivity_X2StrategyElementTemplate					Template;
	//local ActivityCondition_MinRebelsOnJob		RebelCondition;
	local ActivityDetectionCalc_LWOTC					AlwaysDetect;
	local ActivityCooldown_LWOTC						Cooldown;
	//local ActivityCondition_FullOutpostJobBuckets BucketFill;
	//local ActivityCondition_RetalMixer				RetalMixer;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.SupplyConvoyName);
	Template.ActivityCategory = 'RetalOps';

	AlwaysDetect = new class'ActivityDetectionCalc_LWOTC';
	AlwaysDetect.SetAlwaysDetected(true);
	Template.DetectionCalc = AlwaysDetect;

	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetRetalOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	//RetalMixer = new class'ActivityCondition_RetalMixer';
	//RetalMixer.UseSpecificJob = true;
	//RetalMixer.SpecificJob = class'LWRebelJob_DefaultJobSet'.const.SUPPLY_JOB;
	//Template.ActivityCreation.Conditions.AddItem(RetalMixer);

	//RebelCondition = new class 'ActivityCondition_MinRebelsOnJob';
	//RebelCondition.MinRebelsOnJob = default.MIN_REBELS_TO_TRIGGER_SUPPLY_RAID;
	//RebelCondition.Job = class'LWRebelJob_DefaultJobSet'.const.SUPPLY_JOB;
	//RebelCondition.FacelessReduceMinimum=false;
	//Template.ActivityCreation.Conditions.AddItem(RebelCondition);

	//BucketFill = new class 'ActivityCondition_FullOutpostJobBuckets';
	//BucketFill.FullRetal = false;
	//BucketFill.Job = class'LWRebelJob_DefaultJobSet'.const.SUPPLY_JOB;
	//BucketFill.RequiredDays = default.SUPPLY_RAID_BUCKET;
	//Template.ActivityCreation.Conditions.AddItem(BucketFill);

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.SUPPLY_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.SUPPLY_RAID_REGIONAL_COOLDOWN_HOURS_MAX - default.SUPPLY_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = EmptyRetalBucket;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = OnRaidExpired; // just remove the mission
	Template.GetMissionRewardsFn = GetAnyRaidRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = SupplyConvoyCompleted;
    Template.GetMissionSiteFn = GetRebelRaidMissionSite;

	return Template;
}

// SupplyConvoyCompleted (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function SupplyConvoyCompleted (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion Region;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	Region = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if (Region == none)
		Region = XComGameState_WorldRegion(`XCOMHistory.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState, true);

	if (bAlienSuccess)
	{
		ProhibitJob (ActivityState, NewGameState, 'Resupply');
		RegionalAI.AddVigilance (NewGameState, -default.VIGILANCE_DECREASE_ON_ADVENT_RAID_WIN);
	}
	else
	{
		// This counteracts base vigilance increase on an xcom win to prevent vigilance spiralling up in vig->retal cycle
		RegionalAI.AddVigilance (NewGameState, default.VIGILANCE_CHANGE_ON_XCOM_RAID_WIN);
	}
}

// CreateRecruitRaidTemplate()
static function X2DataTemplate CreateRecruitRaidTemplate()
{
	local AlienActivity_X2StrategyElementTemplate						Template;
	//local ActivityCondition_MinRebelsOnJob			RebelCondition;
	local ActivityDetectionCalc_LWOTC						AlwaysDetect;
	local ActivityCooldown_LWOTC							Cooldown;
	//local ActivityCondition_FullOutpostJobBuckets	BucketFill;
	//local ActivityCondition_RetalMixer				RetalMixer;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.RecruitRaidName);
	Template.ActivityCategory = 'RetalOps';

	AlwaysDetect = new class'ActivityDetectionCalc_LWOTC';
	AlwaysDetect.SetAlwaysDetected(true);
	Template.DetectionCalc = AlwaysDetect;

	Template.ActivityCreation = new class'ActivityCreation_LWOTC';
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInWorld());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetContactedAlienRegion());
	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetRetalOpsCondition());
	Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_AlertVigilance');

	//RetalMixer = new class'ActivityCondition_RetalMixer';
	//RetalMixer.UseSpecificJob = true;
	//RetalMixer.SpecificJob = class'LWRebelJob_DefaultJobSet'.const.RECRUIT_JOB;
	//Template.ActivityCreation.Conditions.AddItem(RetalMixer);

	//RebelCondition = new class 'ActivityCondition_MinRebelsOnJob';
	//RebelCondition.MinRebelsOnJob = default.MIN_REBELS_TO_TRIGGER_RECRUIT_RAID;
	//RebelCondition.FacelessReduceMinimum=true;
	//RebelCondition.Job = class'LWRebelJob_DefaultJobSet'.const.RECRUIT_JOB;
	//Template.ActivityCreation.Conditions.AddItem(RebelCondition);

	//BucketFill = new class 'ActivityCondition_FullOutpostJobBuckets';
	//BucketFill.FullRetal = false;
	//BucketFill.Job = class'LWRebelJob_DefaultJobSet'.const.RECRUIT_JOB;
	//BucketFill.RequiredDays = default.RECRUIT_RAID_BUCKET;
	//Template.ActivityCreation.Conditions.AddItem(BucketFill);

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.RECRUIT_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.RECRUIT_RAID_REGIONAL_COOLDOWN_HOURS_MAX - default.RECRUIT_RAID_REGIONAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.OnActivityStartedFn = EmptyRetalBucket;
	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetTypicalMissionForceLevel; // use regional ForceLevel
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;
	Template.GetTimeUpdateFn = none;
	Template.OnMissionExpireFn = OnRaidExpired; // just remove the mission
	Template.GetMissionRewardsFn = GetAnyRaidRewards;
	Template.OnActivityUpdateFn = none;
	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = RecruitRaidCompleted;
    Template.GetMissionSiteFn = GetRebelRaidMissionSite;

	return Template;
}

// RecruitRaidCompleted (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function RecruitRaidCompleted (bool bAlienSuccess, AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion Region;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	Region = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if (Region == none)
		Region = XComGameState_WorldRegion(`XCOMHistory.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState, true);

	if (bAlienSuccess)
	{
		ProhibitJob (ActivityState, NewGameState, 'Recruit');
		RegionalAI.AddVigilance (NewGameState, -default.VIGILANCE_DECREASE_ON_ADVENT_RAID_WIN);
	}
	else
	{
		RegionalAI.AddVigilance (NewGameState, default.VIGILANCE_CHANGE_ON_XCOM_RAID_WIN);
	}
}

// EmptyRetalBucket (AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
static function EmptyRetalBucket (AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	/*
	local XComGameState_LWOutpost							Outpost;
	local XComGameState_WorldRegion							Region;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', Region)
	{
		//Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
		Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', OutPost.ObjectID));
		NewGameState.AddStateObject(Outpost);
		switch (ActivityState.GetMyTemplateName())
		{
			case default.IntelRaidName:
				OutPost.ResetJobBucket(class'LWRebelJob_DefaultJobSet'.const.INTEL_JOB);
				break;
			case default.SupplyConvoyName:
				OutPost.ResetJobBucket(class'LWRebelJob_DefaultJobSet'.const.SUPPLY_JOB);
				break;
			case default.RecruitRaidName:
				OutPost.ResetJobBucket(class'LWRebelJob_DefaultJobSet'.const.RECRUIT_JOB);
				break;
			case default.CounterInsurgencyName:
				OutPost.TotalResistanceBucket = 0;
				break;
			default:
				break;
		}
	}
	*/
}

// GetAnyRaidRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
function array<Name> GetAnyRaidRewards(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
    local array<Name> Rewards;

	Rewards[0] = 'Reward_Dummy_Unhindered';
	return Rewards;
}

// ProhibitJob (AlienActivity_XComGameState ActivityState, XComGameState NewGameState, name JobName)
static function ProhibitJob (AlienActivity_XComGameState ActivityState, XComGameState NewGameState, name JobName)
{
	/*
	local XComGameState_WorldRegion							Region;
	local XComGameState_LWOutpost							Outpost;
	local bool												ExtendCurrent;
	local int												k;
	local string											AlertString;
	local XGParamTag ParamTag;

	`LWTRACE ("PROHIBITING JOB:" @ JobName);
	Region = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	//Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
	Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', OutPost.ObjectID));
	NewGameState.AddStateObject(Outpost);
	ExtendCurrent = false;

	for (k = 0; k < Outpost.ProhibitedJobs.Length; k++)
	{
		if (OutPost.ProhibitedJobs[k].Job == JobName)
		{
			ExtendCurrent = true;
			OutPost.ProhibitedJobs[k].DaysLeft += default.PROHIBITED_JOB_DURATION;
			break;
		}
	}
	if (!ExtendCurrent)
	{
		OutPost.AddProhibitedJob(JobName, default.PROHIBITED_JOB_DURATION);
		//`LWTRACE ("ADDING PROHIBITED JOB:" @ JobName);
		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		ParamTag.IntValue0 = default.PROHIBITED_JOB_DURATION;
		ParamTag.StrValue0 = OutPost.GetJobName(JobName);
		ParamTag.StrValue1 = Region.GetMyTemplate().DisplayName;
		AlertString = `XEXPAND.ExpandString(class'XComGameState_LWOutPost'.default.m_strProhibitedJobAlert);
		`HQPRES.Notify (AlertString);
		for (k=0; k < OutPost.Rebels.Length; k++)
		{
			if (OutPost.Rebels[k].Job == JobName)
			{
				//`LWTRACE ("SETTING REBEL JOB TO HIDING:" @ JobName);
				OutPost.SetRebelJob (OutPost.Rebels[k].Unit, 'Hiding');
			}
		}
	}
	*/
}

// OnRaidExpired (AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function OnRaidExpired (AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	/*
	local int k;
	local XComGameState_MissionSiteRebelRaid_LW RaidState;
	local XComGameSTate_WorldRegion Region;
	local XComGameState_LWOutpost OutPost;

	RaidState = XComGameState_MissionSiteRebelRaid_LW(MissionState);
	if (RaidState != none)
	{
		Region = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		//Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
		Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', OutPost.ObjectID));
		NewGameState.AddStateObject(Outpost);

		// All rebels on this mission are killed (faceless or not)
		for (k=0; k < OutPost.Rebels.Length; k++)
		{
			if (RaidState.Rebels.Find('ObjectID', OutPost.Rebels[k].Unit.ObjectID) != -1)
			{
				OutPost.RemoveRebel(OutPost.Rebels[k].Unit, NewGameState);
				--k;
			}
		}

		// If we have an adviser on this mission, kill/capture them.
		if (Outpost.HasLiaisonValidForMission(MissionState.GeneratedMission.Mission.sType))
		{
			Outpost.RemoveAndCaptureLiaison(NewGameState);
		}
	}
	*/
}

// GetRebelRaidMissionSite(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function XComGameState_MissionSite GetRebelRaidMissionSite(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	/*
    local XComGameState_LWOutpost Outpost;
    local XComGameState_WorldRegion Region;
    local XComGameStateHistory History;
    local XComGameState_MissionSiteRebelRaid_LW RaidMission;
    local array<StateObjectReference> arrRebels;
    local int i;
    local int NumRebelsToChoose;
    local name RequiredJob;

    History = `XCOMHISTORY;

    Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
    //Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);

    switch(MissionFamily)
    {
        case 'IntelRaid_LW':
            RequiredJob = class'LWRebelJob_DefaultJobSet'.const.INTEL_JOB;
            break;
		case 'SupplyConvoy_LW':
            RequiredJob = class'LWRebelJob_DefaultJobSet'.const.SUPPLY_JOB;
            break;
		case 'RecruitRaid_LW':
			RequiredJob = class'LWRebelJob_DefaultJobSet'.const.RECRUIT_JOB;
            break;

        default:
            `Redscreen("GetRebelRaidMissionSite called for an unsupported family: " $ MissionFamily);
            // Not a supported mission.
            return XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite'));
    }

    for (i = 0; i < Outpost.Rebels.Length; ++i)
    {
        if (Outpost.Rebels[i].Job == RequiredJob)
        {
            arrRebels.AddItem(Outpost.Rebels[i].Unit);
        }
    }

    RaidMission = XComGameState_MissionSiteRebelRaid_LW(NewGameState.CreateStateobject(class'XComGameState_MissionSiteRebelRaid_LW'));

    NumRebelsToChoose = default.RAID_MISSION_MIN_REBELS +
        `SYNC_RAND_STATIC(default.RAID_MISSION_MAX_REBELS - default.RAID_MISSION_MIN_REBELS);
    NumRebelsToChoose = Min(NumRebelsToChoose, arrRebels.Length);

    while(NumRebelsToChoose > 0)
    {
        i = `SYNC_RAND_STATIC(arrRebels.Length);
        RaidMission.Rebels.AddItem(arrRebels[i]);
        arrRebels.Remove(i, 1);
        --NumRebelsToChoose;
    }

    // For recruit raids the rebels spawn with the squad and aren't armed. The others use the default spawn at objective.
    if (MissionFamily == 'RecruitRaid_LW')
    {
        RaidMission.SpawnType = eRebelRaid_SpawnWithSquad;
        RaidMission.ArmRebels = false;
    }

    return RaidMission;
	*/
}