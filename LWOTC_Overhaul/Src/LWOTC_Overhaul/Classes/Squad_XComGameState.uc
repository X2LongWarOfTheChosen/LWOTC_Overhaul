//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPersistentSquad.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: This models a single persistent squad, which can be on Avenger or deploying to mission site
//---------------------------------------------------------------------------------------
class Squad_XComGameState extends XComGameState_GeoscapeEntity config(LWOTC_Infiltration);

var localized array<string> DefaultSquadNames; // localizable array of default squadnames to choose from
var localized array<string> TempSquadNames; // localizable array of temporary squadnames to choose from

var localized string BackupSquadName;
var localized string BackupTempSquadName;

var config array<int>		EvacDelayForInfiltratedMissions;
var config array<int>		DefaultBoostInfiltrationCost;
var config string			DefaultSquadImagePath;

var Squad_XComGameState_Soldiers		Soldiers;					// Object containing the soldier lists
var Squad_XComGameState_Infiltration	InfiltrationState;			// Object managing infiltration
var bool								bOnMission;					// indicates the squad is currently deploying to a mission site
var bool								bTemporary;					// indicates that this squad is only for the current infiltration, and shouldn't be retained
var bool								bCannotCancelAbort;			// indicates the squad has been marked to abort their mission cannot continue it

var string								sSquadName;					// auto-generated or user-customize squad name
var string								SquadImagePath;				// option to set a Squad Image custom for this squad
var string								sSquadBiography;			// a player-editable squad history
var int									iNumMissions;				// automatically tracked squad mission counter

// OnCreation( optional X2DataTemplate InitTemplate )
event OnCreation( optional X2DataTemplate InitTemplate )
{
	super.OnCreation(InitTemplate);
	Soldiers = new class'Squad_XComGameState_Soldiers';
	InfiltrationState =  new class'Squad_XComGameState_Infiltration';
}

