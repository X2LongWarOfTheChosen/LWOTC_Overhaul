//---------------------------------------------------------------------------------------
//  FILE:    ActivityCondition_Month
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: ?
//---------------------------------------------------------------------------------------
class ActivityCondition_Month extends ActivityCondition_LWOTC config(LWOTC_AlienActivities);

var config array<int> DARK_EVENT_DIFFICULTY_TABLE;
var config array<int> LIBERATE_DIFFICULTY_TABLE;

var int FirstMonthPossible; //Note game starts at month 0
var bool UseDarkEventDifficultyTable;
var bool UseLiberateDifficultyTable;

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local XComGameState_HeadquartersResistance ResistanceHQ;

    ResistanceHQ = XComGameState_HeadquartersResistance(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	
	if (UseLiberateDifficultyTable)
	{
		if 	(ResistanceHQ.NumMonths >= default.LIBERATE_DIFFICULTY_TABLE[`CAMPAIGNDIFFICULTYSETTING])
			return true;
		return false;
	}

	if (UseDarkEventDifficultyTable)
	{
		if 	(ResistanceHQ.NumMonths >= default.DARK_EVENT_DIFFICULTY_TABLE[`CAMPAIGNDIFFICULTYSETTING])
			return true;
		return false;
	}

	if (ResistanceHQ.NumMonths >= FirstMonthPossible)
		return true;

	return false;
}