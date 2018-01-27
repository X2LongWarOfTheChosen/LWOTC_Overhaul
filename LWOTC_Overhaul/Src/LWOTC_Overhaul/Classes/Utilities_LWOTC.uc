//---------------------------------------------------------------------------------------
//  FILE:    Utilities_LW
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