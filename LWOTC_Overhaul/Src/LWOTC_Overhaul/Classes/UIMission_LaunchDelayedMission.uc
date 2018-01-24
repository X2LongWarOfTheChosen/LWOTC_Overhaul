//---------------------------------------------------------------------------------------
//  FILE:    UIMission_LWLaunchDelayedMission.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: Provides controls for actually launching a mission that has been infiltrated
//--------------------------------------------------------------------------------------- 
class UIMission_LaunchDelayedMission extends UIMission config(LWOTC_Infiltration);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var UITextContainer InfiltrationInfoText;
var UITextContainer MissionInfoText;

var localized string m_strMission;
var localized string m_strOptions;
var localized string m_strImageGreeble;
var localized string m_strWait;
var localized string m_strAbort;

var localized string m_strBoostInfiltration;
var localized string m_strAlreadyBoostedInfiltration;
var localized string m_strInsufficentIntelForBoostInfiltration;
var localized string m_strViewSquad;

var localized string m_strInfiltrationStatusExpiring;
var localized string m_strInfiltrationStatusNonExpiring;
var localized string m_strInfiltrationStatusMissionEnding;
var localized string m_strInfiltrationConsequence;
var localized string m_strMustLaunchMission;
var localized string m_strInsuffientInfiltrationToLaunch;

var localized string m_strBoostInfiltrationDescription;

var localized array<string> m_strAlertnessModifierDescriptions;

var UIButton IgnoreButton;

var bool bCachedMustLaunch;
var bool bAborted;

defaultproperties
{
	Package = "/ package/gfxAlerts/Alerts";
	InputState = eInputState_Consume;
}

// InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local AlienActivity_XComGameState AlienActivity;

	super.InitScreen(InitController, InitMovie, InitName);

	AlienActivity = GetActivity();
	bCachedMustLaunch = AlienActivity != none && AlienActivity.bMustLaunch;

	BuildScreen();
}

