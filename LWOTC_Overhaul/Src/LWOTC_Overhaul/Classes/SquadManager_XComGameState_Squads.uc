class SquadManager_XComGameState_Squads extends Object;

var int ParentObjectId;
var array<StateObjectReference> Squads;

// GetSquad(StateObjectReference SquadRef)
function Squad_XComGameState GetSquad(StateObjectReference SquadRef)
{
	return Squad_XComGameState(`XCOMHISTORY.GetGameStateForObjectID(SquadRef.ObjectID));
}

// GetSquadByName(string SquadName)
function Squad_XComGameState GetSquadByName(string SquadName)
{
	local StateObjectReference SquadRef;
	local Squad_XComGameState Squad;

	foreach Squads(SquadRef)
	{
		Squad = GetSquad(SquadRef);
		if(Squad.sSquadName == SquadName)
			return Squad;
	}
	return none;
}

// GetSquadOnMission(StateObjectReference MissionRef)
//gets the squad assigned to a given mission -- may be none if mission is not being pursued
function Squad_XComGameState GetSquadOnMission(StateObjectReference MissionRef)
{
	local StateObjectReference SquadRef;
	local Squad_XComGameState Squad;

	if(MissionRef.ObjectID == 0) return none;

	foreach Squads(SquadRef)
	{
		Squad = GetSquad(SquadRef);
		if(Squad != none && Squad.CurrentMission.ObjectID == MissionRef.ObjectID)
			return Squad;
	}
	return none;
}

// GetBestSquad()
// Gets a random squad from those not on a mission
function StateObjectReference GetBestSquad()
{
	local array<Squad_XComGameState> PossibleSquads;
	local StateObjectReference SquadRef;
	local Squad_XComGameState Squad;
	local StateObjectReference NullRef;

	foreach Squads(SquadRef)
	{
		Squad = GetSquad(SquadRef);
		if (!Squad.bOnMission && Squad.CurrentMission.ObjectID == 0)
		{
			PossibleSquads.AddItem(Squad);
		} 
	}

	if (PossibleSquads.Length > 0)
		return PossibleSquads[`SYNC_RAND(PossibleSquads.Length)].GetReference();
	else
		return NullRef;
}

// NumSquadsOnAnyMission()
function int NumSquadsOnAnyMission()
{
	local StateObjectReference SquadRef;
	local Squad_XComGameState Squad;
	local int NumMissions;

	foreach Squads(SquadRef)
	{
		Squad = GetSquad(SquadRef);
		if (Squad.bOnMission && Squad.CurrentMission.ObjectID > 0)
			NumMissions++;
	}
	return NumMissions;
}

// AddSquad(optional array<StateObjectReference> Soldiers, optional StateObjectReference MissionRef, optional string SquadName="", optional bool Temp = true, optional float Infiltration=0)
function Squad_XComGameState AddSquad(optional array<StateObjectReference> Soldiers, optional StateObjectReference MissionRef, optional string SquadName="", optional bool Temp = true, optional float Infiltration=0)
{
	local XComGameState NewGameState;
	local Squad_XComGameState NewSquad;
	local SquadManager_XComGameState UpdatedSquadMgr;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding new preformed squad");
	NewSquad = Squad_XComGameState(NewGameState.CreateStateObject(class'Squad_XComGameState'));
	UpdatedSquadMgr = SquadManager_XComGameState(NewGameState.CreateStateObject(Class, ParentObjectId));

	NewSquad.InitSquad(SquadName, Temp);
	UpdatedSquadMgr.SquadState.Squads.AddItem(NewSquad.GetReference());

	if(MissionRef.ObjectID > 0)
		NewSquad.Soldiers.SquadSoldiersOnMission = Soldiers;
	else
		NewSquad.Soldiers.SquadSoldiers = Soldiers;

	NewSquad.InitInfiltration(NewGameState, MissionRef, Infiltration);
	NewSquad.Soldiers.SetOnMissionSquadSoldierStatus(NewGameState);

	NewGameState.AddStateObject(NewSquad);
	NewGameState.AddStateObject(UpdatedSquadMgr);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	return NewSquad;
}