// InitSquad(optional string sName = "", optional bool Temp = false)
function Squad_XComGameState_Persistent InitSquad(optional string sName = "", optional bool Temp = false)
{
	local TDateTime StartDate;
	local string DateString;
	local XGParamTag SquadBioTag;

	bTemporary = Temp;

	if(sName != "")
		sSquadName = sName;
	else
		if (bTemporary)
			sSquadName = GetUniqueRandomName(TempSquadNames, BackupTempSquadName);
		else
			sSquadName = GetUniqueRandomName(DefaultSquadNames, BackupSquadName);

	if (`GAME.GetGeoscape() != none)
	{
		DateString = class'X2StrategyGameRulesetDataStructures'.static.GetDateString(`GAME.GetGeoscape().m_kDateTime);
	}
	else
	{
	class'X2StrategyGameRulesetDataStructures'.static.SetTime(StartDate, 0, 0, 0, class'X2StrategyGameRulesetDataStructures'.default.START_MONTH,
															  class'X2StrategyGameRulesetDataStructures'.default.START_DAY, class'X2StrategyGameRulesetDataStructures'.default.START_YEAR);
		DateString = class'X2StrategyGameRulesetDataStructures'.static.GetDateString(StartDate);
	}

	SquadBioTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	SquadBioTag.StrValue0 = DateString;
	sSquadBiography = `XEXPAND.ExpandString(class'UIPersonnel_SquadBarracks'.default.strDefaultSquadBiography);	

	return self;
}

// SetSquadCrew(optional XComGameState UpdateState, optional bool bOnMissionSoldiers = true, optional bool bForDisplayOnly)
simulated function SetSquadCrew(optional XComGameState UpdateState, optional bool bOnMissionSoldiers = true, optional bool bForDisplayOnly)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local bool bSubmitOwnGameState, bHasMissionData, bAllowWoundedSoldiers;
	local array<XComGameState_Unit> SquadSoldiersToAssign;
	local XComGameState_Unit UnitState;
	local GeneratedMissionData MissionData;
	local int MaxSoldiers, idx;
	local array<name> RequiredSpecialSoldiers;

	bSubmitOwnGameState = UpdateState == none;

	if(bSubmitOwnGameState)
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Persistent Squad Members");

	//try and retrieve XComHQ from GameState if possible
	XComHQ = `XCOMHQ;
	XComHQ = XComGameState_HeadquartersXCom(UpdateState.GetGameStateForObjectID(XComHQ.ObjectID));
	if(XComHQ == none)
		XComHQ = `XCOMHQ;

	if (XComHQ.MissionRef.ObjectID != 0)
	{
		MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);
		bHasMissionData = true;
	}

	if (bHasMissionData)
	{
		MaxSoldiers = class'UISquadSelect_LW'.static.GetMaxSoldiersAllowedOnMission(MissionData.Mission);
		bAllowWoundedSoldiers = MissionData.Mission.AllowDeployWoundedUnits;
	}
	else
	{
		MaxSoldiers = class'X2StrategyGameRulesetDataStructures'.default.m_iMaxSoldiersOnMission;
	}

	XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	UpdateState.AddStateObject(XComHQ);

	if (bOnMissionSoldiers)
	{
		SquadSoldiersToAssign = Soldiers.GetSoldiersOnMission();
	}
	else
	{
		if (bForDisplayOnly)
		{
			SquadSoldiersToAssign = Soldiers.GetSoldiers();
		}
		else
		{
			SquadSoldiersToAssign = Soldiers.GetDeployableSoldiers(bAllowWoundedSoldiers);
		}
	}

	//clear the existing squad as much as possible (leaving in required units if in SquadSelect)
	// we can clear special units when assigning for infiltration or viewing
	if (bOnMissionSoldiers)
	{
		XComHQ.Squad.Length = 0;
	}
	else
	{
		RequiredSpecialSoldiers = MissionData.Mission.SpecialSoldiers;

		for (idx = XComHQ.Squad.Length - 1; idx >= 0; idx--)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.Squad[idx].ObjectID));
			if (UnitState != none && RequiredSpecialSoldiers.Find(UnitState.GetMyTemplateName()) != -1)
			{
			}
			else
			{
				XComHQ.Squad.Remove(idx, 1);
			}
		}
	}

	//fill out the squad as much as possible using the squad units
	foreach SquadSoldiersToAssign(UnitState)
	{
		if (XComHQ.Squad.Length >= MaxSoldiers) { break; }
		XComHQ.Squad.AddItem(UnitRef);
	}

	if(bSubmitOwnGameState)
		`GAMERULES.SubmitGameState(UpdateState);
}

// StartMissionInfiltration(StateObjectReference MissionRef)
function StartMissionInfiltration(StateObjectReference MissionRef)
{
	local XComGameState UpdateState;
	local Squad_XComGameState UpdateSquad;

	UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Start Infiltration Mission");
	UpdateSquad = Squad_XComGameState(UpdateState.CreateStateObject(class'Squad_XComGameState', ObjectID));
	UpdateSquad.InitInfiltration(UpdateState, MissionRef, 0.0);
	UpdateState.AddStateObject(UpdateSquad);
	`XCOMGAME.GameRuleset.SubmitGameState(UpdateState);
}

// InitInfiltration(XComGameState NewGameState, StateObjectReference MissionRef, float Infiltration)
function InitInfiltration(XComGameState NewGameState, StateObjectReference MissionRef, float Infiltration)
{
	bOnMission = true;
	InfiltrationState.InitInfiltration(NewGameState, MissionRef, Infiltration);
}

// ClearMission()
function ClearMission()
{
	bOnMission = false;
	Soldiers.SquadSoldiersOnMission.Length = 0;
	InfiltrationState.CurrentInfiltration = 0;
	InfiltrationState.CurrentMission.ObjectID = 0;
	InfiltrationState.bHasBoostedInfiltration = false;
	bCannotCancelAbort = false;
}

// SpendBoostResource(XComGameState NewGameState)
function SpendBoostResource(XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local StrategyCost BoostCost;
	local array<StrategyCostScalar> CostScalars;
	
	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ == none)
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
	}
	CostScalars.Length = 0;
	BoostCost = GetBoostInfiltrationCost();
	XComHQ.PayStrategyCost(NewGameState, BoostCost, CostScalars);
	
	//`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	//`XCOMHQ.AddResource(NewGameState, 'Intel', -DefaultBoostInfiltrationCost[`DIFFICULTYSETTING]);
}