// BuildScreen()
simulated function BuildScreen()
{
	// Add Interception warning and Shadow Chamber info 
	BindLibraryItem();
	`ACTIVITYMGR.UpdateMissionData(GetMission());
	BuildMissionPanel();
	BuildOptionsPanel();
	class'UIUtilities_LWOTC'.static.BuildMissionInfoPanel(self, MissionRef);

	// Set  up the navigation *after* the alert is built, so that the button visibility can be used. 
	RefreshNavigation();

	PlaySFX("Geoscape_NewResistOpsMissions");
	XComHQPresentationLayer(Movie.Pres).CAMSaveCurrentLocation();

	if(bInstantInterp)
		XComHQPresentationLayer(Movie.Pres).CAMLookAtEarth(GetMission().Get2DLocation(), CAMERA_ZOOM, 0);
	else
		XComHQPresentationLayer(Movie.Pres).CAMLookAtEarth(GetMission().Get2DLocation(), CAMERA_ZOOM);

}

// AddIgnoreButton()
simulated function AddIgnoreButton()
{
	//Button is controlled by flash and shows by default. Hide if need to. 
	//local UIButton IgnoreButton; 

	IgnoreButton = Spawn(class'UIButton', LibraryPanel);
	IgnoreButton.SetResizeToText( false );
	IgnoreButton.InitButton('IgnoreButton', "", OnCancelClicked);
}

// BuildMissionPanel()
simulated function BuildMissionPanel()
{
	local string strDarkEventLabel, strDarkEventValue, strDarkEventTime;
	local AlienActivity_XComGameState AlienActivity;
	local bool bHasDarkEvent;
	local X2RewardTemplate UnknownTemplate;
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_MissionSite Mission;
	local X2StrategyElementTemplateManager TemplateMgr;
	local X2ObjectiveTemplate Template;
	
	Mission = GetMission();

	bHasDarkEvent = Mission.HasDarkEvent();

	if(bHasDarkEvent)
	{
		strDarkEventLabel = class'UIMission_GOps'.default.m_strDarkEventLabel;
		strDarkEventValue = Mission.GetDarkEvent().GetDisplayName();
		strDarkEventTime = Mission.GetDarkEvent().GetPreMissionText();
	}
	else
	{
		strDarkEventLabel = "";
		strDarkEventValue = "";
		strDarkEventTime = "";
	}

	LibraryPanel.MC.BeginFunctionOp("UpdateGuerrillaOpsInfoBlade");
	LibraryPanel.MC.QueueString(GetRegion().GetMyTemplate().DisplayName);
	LibraryPanel.MC.QueueString(m_strMission);
	LibraryPanel.MC.QueueString(GetMissionImage());
	LibraryPanel.MC.QueueString(m_strMissionLabel);
	LibraryPanel.MC.QueueString(GetOpName());
	LibraryPanel.MC.QueueString(m_strMissionObjective);
	LibraryPanel.MC.QueueString(GetObjectiveString());
	LibraryPanel.MC.QueueString(m_strMissionDifficulty);
	LibraryPanel.MC.QueueString(class'UIUtilities_Text_LWOTC'.static.GetDifficultyString(Mission));
	LibraryPanel.MC.QueueString(m_strReward);

	if(GetRewardString() != "")
	{
		LibraryPanel.MC.QueueString(GetRewardString());
	}
	else
	{
		StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
		UnknownTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Dummy_Unknown'));
		LibraryPanel.MC.QueueString(UnknownTemplate.DisplayName);
	}
	LibraryPanel.MC.QueueString(strDarkEventLabel);
	LibraryPanel.MC.QueueString(strDarkEventValue);
	LibraryPanel.MC.QueueString(strDarkEventTime);
	LibraryPanel.MC.QueueString(GetRewardIcon());
	LibraryPanel.MC.EndOp();

	if (MissionInfoText == none)
	{
		MissionInfoText = Spawn(class'UITextContainer', LibraryPanel);	
		MissionInfoText.bAnimateOnInit = false;
		MissionInfoText.MCName = 'MissionInfoText_LW';
		if (bHasDarkEvent)
			MissionInfoText.InitTextContainer('MissionInfoText_LW', , 212, 822+15, 320, 87);
		else // use a larger area to display more text if there's no dark event
			MissionInfoText.InitTextContainer('MissionInfoText_LW', , 212, 822-80, 320, 87+80);
	}

	MissionInfoText.Show();

	AlienActivity = `ACTIVITYMGR.FindAlienActivityByMission(Mission);
	if(AlienActivity != none)
	{
		MissionInfoText.SetHTMLText(class'UIUtilities_Text'.static.GetColoredText(AlienActivity.GetMissionDescriptionForActivity(), eUIState_Normal));
	}
	else
	{
		if (Mission.GetMissionSource().bGoldenPath)
		{
			switch (Mission.GetMissionSource().DataName)
			{
				case 'MissionSource_BlackSite':
				case 'MissionSource_Forge':
				case 'MissionSource_PsiGate':
					MissionInfoText.SetHTMLText(class'UIUtilities_Text'.static.GetColoredText(Mission.GetMissionSource().MissionFlavorText, eUIState_Normal));
					break;
				case 'MissionSource_Broadcast':
					TemplateMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
					if (TemplateMgr != none)
					{
						Template = X2ObjectiveTemplate(TemplateMgr.FindStrategyElementTemplate('T5_M2_CompleteBroadcastTheTruthMission'));
						if (Template != none)
						{
							MissionInfoText.SetHTMLText(class'UIUtilities_Text'.static.GetColoredText(Template.LocLongDescription, eUIState_Normal));
						}
					}
					break;
				default:
					MissionInfoText.Hide();	
					break;
			}
		}
		else
		{
			MissionInfoText.Hide();	
		}
	}
}

// GetObjectiveString()
simulated function String GetObjectiveString()
{
	local string ObjectiveString;
	local AlienActivity_XComGameState AlienActivity;
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local string ActivityObjective;

	ObjectiveString = super.GetObjectiveString();
	ObjectiveString $= "\n";

	AlienActivity = GetActivity();

	if (AlienActivity != none)
	{
		ActivityTemplate = AlienActivity.GetMyTemplate();
		if (ActivityTemplate != none)
		{
			ActivityObjective = ActivityTemplate.ActivityObjectives[AlienActivity.CurrentMissionLevel];
		}
		//if(ActivityObjective == "")
			//ActivityObjective = "Missing ActivityObjectives[" $ AlienActivity.CurrentMissionLevel $ "] for AlienActivity " $ ActivityTemplate.DataName;
	}
	ObjectiveString $= ActivityObjective;

	return ObjectiveString;
}

