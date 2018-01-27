//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_POIAvailable.uc
//  AUTHOR:  JL / Pavonis Interactive
//	PURPOSE: Makes sure the POI Deck ain't empty
//---------------------------------------------------------------------------------------
class ActivityCondition_POIAvailable extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local array<XComGameState_PointOfInterest> POIDeck;

    ResistanceHQ = XComGameState_HeadquartersResistance(`XCOMHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	POIDeck = ResistanceHQ.BuildPOIDeck(false);
	if (POIDeck.length > 0)
	{
		return true;
	}
	return false;
}