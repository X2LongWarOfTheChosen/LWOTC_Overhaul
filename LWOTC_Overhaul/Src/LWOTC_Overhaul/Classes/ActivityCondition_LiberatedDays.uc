//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_MinLiberatedRegions
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: Conditionals on the number of days a region has been liberated
//---------------------------------------------------------------------------------------
class ActivityCondition_LiberatedDays extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var int MinLiberatedDays;

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local TDateTime CurrentTime;
	local int iDaysPassed;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
	if(RegionalAI.bLiberated)
	{
		CurrentTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
		iDaysPassed = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInDays(CurrentTime, RegionalAI.LastLiberationTime);
		if (iDaysPassed >= MinLiberatedDays)
			return true;
	}
	return false;
}