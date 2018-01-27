//---------------------------------------------------------------------------------------
//  FILE:    ActivityDetectionCalc_LWOTC.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Basic detection mechanics for alien activities
//---------------------------------------------------------------------------------------
class ActivityDetectionCalc_LWOTC extends Object config(LWOTC_AlienActivities);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array <bool>  USE_DETECTION_FORCE_LEVEL_MODIFIERS;
var config array <float> FORCE_LEVEL_DETECTION_MODIFIER_ROOKIE;
var config array <float> FORCE_LEVEL_DETECTION_MODIFIER_VETERAN;
var config array <float> FORCE_LEVEL_DETECTION_MODIFIER_COMMANDER;
var config array <float> FORCE_LEVEL_DETECTION_MODIFIER_LEGENDARY;

struct DetectionModifierInfo
{
	var float   Value;
	var string  Reason;
};

var bool bSkipUncontactedRegions;
var protectedwrite bool bAlwaysDetected;
var protectedwrite bool bNeverDetected;

var array<DetectionModifierInfo> DetectionModifiers;       // Can be configured in the activity template to provide always-on modifiers.

var protected name RebelMissionsJob;

defaultProperties
{
	bSkipUncontactedRegions = true
	RebelMissionsJob="Intel"
}

// AddDetectionModifier(const int ModValue, const string ModReason)
function AddDetectionModifier(const int ModValue, const string ModReason)
{
	local DetectionModifierInfo Mod;
	Mod.Value = ModValue;
	Mod.Reason = ModReason;
	DetectionModifiers.AddItem(Mod);
}

// SetAlwaysDetected(bool Val)
function SetAlwaysDetected(bool Val)
{
	bAlwaysDetected = Val;
	if(Val)
		bNeverDetected = false;
}

// SetNeverDetected(bool Val)
function SetNeverDetected(bool Val)
{
	bNeverDetected = Val;
	if(Val)
		bAlwaysDetected = false;
}

