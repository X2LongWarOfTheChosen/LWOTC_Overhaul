//---------------------------------------------------------------------------------------
//  FILE:    WorldRegion_XComGameState_AlienStrategyAI.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: This stores regional Alien AI-related information, such as local ForceLevel, AlertnLevel, and VigilanceLevel
//			 This is designed as a component to be attached to each world region, and is generally updated via the Activity Manager or individual Activities
//---------------------------------------------------------------------------------------
class WorldRegion_XComGameState_AlienStrategyAI extends XComGameState_BaseObject dependson(AlienActivity_XComGameState_Manager) config(LWOTC_AlienActivities);

var config float		LOCAL_VIGILANCE_DECAY_RATE_HOURS;
var config int			BASELINE_OUTPOST_WORKERS_FOR_STD_VIG_DECAY;
var config int			MAX_VIG_DECAY_CHANGE_HOURS;
var config bool			BUSY_HAVENS_SLOW_VIGILANCE_DECAY;

var array<ActivityCooldownTimer>	RegionalCooldowns;
var array<name>						PendingTriggeredActivities;

var bool		LiberateStage1Complete;
var bool		LiberateStage2Complete;

var bool		bLiberated;							// adding an explicit bool to represent when a region is liberated, instead of trying to define in implicitly
var int			NumTimesLiberated;					// total number of times this region has been liberated
var TDateTime	LastLiberationTime;					// set when the region status switches from not-liberated to liberated

var bool		bHasResearchFacility;				//adding an explicit bool to represent when a region has a research facility, instead of trying to define in implicitly

var int			LocalForceLevel;					// ForceLevel determines the types of aliens that can appear on missions, so it sort of "technology"
var int			LocalAlertLevel;					// AlertLevel determines the MissionSchedule, so sets the number and types of pods, so is the "difficulty"
var int			LocalVigilanceLevel;				// VigilanceLevel represents how "on guard" the aliens are, how much they view XCOM (or others?) as a "threat"

var int			GeneralOpsCount;					// Tally of Number of General Ops category missions (essentially security holes) in this region. 
													// Divided by month count elsewhere to conditionally cap number.

var TDateTime	LastVigilanceUpdateTime;			// the last time the vigilance level was updated (either increase or decrease)
var TDateTime	NextVigilanceDecayTime, OldNextVigilanceDecayTime;

// Add Vigilance to Regional AI
function AddVigilance(optional XComGameState NewGameState, optional int Amount = 1)
{
	local WorldRegion_XComGameState_AlienStrategyAI UpdatedRegionalAIState;
	local bool bCreatingOwnGameState;
	local int OldVigilanceLevel;

	if (Amount == 0)
	{
		return;
	}

	bCreatingOwnGameState = NewGameState == none;
	if(bCreatingOwnGameState)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating RegionalAI Vigilance Level");
	}

	UpdatedRegionalAIState = WorldRegion_XComGameState_AlienStrategyAI(NewGameState.CreateStateObject(class'WorldRegion_XComGameState_AlienStrategyAI', ObjectID));
	NewGameState.AddStateObject(UpdatedRegionalAIState);

	OldVigilanceLevel = LocalVigilanceLevel;

	UpdatedRegionalAIState.LocalVigilanceLevel += Amount;
	if (UpdatedRegionalAIState.LocalVigilanceLevel < 1)
		UpdatedRegionalAIState.LocalVigilanceLevel = 1;

	if (OldVigilanceLevel != UpdatedRegionalAIState.LocalVigilanceLevel)
	{
		// `LOG ("Updating LastVigilanceUpdateTime for" @ GetOwningRegion().GetMyTemplateName());
		UpdatedRegionalAIState.LastVigilanceUpdateTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
	}

	if(bCreatingOwnGameState)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
}

