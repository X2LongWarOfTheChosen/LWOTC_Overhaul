//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWSquadManager.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: This singleton object manages persistent squad information for the mod
//---------------------------------------------------------------------------------------
class SquadManager_XComGameState extends XComGameState_BaseObject config(LWOTC_Squads);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var localized string LabelBarracks_SquadManagement;
var localized string TooltipBarracks_SquadManagement;

var config int MAX_SQUAD_SIZE;
var config int MAX_FIRST_MISSION_SQUAD_SIZE;
var config array<name> NonInfiltrationMissions;
var config MissionIntroDefinition InfiltrationMissionIntroDefinition;

var SquadManager_XComGameState_Squads Squads;
var transient StateObjectReference LaunchingMissionSquad;
var bool bNeedsAttention;

// The name of the sub-menu for resistance management
const nmSquadManagementSubMenu = 'LW_SquadManagementMenu';

// GetSquadManager(optional bool AllowNULL = false)
static function SquadManager_XComGameState GetSquadManager(optional bool AllowNULL = false)
{
	return SquadManager_XComGameState(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'SquadManager_XComGameState', AllowNULL));
}

// CreateSquadManager(optional XComGameState StartState)
static function CreateSquadManager(optional XComGameState StartState)
{
	local SquadManager_XComGameState SquadMgr;
	local XComGameState NewGameState;

	//first check that there isn't already a singleton instance of the squad manager
	if(GetSquadManager(true) != none)
		return;

	if(StartState != none)
	{
		SquadMgr = SquadManager_XComGameState(StartState.CreateStateObject(class'SquadManager_XComGameState'));
		StartState.AddStateObject(SquadMgr);
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating LW Squad Manager Singleton");
		SquadMgr = SquadManager_XComGameState(NewGameState.CreateStateObject(class'SquadManager_XComGameState'));
		NewGameState.AddStateObject(SquadMgr);
		`XCOMHISTORY.AddGameStateToHistory(NewGameState);
	}
	SquadMgr.InitSquadManagerListeners();
}

// CreateFirstMissionSquad(XComGameState StartState)
// add the first mission squad to the StartState
static function CreateFirstMissionSquad(XComGameState StartState)
{
	local Squad_XComGameState NewSquad;
	local SquadManager_XComGameState StartSquadMgr;
	local XComGameState_HeadquartersXCom StartXComHQ;
	local XComGameState_MissionSite StartMission;

	foreach StartState.IterateByClassType(class'SquadManager_XComGameState', StartSquadMgr)
	{
		break;
	}
	foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', StartXComHQ)
	{
		break;
	}
	foreach StartState.IterateByClassType(class'XComGameState_MissionSite', StartMission)
	{
		break;
	}

	if (StartSquadMgr == none || StartXComHQ == none || StartMission == none)
	{
		return;
	}
	StartXComHQ.MissionRef = StartMission.GetReference();

	//create the first mission squad state
	NewSquad = Squad_XComGameState(StartState.CreateStateObject(class'Squad_XComGameState'));
	StartState.AddStateObject(NewSquad);

	StartSquadMgr.Squads.Squads.AddItem(NewSquad.GetReference());

	NewSquad.InitSquad(, false);
	NewSquad.Soldiers.SquadSoldiersOnMission = StartXComHQ.Squad;
	NewSquad.Soldiers.SquadSoldiers = StartXComHQ.Squad;
	NewSquad.InfiltrationState.CurrentMission = StartXComHQ.MissionRef;
	NewSquad.bOnMission = true;
	NewSquad.InfiltrationState.CurrentInfiltration = 1.0;
	NewSquad.InfiltrationState.CurrentEnemyAlertnessModifier = 0;
}

// IsValidInfiltrationMission(StateObjectReference MissionRef)
static function bool IsValidInfiltrationMission(StateObjectReference MissionRef)
{
	local GeneratedMissionData MissionData;

	MissionData = `XCOMHQ.GetGeneratedMissionData(MissionRef.ObjectID);

	return (default.NonInfiltrationMissions.Find(MissionData.Mission.MissionName) == -1);
}

// OnCreation( optional X2DataTemplate InitTemplate )
event OnCreation( optional X2DataTemplate InitTemplate )
{
	super.OnCreation(InitTemplate);
	Squads = new class'SquadManager_XComGameState_Squads';
	Squads.ParentObjectId = ObjectId;
}

// UpdateSquadPostMission(optional StateObjectReference MissionRef, optional bool bCompletedMission)
function UpdateSquadPostMission(optional StateObjectReference MissionRef, optional bool bCompletedMission)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local Squad_XComGameState SquadState, UpdatedSquadState;
	local XComGameState UpdateState;
	local SquadManager_XComGameState UpdatedSquadMgr;
	local StateObjectReference NullRef;

	if (MissionRef.ObjectID == 0)
	{
		XComHQ = `XCOMHQ;
		MissionRef = XComHQ.MissionRef;
	}

	SquadState = Squads.GetSquadOnMission(MissionRef);
	if(SquadState == none)
	{
		`REDSCREEN("SquadManager : UpdateSquadPostMission called with no squad on mission");
		return;
	}
	UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Post Mission Persistent Squad Cleanup");

	UpdatedSquadMgr = SquadManager_XComGameState(UpdateState.CreateStateObject(Class, ObjectID));
	UpdateState.AddStateObject(UpdatedSquadMgr);

	UpdatedSquadState = Squad_XComGameState(UpdateState.CreateStateObject(SquadState.Class, SquadState.ObjectID));
	UpdateState.AddStateObject(UpdatedSquadState);

	if (bCompletedMission)
		UpdatedSquadState.iNumMissions += 1;

	UpdatedSquadMgr.LaunchingMissionSquad = NullRef;
	UpdatedSquadState.Soldiers.PostMissionRevertSoldierStatus(UpdateState, UpdatedSquadMgr);
	UpdatedSquadState.ClearMission();
	`XCOMGAME.GameRuleset.SubmitGameState(UpdateState);

	if(SquadState.bTemporary)
	{
		Squads.RemoveSquad(SquadState.GetReference(), UpdateState);
	}
}

//--------------------- UI --------------------------

// SetupSquadManagerInterface()
// After beginning a game, set up the squad management interface.
function SetupSquadManagerInterface()
{
    EnableSquadManagementMenu();
}

// Enable the Squad Manager menu
function EnableSquadManagementMenu(optional bool forceAlert = false)
{
    local string AlertIcon;
    local UIAvengerShortcutSubMenuItem SubMenu;
    local UIAvengerShortcuts Shortcuts;

    if (NeedsAttention() || forceAlert)
    {
        AlertIcon = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_AttentionIcon, 20, 20, 0) $" ";
    }

    ShortCuts = `HQPRES.m_kAvengerHUD.Shortcuts;

    if (ShortCuts.FindSubMenu(eUIAvengerShortcutCat_Barracks, nmSquadManagementSubMenu, SubMenu))
    {
        // It already exists: just update the label to adjust the alert state (if necessary).
        SubMenu.Message.Label = AlertIcon $ LabelBarracks_SquadManagement;
        Shortcuts.UpdateSubMenu(eUIAvengerShortcutCat_Barracks, SubMenu);
    }
    else
    {
        SubMenu.Id = nmSquadManagementSubMenu;
        SubMenu.Message.Label = AlertIcon $ LabelBarracks_SquadManagement;
        SubMenu.Message.Description = TooltipBarracks_SquadManagement;
        SubMenu.Message.Urgency = eUIAvengerShortcutMsgUrgency_Low;
        SubMenu.Message.OnItemClicked = GoToSquadManagement;
        Shortcuts.AddSubMenu(eUIAvengerShortcutCat_Barracks, SubMenu);
    }
}

