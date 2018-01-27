//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_HasFaceless.uc
//  AUTHOR:  tracktwo / Pavonis Interactive
//	PURPOSE: Allow activity creation only if the local outpost has faceless
//---------------------------------------------------------------------------------------
class ActivityCondition_HasFaceless extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
    //local XComGameState_LWOutpost Outpost;

    //Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);

    //return Outpost.GetNumFaceless() > 0;
	return false;
}