// CreateEmptySquad(optional int idx = -1, optional string SquadName = "", optional XComGameState NewGameState, optional bool bTemporary)
// creates an empty squad at the given position with the given name
function Squad_XComGameState CreateEmptySquad(optional int idx = -1, optional string SquadName = "", optional XComGameState NewGameState, optional bool bTemporary)
{
	local Squad_XComGameState NewSquad;
	local SquadManager_XComGameState UpdatedSquadMgr;
	local bool bNeedsUpdate;

	bNeedsUpdate = NewGameState == none;
	if (bNeedsUpdate)
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding new empty squad");

	NewSquad = Squad_XComGameState(NewGameState.CreateStateObject(class'Squad_XComGameState'));
	UpdatedSquadMgr = SquadManager_XComGameState(NewGameState.CreateStateObject(Class, ParentObjectId));

	NewSquad.InitSquad(SquadName, bTemporary);
	if(idx <= 0 || idx >= Squads.Length)
		UpdatedSquadMgr.SquadState.Squads.AddItem(NewSquad.GetReference());
	else
		UpdatedSquadMgr.SquadState.Squads.InsertItem(idx, NewSquad.GetReference());

	NewGameState.AddStateObject(NewSquad);
	NewGameState.AddStateObject(UpdatedSquadMgr);
	if (bNeedsUpdate)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	return NewSquad;
}

// RemoveSquad(StateObjectReference SquadRef)
function RemoveSquad(StateObjectReference SquadRef)
{
	local SquadManager_XComGameState UpdatedSquadMgr;
	local Squad_XComGameState SquadState;
	
	UpdatedSquadMgr = SquadManager_XComGameState(NewGameState.CreateStateObject(Class, ParentObjectId));
	NewGameState.AddStateObject(UpdatedSquadMgr);
	UpdatedSquadMgr.SquadState.Squads.RemoveItem(SquadRef);

	SquadState = GetSquad(SquadRef);
	NewGameState.RemoveStateObject(SquadState.ObjectID);
}

// GetAssignedSoldiers()
// Return list of references to all soldiers assigned to any squad
function array<StateObjectReference> GetAssignedSoldiers()
{
	local StateObjectReference SquadRef, SoldierRef;
	local Squad_XComGameState Squad;
	local array<StateObjectReference> UnitRefs;

	foreach Squads(SquadRef)
	{
		Squad = GetSquad(SquadRef);

		foreach Squad.Soldiers.SquadSoldiers(SoldierRef)
		{
			UnitRefs.AddItem(SoldierRef);
		}
		foreach Squad.Soldiers.SquadSoldiersOnMission(SoldierRef)
		{
			if (UnitRefs.Find('ObjectID', SoldierRef.ObjectID) == -1)
				UnitRefs.AddItem(SoldierRef);
		}
	}
	return UnitRefs;
}

// GetUnassignedSoldiers()
// Return list of references to all soldier NOT assigned to any squad
function array<StateObjectReference> GetUnassignedSoldiers()
{
	local array<StateObjectReference> AssignedRefs, UnassignedRefs;
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;

	Soldiers = `XCOMHQ.GetSoldiers();
	AssignedRefs = GetAssignedSoldiers();
	foreach Soldiers(Soldier)
	{
		if(AssignedRefs.Find('ObjectID', Soldier.ObjectID) == -1)
		{
			UnassignedRefs.AddItem(Soldier.GetReference());
		}
	}
	return UnassignedRefs;
}

// UnitIsInAnySquad(StateObjectReference UnitRef, optional out Squad_XComGameState SquadState)
function bool UnitIsInAnySquad(StateObjectReference UnitRef, optional out Squad_XComGameState SquadState)
{
	local StateObjectReference SquadRef;

	foreach Squads(SquadRef)
	{
		SquadState = GetSquad(SquadRef);
		if(SquadState.Soldiers.UnitIsInSquad(UnitRef))
			return true;
	}
	SquadState = none;
	return false;
}

// UnitIsOnMission(StateObjectReference UnitRef)
function bool UnitIsOnMission(StateObjectReference UnitRef)
{
	local StateObjectReference SquadRef;

	foreach Squads(SquadRef)
	{
		if(GetSquad(SquadRef).Soldiers.IsSoldierOnMission(UnitRef))
			return true;
	}
	return false;
}