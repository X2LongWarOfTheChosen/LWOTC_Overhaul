//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_MinRebels
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: Conditionals on the number of rebels in a region
//---------------------------------------------------------------------------------------
class ActivityCondition_MinRebels extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var int MinRebels;

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	/*
	local XComGameState_LWOutpostManager			OutPostManager;
	local XComGameState_LWOutpost					OutPostState;

	OutpostManager = class'XComGameState_LWOutpostManager'.static.GetOutpostManager();
	OutpostState = OutpostManager.GetOutpostForRegion(Region);
	if (OutPostState.Rebels.length >= MinRebels)
	{
		`LWTRACE ("Passed X2LWActivityCondition_MinRebels" @ ActivityCreation.ActivityTemplate.ActivityName);
		return true;
	}
	`LWTRACE ("Passed X2LWActivityCondition_MinRebels" @ ActivityCreation.ActivityTemplate.ActivityName);
	return false;
	*/
	return false;
}



