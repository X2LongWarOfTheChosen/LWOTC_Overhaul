class Squad_XComGameState_Soldiers extends Object config(LWOTC_Infiltration);

var config array<int>				EvacDelayAtSquadSize;

var array<StateObjectReference>		SquadSoldiers;				// Which soldiers make up the squad
var array<StateObjectReference>		SquadSoldiersOnMission;		// possibly different from SquadSoldiers due to injury, training, or being a temporary reserve replacement

// GetSoldiers()
function array<XComGameState_Unit> GetSoldiers()
{
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;
	local StateObjectReference SoldierReference;

	foreach SquadSoldiers(SoldierReference)
	{
		Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierReference.ObjectID));
		if (Soldier != none)
		{
			if (IsValidSoldierForSquad(Soldier))
			{
				Soldiers.AddItem(Soldier);
			}
		}
	}

	return Soldiers;
}

// GetSoldiersOnMission()
function array<XComGameState_Unit> GetSoldiersOnMission()
{
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;
	local StateObjectReference SoldierReference;

	foreach SquadSoldiersOnMission(SoldierReference)
	{
		Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierReference.ObjectID));
		if (Soldier != none)
		{
			if (IsValidSoldierForSquad(Soldier))
			{
				Soldiers.AddItem(Soldier);
			}
		}
	}

	return Soldiers;
}

// IsValidSoldierForSquad(XComGameState_Unit Soldier)
// Is this soldier valid for a squad? Yes as long as they aren't dead or captured.
// This is often used to filter which units to display in a squad, as the unit list
// in a given squad is not always clean. For example, a mission might involve soldiers
// from a mix of squads as temporary additions to another squad, and if they die or
// are captured on mission the other squads are not necessarily cleaned up from the
// squad right away, but we don't want them to be listed in the squad or appear on any
// missions. A better long-term fix here is to do a better job at post-mission cleanup
// to remove dead/captured soldiers from every squad (can't just do the one that went
// on the mission because they can involve temporary members from other squads).
function bool IsValidSoldierForSquad(XComGameState_Unit Soldier)
{
	return Soldier.IsSoldier() && !Soldier.IsDead() && !Soldier.bCaptured;
}

// GetTempSoldiers()
function array<XComGameState_Unit> GetTempSoldiers()
{
	local array<XComGameState_Unit> SoldiersOnMission;
	local array<XComGameState_Unit> TempSoldiers;
	local XComGameState_Unit Soldier;
	
	SoldiersOnMission = GetSoldiersOnMission();

	foreach SoldiersOnMission(Soldier)
	{
		if (IsSoldierTemporary(Soldier))
		{
			TempSoldiers.AddItem(Soldier);
		}
	}
	return TempSoldiers;
}

// IsSoldierTemporary(XComGameState_Unit Soldier)
function bool IsSoldierTemporary(XComGameState_Unit Soldier)
{
	if (SquadSoldiersOnMission.Find('ObjectID', Soldier.GetReference().ObjectID) == -1)
		return false;
	return SquadSoldiers.Find('ObjectID', Soldier.GetReference().ObjectID) == -1;
}

// GetDeployableSoldiers(optional bool bAllowWoundedSoldiers=false)
function array<XComGameState_Unit> GetDeployableSoldiers(optional bool bAllowWoundedSoldiers=false)
{
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;
	local array<XComGameState_Unit> DeployableSoldiers;

	Soldiers = GetSoldiers();

	foreach Soldiers(Soldier)
	{
		if (Soldier.GetStatus() == eStatus_Active || Soldier.GetStatus() == eStatus_PsiTraining || (bAllowWoundedSoldiers && Soldier.IsInjured()))
		{
			DeployableSoldiers.AddItem(Soldier);
		}
	}
	return DeployableSoldiers;
}

// GetSoldierRefs(optional bool bIncludeTemp = false)
function array<StateObjectReference> GetSoldierRefs(optional bool bIncludeTemp = false)
{
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;
	local array<StateObjectReference> SoldierRefs;

	Soldiers = GetSoldiers();
	foreach Soldiers(Soldier)
	{
		SoldierRefs.AddItem(Soldier.GetReference());
	}

	if (!bIncludeTemp)
	{
		return SoldierRefs;
	}

	Soldiers = GetTempSoldiers();
	foreach Soldiers(Soldier)
	{
		SoldierRefs.AddItem(Soldier.GetReference());
	}
	return SoldierRefs;
}