// CanBeDetected(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
//activity detection mechanic
function bool CanBeDetected(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	//local XComGameState_LWOutpost OutpostState;
	//local XComGameState_LWOutpostManager OutpostManager;
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local float DetectionChance, RandValue;

	`LWTRACE("TypicalActivity Discovery: Starting");
	if(bAlwaysDetected)
		return true;

	if(bNeverDetected)
		return false;

	//OutpostManager = class'XComGameState_LWOutpostManager'.static.GetOutpostManager();
	
    RegionState = GetRegion(ActivityState);
	if(RegionState == none)
	{
		`REDSCREEN("Cannot find region for activity " $ ActivityState.GetMyTemplateName());
		return false;
	}
	if(!RegionState.HaveMadeContact() && ShouldSkipUncontactedRegion())
		return false;

	//OutpostState = OutpostManager.GetOutpostForRegion(RegionState);
	//if(OutpostState == none)
	//{
	//	`REDSCREEN("Activity Discovery : No outpost found in region");
	//	return false;
	//}

	ActivityTemplate = ActivityState.GetMyTemplate();
	ActivityState.MissionResourcePool += GetMissionIncomeForUpdate();//OutpostState);
	ActivityState.MissionResourcePool += GetExternalMissionModifiersForUpdate(ActivityState, NewGameState); // for other mods to hook into

	if(MeetsRequiredMissionIncome(ActivityState, ActivityTemplate)) // have enough income
	{
		if(MeetsOnMissionJobRequirements(ActivityState, ActivityTemplate))//, OutpostState))  // have enough rebels on job -- use the daily income, to include Avenger/Dark Events, etc
		{
	
			DetectionChance = GetDetectionChance(ActivityState, ActivityTemplate);//, OutpostState);
			`LWTRACE("DISCOVERY:" @ RegionState.GetMyTemplate().DisplayName @ ": DetectionChance for" @ ActivityTemplate.DataName @ ":" @ string(DetectionChance));

			RandValue = `SYNC_FRAND() * 100.0;
			if(RandValue < DetectionChance)  // pass random roll
			{
				`LWTRACE("SUCCESS: Roll was" @ string(Randvalue));
				//we found the activity (which will spawn the mission) so spend the income
				ActivityState.MissionResourcePool = 0;
				return true;
			}
		}
	}

	return false;
}

// GetDetectionChance(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate) //, XComGameState_LWOutpost OutpostState)
function float GetDetectionChance(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate) //, XComGameState_LWOutpost OutpostState)
{
	local float ResourcePool;
	local float DetectionChance;
	local DetectionModifierInfo Mod;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	ResourcePool = ActivityState.MissionResourcePool;
	if (ActivityTemplate.RequiredRebelMissionIncome > 0)
		ResourcePool -= ActivityTemplate.RequiredRebelMissionIncome;
	DetectionChance = ResourcePool / 100.0 * ActivityTemplate.DiscoveryPctChancePerDayPerHundredMissionIncome;

	//add fixed modifiers
	foreach DetectionModifiers(Mod)
	{
		DetectionChance += Mod.Value;
	}

	// insert something sort of cheaty
	`LWTRACE ("Bugcheck:" @ string(`CAMPAIGNDIFFICULTYSETTING) @ default.USE_DETECTION_FORCE_LEVEL_MODIFIERS[`CAMPAIGNDIFFICULTYSETTING]);
	if (default.USE_DETECTION_FORCE_LEVEL_MODIFIERS[`CAMPAIGNDIFFICULTYSETTING])
	{
	    RegionState = GetRegion(ActivityState);
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
		if(RegionState == none)
		{
			`REDSCREEN("Cannot find region for activity " $ ActivityState.GetMyTemplateName());
		}
		switch (`CAMPAIGNDIFFICULTYSETTING)
		{
			case 0: DetectionChance += default.FORCE_LEVEL_DETECTION_MODIFIER_ROOKIE[clamp(RegionalAI.LocalForceLevel, 1, 20)]; break;
			case 1: DetectionChance += default.FORCE_LEVEL_DETECTION_MODIFIER_VETERAN[clamp(RegionalAI.LocalForceLevel, 1, 20)]; break;
			case 2: DetectionChance += default.FORCE_LEVEL_DETECTION_MODIFIER_COMMANDER[clamp(RegionalAI.LocalForceLevel, 1, 20)]; break;
			case 3: DetectionChance += default.FORCE_LEVEL_DETECTION_MODIFIER_LEGENDARY[clamp(RegionalAI.LocalForceLevel, 1, 20)]; break;
			default: break;
		}
	}

	//normalize for update rate
	DetectionChance *= float(class'AlienActivity_X2StrategyElementTemplate'.default.HOURS_BETWEEN_ALIEN_ACTIVITY_DETECTION_UPDATES) / 24.0;

	return DetectionChance;
}

// MeetsOnMissionJobRequirements(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate) //, XComGameState_LWOutpost OutpostState)
function bool MeetsOnMissionJobRequirements(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate) //, XComGameState_LWOutpost OutpostState)
{
	return true;
	//return OutpostState.GetTrueDailyIncomeForJob(default.RebelMissionsJob) >= ActivityTemplate.MinimumRequiredIntelDailyIncome;
}

// MeetsRequiredMissionIncome(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate)
function bool MeetsRequiredMissionIncome(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate)
{
	return ActivityState.MissionResourcePool >= ActivityTemplate.RequiredRebelMissionIncome;
}

// GetMissionIncomeForUpdate()// XComGameState_LWOutpost OutpostState)
function float GetMissionIncomeForUpdate()// XComGameState_LWOutpost OutpostState)
{
	local float NewIncome;

	NewIncome = 10; //OutpostState.GetDailyIncomeForJob(default.RebelMissionsJob);
	NewIncome *= float(class'AlienActivity_X2StrategyElementTemplate'.default.HOURS_BETWEEN_ALIEN_ACTIVITY_DETECTION_UPDATES) / 24.0;

	return NewIncome;
}

// GetExternalMissionModifiersForUpdate(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
function float GetExternalMissionModifiersForUpdate(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
    local XComLWTuple Tuple;

    Tuple = new class'XComLWTuple';
	Tuple.Data.Add(1);
    Tuple.Id = 'GetActivityDetectionIncomeModifier';

    // add the new amount
    Tuple.Data[0].Kind = XComLWTVFloat;
    Tuple.Data[0].f = 0;

    // Fire the event
    `XEVENTMGR.TriggerEvent('GetActivityDetectionIncomeModifier', Tuple, ActivityState, NewGameState);

    if (Tuple.Data.Length == 0 || Tuple.Data[0].Kind != XComLWTVFloat)
		return 0;
	else
		return Tuple.Data[0].f;
}

// GetRegion(AlienActivity_XComGameState ActivityState)
function XComGameState_WorldRegion GetRegion(AlienActivity_XComGameState ActivityState)
{
	return XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
}

// ShouldSkipUncontactedRegion()
function bool ShouldSkipUncontactedRegion()
{
	 return bSkipUncontactedRegions;
}

// ShouldSkipLiberatedRegion(AlienActivity_X2StrategyElementTemplate ActivityTemplate)
function bool ShouldSkipLiberatedRegion(AlienActivity_X2StrategyElementTemplate ActivityTemplate)
{
	 return !ActivityTemplate.CanOccurInLiberatedRegion;
}