// GetMissionImage()
simulated function string GetMissionImage()
{
	local AlienActivity_XComGameState AlienActivity;

	AlienActivity = GetActivity();
	if(AlienActivity != none)
		return AlienActivity.GetMissionImage(GetMission());

	return "img:///UILibrary_StrategyImages.X2StrategyMap.Alert_Guerrilla_Ops";
}

// BuildOptionsPanel()
simulated function BuildOptionsPanel()
{
	local string Reason;

	LibraryPanel.MC.BeginFunctionOp("UpdateGuerrillaOpsButtonBlade");
	LibraryPanel.MC.QueueString(m_strOptions);
	LibraryPanel.MC.QueueString(""); //// left blank in favor of a separately placed string, InfiltrationInfoText
	//LibraryPanel.MC.QueueString(GetInfiltrationString()); 
	LibraryPanel.MC.QueueString(m_strBoostInfiltration);
	LibraryPanel.MC.QueueString(m_strViewSquad);
	LibraryPanel.MC.QueueString(m_strAbort);
	LibraryPanel.MC.QueueString(m_strLaunchMission);
	LibraryPanel.MC.QueueString((bCachedMustLaunch ? class'UISkyrangerArrives'.default.m_strReturnToBase : m_strWait));
	LibraryPanel.MC.EndOp();

	Button1.OnClickedDelegate = OnBoostInfiltrationClicked;
	Button2.OnClickedDelegate = OnViewSquadClicked;
	//If mission is expiring, can't Cancel/wait, so need to disable
	Button3.OnClickedDelegate = OnAbortClicked;

	BuildConfirmPanel();

	if (CanBoostInfiltration(Reason))
		Button1.SetDisabled(false);
	else
		Button1.SetDisabled(true, Reason);

	if (CanLaunchInfiltration(Reason))
		ConfirmButton.SetDisabled(false);
	else
		ConfirmButton.SetDisabled(true, Reason);

	if (InfiltrationInfoText == none)
	{
		InfiltrationInfoText = Spawn(class'UITextContainer', self);	
		InfiltrationInfoText.bAnimateOnInit = false;
		InfiltrationInfoText.InitTextContainer( , "TEST TEXT", 100+1283-17, 100+501, 320, 93);
	}

	InfiltrationInfoText.SetHTMLText(class'UIUtilities_Text'.static.GetColoredText(GetInfiltrationString(), eUIState_Normal));

		
}

// CanBoostInfiltration(out string Reason)
simulated function bool CanBoostInfiltration(out string Reason)
{
	local Squad_XComGameState Squad;
	local XGParamTag ParamTag;
	local bool bCanBoost, bCanAfford;
	local StrategyCost BoostInfiltrationCost;
	local array<StrategyCostScalar> CostScalars;
	
	bCanBoost = true;
	Squad =  GetInfiltratingSquad();
	BoostInfiltrationCost = Squad.GetBoostInfiltrationCost();
	CostScalars.Length = 0;
	bCanAfford = `XCOMHQ.CanAffordAllStrategyCosts(BoostInfiltrationCost, CostScalars);
	if (Squad.bHasBoostedInfiltration)
	{
		ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		ParamTag.StrValue0 = Squad.sSquadName;
		Reason = `XEXPAND.ExpandString(m_strAlreadyBoostedInfiltration);

		bCanBoost = false;
	}
	else if (!bCanAfford)
	{
		Reason = m_strInsufficentIntelForBoostInfiltration;

		bCanBoost = false;
	}

	return bCanBoost;
}