// GetDeployableSoldierRefs(optional bool bAllowWoundedSoldiers=false)
function array<StateObjectReference> GetDeployableSoldierRefs(optional bool bAllowWoundedSoldiers=false)
{
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;
	local array<StateObjectReference> DeployableSoldierRefs;

	Soldiers = GetDeployableSoldiers(bAllowWoundedSoldiers);
	foreach Soldiers(Soldier)
	{
		DeployableSoldierRefs.AddItem(Soldier.GetReference());
	}
	return DeployableSoldierRefs;
}

// UnitIsInSquad(StateObjectReference UnitRef) Switch to XComGameState_Unit?
function bool UnitIsInSquad(StateObjectReference UnitRef)
{
	return SquadSoldiers.Find('ObjectID', UnitRef.ObjectID) != -1;
}

// IsSoldierOnMission(StateObjectReference UnitRef) Switch to XComGameState_Unit?
function bool IsSoldierOnMission(StateObjectReference UnitRef)
{
	return SquadSoldiersOnMission.Find('ObjectID', UnitRef.ObjectID) != -1;
}

// AddSoldier(StateObjectReference UnitRef) Switch to XComGameState_Unit?
function AddSoldier(StateObjectReference UnitRef)
{
	local StateObjectReference SoldierRef;
	local int idx;

	// the squad may have "blank" ObjectIDs in order to allow player to arrange squad as desired
	// so, when adding a new soldier generically, try and find an existing ObjectID == 0 to fill before adding
	// This is a fix for ID 863
	foreach SquadSoldiers(SoldierRef, idx)
	{
		if (SoldierRef.ObjectID == 0)
		{
			SquadSoldiers[idx] = UnitRef;
			return;
		}
	}
	SquadSoldiers.AddItem(UnitRef);
}

// RemoveSoldier(StateObjectReference UnitRef) Switch to XComGameState_Unit?
function RemoveSoldier(StateObjectReference UnitRef)
{
	SquadSoldiers.RemoveItem(UnitRef);
}

// GetSquadCount()
function int GetSquadCount()
{
	local int idx, Count;

	for(idx = 0; idx < SquadSoldiers.Length; idx++)
	{
		if(SquadSoldiers[idx].ObjectID > 0)
			Count++;
	}
	return Count;
}

// GetSquadOnMissionCount()
function int GetSquadOnMissionCount()
{
	local int idx, Count;

	for(idx = 0; idx < SquadSoldiersOnMission.Length; idx++)
	{
		if(SquadSoldiersOnMission[idx].ObjectID > 0)
			Count++;
	}
	return Count;
}

// EvacDelayModifier()
function int EvacDelayModifier()
{
	local int SquadSize;

	SquadSize = GetSquadOnMissionCount();

	if (SquadSize >= default.EvacDelayAtSquadSize.Length)
		SquadSize = default.EvacDelayAtSquadSize.Length - 1;

	return default.EvacDelayAtSquadSize[SquadSize];
}

// SetOnMissionSquadSoldierStatus(XComGameState NewGameState)
function SetOnMissionSquadSoldierStatus(XComGameState NewGameState)
{
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;

	foreach SquadSoldiersOnMission(UnitRef)
	{
		UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitRef.ObjectID));
		if(UnitState == none && UnitRef.ObjectID != 0)
		{
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
			NewGameState.AddStateObject(UnitState);
		}
		if (UnitState != none)
		{
			class'Squad_Static_Soldiers_Helper'.static.SetOnMissionStatus(UnitState, NewGameState);
		}
	}
}

// PostMissionRevertSoldierStatus(XComGameState NewGameState, XComGameState_LWSquadManager SquadMgr)
function PostMissionRevertSoldierStatus(XComGameState NewGameState, SquadManager_XComGameState SquadMgr)
{
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;

	foreach SquadSoldiersOnMission(UnitRef)
	{
		if (UnitRef.ObjectID == 0)
			continue;

		UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitRef.ObjectID));
		if(UnitState == none)
		{
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
			if (UnitState == none)
				continue;
			NewGameState.AddStateObject(UnitState);
		}
		
		PostMissionCheckForDeadOrCapturedSoldiers(NewGameState, UnitState, SquadMgr);
		PostMissionCheckForActivePsiTraining(NewGameState, UnitState);

		//if soldier still has OnMission status, set status to active
		if(class'Squad_Static_Soldiers_Helper'.static.IsUnitOnMission(UnitState))
		{
			UnitState.SetStatus(eStatus_Active);		
		}
	}
}

