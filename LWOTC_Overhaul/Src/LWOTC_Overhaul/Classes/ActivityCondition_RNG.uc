//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_RNG.uc
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: Conditional on a die rolled every activity check
//---------------------------------------------------------------------------------------

class ActivityCondition_RNG extends ActivityCondition_LWOTC;

var float CheckValue; // should be between 0 and 100;

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local float RandValue;
	RandValue = `SYNC_FRAND() * 100.0;
	if (RandValue <= CheckValue)
		return true;

	return false;
}