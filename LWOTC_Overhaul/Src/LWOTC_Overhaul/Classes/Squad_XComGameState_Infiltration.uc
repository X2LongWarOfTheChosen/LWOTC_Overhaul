class Squad_XComGameState_Infiltration extends Object config(LWOTC_Infiltration);

struct InfiltrationModifier
{
	var float Infiltration;
	var float Modifier;
};
var config array<InfiltrationModifier> AlertModifierAtInfiltration;
var config array<InfiltrationModifier> EvacDelayAtInfiltration;

var config float			AlertnessUpdateInterval;			// how often to reroll enemy "Alertness"/difficulty
var config float			RequiredInfiltrationToLaunch;
var config array<name>		MissionsRequiring100Infiltration;

var config array<float>		DefaultBoostInfiltrationFactor;		// allows for boosting infiltration rate in various ways
var config array<float>		InfiltrationHaltPoints;				// infiltration values at which the game will pause (or as soon as possible)
var array<bool>				InfiltrationPointPassed;			// recordings of when a particular point has been passed


var TDateTime					StartInfiltrationDateTime;		// the time when the current infiltration began
var StateObjectReference		CurrentMission;					// the current mission being deployed to -- none if no mission
var float						CurrentInfiltration;			// the current infiltration progress against the mission
var float						LastInfiltrationUpdate;			// the infiltration value the last time the AlertnessModifier was updated
var bool						bHasBoostedInfiltration;		// indicates if the player has boosted infiltration for this squad

var int							LastAlertIndex;					// the last AlertIndex delivered
var int							CurrentEnemyAlertnessModifier;  // the modifier to alertness based on the infiltration progress

// InitInfiltration(XComGameState NewGameState, StateObjectReference MissionRef, float Infiltration)
function InitInfiltration(XComGameState NewGameState, StateObjectReference MissionRef, float Infiltration)
{
	CurrentMission = MissionRef;
	CurrentInfiltration = Infiltration;
	CurrentEnemyAlertnessModifier = 99999;
	GetAlertnessModifierForCurrentInfiltration(NewGameState, true);
	StartInfiltrationDateTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
	InfiltrationPointPassed.Length = 0;
}

// UpdateInfiltrationState(bool AllowPause, array<StateObjectReference> SquadSoldiersOnMission)
function UpdateInfiltrationState(bool AllowPause, array<StateObjectReference> SquadSoldiersOnMission)
{
	local XComGameState UpdateState;
	local Squad_XComGameState UpdateSquad;
	local int SecondsOfInfiltration;
	local float HoursOfInfiltration;
	local float HoursToFullInfiltration;
	local float PossibleInfiltrationUpdate;
	local float InfiltrationBonusOnLiberation;
	local UIStrategyMap StrategyMap;
	local bool ShouldPause;
	local int InfiltrationHaltIndex;
	local XGGeoscape Geoscape;
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
    local XComGameState_MissionSite MissionSite;
	
	if(CurrentMission.ObjectID == 0) return;  // only needs update when on mission
	SecondsOfInfiltration = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInSeconds(GetCurrentTime(), StartInfiltrationDateTime);
	HoursOfInfiltration = float(SecondsOfInfiltration) / 3600.0;
	HoursToFullInfiltration = class'Squad_Static_Infiltration_Helper'.static.GetHoursToFullInfiltration(SquadSoldiersOnMission, CurrentMission);

	if (bHasBoostedInfiltration)
		HoursToFullInfiltration /= DefaultBoostInfiltrationFactor[`CAMPAIGNDIFFICULTYSETTING];
	
	// Add the liberation infiltration bonus to the infiltration time if the region has been liberated.
	// This handles boosting of missions that are still around after liberating the region where the boost
	// was not being applied fully, or at all.
	MissionSite = GetCurrentMission();
	if(MissionSite != none)
	{
		RegionState = MissionSite.GetWorldRegion();
		RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState);
		if(RegionalAI.bLiberated)
		{
			InfiltrationBonusOnLiberation = class'X2StrategyElement_DefaultAlienActivities'.default.INFILTRATION_BONUS_ON_LIBERATION[`CAMPAIGNDIFFICULTYSETTING] / 100.0;
			HoursOfInfiltration += class'Squad_Static_Infiltration_Helper'.static.GetHoursToFullInfiltration(SquadSoldiersOnMission, CurrentMission) * InfiltrationBonusOnLiberation;
		}
	}
	
	PossibleInfiltrationUpdate = FClamp(HoursOfInfiltration / HoursToFullInfiltration, 0.0, 2.0000001);

	UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Infiltration Progress");
	if(PossibleInfiltrationUpdate - CurrentInfiltration >= 0.01 || PossibleInfiltrationUpdate >= 2.0)
	{
		UpdateSquad = Squad_XComGameState(UpdateState.CreateStateObject(class'Squad_XComGameState', ObjectID));
		UpdateSquad.CurrentInfiltration = PossibleInfiltrationUpdate;
		UpdateState.AddStateObject(UpdateSquad);
	}
	StrategyMap = `HQPRES.StrategyMap2D;
	if (StrategyMap != none && StrategyMap.m_eUIState != eSMS_Flight)
	{
		if (UpdateSquad != none)  
		{
			InfiltrationHaltIndex = HasPassedAvailableInfiltrationHaltPoint(UpdateSquad.CurrentInfiltration);
			if (InfiltrationHaltIndex >= 0)
			{
				ShouldPause = true;
				UpdateSquad.InfiltrationPointPassed[InfiltrationHaltIndex] = true;
			}
		}
	}
	if (UpdateState.GetNumGameStateObjects() > 0)
		`XCOMGAME.GameRuleset.SubmitGameState(UpdateState);
	else
		`XCOMHISTORY.CleanupPendingGameState(UpdateState);

	if (AllowPause && ShouldPause)
	{
		Geoscape = `GAME.GetGeoscape();
		Geoscape.Pause();
		Geoscape.Resume();
	}
}