// CanLaunchInfiltration(out string Reason)
simulated function bool CanLaunchInfiltration(out string Reason)
{
	local Squad_XComGameState Squad;
	local XComGameState_MissionSite MissionState;
	local XGParamTag ParamTag;

	Squad =  GetInfiltratingSquad();
	MissionState = GetMission();

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	ParamTag.IntValue0 = Round(Squad.InfiltrationState.GetRequiredPctInfiltrationToLaunch(MissionState));
	Reason = `XEXPAND.ExpandString(m_strInsuffientInfiltrationToLaunch);

	return Squad.InfiltrationState.HasSufficientInfiltrationToStartMission(MissionState);
}

// GetInfiltrationString()
simulated function string GetInfiltrationString()
{
	local string InfiltrationString;
	local Squad_XComGameState InfiltratingSquad;
	local AlienActivity_XComGameState AlienActivity;
	local XComGameState_MissionSite MissionState;
	local XGParamTag ParamTag;
	local float TotalSeconds_Mission, TotalSeconds_Infiltration;
	local float TotalSeconds, TotalHours, TotalDays;
	local bool bExpiringMission, bCanFullyInfiltrate;
	local int AlertnessIndex, AlertModifier;

	InfiltratingSquad = GetInfiltratingSquad();
	MissionState = GetMission();
	AlienActivity = GetActivity();

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	ParamTag.IntValue0 = int(InfiltratingSquad.InfiltrationState.CurrentInfiltration * 100.0);
	
	bExpiringMission = MissionState.ExpirationDateTime.m_iYear < 2050;
	if(bCachedMustLaunch)
	{
		InfiltrationString = `XEXPAND.ExpandString(m_strInfiltrationStatusNonExpiring);
	}
	else if(bExpiringMission)
	{
		//determine if can fully infiltrate before mission expires
		TotalSeconds_Mission = AlienActivity.SecondsRemainingCurrentMission();
		TotalSeconds_Infiltration = InfiltratingSquad.InfiltrationState.GetSecondsRemainingToFullInfiltration();

		bCanFullyInfiltrate = (TotalSeconds_Infiltration < TotalSeconds_Mission) && (InfiltratingSquad.InfiltrationState.CurrentInfiltration < 1.0);
		if(bCanFullyInfiltrate)
		{
			TotalSeconds = TotalSeconds_Infiltration;
		}
		else
		{
			TotalSeconds = TotalSeconds_Mission;
		}
		TotalHours = int(TotalSeconds / 3600.0) % 24;
		TotalDays = TotalSeconds / 86400.0;
		ParamTag.IntValue1 = int(TotalDays);
		ParamTag.IntValue2 = int(TotalHours);

		if(bCanFullyInfiltrate && InfiltratingSquad.InfiltrationState.CurrentInfiltration < 1.0)
			InfiltrationString = `XEXPAND.ExpandString(m_strInfiltrationStatusExpiring);
		else
			InfiltrationString = `XEXPAND.ExpandString(m_strInfiltrationStatusMissionEnding);
	}
	else // mission does not expire
	{
		//ID 619 - allow non-expiring missions to show remaining time until 100% infiltration will be reached
		if (InfiltratingSquad.InfiltrationState.CurrentInfiltration < 1.0)
		{
			TotalSeconds = InfiltratingSquad.InfiltrationState.GetSecondsRemainingToFullInfiltration();
			TotalHours = int(TotalSeconds / 3600.0) % 24;
			TotalDays = TotalSeconds / 86400.0;
			ParamTag.IntValue1 = int(TotalDays);
			ParamTag.IntValue2 = int(TotalHours);
			InfiltrationString = `XEXPAND.ExpandString(m_strInfiltrationStatusExpiring);
		}
		else
		{
			InfiltrationString = `XEXPAND.ExpandString(m_strInfiltrationStatusNonExpiring);
		}
	}

	InfiltrationString $= "\n";

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	AlertModifier = InfiltratingSquad.InfiltrationState.GetAlertnessModifierForCurrentInfiltration(,, AlertnessIndex);
	ParamTag.StrValue0 = default.m_strAlertnessModifierDescriptions[AlertnessIndex];  
	if (false) // for debugging only !
		ParamTag.StrValue0 $= " (" $ AlertModifier $ ")";
	InfiltrationString $= `XEXPAND.ExpandString(m_strInfiltrationConsequence);
	
	if(bCachedMustLaunch)
	{
		InfiltrationString $= "\n";
		InfiltrationString $= m_strMustLaunchMission;
	}

	InfiltrationString = class'UIUtilities_Text'.static.AlignCenter(InfiltrationString);
	return InfiltrationString;
}

// OnLaunchClicked(UIButton button)
simulated public function OnLaunchClicked(UIButton button)
{
	local Squad_XComGameState InfiltratingSquad;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState UpdateState;
	
	InfiltratingSquad = GetInfiltratingSquad();
	if(InfiltratingSquad == none)
	{
		`REDSCREEN("UIMission_LWLaunchDelayedMission: No Infiltrating Squad");
		return;
	}
	// update the XComHQ mission ref first, so that it is available when setting the squad
	XComHQ = `XCOMHQ;
	UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update XComHQ for current mission being started");
	XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	XComHQ.MissionRef = InfiltratingSquad.InfiltrationState.CurrentMission;
	UpdateState.AddStateObject(XComHQ);
	`GAMERULES.SubmitGameState(UpdateState);

	InfiltratingSquad.SetSquadCrew();

	XComHQ.PauseProjectsForFlight();
	XComHQ.ResumeProjectsPostFlight();

	//TODO : handle black transition screen
	GetMission().ConfirmMission();
}