// GoToSquadManagement(optional StateObjectReference Facility)
simulated function GoToSquadManagement(optional StateObjectReference Facility)
{
    local XComHQPresentationLayer HQPres;
    local UIAvengerShortcutSubMenuItem SubMenu;
    local UIAvengerShortcuts Shortcuts;
	local UIPersonnel_SquadBarracks kPersonnelList;

    HQPres = `HQPRES;

    // Set the squad manager game state as not needing attention.
    SetSquadMgrNeedsAttention(false);

    // Clear the attention label from the submenu item.
    ShortCuts = HQPres.m_kAvengerHUD.Shortcuts;
    Shortcuts.FindSubMenu(eUIAvengerShortcutCat_Barracks, nmSquadManagementSubMenu, SubMenu);
    SubMenu.Message.Label = LabelBarracks_SquadManagement;
    Shortcuts.UpdateSubMenu(eUIAvengerShortcutCat_Barracks, SubMenu);

	if (HQPres.ScreenStack.IsNotInStack(class'UIPersonnel_SquadBarracks'))
	{
		kPersonnelList = HQPres.Spawn(class'UIPersonnel_SquadBarracks', HQPres);
		kPersonnelList.onSelectedDelegate = OnPersonnelSelected;
		HQPres.ScreenStack.Push(kPersonnelList);
	}
}

// OnPersonnelSelected(StateObjectReference selectedUnitRef)
simulated function OnPersonnelSelected(StateObjectReference selectedUnitRef)
{
	//add any logic here for selecting someone in the squad barracks
}

// SetSquadMgrNeedsAttention(bool Enable)
function SetSquadMgrNeedsAttention(bool Enable)
{
    local XComGameState NewGameState;
    local XComGameState_FacilityXCom BarracksFacility;
    local SquadManager_XComGameState NewManager;
    
    if (Enable != NeedsAttention())
    {
        // Set the rebel outpost manager as needing attention (or not)
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set squad manager needs attention");
        NewManager = SquadManager_XComGameState(NewGameState.CreateStateObject(class'SquadManager_XComGameState', self.ObjectID));
        NewGameState.AddStateObject(NewManager);
        if (Enable)
        {
            NewManager.SetNeedsAttention();
        }
        else
        {
            NewManager.ClearNeedsAttention();
        }

        // And update the CIC state to also require attention if necessary.
        // We don't need to clear it as clearing happens automatically when the 
        // facility is selected.
        BarracksFacility = `XCOMHQ.GetFacilityByName('Hangar');
        if (Enable && !BarracksFacility.NeedsAttention())
        {
            BarracksFacility = XComGameState_FacilityXCom(NewGameState.CreateStateObject(class'XComGameState_FacilityXCom', BarracksFacility.ObjectID));
            BarracksFacility.TriggerNeedsAttention();
            NewGameState.AddStateObject(BarracksFacility);
        }

        `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
    }
}

// NeedsAttention()
function bool NeedsAttention()
{
    return bNeedsAttention;
}

// SetNeedsAttention()
function SetNeedsAttention()
{
    bNeedsAttention = true;
}

// ClearNeedsAttention()
function ClearNeedsAttention()
{
    bNeedsAttention = false;
}

// GetSquadSelect()
simulated function UISquadSelect GetSquadSelect()
{
	local UIScreenStack ScreenStack;
	local int Index;
	ScreenStack = `SCREENSTACK;
	for( Index = 0; Index < ScreenStack.Screens.Length;  ++Index)
	{
		if(UISquadSelect(ScreenStack.Screens[Index]) != none )
			return UISquadSelect(ScreenStack.Screens[Index]);
	}
	return none; 
}

