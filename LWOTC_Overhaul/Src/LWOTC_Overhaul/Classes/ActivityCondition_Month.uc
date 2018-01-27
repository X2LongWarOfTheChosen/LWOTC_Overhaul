class ActivityCondition_Month extends ActivityCondition_LWOTC config(LW_Activities);

var int FirstMonthPossible; //Note game starts at month 0
var bool UseDarkEventDifficultyTable;
var bool UseLiberateDifficultyTable;
var config array<int> DarkEventDifficultyTable;
var config array<int> LiberateDifficultyTable;

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local XComGameState_HeadquartersResistance ResistanceHQ;

    ResistanceHQ = XComGameState_HeadquartersResistance(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	
	if (UseLiberateDifficultyTable)
	{
		if 	(ResistanceHQ.NumMonths >= default.LiberateDifficultyTable[`CAMPAIGNDIFFICULTYSETTING])
			return true;
		return false;
	}

	if (UseDarkEventDifficultyTable)
	{
		if 	(ResistanceHQ.NumMonths >= default.DarkEventDifficultyTable[`CAMPAIGNDIFFICULTYSETTING])
			return true;
		return false;
	}

	if (ResistanceHQ.NumMonths >= FirstMonthPossible)
		return true;

	return false;
}