// PostMissionCheckForDeadOrCapturedSoldiers(XComGameState NewGameState, XComGameState_Unit UnitState, SquadManager_XComGameState SquadMgr)
function PostMissionCheckForDeadOrCapturedSoldiers(XComGameState NewGameState, XComGameState_Unit UnitState, SquadManager_XComGameState SquadMgr)
{
	local Squad_XComGameState SquadState, UpdatedSquad;
	local StateObjectReference SquadRef;

	//if solder is dead or captured, remove from squad
	if(UnitState.IsDead() || UnitState.bCaptured)
	{
		RemoveSoldier(UnitState.GetReference());
		// Also find if the unit was a persistent member of another squad, and remove that that squad as well if so - ID 1675
		foreach SquadMgr.Squads.Squads(SquadRef)
		{
			SquadState = SquadMgr.Squads.GetSquad(SquadRef);
			if(SquadState.Soldiers.UnitIsInSquad(UnitState.GetReference()))
			{
				UpdatedSquad = Squad_XComGameState(NewGameState.GetGameStateForObjectID(SquadState.ObjectID));
				if (UpdatedSquad == none)
				{
					UpdatedSquad = Squad_XComGameState(NewGameState.CreateStateObject(class'Squad_XComGameState', SquadState.ObjectID));
					NewGameState.AddStateObject(UpdatedSquad);
				}
				UpdatedSquad.Soldiers.RemoveSoldier(UnitState.GetReference());
				break;	
			}
		}
	}
}

// PostMissionCheckForActivePsiTraining(XComGameState NewGameState, XComGameState_Unit UnitState)
function PostMissionCheckForActivePsiTraining(XComGameState NewGameState, XComGameState_Unit UnitState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersProjectPsiTraining PsiProjectState;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_StaffSlot SlotState;
	local int SlotIndex;
	local StaffUnitInfo UnitInfo;

	XComHQ = `XCOMHQ;

	//if soldier has an active psi training project, handle it if needed
	PsiProjectState = XComHQ.GetPsiTrainingProject(UnitState.GetReference());
	if (PsiProjectState != none) // A paused Psi Training project was found for the unit
	{
		if(UnitState.GetStatus() != eStatus_PsiTraining) // if the project wasn't already resumed (e.g. during typical post-mission processing)
		{
			//following code was copied from XComGameStateContext_StrategyGameRule.SquadTacticalToStrategyTransfer
			if (UnitState.IsDead() || UnitState.bCaptured) // The unit died or was captured, so remove the project
			{
				XComHQ.Projects.RemoveItem(PsiProjectState.GetReference());
				NewGameState.RemoveStateObject(PsiProjectState.ObjectID);
			}
			else if (!UnitState.IsInjured()) // If the unit is uninjured, restart the training project automatically
			{
				// Get the Psi Chamber facility and staff the unit in it if there is an open slot
				FacilityState = XComHQ.GetFacilityByName('PsiChamber'); // Only one Psi Chamber allowed, so safe to do this

				for (SlotIndex = 0; SlotIndex < FacilityState.StaffSlots.Length; ++SlotIndex)
				{
					//If this slot has not already been modified (filled) in this tactical transfer, check to see if it's valid
					SlotState = XComGameState_StaffSlot(NewGameState.GetGameStateForObjectID(FacilityState.StaffSlots[SlotIndex].ObjectID));
					if (SlotState == None)
					{
						SlotState = FacilityState.GetStaffSlot(SlotIndex);

						// If this is a valid soldier slot in the Psi Lab, restaff the soldier and restart their training project
						if (!SlotState.IsLocked() && SlotState.IsSlotEmpty() && SlotState.IsSoldierSlot())
						{
							// Restart the paused training project
							PsiProjectState = XComGameState_HeadquartersProjectPsiTraining(NewGameState.CreateStateObject(class'XComGameState_HeadquartersProjectPsiTraining', PsiProjectState.ObjectID));
							NewGameState.AddStateObject(PsiProjectState);
							PsiProjectState.bForcePaused = false;

							UnitInfo.UnitRef = UnitState.GetReference();
							SlotState.FillSlot(UnitInfo, NewGameState);
							break;
						}
					}
				}
			}
		}
	}
}