//--------------- EVENT HANDLING ------------------

// InitSquadManagerListeners()
function InitSquadManagerListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	//class'XComGameState_LWToolboxPrototype'.static.SetMaxSquadSize(default.MAX_SQUAD_SIZE);

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	EventMgr.RegisterForEvent(ThisObj, 'OnValidateDeployableSoldiers', ValidateDeployableSoldiersForSquads,,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'OnSoldierListItemUpdateDisabled', SetDisabledSquadListItems,,,,true);  // hook to disable selecting soldiers if they are in another squad
	EventMgr.RegisterForEvent(ThisObj, 'OnUpdateSquadSelectSoldiers', ConfigureSquadOnEnterSquadSelect, ELD_Immediate,,,true); // hook to set initial squad/soldiers on entering squad select
	EventMgr.RegisterForEvent(ThisObj, 'OnDismissSoldier', DismissSoldierFromSquad, ELD_Immediate,,,true); // allow clearing of units from existing squads when dismissed

}

// ValidateDeployableSoldiersForSquads(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn ValidateDeployableSoldiersForSquads(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local int idx;
	local XComLWTuple DeployableSoldiers;
	local UISquadSelect SquadSelect;
	local XComGameState_Unit UnitState;
	local Squad_XComGameState CurrentSquad, TestUnitSquad;

	DeployableSoldiers = XComLWTuple(EventData);
	if(DeployableSoldiers == none)
	{
		`REDSCREEN("Validate Deployable Soldiers event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	SquadSelect = UISquadSelect(EventSource);
	if(SquadSelect == none)
	{
		`REDSCREEN("Validate Deployable Soldiers event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}

	if(DeployableSoldiers.Id != 'DeployableSoldiers')
		return ELR_NoInterrupt;

	if(LaunchingMissionSquad.ObjectID > 0)
	{
		CurrentSquad = Squad_XComGameState(`XCOMHISTORY.GetGameStateForObjectID(LaunchingMissionSquad.ObjectID));
	}
	for(idx = DeployableSoldiers.Data.Length - 1; idx >= 0; idx--)
	{
		if(DeployableSoldiers.Data[idx].kind == XComLWTVObject)
		{
			UnitState = XComGameState_Unit(DeployableSoldiers.Data[idx].o);
			if(UnitState != none)
			{
				//disallow if actively on a mission
				if(class'Squad_Static_Soldiers_Helper'.static.IsUnitOnMission(UnitState))
				{
					DeployableSoldiers.Data.Remove(idx, 1);
				}
				//disallow if unit is in a different squad
				if (Squads.UnitIsInAnySquad(UnitState.GetReference(), TestUnitSquad))
				{
					if (TestUnitSquad != none && TestUnitSquad.ObjectID != CurrentSquad.ObjectID)
					{
						DeployableSoldiers.Data.Remove(idx, 1);
					}
				}
			}
		}
	}
	return ELR_NoInterrupt;
}

// SetDisabledSquadListItems(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn SetDisabledSquadListItems(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local UIPersonnel_ListItem ListItem;
	local Squad_XComGameState Squad;
    local XComGameState_Unit UnitState;
	local bool bInSquadEdit;

	//only do this for squadselect
	if(GetSquadSelect() == none)
		return ELR_NoInterrupt;

	ListItem = UIPersonnel_ListItem(EventData);
	if(ListItem == none)
	{
		`REDSCREEN("Set Disabled Squad List Items event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	bInSquadEdit = `SCREENSTACK.IsInStack(class'UIPersonnel_SquadBarracks');

	if(ListItem.UnitRef.ObjectID > 0)
	{
		if (LaunchingMissionSquad.ObjectID > 0)
			Squad = Squad_XComGameState(`XCOMHISTORY.GetGameStateForObjectID(LaunchingMissionSquad.ObjectID));

        UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ListItem.UnitRef.ObjectID));
		if(bInSquadEdit && Squads.UnitIsInAnySquad(ListItem.UnitRef) && (Squad == none || !Squad.Soldiers.UnitIsInSquad(ListItem.UnitRef)))
		{
			ListItem.SetDisabled(true); // can now select soldiers from other squads, but will generate pop-up warning and remove them
		}
        else 
		if (class'Squad_Static_Soldiers_Helper'.static.IsUnitOnMission(UnitState))
        {
		    ListItem.SetDisabled(true);
		}
            
	}
	return ELR_NoInterrupt;
}

// ConfigureSquadOnEnterSquadSelect(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// selects a squad that matches a persistent squad 
function EventListenerReturn ConfigureSquadOnEnterSquadSelect(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComGameStateHistory				History;
	//local XComGameState						NewGameState;
	local XComGameState_HeadquartersXCom	XComHQ, UpdatedXComHQ;
	local UISquadSelect						SquadSelect;
	local SquadManager_XComGameState		UpdatedSquadMgr;
	local StateObjectReference				SquadRef;
	local Squad_XComGameState				SquadState;
	local bool								bInSquadEdit;
	local GeneratedMissionData				MissionData;
	local int								MaxSoldiersInSquad;
	local XComGameState_MissionSite			MissionSite;

	`LWTRACE("ConfigureSquadOnEnterSquadSelect : Starting listener.");
	XComHQ = XComGameState_HeadquartersXCom(EventData);
	if(XComHQ == none)
	{
		`REDSCREEN("OnUpdateSquadSelectSoldiers event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	`LWTRACE("ConfigureSquadOnEnterSquadSelect : Parsed XComHQ.");

	SquadSelect = GetSquadSelect();
	if(SquadSelect == none)
	{
		`REDSCREEN("ConfigureSquadOnEnterSquadSelect event triggered with UISquadSelect not in screenstack.");
		return ELR_NoInterrupt;
	}
	`LWTRACE("ConfigureSquadOnEnterSquadSelect : RetrievedSquadSelect.");

	History = `XCOMHISTORY;
	//NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Squad consistent with persistent squad");

	bInSquadEdit = `SCREENSTACK.IsInStack(class'UIPersonnel_SquadBarracks');
	if (bInSquadEdit)
		return ELR_NoInterrupt;

	MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);

	if (LaunchingMissionSquad.ObjectID > 0)
		SquadRef = LaunchingMissionSquad;
	else	
		SquadRef = Squads.GetBestSquad();

	UpdatedSquadMgr = SquadManager_XComGameState(NewGameState.CreateStateObject(Class, ObjectID));
	NewGameState.AddStateObject(UpdatedSquadMgr);

	if(SquadRef.ObjectID > 0)
		SquadState = Squad_XComGameState(History.GetGameStateForObjectID(SquadRef.ObjectID));
	else
		SquadState = UpdatedSquadMgr.Squads.CreateEmptySquad(,, NewGamestate, true);  // create new, empty, temporary squad

	UpdatedSquadMgr.LaunchingMissionSquad = SquadState.GetReference();

	UpdatedXComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(XComHQ.Class, XComHQ.ObjectID));
	NewGameState.AddStateObject(UpdatedXComHQ);
	UpdatedXComHQ.Squad = SquadState.Soldiers.GetDeployableSoldierRefs(MissionData.Mission.AllowDeployWoundedUnits); 

	MissionSite = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));
	MaxSoldiersInSquad = class'X2StrategyGameRulesetDataStructures'.static.GetMaxSoldiersAllowedOnMission(MissionSite);
	if (UpdatedXComHQ.Squad.Length > MaxSoldiersInSquad)
		UpdatedXComHQ.Squad.Length = MaxSoldiersInSquad;

	//if (NewGameState.GetNumGameStateObjects() > 0)
		//`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	//else
		//History.CleanupPendingGameState(NewGameState);

	return ELR_NoInterrupt;
}

// DismissSoldierFromSquad(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn DismissSoldierFromSquad(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_Unit DismissedUnit;
	local UIArmory_MainMenu MainMenu;
	local StateObjectReference DismissedUnitRef;
	local Squad_XComGameState SquadState, UpdatedSquadState;
	local XComGameState NewGameState;
	local StateObjectReference SquadRef;

	DismissedUnit = XComGameState_Unit(EventData);
	if(DismissedUnit == none)
	{
		`REDSCREEN("Dismiss Soldier From Squad listener triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	MainMenu = UIArmory_MainMenu(EventSource);
	if(MainMenu == none)
	{
		`REDSCREEN("Dismiss Soldier From Squad listener triggered with invalid source data.");
		return ELR_NoInterrupt;
	}

	DismissedUnitRef = DismissedUnit.GetReference();

	foreach Squads.Squads(SquadRef)
	{
		SquadState = Squads.GetSquad(SquadRef);
		if(SquadState.Soldiers.UnitIsInSquad(DismissedUnitRef))
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Dismissed Soldier from Squad");
			UpdatedSquadState = Squad_XComGameState(NewGameState.CreateStateObject(class'Squad_XComGameState', SquadState.ObjectID));
			NewGameState.AddStateObject(UpdatedSquadState);
			UpdatedSquadState.Soldiers.RemoveSoldier(DismissedUnitRef);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
	}
	return ELR_NoInterrupt;
}