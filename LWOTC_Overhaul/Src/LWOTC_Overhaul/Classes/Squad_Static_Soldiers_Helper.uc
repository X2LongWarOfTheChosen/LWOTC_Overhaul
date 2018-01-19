class Squad_Static_Soldiers_Helper extends Object;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

// IsUnitOnMission(XComGameState_Unit UnitState)
// helper for sparks to resolve if a wounded spark is on a mission, since that status can override the OnMission one
static function bool IsUnitOnMission(XComGameState_Unit UnitState)
{
	switch (UnitState.GetMyTemplateName())
	{
		case  'SparkSoldier':
			//sparks can be wounded and on a mission, so instead we have to do a more brute force check of existing squads and havens
			if (UnitState.GetStatus() == eStatus_OnMission)
			{
				return true;
			}
			if (`SQUADMGR.UnitIsOnMission(UnitState.GetReference()))
			{
				return true;
			}
			//if (`LWOUTPOSTMGR.IsUnitAHavenLiaison(UnitState.GetReference()))
			//{
			//	return true;
			//}
			break;
		default:
			return UnitState.GetStatus() == eStatus_OnMission;
			break;
	}
	return false;
}

// SetOnMissionStatus(XComGameState_Unit UnitState, XComGameState NewGameState)
// helper for sparks to update healing project and staffslot
static function SetOnMissionStatus(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local XComGameState_StaffSlot StaffSlotState;
	local XComGameState_HeadquartersProjectHealSoldier HealSparkProject;

	switch (UnitState.GetMyTemplateName())
	{
		case  'SparkSoldier':
			//sparks can be wounded and set on a mission, in which case don't update their status, but pull them from the healing bay
			if (UnitState.GetStatus() == eStatus_Healing)
			{
				//if it's in a healing slot, remove it from slot
				StaffSlotState = UnitState.GetStaffSlot();
				if(StaffSlotState != none)
				{
					StaffSlotState.EmptySlot(NewGameState);
				}
				//and pause any healing project
				HealSparkProject = GetHealSparkProject(UnitState.GetReference());
				if (HealSparkProject != none)
				{
					HealSparkProject.PauseProject();
				}
			}
			break;
		default:
			break;
	}
	UnitState.SetStatus(eStatus_OnMission);
}