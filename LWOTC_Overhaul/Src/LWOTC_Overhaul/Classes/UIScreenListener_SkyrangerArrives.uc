//---------------------------------------------------------------------------------------
//  FILE:    UIScreenListener
//  AUTHOR:  Amineri / Pavonis Interactive
//
//  PURPOSE: Provides functionality for launching infiltration missions after skyranger arrival
//--------------------------------------------------------------------------------------- 

class UIScreenListener_SkyrangerArrives extends UIScreenListener;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var localized string strLaunchInfiltration;
var localized string strAbortInfiltration;
var localized string strContinueInfiltration;

event OnInit(UIScreen Screen)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local UISkyrangerArrives SkyrangerArrives;
	local SquadManager_XComGameState SquadMgr;
	local Squad_XComGameState Squad;

	if(!Screen.IsA('UISkyrangerArrives')) return;

	SkyrangerArrives = UISkyrangerArrives(Screen);
	if(SkyrangerArrives == none) return;

	XComHQ = `XCOMHQ;
	SquadMgr = `SQUADMGR;

	if(SquadMgr.IsValidInfiltrationMission(XComHQ.SelectedDestination))
	{
		Squad = SquadMgr.Squads.GetSquadOnMission(XComHQ.SelectedDestination);
		if (Squad != none) // there was a squad so we are aborting
		{
			if (Squad.bCannotCancelAbort)
			{
				OnAbortInfiltration(SkyrangerArrives.Button1);
			}
			else
			{
				SkyrangerArrives.Button1.OnClickedDelegate = OnAbortInfiltration;
				SkyrangerArrives.Button1.SetText(strAbortInfiltration);
				SkyrangerArrives.Button2.OnClickedDelegate = OnContinueInfiltration;
				SkyrangerArrives.Button2.SetText(strContinueInfiltration);
			}
		}
		else  // no current squad, so are starting infiltration
		{
			SkyrangerArrives.Button1.OnClickedDelegate = OnLaunchInfiltration;
			SkyrangerArrives.Button1.SetText(strLaunchInfiltration);

			PlaySkyrangerArrivesNarrativeMoment();
		}
	}
	else // not an infiltration
	{
		PlaySkyrangerArrivesNarrativeMoment();
	}
}

simulated function PlaySkyrangerArrivesNarrativeMoment()
{
	local XComGameState_Objective ObjectiveState;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Objective', ObjectiveState)
	{
		if (ObjectiveState.GetMyTemplateName() == 'N_InDropPosition')
		{
			ObjectiveState.OnNarrativeEventTrigger(none, none, none, 'OnSkyrangerArrives', none);
			break;
		}
	}
}

simulated function PlayAbortInfiltrationNarrativeMoment()
{
	local XComHQPresentationLayer HQPres;

	HQPres = `HQPRES;

	switch (`SYNC_RAND(4))
	{
		case 0:
			HQPres.UINarrative(XComNarrativeMoment'X2NarrativeMoments.T_EVAC_All_Out_Firebrand_02');
			break;
		case 1:
			HQPres.UINarrative(XComNarrativeMoment'X2NarrativeMoments.T_EVAC_All_Out_Firebrand_03');
			break;
		case 2:
			HQPres.UINarrative(XComNarrativeMoment'X2NarrativeMoments.T_EVAC_All_Out_Firebrand_04');
			break;
		case 3:
			HQPres.UINarrative(XComNarrativeMoment'X2NarrativeMoments.T_EVAC_All_Out_Firebrand_05');
			break;
		default:
			break;
	}
}

simulated function OnAbortInfiltration(UIButton Button)
{
	local UISkyrangerArrives SkyrangerArrives;
	local XComGameState_MissionSite SelectedDestinationMission;

	SelectedDestinationMission = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(`XCOMHQ.SelectedDestination.ObjectID));
	if (SelectedDestinationMission == none)
	{
		`REDSCREEN("Attempting to abort infiltration on non-mission entity");
		return;
	}
	`SQUADMGR.UpdateSquadPostMission(SelectedDestinationMission.GetReference());
	SelectedDestinationMission.InteractionComplete(true);

	SkyrangerArrives = UISkyrangerArrives(Button.GetParent(class'UISkyrangerArrives'));
	if (SkyrangerArrives != none)
	{
		SkyrangerArrives.CloseScreen();
	}
	else
	{
		`REDSCREEN("Unable to find UISkyrangerArrives to close when aborting infiltration");
	}
	PlayAbortInfiltrationNarrativeMoment();
}

simulated function OnContinueInfiltration(UIButton Button)
{
	local UISkyrangerArrives SkyrangerArrives;
	local XComGameState_MissionSite SelectedDestinationMission;

	SelectedDestinationMission = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(`XCOMHQ.SelectedDestination.ObjectID));
	if (SelectedDestinationMission == none)
	{
		`REDSCREEN("Attempting to continue infiltration on non-mission entity");
	}
	SelectedDestinationMission.InteractionComplete(true);

	SkyrangerArrives = UISkyrangerArrives(Button.GetParent(class'UISkyrangerArrives'));
	if (SkyrangerArrives != none)
	{
		SkyrangerArrives.CloseScreen();
	}
}

simulated function OnLaunchInfiltration(UIButton Button)
{
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local SquadManager_XComGameState SquadMgr, UpdatedSquadMgr;
	local Squad_XComGameState Squad;
	local StateObjectReference NullRef;
	local UISkyrangerArrives SkyrangerArrives;

	XComHQ = `XCOMHQ;
	SquadMgr = `SQUADMGR;

	if(SquadMgr.LaunchingMissionSquad.ObjectID > 0)
	{

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Sending existing squad on infiltration mission");
		Squad = Squad_XComGameState(NewGameState.CreateStateObject(class'Squad_XComGameState', SquadMgr.LaunchingMissionSquad.ObjectID));
		NewGameState.AddStateObject(Squad);

		Squad.Soldiers.SquadSoldiersOnMission = XComHQ.Squad;
		Squad.InfiltrationState.InitInfiltration(NewGameState, XComHQ.MissionRef, 0.0);
		Squad.Soldiers.SetOnMissionSquadSoldierStatus(NewGameState);

		UpdatedSquadMgr = SquadManager_XComGameState(NewGameState.CreateStateObject(SquadMgr.Class, SquadMgr.ObjectID));
		NewGameState.AddStateObject(UpdatedSquadMgr);
		UpdatedSquadMgr.LaunchingMissionSquad = NullRef;

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else // not persistent, create a new temporary squad for this mission
	{
		Squad = SquadMgr.Squads.AddSquad(XComHQ.Squad, XComHQ.MissionRef);
	}

	// skyranger flies back to avenger after dropping off to start infiltration
	SkyrangerArrives = UISkyrangerArrives(Button.GetParent(class'UISkyrangerArrives'));
	if (SkyrangerArrives != none)
		SkyrangerArrives.GetMission().InteractionComplete(true);

	SkyrangerArrives.CloseScreen();

	//cancel the squad deploying music
	`XSTRATEGYSOUNDMGR.PlayGeoscapeMusic();

	//clear the squad so it's not populated again for next mission
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clearing existing squad from HQ");
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	XComHQ.Squad.Length = 0;
	NewGameState.AddStateObject(XComHQ);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

}

defaultproperties
{
	// Leaving this assigned to none will cause every screen to trigger its signals on this class
	ScreenClass = none;
}