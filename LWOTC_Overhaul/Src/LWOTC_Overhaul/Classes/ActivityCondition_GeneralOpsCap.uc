class ActivityCondition_GeneralOpsCap extends ActivityCondition_LWOTC config(LW_Activities);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array <int> MAX_GEN_OPS_PER_REGION_PER_MONTH;

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;

	ResistanceHQ = XComGameState_HeadquartersResistance(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region, NewGameState);
	`LWTRACE ("Monthly GeneralOps Count" @ RegionalAI.GeneralOpsCount @ "compared to monthly cap" @ MAX_GEN_OPS_PER_REGION_PER_MONTH[`CAMPAIGNDIFFICULTYSETTING] * (ResistanceHQ.NumMonths +1));
	if (RegionalAI.GeneralOpsCount > MAX_GEN_OPS_PER_REGION_PER_MONTH[`CAMPAIGNDIFFICULTYSETTING] * (ResistanceHQ.NumMonths +1))
	{
		`LWTRACE ("Activity disallowed, General Ops Cap exceeded for" @ Region.GetDisplayName());
		return false;
	}
	return true;
}
