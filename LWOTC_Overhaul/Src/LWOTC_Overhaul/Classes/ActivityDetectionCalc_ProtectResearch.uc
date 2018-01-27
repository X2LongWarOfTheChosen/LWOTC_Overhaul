//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityDetectionCalc_ProtectResearch.uc
//  AUTHOR:  JL / Pavonis Interactive
//	PURPOSE: Adds additional detection chance if facility is in the region, even more if it's also liberated
//---------------------------------------------------------------------------------------
class ActivityDetectionCalc_ProtectResearch extends ActivityDetectionCalc_LWOTC;

function float GetDetectionChance(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate) //, XComGameState_LWOutpost OutpostState)
{
	local float DetectionChance;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI	RegionalAI;

	DetectionChance = super.GetDetectionChance(ActivityState, ActivityTemplate); //, OutpostState);

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(GetRegion(ActivityState));

	// If there's a local Research facility, grant a bonus
	if(RegionalAI.bHasResearchFacility)
	{
		DetectionChance *= 1.5;
	}

	// for each hidden facility in a liberated region, have more bonuses
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);

		if (RegionalAI.bLiberated && RegionalAI.bHasResearchFacility)
		{
			DetectionChance *= 1.5;
		}
	}

	return DetectionChance;
}
