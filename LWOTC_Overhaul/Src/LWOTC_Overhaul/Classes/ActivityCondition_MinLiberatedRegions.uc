//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_MinLiberatedRegions
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: Conditionals on the number of liberated regions
//---------------------------------------------------------------------------------------
class ActivityCondition_MinLiberatedRegions extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var int MaxAlienRegions;

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	//local int LiberatedRegions, NumRegions
	local int AlienRegions;
	local XComGameState_WorldRegion Region;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	//LiberatedRegions = 0;
	AlienRegions = 0;
	//NumRegions = 0;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', Region)
	{
		//NumRegions += 1;
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
		if (!RegionalAI.bLiberated)
		//{
			//LiberatedRegions += 1;
		//}
		//else
		{
			AlienRegions += 1;
		}
	}

	//`LWTRACE ("Foothold Test: Liberated:" @ string(LiberatedRegions) @ "MaxAlienRegions (to fire activity):" @ string (MaxAlienRegions) @ "NumRegions:" @ string (NumRegions));

	if (AlienRegions <= MaxAlienRegions)
		return true;

	return false;
}