// OnBoostInfiltrationClicked(UIButton button)
simulated public function OnBoostInfiltrationClicked(UIButton button)
{
	local TDialogueBoxData kDialogData;
	local XGParamTag ParamTag;
	local Squad_XComGameState Squad;
	local StrategyCost BoostInfiltrationCost;
	local array<StrategyCostScalar> CostScalars;

	Squad =  GetInfiltratingSquad();
	BoostInfiltrationCost = Squad.GetBoostInfiltrationCost();
	CostScalars.Length = 0;

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	ParamTag.StrValue0 = class'UIUtilities_Strategy'.static.GetStrategyCostString(BoostInfiltrationCost, CostScalars);
	//ParamTag.IntValue0 = Squad.DefaultBoostInfiltrationCost[`CAMPAIGNDIFFICULTYSETTING];
	ParamTag.IntValue1 = Round((Squad.DefaultBoostInfiltrationFactor[`CAMPAIGNDIFFICULTYSETTING] - 1.0) * 100.0);

	PlaySound(SoundCue'SoundUI.HUDOnCue');

	kDialogData.eType = eDialog_Normal;
	kDialogData.strTitle = m_strBoostInfiltration;
	kDialogData.isModal = true;
	kDialogData.strText = `XEXPAND.ExpandString(m_strBoostInfiltrationDescription);
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	kDialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNO;
	kDialogData.fnCallback = ConfirmBoostInfiltrationCallback;

	Movie.Pres.UIRaiseDialog(kDialogData);
	return;

}

// ConfirmBoostInfiltrationCallback(EUIAction Action)
simulated function ConfirmBoostInfiltrationCallback(EUIAction Action)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local Squad_XComGameState Squad, UpdatedSquad;

	if(Action == eUIAction_Accept)
	{
		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding Boost Infiltration");
		Squad = GetInfiltratingSquad();
		UpdatedSquad = Squad_XComGameState(NewGameState.ModifyStateObject(class'Squad_XComGameState', Squad.ObjectID));
		NewGameState.AddStateObject(UpdatedSquad);
		UpdatedSquad.bHasBoostedInfiltration = true;
		UpdatedSquad.SpendBoostResource(NewGameState);

		if (NewGameState.GetNumGameStateObjects() > 0)
			`GAMERULES.SubmitGameState(NewGameState);
		else
			History.CleanupPendingGameState(NewGameState);

        // update the infiltration status, but don't pause the game. We're already in a popup and actually paused completely, and this
        // update "pause" actually resets to 'slow time' and causes a hang.
		UpdatedSquad.InfiltrationState.UpdateInfiltrationState(false);

		`ACTIVITYMGR.UpdateMissionData(GetMission()); // update units on the mission, since AlertLevel likely changed

		// rebuild the panels to display the updated status
		BuildMissionPanel();
		BuildOptionsPanel(); 
		class'UIUtilities_LWOTC'.static.BuildMissionInfoPanel(self, MissionRef);

		Movie.Pres.PlayUISound(eSUISound_SoldierPromotion);
	}
	else
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
}

// GetInfiltratingSquad()
simulated function Squad_XComGameState GetInfiltratingSquad()
{
	local SquadManager_XComGameState SquadMgr;
	
	SquadMgr = `SQUADMGR;
	if(SquadMgr == none)
	{
		`REDSCREEN("UIStrategyMapItem_Mission_LW: No SquadManager");
		return none;
	}
	return SquadMgr.Squads.GetSquadOnMission(MissionRef);
}

// OnViewSquadClicked(UIButton button)
simulated public function OnViewSquadClicked(UIButton button)
{
	local UIPersonnel_SquadBarracks kPersonnelList;
	local XComHQPresentationLayer HQPres;

	HQPres = `HQPRES;

	if (HQPres.ScreenStack.IsNotInStack(class'UIPersonnel_SquadBarracks'))
	{
		kPersonnelList = HQPres.Spawn(class'UIPersonnel_SquadBarracks', HQPres);
		kPersonnelList.bHideSelect = true;
		kPersonnelList.ExternalSelectedSquadRef = GetInfiltratingSquad().GetReference();
		HQPres.ScreenStack.Push(kPersonnelList);
	}
}

// OnAbortClicked(UIButton button)
simulated public function OnAbortClicked(UIButton button)
{
	local XComGameStateHistory History;
	local XComGameState_Skyranger SkyrangerState;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_GeoscapeEntity ThisEntity;
	local XComGameState_MissionSite Mission;
	local Squad_XComGameState Squad;

	if(CanBackOut())
	{
		Mission = GetMission();

		if(Mission.GetMissionSource().DataName != 'MissionSource_Final' || class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T5_M3_CompleteFinalMission') != eObjectiveState_InProgress)
		{
			//Restore the saved camera location
			XComHQPresentationLayer(Movie.Pres).CAMRestoreSavedLocation();
		}
		History = `XCOMHISTORY;
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Squad As On Board");
		SkyrangerState = XComGameState_Skyranger(NewGameState.ModifyStateObject(class'XComGameState_Skyranger', XComHQ.SkyrangerRef.ObjectID));
		SkyrangerState.SquadOnBoard = true;
		NewGameState.AddStateObject(SkyrangerState);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		if (Mission.Region == XComHQ.Region || Mission.Region.ObjectID == 0)
		{
			// move skyranger directly to mission
			ThisEntity = Mission;
			XComHQ.SetPendingPointOfTravel(ThisEntity);
		}
		else
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Store cross continent mission reference");
			XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
			NewGameState.AddStateObject(XComHQ);
			XComHQ.CrossContinentMission = MissionRef;
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

			// move skyranger to region first
			ThisEntity = Mission.GetWorldRegion();
			XComHQ.SetPendingPointOfTravel(ThisEntity);
		}

		if (bCachedMustLaunch)
		{
			Squad = `SQUADMGR.GetSquadOnMission(MissionRef);
			if (Squad != none)
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Mark Squad Abort Status");
				Squad = Squad_XComGameState(NewGameState.ModifyStateObject(class'Squad_XComGameState', Squad.ObjectID));
				NewGameState.AddStateObject(Squad);
				Squad.bCannotCancelAbort = true;
				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			}
		}

		bAborted = true;
		CloseScreen();
	}
}

// CloseScreen()
simulated function CloseScreen()
{
	local UIScreenStack ScreenStack;
	local UIStrategyMap StrategyMap;
	//local UIScreen aScreen;

	ScreenStack = `SCREENSTACK;
	//foreach ScreenStack.Screens(aScreen)
	//{
		//`LOG("Closing LaunchDelayedMission:" @ aScreen.Class);
	//}

	if(bCachedMustLaunch && !bAborted)
	{
		super.CloseScreen();
		StrategyMap = UIStrategyMap(ScreenStack.GetScreen(class'UIStrategyMap'));
		StrategyMap.CloseScreen();
	}
	else
	{
		super.CloseScreen();
	}
}

// OnRemoved()
// Called when screen is removed from Stack
simulated function OnRemoved()
{
	super.OnRemoved();

	//Restore the saved camera location
	if(GetMission().GetMissionSource().DataName != 'MissionSource_Final' || class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T5_M3_CompleteFinalMission') != eObjectiveState_InProgress)
	{
		HQPRES().CAMRestoreSavedLocation();
	}

	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();

	class'UIUtilities_Sound'.static.PlayCloseSound();
}

// GetActivity()
simulated function AlienActivity_XComGameState GetActivity()
{
	return `ACTIVITYMGR.FindAlienActivityByMission(GetMission());
}

// GetLibraryID()
simulated function Name GetLibraryID()
{
	return 'Alert_GuerrillaOpsBlades';
}