// HasPassedAvailableInfiltrationHaltPoint(float InfiltrationToCheck)
function int HasPassedAvailableInfiltrationHaltPoint(float InfiltrationToCheck)
{
	local int idx;
	local float InfiltrationHaltPoint;

	foreach default.InfiltrationHaltPoints(InfiltrationHaltPoint, idx)
	{
		// This is causing log warnings -- A:fixed with length check
		if ((idx >= InfiltrationPointPassed.Length  || !InfiltrationPointPassed[idx]) && InfiltrationToCheck >= InfiltrationHaltPoint/100.0)
		{
			return idx;
		}
	}
	return -1;
}

// GetAlertnessModifierForCurrentInfiltration(optional XComGameState UpdateState, optional bool bForceUpdate = false, optional out int ArrayIndex)
function int GetAlertnessModifierForCurrentInfiltration(optional XComGameState UpdateState, optional bool bForceUpdate = false, optional out int ArrayIndex)
{
	local bool bUpdateSelf;
	local Squad_XComGameState UpdateSquad;
	local float fAlertnessModifier, FractionalBit;
	local int iAlertnessModifier;
	local int idx;
	local float Infiltration_Low, Infiltration_High;
	local float fAlert_Low, fAlert_High;
	local InfiltrationModifier AlertLevelModifier;

	//use the previously cached version if not enough additional infiltration has occurred
	if(!bForceUpdate && (CurrentInfiltration < LastInfiltrationUpdate + AlertnessUpdateInterval))
	{
		ArrayIndex = LastAlertIndex;
		return CurrentEnemyAlertnessModifier;
	}
	//time to update the alertness modifier
	if(UpdateState == none)
	{
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Alertness Modifier from Infiltration");
		UpdateSquad = Squad_XComGameState(UpdateState.CreateStateObject(class'Squad_XComGameState', ObjectID));
		bUpdateSelf = true;
	}

	foreach default.AlertModifierAtInfiltration(AlertLevelModifier, idx)
	{
		if (AlertLevelModifier.Infiltration > CurrentInfiltration)
		{
			break;
		}
	}
	if (CurrentInfiltration <= (RequiredInfiltrationToLaunch/100.0))
	{
		ArrayIndex = 0;
		iAlertnessModifier = Round(default.AlertModifierAtInfiltration[ArrayIndex].Modifier);
	}
	else if (idx >= default.AlertModifierAtInfiltration.Length - 1)
	{
		ArrayIndex = default.AlertModifierAtInfiltration.Length - 1;
		iAlertnessModifier = Round(default.AlertModifierAtInfiltration[ArrayIndex].Modifier);
	}
	else
	{
		Infiltration_Low = default.AlertModifierAtInfiltration[idx-1].Infiltration;
		Infiltration_High = default.AlertModifierAtInfiltration[idx].Infiltration;
		fAlert_Low = default.AlertModifierAtInfiltration[idx-1].Modifier;
		fAlert_High = default.AlertModifierAtInfiltration[idx].Modifier;

		fAlertnessModifier = fAlert_Low + (fAlert_High - fAlert_Low) * (CurrentInfiltration - Infiltration_Low ) / (Infiltration_High - Infiltration_Low);  // goes down when infiltration is high
		FractionalBit = Abs(fAlertnessModifier - fAlert_Low);
		if(`SYNC_FRAND() < FractionalBit)
		{
			ArrayIndex = idx - 1;
			iAlertnessModifier = Round(fAlert_High);
		}
		else
		{
			ArrayIndex = idx;
			iAlertnessModifier = Round(fAlert_Low);
		}
	}
	iAlertnessModifier = Min(iAlertnessModifier, CurrentEnemyAlertnessModifier);

	ArrayIndex = default.AlertModifierAtInfiltration.Find('Modifier', iAlertnessModifier);
	if(bUpdateSelf)
	{
		UpdateSquad.LastAlertIndex = ArrayIndex;
		UpdateSquad.CurrentEnemyAlertnessModifier = iAlertnessModifier;
		UpdateSquad.LastInfiltrationUpdate = CurrentInfiltration;
		UpdateState.AddStateObject(UpdateSquad);
		`XCOMGAME.GameRuleset.SubmitGameState(UpdateState);
	}
	else
	{
		LastAlertIndex = ArrayIndex;
		CurrentEnemyAlertnessModifier = iAlertnessModifier;
		LastInfiltrationUpdate = CurrentInfiltration;
	}
	return iAlertnessModifier;
}

// GetSecondsRemainingToFullInfiltration(array<StateObjectReference> SquadSoldiersOnMission)
function float GetSecondsRemainingToFullInfiltration(array<StateObjectReference> SquadSoldiersOnMission)
{
	local float HoursToFullInfiltration;
	local float TotalSecondsToInfiltrate;
	local float SecondsOfInfiltration;
	local float SecondsToInfiltrate;

	HoursToFullInfiltration = GetHoursToFullInfiltration_Static(SquadSoldiersOnMission, CurrentMission);

	if (bHasBoostedInfiltration)
		HoursToFullInfiltration /= DefaultBoostInfiltrationFactor[`CAMPAIGNDIFFICULTYSETTING];

	TotalSecondsToInfiltrate = 3600.0 * HoursToFullInfiltration;
	SecondsOfInfiltration = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInSeconds(GetCurrentTime(), StartInfiltrationDateTime);
	SecondsToInfiltrate = TotalSecondsToInfiltrate - SecondsOfInfiltration;

	return SecondsToInfiltrate;
}

// EvacDelayModifier()
function int EvacDelayModifier()
{
	local float Infiltration;
	local int EvacDelayForInfiltration;
	local InfiltrationModifier EvacDelayModifier;
	
	Infiltration = CurrentInfiltration;
	foreach default.EvacDelayAtInfiltration(EvacDelayModifier)
	{
		if (EvacDelayModifier.Infiltration <= Infiltration)
			EvacDelayForInfiltration = EvacDelayModifier.Modifier;
	}
	return EvacDelayForInfiltration;
}

// HasSufficientInfiltrationToStartMission(XComGameState_MissionSite MissionState)
function bool HasSufficientInfiltrationToStartMission(XComGameState_MissionSite MissionState)
{
	return CurrentInfiltration >= (GetRequiredPctInfiltrationToLaunch(MissionState) / 100.0);
}

// GetRequiredPctInfiltrationToLaunch(XComGameState_MissionSite MissionState)
static function float GetRequiredPctInfiltrationToLaunch(XComGameState_MissionSite MissionState)
{
	if (default.MissionsRequiring100Infiltration.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
	{
		return 100.0;
	}
	return default.RequiredInfiltrationToLaunch;
}