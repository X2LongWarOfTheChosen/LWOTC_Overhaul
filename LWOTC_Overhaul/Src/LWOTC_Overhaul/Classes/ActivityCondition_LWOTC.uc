//---------------------------------------------------------------------------------------
//  FILE:    ActivityCondition_LWOTC.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Conditional emchanics for creation of alien activities
//---------------------------------------------------------------------------------------
class ActivityCondition_LWOTC extends Object abstract;

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState) {return true;}
simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState) {return true;}
