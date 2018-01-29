//---------------------------------------------------------------------------------------
//  FILE:    UIUtilities_LWOTC
//  AUTHOR:  tracktwo / Pavonis Interactive
//
//  PURPOSE: Miscellanous UI helper routines
//---------------------------------------------------------------------------------------

class UIUtilities_LWOTC extends Object config(LWOTC_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var localized string m_strInfiltrationMission;
var localized string m_strQuickResponseMission;
var localized string m_strFixedEvacLocation;
var localized string m_strFlareEvac;
var localized string m_strDelayedEvac;
var localized string m_strNoEvac;
var localized string m_strMaxSquadSize;
var localized string m_strConcealedStart;
var localized string m_strRevealedStart;
var localized string m_strObjectiveTimer;
var localized string m_strExtractionTimer;
var localized string m_strGetCorpses;
var localized string m_strSweepObjective;
var localized string m_strEvacRequired;
var localized string m_strTurnSingular;
var localized string m_strTurnPlural;
var localized string m_strMinimumInfiltration;
var localized string m_strYellowAlert;
var localized string m_sAverageScatterText;
var localized string m_strBullet;

var localized string m_strStripWeaponUpgrades;
var localized string m_strStripWeaponUpgradesLower;
var localized string m_strStripWeaponUpgradesConfirm;
var localized string m_strStripWeaponUpgradesConfirmDesc;
var localized string m_strTooltipStripWeapons;
var localized string m_strVIPCaptureReward;

var config array<name> EvacFlareMissions;
var config array<name> EvacFlareEscapeMissions;
var config array<name> FixedExitMissions;
var config array<name> DelayedEvacMissions;
var config array<name> NoEvacMissions;
var config array<name> ObjectiveTimerMissions;
var config array<name> EvacTimerMissions;

// BuildMissionInfoPanel(UIScreen ParentScreen, StateObjectReference MissionRef)
function static BuildMissionInfoPanel(UIScreen ParentScreen, StateObjectReference MissionRef)
{
	local SquadManager_XComGameState SquadMgr;
	local XComGameState_MissionSite MissionState;
	local AlienActivity_XComGameState ActivityState;
	local UIPanel MissionExpiryPanel;
	local UIBGBox MissionExpiryBG;
	local UIX2PanelHeader MissionExpiryTitle;
	//local MissionSite_XComGameState_Rendezvous RendezvousMissionState;
	//local X2CharacterTemplate FacelessTemplate;
	local String MissionTime;
	local float TotalMissionHours;
	local string MissionInfoTimer, MissionInfo1, MissionInfo2, HeaderStr;
	local int EvacFlareTimer;

	SquadMgr = `SQUADMGR;
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));

	//if (SquadMgr.IsValidInfiltrationMission(MissionRef) &&
			//MissionState.ExpirationDateTime.m_iYear < 2100)

	ActivityState = class'AlienActivity_XComGameState_Manager'.static.FindAlienActivityByMission(MissionState);
	if(ActivityState != none)
		TotalMissionHours = int(ActivityState.SecondsRemainingCurrentMission() / 3600.0);
	else
		TotalMissionHours = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInSeconds(MissionState.ExpirationDateTime, class'XComGameState_GeoscapeEntity'.static.GetCurrentTime()) / 3600.0;
	MissionInfoTimer = "";
	MissionInfo1 = "<font size=\"16\">";
	MissionInfo1 $= GetMissionTypeString (MissionRef) @ default.m_strBullet $ " ";

	if (SquadMgr.Squads.GetSquadOnMission(MissionRef) != none)
	{
		EvacFlareTimer = GetCurrentEvacDelay(SquadMgr.Squads.GetSquadOnMission(MissionRef),ActivityState);
	}
	else
	{
		EvacFlareTimer = -1;
	}
	if (GetEvacTypeString (MissionState) != "")
	{
		MissionInfo1 $= GetEvacTypeString (MissionState);
		if (EvacFlareTimer >= 0 && (default.EvacFlareMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1 || default.EvacFlareEscapeMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1))
		{
			MissionInfo1 @= "(" $ string (EvacFlareTimer) @ GetTurnsLabel(EvacFlareTimer) $ ")";
		}
		MissionInfo1 @= default.m_strBullet $ " ";
	}
	MissionInfo1 $= default.m_strMaxSquadSize @ string(MissionState.GeneratedMission.Mission.MaxSoldiers);
	MissionInfo2 = "";
	MissionInfo2 $= GetTimerInfoString (MissionState);
	if (GetTimerInfoString (MissionState) != "")
	{
		MissionInfo2 @= default.m_strBullet $ " ";
	}
	if (HasSweepObjective(MissionState))
	{
		MissionInfo2 $= default.m_strSweepObjective @ default.m_strBullet $ " ";
	}
	if (FullSalvage(MissionState))
	{
		MissionInfo2 $= default.m_strGetCorpses @ default.m_strBullet $ " ";
	}

    //if (MissionState.GeneratedMission.Mission.sType == "Rendezvous_LW")
	//{
	//	RendezvousMissionState = XComGameState_MissionSiteRendezvous_LW(MissionState);
	//	FacelessTemplate = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().FindCharacterTemplate('Faceless');
	//	MissionInfo2 $= FacelessTemplate.strCharacterName $ ":" @ RendezvousMissionState.FacelessSpies.Length @ default.m_strBullet $ " ";
	//}
	MissionInfo2 $= GetMissionConcealStatusString (MissionRef);
	MissionTime = class'UISquadSelect_InfiltrationPanel'.static.GetDaysAndHoursString(TotalMissionHours);

	// Try to find an existing panel first. If we have one, remove it - we need to refresh.
	MissionExpiryPanel = ParentScreen.GetChildByName('ExpiryPanel', false);
	if (MissionExpiryPanel != none)
	{
		MissionExpiryPanel.Remove();
	}
	MissionExpiryPanel = ParentScreen.Spawn(class'UIPanel', ParentScreen);
	MissionExpiryPanel.InitPanel('ExpiryPanel').SetPosition(725, 800);
	MissionExpiryBG = ParentScreen.Spawn(class'UIBGBox', MissionExpiryPanel);
	MissionExpiryBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
	MissionExpiryBG.InitBG('ExpiryBG', 0, 0, 470, 130);
	MissionExpiryTitle = ParentScreen.Spawn(class'UIX2PanelHeader', MissionExpiryPanel);

	if (TotalMissionHours >= 0.0 && TotalMissionHours <= 10000.0 && MissionState.ExpirationDateTime.m_iYear < 2100)
		MissionInfoTimer = class'UISquadSelect_InfiltrationPanel'.default.strMissionTimeTitle @ MissionTime $ "\n";

	HeaderStr = class'UIMissionIntro'.default.m_strMissionTitle;
	HeaderStr -= ":";
	MissionExpiryTitle.InitPanelHeader('MissionExpiryTitle',
										HeaderStr,
										MissionInfoTimer $ MissionInfo1 $ "\n" $ MissionInfo2 $ "</font>");
	MissionExpiryTitle.SetHeaderWidth(MissionExpiryBG.Width - 20);
	MissionExpiryTitle.SetPosition(MissionExpiryBG.X + 10, MissionExpiryBG.Y + 10);
	MissionExpiryPanel.Show();
}

// GetCurrentEvacDelay (Squad_XComGameState Squad, AlienActivity_XComGameState ActivityState)
// Read the evac delay in the strat layer
private static function int GetCurrentEvacDelay (Squad_XComGameState Squad, AlienActivity_XComGameState ActivityState)
{
	local int EvacDelay; //, k;
	//local XComGameState_Unit UnitState;
	//local XComGameState_Unit_LWOfficer OfficerState;

	if (Squad == none)
		return -1;

	EvacDelay = class'EvacZone_X2Ability_PlaceDelayed'.default.DEFAULT_EVAC_PLACEMENT_DELAY[`CAMPAIGNDIFFICULTYSETTING];

	EvacDelay += Squad.Soldiers.EvacDelayModifier();
	EvacDelay += Squad.InfiltrationState.EvacDelayModifier();
	EvacDelay += Squad.EvacDelayModifier();
	EvacDelay += ActivityState.GetMyTemplate().MissionTree[ActivityState.CurrentMissionLevel].EvacModifier;

	/*
	for (k = 0; k < Squad.SquadSoldiersOnMission.Length; k++)
	{
		UnitState = Squad.GetSoldier(k);
		if (class'LWOfficerUtilities'.static.IsOfficer(UnitState))
		{
			if (class'LWOfficerUtilities'.static.IsHighestRankOfficerinSquad(UnitState))
			{
				OfficerState = class'LWOfficerUtilities'.static.GetOfficerComponent(UnitState);
				if (OfficerState.HasOfficerAbility('AirController'))
				{
					EvacDelay -= class'X2Ability_OfficerAbilitySet'.default.AIR_CONTROLLER_EVAC_TURN_REDUCTION;
					break;
				}
			}
		}
	}
	*/

	EvacDelay = Clamp (EvacDelay, class'EvacZone_X2Ability_PlaceDelayed'.default.MIN_EVAC_PLACEMENT_DELAY[`CAMPAIGNDIFFICULTYSETTING], class'EvacZone_X2Ability_PlaceDelayed'.default.MAX_EVAC_PLACEMENT_DELAY);

	return EvacDelay;

}

// HasSweepObjective (XComGameState_MissionSite MissionState)
static function bool HasSweepObjective (XComGameState_MissionSite MissionState)
{
	local int ObjectiveIndex;

    ObjectiveIndex = 0;
    if(ObjectiveIndex < MissionState.GeneratedMission.Mission.MissionObjectives.Length)
    {
        if(instr(string(MissionState.GeneratedMission.Mission.MissionObjectives[ObjectiveIndex].ObjectiveName), "Sweep") != -1)
        {
            return true;
        }
    }
    return false;
}

// FullSalvage (XComGameState_MissionSite MissionState)
static function bool FullSalvage (XComGameState_MissionSite MissionState)
{
	local int ObjectiveIndex;

    ObjectiveIndex = 0;
    if(ObjectiveIndex < MissionState.GeneratedMission.Mission.MissionObjectives.Length)
    {
        if(MissionState.GeneratedMission.Mission.MissionObjectives[ObjectiveIndex].bIsTacticalObjective)
        {
            return true;
        }
    }
    return false;
}

// GetMissionTypeString (StateObjectReference MissionRef)
static function string GetMissionTypeString (StateObjectReference MissionRef)
{
	//local XComGameState_MissionSite MissionState;

	//MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));

	if (`SQUADMGR.IsValidInfiltrationMission(MissionRef)) // && MissionState.ExpirationDateTime.m_iYear < 2100)
	{
		return default.m_strInfiltrationMission;
	}
	else
	{
		return default.m_strQuickResponseMission;
	}
}

// GetMissionConcealStatusString (StateObjectReference MissionRef)
static function string GetMissionConcealStatusString (StateObjectReference MissionRef)
{
	local MissionSchedule CurrentSchedule;
	local XComGameState_MissionSite MissionState;
	local int k;
	local XGParamTag LocTag;
	local string ExpandedString;

	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));

	if (MissionState.SelectedMissionData.SelectedMissionScheduleName != '')
	{
		`TACTICALMISSIONMGR.GetMissionSchedule(MissionState.SelectedMissionData.SelectedMissionScheduleName, CurrentSchedule);
	}
	else
	{
		// No mission schedule yet. This generally only happens for missions that spawn outside geoscape elements, like avenger def.
		// Just look over the possible schedules and pick one to use. It may be wrong if the mission type changes concealment status
		// based on the schedule, but no current missions do this.
		`TACTICALMISSIONMGR.GetMissionSchedule(MissionState.GeneratedMission.Mission.MissionSchedules[0], CurrentSchedule);
	}

	if (CurrentSchedule.XComSquadStartsConcealed)
	{
		for (k = 0; k < class'Squad_XComGameState_Listener'.default.MINIMUM_INFIL_FOR_CONCEAL.length; k++)
		{
			if (MissionState.GeneratedMission.Mission.sType == class'Squad_XComGameState_Listener'.default.MINIMUM_INFIL_FOR_CONCEAL[k].MissionType)
			{
				LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
				LocTag.IntValue0 = round (100 * class'Squad_XComGameState_Listener'.default.MINIMUM_INFIL_FOR_CONCEAL[k].MinInfiltration);
				ExpandedString = `XEXPAND.ExpandString(default.m_strMinimumInfiltration);
				return default.m_strConcealedStart @ ExpandedString;
			}
		}
		return default.m_strConcealedStart;
	}
	else
	{
		return default.m_strRevealedStart;
	}
}

// GetTimerInfoString (XComGameState_MissionSite MissionState)
static function string GetTimerInfoString (XComGameState_MissionSite MissionState)
{
	local int Timer;

	Timer = class'Infiltration_SeqAct_InitializeMissionTimer'.static.GetInitialTimer(MissionState.GeneratedMission.Mission.MissionFamily);
	if (Timer > 0)
	{
		if (default.ObjectiveTimerMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
		{
			return default.m_strObjectiveTimer @ string(Timer - 1) @ GetTurnsLabel(Timer);
		}
		else
		{
			if (default.EvacTimerMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
			{
				if (default.FixedExitMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
				{
					return default.m_strExtractionTimer @ string(Timer - 1) $ "+" @ GetTurnsLabel(Timer);
				}
				else
				{
					return default.m_strExtractionTimer @ string(Timer - 1) @ GetTurnsLabel(Timer);
				}
			}
		}
	}
	return "";
}

// GetEvacTypeString (XComGameState_MissionSite MissionState)
static function string GetEvacTypeString (XComGameState_MissionSite MissionState)
{
	if (default.EvacFlareMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1 || default.EvacFlareEscapeMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
	{
		return default.m_strFlareEvac;
	}
	else
	{
		if (default.FixedExitMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
		{
			return default.m_strFixedEvacLocation;
		}
		else
		{
			if (default.DelayedEvacMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
			{
				return default.m_strDelayedEvac;
			}
			else
			{
				if (default.NoEvacMissions.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
				{
					return default.m_strNoEvac;
				}
			}
		}
	}
	return "";
}

// GetMouseCoords()
static function vector2d GetMouseCoords()
{
	local PlayerController PC;
	local PlayerInput kInput;
	local vector2d vMouseCursorPos;

	foreach `XWORLDINFO.AllControllers(class'PlayerController',PC)
	{
		if ( PC.IsLocalPlayerController() )
		{
			break;
		}
	}
	kInput = PC.PlayerInput;

	XComTacticalInput(kInput).GetMouseCoordinates(vMouseCursorPos);
	return vMouseCursorPos;
}

// GetHTMLAverageScatterText(float value, optional int places = 2)
static function string GetHTMLAverageScatterText(float value, optional int places = 2)
{
	local XGParamTag LocTag;
	local string ReturnString, FloatString, TempString;
	local int i;
	local float TempFloat, TestFloat;

	TempFloat = value;
	for (i=0; i< places; i++)
	{
		TempFloat *= 10.0;
	}
	TempFloat = Round(TempFloat);
	for (i=0; i< places; i++)
	{
		TempFloat /= 10.0;
	}

	TempString = string(TempFloat);
	for (i = InStr(TempString, ".") + 1; i < Len(TempString) ; i++)
	{
		FloatString = Left(TempString, i);
		TestFloat = float(FloatString);
		if (TempFloat ~= TestFloat)
		{
			break;
		}
	}

	if (Right(FloatString, 1) == ".")
	{
		FloatString $= "0";
	}

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = FloatString;
	ReturnString = `XEXPAND.ExpandString(default.m_sAverageScatterText);

	return class'UIUtilities_Text'.static.GetColoredText(ReturnString, eUIState_Bad, class'UIUtilities_Text'.const.BODY_FONT_SIZE_3D);
}

// GetTurnsLabel(int kounter)
// Returns Singluar or Plural
private static function string GetTurnsLabel(int kounter)
{
	if (kounter == 1)
		return default.m_strTurnSingular;
	return default.m_strTurnPlural;
}