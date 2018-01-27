//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCreation_MostDangerous.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Extended Creation class that optimizes to putting activity in the most dangerous region possible
//---------------------------------------------------------------------------------------
class ActivityCreation_MostDangerous extends ActivityCreation_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

simulated function StateObjectReference FindBestPrimaryRegion(XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local StateObjectReference RegionRef, NullRef;
	local array<StateObjectReference> BestRegions;
	local XComGameState_WorldRegion		RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
	local int CurrentSafety, LowestSafety;

	if (PrimaryRegions.Length == 0)
		return NullRef;

	History = `XCOMHISTORY;
	LowestSafety = 99;
	foreach PrimaryRegions(RegionRef)
	{
		RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(RegionRef.ObjectID));
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);
		if (RegionalAI == none)
		{
			`LWTRACE("GetScheduledOffworldReinforcementsPrimaryRegion: Can't Find Regional AI for" @ RegionState.GetMyTemplate().DisplayName);
		}
		else
		{
			CurrentSafety = RegionalAI.LocalAlertLevel - RegionalAI.LocalVigilanceLevel;
			if (LowestSafety > CurrentSafety)
			{
				BestRegions.Length = 0;
				BestRegions.AddItem(RegionRef);
				LowestSafety = CurrentSafety;
			}
			if (LowestSafety == CurrentSafety)
			{
				BestRegions.AddItem(RegionRef);
			}
		}
	}
	
	if(BestRegions.Length == 0)
		return NullRef;
	else
		return BestRegions[`SYNC_RAND(BestRegions.Length)];
}