//Updates RegionalAI based on regular time update
function bool UpdateRegionalAI(XComGameState NewGameState)
{
	local TDateTime CurrentTime;
	local ActivityCooldownTimer Cooldown;
	local array<ActivityCooldownTimer> CooldownsToRemove;
	local bool bUpdated;
	// TODO: Implement havens
	//local XComGameState_LWOutpost OutPostState;
	//local int WorkingRebels, EmptySlots, 
	local int SlotsDelta, HoursMod, OldLocalVigilanceLevel;

	// This is a fix for existing campaigns
	if (class'X2StrategyGameRulesetDataStructures'.static.GetMonth(LastVigilanceUpdateTime) < 1 || class'X2StrategyGameRulesetDataStructures'.static.GetMonth(LastVigilanceUpdateTime) > 12)
	{
		`LOG ("Fixing bad LastVigilanceUpdateTime in" @ GetOwningRegion().GetMyTemplateName());
		LastVigilanceUpdateTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
		bUpdated = true;
	}
	
	// Vigilance Decay
	if (GetOwningRegion().HaveMadeContact() && LocalVigilanceLevel > 1)
	{
		CurrentTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
		NextVigilanceDecayTime = LastVigilanceUpdateTime;
		class'X2StrategyGameRulesetDataStructures'.static.AddHours(NextVigilanceDecayTime, default.LOCAL_VIGILANCE_DECAY_RATE_HOURS);
		
		// modify by number of hidings / inactives. First count people on jobs. subtract that from the max who can be working in a haven (13)
		HoursMod = 0;

		// TODO: Implement havens
		//OutPostState = `LWOUTPOSTMGR.GetOutpostForRegion(GetOwningRegion());
		//WorkingRebels = OutPostState.Rebels.Length - OutPostState.GetNumRebelsOnJob (class'LWRebelJob_DefaultJobSet'.const.HIDING_JOB);
		//EmptySlots = class'XComGameState_LWOutpost'.default.DEFAULT_OUTPOST_MAX_SIZE - WorkingRebels;
		//SlotsDelta = class'XComGameState_LWOutPost'.default.DEFAULT_OUTPOST_MAX_SIZE - default.BASELINE_OUTPOST_WORKERS_FOR_STD_VIG_DECAY - EmptySlots;
		SlotsDelta = 6; // Random number

		HoursMod = (float (SlotsDelta) / float (default.BASELINE_OUTPOST_WORKERS_FOR_STD_VIG_DECAY)) * default.MAX_VIG_DECAY_CHANGE_HOURS;
		//`LWTRACE("Setting new HoursMod for this region" @ HoursMod @ EmptySlots @ SlotsDelta);
		If (!default.BUSY_HAVENS_SLOW_VIGILANCE_DECAY && HoursMod > 0.0)
		{
			HoursMod = 0;
		}
		class'X2StrategyGameRulesetDataStructures'.static.AddHours(NextVigilanceDecayTime, HoursMod);

		//`LWTRACE("Current Time:" @ class'X2StrategyGameRulesetDataStructures'.static.GetDateString(CurrentTime) @ class'X2StrategyGameRulesetDataStructures'.static.GetTimeString(CurrentTime));
		//`LWTRACE("Next Vigilance Decay for" @ GetOwningRegion().GetMyTemplateName() @ "scheduled for" @ class'X2StrategyGameRulesetDataStructures'.static.GetDateString(NextVigilanceDecayTime) @ class'X2StrategyGameRulesetDataStructures'.static.GetTimeString(NextVigilanceDecayTime));
		if (class'X2StrategyGameRulesetDataStructures'.static.LessThan(NextVigilanceDecayTime, class'XComGameState_GeoscapeEntity'.static.GetCurrentTime()))
		{
			OldLocalVigilanceLevel = LocalVigilanceLevel;

			// Towers permanently piss off ADVENT outside of starting region
			if (GetOwningRegion().ResistanceLevel >= eResLevel_Outpost && LocalVigilanceLevel < 2 && !GetOwningRegion().IsStartingRegion())
			{
				LocalVigilanceLevel = 2;
			}
			else
			{	
				LocalVigilanceLevel -= 1;
			}
			if (LocalVigilanceLevel != OldLocalVigilanceLevel)
			{
				//`LWTRACE("PASS: Region " $ GetOwningRegion().GetMyTemplateName() $ " Vigilance Decay by 1.");
				LastVigilanceUpdateTime = CurrentTime;
				bUpdated = true;	
			}
		}
	}

	//handle local activity cooldowns
	foreach RegionalCooldowns(Cooldown)
	{
		if(class'X2StrategyGameRulesetDataStructures'.static.LessThan(Cooldown.CooldownDateTime, class'XComGameState_GeoscapeEntity'.static.GetCurrentTime()))
		{
			CooldownsToRemove.AddItem(Cooldown);
		}
	}
	if(CooldownsToRemove.Length > 0)
	{
		foreach CooldownsToRemove(Cooldown)
		{
			RegionalCooldowns.RemoveItem(Cooldown);
		}
		bUpdated = true;
	}
	return bUpdated;
}

function XComGameState_WorldRegion GetOwningRegion()
{
	return XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(OwningObjectId));
}

// Get Global Alert Level
static function int GetGlobalAlertLevel(optional XComGameState NewGameState)
{
    local XComGameState_WorldRegion RegionState;
	local int AlertLevel;

	AlertLevel = 0;
    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
    {
		AlertLevel += GetRegionalAIFromRegion(RegionState, NewGameState).LocalAlertLevel;
	}

	return AlertLevel;
}

// Get Regional AI from Region State
static function WorldRegion_XComGameState_AlienStrategyAI GetRegionalAIFromRegion(XComGameState_WorldRegion RegionState, optional XComGameState NewGameState, optional bool bAddToGameState)
{
	 local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	if (RegionState == none)
	{
		`REDSCREEN("GetRegionalAIFromRegion ERROR : NONE Region Passed");
		return none;
	}
	if (NewGameState != none)
	{
		foreach NewGameState.IterateByClassType(class'WorldRegion_XComGameState_AlienStrategyAI', RegionalAI)
		{
			if (RegionalAI.OwningObjectId == RegionState.ObjectID)
			{
				return RegionalAI;
			}
		}
	}
	RegionalAI = WorldRegion_XComGameState_AlienStrategyAI(RegionState.FindComponentObject(class'WorldRegion_XComGameState_AlienStrategyAI'));
	if (RegionalAI != none && NewGameState != none && bAddToGameState)
	{
		RegionalAI = WorldRegion_XComGameState_AlienStrategyAI(NewGameState.CreateStateObject(class'WorldRegion_XComGameState_AlienStrategyAI', RegionalAI.ObjectID));
		NewGameState.AddStateObject(RegionalAI);
	}
	return RegionalAI;
}