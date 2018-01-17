//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCooldown.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Cooldown mechanics for creation of alien activities
//---------------------------------------------------------------------------------------
class ActivityCooldown_LWOTC extends Object;

struct ActivityCooldownTimer
{
	var name ActivityName;
	var TDateTime CooldownDateTime;
};

var float Cooldown_Hours;
var float RandCooldown_Hours;

simulated function ApplyCooldown(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local ActivityCooldownTimer Cooldown;

	//add a cooldown to the affected region
	RegionState = XComGameState_WorldRegion(NewGameState.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
	if(RegionState == none)
		RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState, true);

	Cooldown.ActivityName = ActivityState.GetMyTemplateName();
	Cooldown.CooldownDateTime = GetCooldownDateTime();

	RegionalAI.RegionalCooldowns.AddItem(Cooldown);
}

function TDateTime GetCooldownDateTime()
{
	local TDateTime DateTime;

	DateTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
	class'X2StrategyGameRulesetDataStructures'.static.AddTime(DateTime, int(3600.0 * GetCooldownHours()));
	return DateTime;
}

function float GetCooldownHours()
{
	return Cooldown_Hours + `SYNC_FRAND() * RandCooldown_Hours;
}