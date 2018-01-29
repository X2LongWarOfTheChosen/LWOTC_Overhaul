//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_ResearchFacility.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Conditionals on the alien research facilities
//---------------------------------------------------------------------------------------
class ActivityCondition_ResearchFacility extends ActivityCondition_LWOTC config(LWOTC_AlienActivities);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int MAX_UNOBSTRUCTED_FACILITIES;
var config int GLOBAL_ALERT_DELTA_PER_EXTRA_FACILITY;

var bool bRequiresAlienResearchFacilityInRegion;
var bool bRequiresHiddenAlienResearchFacilityInWorld;
var bool bAllowedAlienResearchFacilityInRegion;
var bool bBuildingResearchFacility;

defaultProperties
{
	bRequiresAlienResearchFacilityInRegion=false
	bRequiresHiddenAlienResearchFacilityInWorld=false
	bAllowedAlienResearchFacilityInRegion=true
	bBuildingResearchFacility=false
}

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local AlienActivity_XComGameState ActivityState;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local bool bMeetsCondition;
	local int Facilities;

	if(!bRequiresHiddenAlienResearchFacilityInWorld && !bBuildingResearchFacility)
		return true;

	bMeetsCondition = false;
	History = `XCOMHISTORY;

	// Testing if there is an undiscovered facility in the world
	foreach ActivityCreation.ActivityStates(ActivityState)
	{
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);
		if(RegionalAI.bHasResearchFacility && !ActivityState.bDiscovered && !bBuildingResearchFacility)
		{
			bMeetsCondition = true;
			break;
		}
	}
	if (bBuildingResearchFacility)
	{
		Facilities = 0;
		bMeetsCondition = true;
		foreach History.IterateByClassType(class'WorldRegion_XComGameState_AlienStrategyAI', RegionalAI )
		{
			// How many facilities are already built
			if(RegionalAI.bHasResearchFacility)
			{
				Facilities +=1;
			}
		}
		// Only build more than 3 if feeling safe
		if (Facilities >= default.MAX_UNOBSTRUCTED_FACILITIES)
		{
			if (`ACTIVITYMGR.GetGlobalAlert() - (default.GLOBAL_ALERT_DELTA_PER_EXTRA_FACILITY * (Facilities - default.MAX_UNOBSTRUCTED_FACILITIES + 1)) < `ACTIVITYMGR.GetGlobalVigilance())
			{
				bMeetsCondition = false;
				`LWTRACE("Bad guys can't build research facility because Global Vig is TOO HIGH");
			}
		}
	}
	return bMeetsCondition;
}

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local bool bMeetsCondition;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	bMeetsCondition = true;

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
	if(!RegionalAI.bHasResearchFacility && bRequiresAlienResearchFacilityInRegion)
		bMeetsCondition = false;
	if(RegionalAI.bHasResearchFacility && !bAllowedAlienResearchFacilityInRegion)
		bMeetsCondition = false;
	
	return bMeetsCondition;
}