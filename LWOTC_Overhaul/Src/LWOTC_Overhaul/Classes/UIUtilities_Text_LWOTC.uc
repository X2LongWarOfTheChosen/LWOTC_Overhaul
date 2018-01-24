//---------------------------------------------------------------------------------------
//  FILE:    UIUtilities_Text_LW.uc
//  AUTHOR:  tracktwo / Pavonis Interactive
//  PURPOSE: Utilities & generic localized text for UI
//--------------------------------------------------------------------------------------- 

class UIUtilities_Text_LWOTC extends Object;

var localized string m_strHelp;

// GetDifficultyString(XComGameState_MissionSite MissionState)
static function String GetDifficultyString(XComGameState_MissionSite MissionState)
{
	local string Text;
	local int Difficulty, LabelsLength, EnemyUnits;
	local array<X2CharacterTemplate> Dummy;

	MissionState.GetShadowChamberMissionInfo (EnemyUnits, Dummy);
	Difficulty = Max (1, (EnemyUnits-4) / 3);
	LabelsLength = class'X2StrategyGameRulesetDataStructures'.default.MissionDifficultyLabels.Length;
	if(Difficulty >= LabelsLength)
		Text = class'X2StrategyGameRulesetDataStructures'.default.MissionDifficultyLabels[LabelsLength - 1];
	else
		Text = class'X2StrategyGameRulesetDataStructures'.default.MissionDifficultyLabels[Difficulty];

	if (EnemyUnits <= 0)
		Text = class'X2StrategyGameRulesetDataStructures'.default.MissionDifficultyLabels[0];

	return Caps(Text);
}

// StripHTML (String InputString)
// Strips up to 50 html tags and what's between them from a string
// This doesn't actually work yet (discovered the bug it was trying to fix was caused by a mod), but leaving it here in case we need to come back and fix it later
static function string StripHTML (String InputString)
{
	local string WorkingString, StripString;
	local int StartPoint, EndPoint, Passes;

	WorkingString = InputString;
	Passes = 0;
	while (InStr (WorkingString, "<") != -1)
	{
		StartPoint = InStr (WorkingString, "<");
		EndPoint = InStr (WorkingString, ">");
		if (StartPoint > -1 && EndPoint > -1)
		{
			StripString = Mid (WorkingString, StartPoint, EndPoint);
			WorkingString = Repl (WorkingString, StripString, "", false);
		}
		Passes += 1;
		if (Passes > 50)
			break;
	}

	return WorkingString;
}