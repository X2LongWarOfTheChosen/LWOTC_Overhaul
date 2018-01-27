//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_HasFaceless.uc
//  AUTHOR:  JL / Pavonis Interactive
//	PURPOSE: Allow activity creation only if the local outpost has an adviser
//---------------------------------------------------------------------------------------
class ActivityCondition_HasAdviserofClass extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var bool specifictype;
var name advisertype;

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	/*
    local XComGameState_LWOutpost Outpost;
	local XComGameState_Unit Liaison;
    local StateObjectReference LiaisonRef;

	Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
    LiaisonRef = Outpost.GetLiaison();
    Liaison = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(LiaisonRef.ObjectID));

	if (Liaison == none)
		return false;

	if (specifictype)
	{
		if (AdviserType == 'Soldier' && Liaison.IsASoldier())
			return true;
		if (AdviserType == 'Scientist' && Liaison.IsAScientist());
			return true;
		if (AdviserType == 'Engineer' && Liaison.IsAnEngineer());
			return true;
		return false;
	}
	return true;
	*/
	return false;
}