// GetBoostInfiltrationCost()
function StrategyCost GetBoostInfiltrationCost()
{
	local StrategyCost Cost;
	local ArtifactCost ResourceCost;

	ResourceCost.ItemTemplateName = 'Intel';
	ResourceCost.Quantity = DefaultBoostInfiltrationCost[`DIFFICULTYSETTING];
	Cost.ResourceCosts.AddItem(ResourceCost);

	return Cost;
}

//---------------------------
// MAIN FUNCTIONALITY -------
//---------------------------

// UpdateGameBoard()
function UpdateGameBoard()
{
    UpdateInfiltrationState(true);
}

// UpdateInfiltrationState(bool AllowPause)
function UpdateInfiltrationState(bool AllowPause)
{
	InfiltrationState.UpdateInfiltrationState(AllowPause, Soldiers.SquadSoldiersOnMission);
}

// GetSecondsRemainingToFullInfiltration()
function float GetSecondsRemainingToFullInfiltration()
{
	return InfiltrationState.GetSecondsRemainingToFullInfiltration(Soldiers.SquadSoldiersOnMission);
}

// IsDeployedOnMission()
function bool IsDeployedOnMission()
{
	if(bOnMission && InfiltrationState.CurrentMission.ObjectID == 0)
		`REDSCREEN("Squad_XComGameState: Squad marked on mission, but no current mission");
	return (bOnMission && InfiltrationState.CurrentMission.ObjectID != 0);
}

// EvacDelayModifier_Missions()
function int EvacDelayModifier_Missions()
{
	local int NumMissions;
	local SquadManager_XComGameState SquadMgr;

	SquadMgr = class'SquadManager_XComGameState'.static.GetSquadManager();
	NumMissions = SquadMgr.NumSquadsOnAnyMission();
	if (NumMissions >= default.EvacDelayForInfiltratedMissions.Length)
		NumMissions = default.EvacDelayForInfiltratedMissions.Length - 1;

	return default.EvacDelayForInfiltratedMissions[NumMissions];
}

// GetCurrentMission()
function XComGameState_MissionSite GetCurrentMission()
{
	if(InfiltrationState.CurrentMission.ObjectID == 0)
		return none;
	return XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(InfiltrationState.CurrentMission.ObjectID));
}

//---------------------------
// MISC SETTINGS ------------
//---------------------------

// GetUniqueRandomName(const array<string> NameList, string DefaultName)
function string GetUniqueRandomName(const array<string> NameList, string DefaultName)
{
	local SquadManager_XComGameState SquadMgr;
	local array<string> PossibleNames;
	local StateObjectReference SquadRef;
	local Squad_XComGameState SquadState;
	local XGParamTag SquadNameTag;

	SquadMgr = class'SquadManager_XComGameState'.static.GetSquadManager();
	PossibleNames = NameList;
	foreach SquadMgr.Squads(SquadRef)
	{
		SquadState = Squad_XComGameState(`XCOMHISTORY.GetGameStateForObjectID(SquadRef.ObjectID));
		if (SquadState == none)
			continue;

		PossibleNames.RemoveItem(SquadState.sSquadName);
	}

	if (PossibleNames.Length == 0)
	{
		SquadNameTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		SquadNameTag.StrValue0 = GetRightMost(string(self));
		return `XEXPAND.ExpandString(DefaultName);		
	}

	return PossibleNames[`SYNC_RAND(PossibleNames.Length)];
}

// GetSquadName()
function string GetSquadName()
{
	return sSquadName;
}

// SetSquadName(string NewName)
function SetSquadName(string NewName)
{
	sSquadName = NewName;
}

// GetSquadImagePath()
function string GetSquadImagePath()
{
	if(SquadImagePath != "")
		return SquadImagePath;

	return default.DefaultSquadImagePath;
}

// GetUIClass()
// We need a UI class for all strategy elements (but they'll never be visible)
function class<UIStrategyMapItem> GetUIClass()
{
    return class'UIStrategyMapItem';
}

// ShouldBeVisible()
// Never show these on the map.
function bool ShouldBeVisible()
{
    return false;
}