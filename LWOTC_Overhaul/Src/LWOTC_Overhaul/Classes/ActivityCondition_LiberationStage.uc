//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_LiberationStage.uc
//  AUTHOR:  JL / Pavonis Interactive
//	PURPOSE: Conditionals on the LiberationStage of the region
//---------------------------------------------------------------------------------------
class ActivityCondition_LiberationStage extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var bool NoStagesComplete;
var bool Stage1Complete;
var bool Stage2Complete;

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
	
	//`LWTRACE ("X2LWActivityCondition_LiberationStage" @ Region.GetMyTemplateName() @ "Checking:" @ NoStagesComplete @ Stage1Complete @ Stage2Complete @ "Status:" @ RegionalAI.LiberateStage1Complete @ RegionalAI.LiberateStage2Complete);

	if (NoStagesComplete && !RegionalAI.LiberateStage1Complete && !RegionalAI.LiberateStage2Complete)
	{
		`LWTRACE("ProtectRegionEarly Liberation Stage condition met in " $ Region.GetMyTemplateName());
		return true;
	}
	if (!NoStagesComplete && Stage1Complete && RegionalAI.LiberateStage1Complete && !Stage2Complete && !RegionalAI.LiberateStage2Complete)
	{
		`LWTRACE("ProtectRegionMid Liberation Stage condition met in " $ Region.GetMyTemplateName());
		return true;
	}
	if (!NoStagesComplete && Stage2Complete && RegionalAI.LiberateStage2Complete)
	{
		//`LWTRACE("ProtectRegion (final) Liberation Stage condition met in " $ Region.GetMyTemplateName());
		return true;
	}

	//`LWTRACE ("X2LWActivityCondition_LiberationStage returning false");

	return false;
}