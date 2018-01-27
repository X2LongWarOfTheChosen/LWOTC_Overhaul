//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityDetectionCalc_TroopManeuvers.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Adds additional detection chance for AlertLevel
//---------------------------------------------------------------------------------------
class ActivityDetectionCalc_TroopManeuvers extends ActivityDetectionCalc_LWOTC;

var float DetectionChancePerLocalAlert;

function float GetDetectionChance(AlienActivity_XComGameState ActivityState, AlienActivity_X2StrategyElementTemplate ActivityTemplate) //, XComGameState_LWOutpost OutpostState)
{
	local float DetectionChance, BonusAlertDetectionChance;
	local WorldRegion_XComGameState_AlienStrategyAI	RegionalAI;

	DetectionChance = super.GetDetectionChance(ActivityState, ActivityTemplate); //, OutpostState);

	RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(GetRegion(ActivityState));

	BonusAlertDetectionChance = float(RegionalAI.LocalAlertLevel) * DetectionChancePerLocalAlert;
	BonusAlertDetectionChance *= float(class'AlienActivity_X2StrategyElementTemplate'.default.HOURS_BETWEEN_ALIEN_ACTIVITY_DETECTION_UPDATES) / 24.0;
	DetectionChance += BonusAlertDetectionChance;

	return DetectionChance;
}
