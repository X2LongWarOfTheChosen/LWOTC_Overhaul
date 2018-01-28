//---------------------------------------------------------------------------------------
//  FILE:    Utilities_LWOTC
//  AUTHOR:  tracktwo (Pavonis Interactive)
//
//  PURPOSE: Miscellaneous helper routines.
//--------------------------------------------------------------------------------------- 

class Utilities_LWOTC extends Object;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

// GetMissionSettings(XComGameState_MissionSite MissionSite, out MissionSettings_LW Settings)
function static bool GetMissionSettings(XComGameState_MissionSite MissionSite, out MissionSettings_LW Settings)
{
    local name MissionName;
	local string MissionFamilyName;
	local int idx;

    // Retreive the mission type and family names.
	MissionName = MissionSite.GeneratedMission.Mission.MissionName;
	MissionFamilyName = MissionSite.GeneratedMission.Mission.MissionFamily;
	if(MissionFamilyName == "")
		MissionFamilyName = MissionSite.GeneratedMission.Mission.sType;

    // First look for a settings match using the mission name.
    idx = class'Mission_X2StrategyElement_LWOTC'.default.MissionSettings.Find('MissionOrFamilyName', MissionName);
	if(idx != -1)
    {
		Settings = class'Mission_X2StrategyElement_LWOTC'.default.MissionSettings[idx];
        return true;
    }

    // Failing that, look for the family name.
	idx = class'Mission_X2StrategyElement_LWOTC'.default.MissionSettings.Find('MissionOrFamilyName', name(MissionFamilyName));
	if(idx != -1)
	{
		Settings = class'Mission_X2StrategyElement_LWOTC'.default.MissionSettings[idx];
        return true;
    }

    // Neither
    `redscreen("GetMissionSettings: No entry for " $ MissionName $ " / " $ MissionFamilyName);
    return false;
}

// CurrentMissionType()
function static string CurrentMissionType()
{
    local XComGameStateHistory History;
    local XComGameState_BattleData BattleData;
    local GeneratedMissionData GeneratedMission;
    local XComGameState_HeadquartersXCom XComHQ;

    History = `XCOMHISTORY;
    XComHQ = `XCOMHQ;

    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    GeneratedMission = XComHQ.GetGeneratedMissionData(BattleData.m_iMissionID);
    if (GeneratedMission.Mission.sType == "")
    {
        // No mission type set. This is probably a tactical quicklaunch.
        return `TACTICALMISSIONMGR.arrMissions[BattleData.m_iMissionType].sType;
    }

    return GeneratedMission.Mission.sType;
}

// CurrentMissionFamily()
function static string CurrentMissionFamily()
{
    local XComGameStateHistory History;
    local XComGameState_BattleData BattleData;
    local GeneratedMissionData GeneratedMission;
    local XComGameState_HeadquartersXCom XComHQ;

    History = `XCOMHISTORY;
    XComHQ = `XCOMHQ;

    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    GeneratedMission = XComHQ.GetGeneratedMissionData(BattleData.m_iMissionID);
    if (GeneratedMission.Mission.MissionFamily == "")
    {
        // No mission type set. This is probably a tactical quicklaunch.
        return `TACTICALMISSIONMGR.arrMissions[BattleData.m_iMissionType].MissionFamily;
    }

    return GeneratedMission.Mission.MissionFamily;
}

// XComGameState_Player FindPlayer(ETeam team)
function static XComGameState_Player FindPlayer(ETeam team)
{
    local XComGameState_Player PlayerState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Player', PlayerState)
    {
        if(PlayerState.GetTeam() == team)
        {
            return PlayerState;
        }
    }

    return none;
}