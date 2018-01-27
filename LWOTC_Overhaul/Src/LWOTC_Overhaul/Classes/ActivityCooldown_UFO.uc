//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCooldown_UFO.uc
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: Cooldown mechanics for creation of UFO activities; primarily here so we can have difficulty-specific 
//---------------------------------------------------------------------------------------
class ActivityCooldown_UFO extends ActivityCooldown_Global config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array<int> FORCE_UFO_COOLDOWN_DAYS;
var config array<int> ALERT_UFO_COOLDOWN_DAYS;

var bool UseForceTable;

function float GetCooldownHours()
{
	if (UseForceTable)
	{
		return (default.FORCE_UFO_COOLDOWN_DAYS[`CAMPAIGNDIFFICULTYSETTING] * 24) + (`SYNC_FRAND() * RandCooldown_Hours);
	}
	`LWTRACE ("Using UFO Alert Cooldown Table" @ ALERT_UFO_COOLDOWN_DAYS[`CAMPAIGNDIFFICULTYSETTING]);
	return (default.ALERT_UFO_COOLDOWN_DAYS[`CAMPAIGNDIFFICULTYSETTING] * 24) + (`SYNC_FRAND() * RandCooldown_Hours);
}