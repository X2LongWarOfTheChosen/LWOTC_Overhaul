//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_RegionStatus.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Conditionals on the status of the region
//---------------------------------------------------------------------------------------
class ActivityCondition_RegionStatus extends ActivityCondition_LWOTC;

var bool bAllowInLiberated;
var bool bAllowInAlien;
var bool bAllowInContacted;
var bool bAllowInUncontacted;
var bool bAllowInContactedOrAdjacentToContacted;

defaultProperties
{
	bAllowInLiberated=false
	bAllowInAlien=true
	bAllowInContacted=false
	bAllowInUncontacted=false
	bAllowInContactedOrAdjacentToContacted=false
}

function bool ContactedOrAdjacentToContacted (XComGameState_WorldRegion Region, WorldRegion_XComGameState_AlienStrategyAI RegionalAI)
{
	local StateObjectReference			LinkedRegionRef;
	local XComGameState_WorldRegion		NeighborRegionState; 
	local WorldRegion_XComGameState_AlienStrategyAI NeighborRegionStateAI;

	if (Region.HaveMadeContact() && !RegionalAI.bLiberated)
		return true;

	foreach Region.LinkedRegions (LinkedRegionRef)
	{
		NeighborRegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(LinkedRegionRef.ObjectID));
		NeighborRegionStateAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(NeighborRegionState);
		if (NeighborRegionState.HaveMadeContact() && !NeighborRegionStateAI.bLiberated)
		{
			return true;
		}
	}
	return false;
}


simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local bool bMeetsCondition;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	bMeetsCondition = true;

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
	if(RegionalAI.bLiberated && !bAllowInLiberated)
		bMeetsCondition = false;
		
	if(!RegionalAI.bLiberated && !bAllowInAlien)
		bMeetsCondition = false;

	if(Region.HaveMadeContact() && !bAllowInContacted)
		bMeetsCondition = false;
	
	if(!Region.HaveMadeContact() && !bAllowInUncontacted)
		bMeetsCondition = false;

	If (!ContactedOrAdjacentToContacted(Region, RegionalAI) && bAllowInContactedOrAdjacentToContacted)
		bMeetsCondition = false;

	return bMeetsCondition;
}