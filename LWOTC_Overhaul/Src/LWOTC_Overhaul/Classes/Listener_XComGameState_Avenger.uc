class Listener_XComGameState_Avenger extends Object;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var localized string m_strOnLiaisonMission;
var localized string m_strSoldierInfiltrating;
var localized string CannotModifyOnMissionSoldierTooltip;
var localized string strUnitAlreadyInSquadStatus;
var localized string strUnitInSquadStatus;
var localized string strRankTooLow;

var int OverrideNumUtilitySlots;

defaultproperties
{
	OverrideNumUtilitySlots = 3;
}

// InitListeners()
function InitListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	EventMgr.RegisterForEvent(ThisObj, 'OnUpdateSquadSelect_ListItem', UpdateSquadSelectUtilitySlots,,,,true);
	//auto-fill squad
	EventMgr.RegisterForEvent(ThisObj, 'OnCheckAutoFillSquad', DisableAutoFillSquad,,,,true);
	//override disable flags
	EventMgr.RegisterForEvent(ThisObj, 'OverrideSquadSelectDisableFlags', OverrideSquadSelectDisableFlags,,,,true);
	//OnMission status in UIPersonnel
	EventMgr.RegisterForEvent(ThisObj, 'OverrideGetPersonnelStatusSeparate', OverrideGetPersonnelStatusSeparate,, 40,,true); // slight higher priority so it takes precedence over officer status
	//Can Unequip items
	EventMgr.RegisterForEvent(ThisObj, 'OverrideItemCanBeUnequipped', OverrideItemCanBeUnequipped,,,,true);
	// Armory Main Menu - disable buttons for On-Mission soldiers
	EventMgr.RegisterForEvent(ThisObj, 'OnArmoryMainMenuUpdate', UpdateArmoryMainMenuItems, ELD_Immediate,,,true);
	//Help for some busted objective triggers
	EventMgr.RegisterForEvent(ThisObj, 'OnGeoscapeEntry', OnGeoscapeEntry, ELD_Immediate,,, true);
	// listeners for weapon mod stripping
	EventMgr.RegisterForEvent(ThisObj, 'OnCheckBuildItemsNavHelp', AddSquadSelectStripWeaponsButton, ELD_Immediate);
	EventMgr.RegisterForEvent(ThisObj, 'ArmoryLoadout_PostUpdateNavHelp', AddArmoryStripWeaponsButton, ELD_Immediate);
    // Async rebel photographs
    // EventMgr.RegisterForEvent(ThisObj, 'RefreshCrewPhotographs', OnRefreshCrewPhotographs, ELD_Immediate,,, true);
}

// UpdateSquadSelectUtilitySlots(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn UpdateSquadSelectUtilitySlots(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	//reference to the list item
	local UISquadSelect_ListItem ListItem;

	//variables from list item Update
	//local bool bCanPromote;
	//local string ClassStr;
	local int i, NumUtilitySlots, UtilityItemIndex;
	local float UtilityItemWidth, UtilityItemHeight;
	local UISquadSelect_UtilityItem UtilityItem;
	local array<XComGameState_Item> EquippedItems;
	local XComGameState_Unit Unit;
	//local XComGameState_Item PrimaryWeapon, HeavyWeapon;
	//local X2WeaponTemplate PrimaryWeaponTemplate, HeavyWeaponTemplate;
	//local X2AbilityTemplate HeavyWeaponAbilityTemplate;
	//local X2AbilityTemplateManager AbilityTemplateManager;

	ListItem = UISquadSelect_ListItem(EventSource);

	if(ListItem == none)
		return ELR_NoInterrupt;

	if(ListItem.bDisabled)
		return ELR_NoInterrupt;

	// -------------------------------------------------------------------------------------------------------------

	// empty slot
	if(ListItem.GetUnitRef().ObjectID <= 0)
		return ELR_NoInterrupt;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
	if (Unit == none)
		return ELR_NoInterrupt;

	switch (Unit.GetMyTemplateName())
	{
		case 'Soldier':
			NumUtilitySlots = OverrideNumUtilitySlots;
			break;
		default:
			return ELR_NoInterrupt;
			break;
	}

	if(Unit.HasGrenadePocket()) NumUtilitySlots++;
	if(Unit.HasAmmoPocket()) NumUtilitySlots++;

	UtilityItemWidth = (ListItem.UtilitySlots.GetTotalWidth() - (ListItem.UtilitySlots.ItemPadding * (NumUtilitySlots - 1))) / NumUtilitySlots;
	UtilityItemHeight = ListItem.UtilitySlots.Height;

	//if(ListItem.UtilitySlots.ItemCount != NumUtilitySlots)
		ListItem.UtilitySlots.ClearItems();

	for(i = 0; i < NumUtilitySlots; ++i)
	{
		if(i >= ListItem.UtilitySlots.ItemCount)
		{
			UtilityItem = UISquadSelect_UtilityItem(ListItem.UtilitySlots.CreateItem(class'UISquadSelect_UtilityItem').InitPanel());
			UtilityItem.SetSize(UtilityItemWidth, UtilityItemHeight);
			UtilityItem.CannotEditSlots = ListItem.CannotEditSlots;
			ListItem.UtilitySlots.OnItemSizeChanged(UtilityItem);
		}
	}

	UtilityItemIndex = 0;

	EquippedItems = class'UIUtilities_Strategy'.static.GetEquippedItemsInSlot(Unit, eInvSlot_Utility);

	UtilityItem = UISquadSelect_UtilityItem(ListItem.UtilitySlots.GetItem(UtilityItemIndex++));
	UtilityItem.SetAvailable(EquippedItems.Length > 0 ? EquippedItems[0] : none, eInvSlot_Utility, 0, NumUtilitySlots);

	if(class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M5_EquipMedikit') == eObjectiveState_InProgress)
	{
		// spawn the attention icon externally so it draws on top of the button and image
		ListItem.Spawn(class'UIPanel', UtilityItem).InitPanel('attentionIconMC', class'UIUtilities_Controls'.const.MC_AttentionIcon)
		.SetPosition(2, 4)
		.SetSize(70, 70); //the animated rings count as part of the size.
	} else if(ListItem.GetChildByName('attentionIconMC', false) != none) {
		ListItem.GetChildByName('attentionIconMC').Remove();
	}

	UtilityItem = UISquadSelect_UtilityItem(ListItem.UtilitySlots.GetItem(UtilityItemIndex++));
	UtilityItem.SetAvailable(EquippedItems.Length > 1 ? EquippedItems[1] : none, eInvSlot_Utility, 1, NumUtilitySlots);

	UtilityItem = UISquadSelect_UtilityItem(ListItem.UtilitySlots.GetItem(UtilityItemIndex++));
	UtilityItem.SetAvailable(EquippedItems.Length > 2 ? EquippedItems[2] : none, eInvSlot_Utility, 2, NumUtilitySlots);

	if(Unit.HasGrenadePocket())
	{
		UtilityItem = UISquadSelect_UtilityItem(ListItem.UtilitySlots.GetItem(UtilityItemIndex++));
		EquippedItems = class'UIUtilities_Strategy'.static.GetEquippedItemsInSlot(Unit, eInvSlot_GrenadePocket);
		UtilityItem.SetAvailable(EquippedItems.Length > 0 ? EquippedItems[0] : none, eInvSlot_GrenadePocket, 0, NumUtilitySlots);
	}

	if(Unit.HasAmmoPocket())
	{
		UtilityItem = UISquadSelect_UtilityItem(ListItem.UtilitySlots.GetItem(UtilityItemIndex++));
		EquippedItems = class'UIUtilities_Strategy'.static.GetEquippedItemsInSlot(Unit, eInvSlot_AmmoPocket);
		UtilityItem.SetAvailable(EquippedItems.Length > 0 ? EquippedItems[0] : none, eInvSlot_AmmoPocket, 0, NumUtilitySlots);
	}

	return ELR_NoInterrupt;
}

// DisableAutoFillSquad(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// disable auto-fill mechanism in UISquadSelect
function EventListenerReturn DisableAutoFillSquad(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple			OverrideTuple;
	local UISquadSelect			SquadSelect;

	`LWTRACE("DisableAutoFillSquad : Starting listener.");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("DisableAutoFillSquad event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	`LWTRACE("DisableAutoFillSquad : Parsed XComLWTuple.");

	SquadSelect = UISquadSelect(EventSource);
	if(SquadSelect == none)
	{
		`REDSCREEN("DisableAutoFillSquad event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}
	`LWTRACE("DisableAutoFillSquad : EventSource valid.");

	if(OverrideTuple.Id != 'OnCheckAutoFillSquad')
		return ELR_NoInterrupt;

	OverrideTuple.Data[0].b = false;

	`LWTRACE("DisableAutoFillSquad Override : working. Set to false.");

	return ELR_NoInterrupt;
}

// OverrideSquadSelectDisableFlags(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// add restrictions on when units can be edited, have loadout changed, or dismissed, based on status
function EventListenerReturn OverrideSquadSelectDisableFlags(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple			OverrideTuple;
	local UISquadSelect			SquadSelect;
	local XComGameState_Unit	UnitState;
	local XComLWTValue			Value;

	`LWTRACE("DisableAutoFillSquad : Starting listener.");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OverrideSquadSelectDisableFlags event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	SquadSelect = UISquadSelect(EventSource);
	if(SquadSelect == none)
	{
		`REDSCREEN("OverrideSquadSelectDisableFlags event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}

	if(OverrideTuple.Id != 'OverrideSquadSelectDisableFlags')
		return ELR_NoInterrupt;

	if (class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M3_WelcomeToHQ') == eObjectiveState_InProgress)
	{
		//retain this just in case
		OverrideTuple.Data[0].b = true; // bDisableEdit
		OverrideTuple.Data[1].b = true; // bDisableDismiss
		OverrideTuple.Data[2].b = false; // bDisableLoadout
		return ELR_NoInterrupt;
	}
	UnitState = XComGameState_Unit(OverrideTuple.Data[3].o);
	if (UnitState == none) { return ELR_NoInterrupt; }

	if (class'LWOTC_DLCHelpers'.static.IsUnitOnMission(UnitState))
	{
		OverrideTuple.Data[0].b = false; // bDisableEdit
		OverrideTuple.Data[1].b = true; // bDisableDismiss
		OverrideTuple.Data[2].b = true; // bDisableLoadout

		Value.Kind = XComLWTVInt;
		Value.i = eInvSlot_Utility;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_Armor;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_GrenadePocket;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_GrenadePocket;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_PrimaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_SecondaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_HeavyWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_TertiaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_QuaternaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_QuinaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_SenaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		Value.i = eInvSlot_SeptenaryWeapon;
		OverrideTuple.Data.AddItem(Value);

		`LWTRACE("OverrideSquadSelectDisableFlags : Disabling Dismiss/Loadout for Status OnMission soldier");
	}

	`LWTRACE("OverrideSquadSelectDisableFlags : Reached end of event handler.");

	return ELR_NoInterrupt;
}

// OverrideGetPersonnelStatusSeparate(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// updates status info for soldiers with mission and squad info
function EventListenerReturn OverrideGetPersonnelStatusSeparate(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local string				Status, TimeLabel;
	local int					TimeNum, TextState;
	local XComLWTuple			OverrideTuple;
	local XComGameState_Unit	Unit;
    // local XComGameState_LWOutpostManager OutpostMgr;
    // local XComGameState_WorldRegion WorldRegion;
	local bool bUpdateStrings;
	local Squad_XComGameState Squad;
	local SquadManager_XComGameState SquadMgr;

	//`LWTRACE("OverrideGetPersonnelStatusSeparate : Starting listener.");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OverrideGetPersonnelStatusSeparate event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//`LWTRACE("OverrideGetPersonnelStatusSeparate : Parsed XComLWTuple.");

	Unit = XComGameState_Unit(EventSource);
	if(Unit == none)
	{
		`REDSCREEN("OverrideGetPersonnelStatusSeparate event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}
	//`LWTRACE("OverrideGetPersonnelStatusSeparate : EventSource valid.");

	if(OverrideTuple.Id != 'OverrideGetPersonnelStatusSeparate')
		return ELR_NoInterrupt;

	if(class'LWOTC_DLCHelpers'.static.IsUnitOnMission(Unit))
	{
        // On-mission: This could mean they're infiltrating, or they could be a liaison.
		/*
        OutpostMgr = `LWOUTPOSTMGR;
        if (OutpostMgr.IsUnitAHavenLiaison(Unit.GetReference()))
        {
            Status = default.m_strOnLiaisonMission;
            WorldRegion = OutpostMgr.GetRegionForLiaison(Unit.GetReference());
            Status @= "-" @ WorldRegion.GetDisplayName();
            // Abuse the time label to show what region they're in
            TimeLabel = "";
            TimeNum = 0;
            TextState = eUIState_Bad;
        }
        else
        {
		*/
		    Status = default.m_strSoldierInfiltrating;
		    TimeLabel = "";  // TODO: Update with mission time
		    TimeNum = 0;
		    TextState = eUIState_Bad;
       // }
	   bUpdateStrings = true;
	}
	else if (GetScreenOrChild('UIPersonnel_SquadBarracks') == none)
	{
		SquadMgr = `SQUADMGR;
		if (`XCOMHQ.IsUnitInSquad(Unit.GetReference()) && GetScreenOrChild('UISquadSelect') != none)
		{
			Status = class'UIUtilities_Strategy'.default.m_strOnMissionStatus;
			TextState = eUIState_Highlight;
		}
		else if (SquadMgr != none && SquadMgr.Squads.UnitIsInAnySquad(Unit.GetReference(), Squad))
		{
			if (SquadMgr.LaunchingMissionSquad.ObjectID != Squad.ObjectID)
			{
				if (Unit.GetStatus() != eStatus_Healing && Unit.GetStatus() != eStatus_Training)
				{
					if (GetScreenOrChild('UISquadSelect') != none)
					{
						Status = default.strUnitAlreadyInSquadStatus;
						TextState = eUIState_Warning;
					}
					else if (GetScreenOrChild('UIPersonnel_Liaison') != none)
					{
						Status = default.strUnitInSquadStatus;
						TextState = eUIState_Warning;
					}
				}
			}
		
		}
		/*
		else if (Unit.GetRank() < class'XComGameState_LWOutpost'.default.REQUIRED_RANK_FOR_LIAISON_DUTY)
		{
			if (GetScreenOrChild('UIPersonnel_Liaison') != none)
			{
				Status = default.strRankTooLow;
				TextState = eUIState_Bad;
			}
		}
		*/
		if (Status != "")
		{
			TimeLabel = "";  // TODO: Update with mission time
			TimeNum = 0;
			bUpdateStrings = true;
		}
	}

	if (bUpdateStrings)
	{
		OverrideTuple.Data.Add(4-OverrideTuple.Data.Length);
		OverrideTuple.Data[0].s = Status;
		OverrideTuple.Data[0].kind = XComLWTVString;

		OverrideTuple.Data[1].s = TimeLabel;
		OverrideTuple.Data[1].kind = XComLWTVString;

		OverrideTuple.Data[2].i = TimeNum;
		OverrideTuple.Data[2].kind = XComLWTVInt;

		OverrideTuple.Data[3].i = TextState;
		OverrideTuple.Data[3].kind = XComLWTVInt;
	}
	return ELR_NoInterrupt;
}

// GetScreenOrChild(name ScreenType)
function UIScreen GetScreenOrChild(name ScreenType)
{
	local UIScreenStack ScreenStack;
	local int Index;
	ScreenStack = `SCREENSTACK;
	for( Index = 0; Index < ScreenStack.Screens.Length;  ++Index)
	{
		if(ScreenStack.Screens[Index].IsA(ScreenType))
			return ScreenStack.Screens[Index];
	}
	return none;
}

// OverrideItemCanBeUnequipped(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// allows overriding of unequipping items, allowing even infinite utility slot items to be unequipped
function EventListenerReturn OverrideItemCanBeUnequipped(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple			OverrideTuple;
	local XComGameState_Item	ItemState;
	local X2EquipmentTemplate	EquipmentTemplate;

	`LWTRACE("OverrideItemCanBeUnequipped : Starting listener.");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OverrideItemCanBeUnequipped event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	`LWTRACE("OverrideItemCanBeUnequipped : Parsed XComLWTuple.");

	ItemState = XComGameState_Item(EventSource);
	if(ItemState == none)
	{
		`REDSCREEN("OverrideItemCanBeUnequipped event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}
	`LWTRACE("OverrideItemCanBeUnequipped : EventSource valid.");

	if(OverrideTuple.Id != 'OverrideItemCanBeUnequipped')
		return ELR_NoInterrupt;

	//check if item is a utility slot item
	EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
	if(EquipmentTemplate != none)
	{
		if(EquipmentTemplate.InventorySlot == eInvSlot_Utility)
		{
			OverrideTuple.Data[0].b = true;  // item can be unequipped
		}
	}

	return ELR_NoInterrupt;
}

// UpdateArmoryMainMenuItems(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn UpdateArmoryMainMenuItems(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local UIList List;
	local XComGameState_Unit Unit;
	local UIArmory_MainMenu ArmoryMainMenu;
	//local array<string> ButtonsToDisableStrings;
	local array<name> ButtonToDisableMCNames;
	local int idx;
	local UIListItemString CurrentButton;
	local XComGameState_StaffSlot StaffSlotState;

	`LOG("AWCPack / UpdateArmoryMainMenuItems: Starting.");

	List = UIList(EventData);
	if(List == none)
	{
		`REDSCREEN("Update Armory MainMenu event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	ArmoryMainMenu = UIArmory_MainMenu(EventSource);
	if(ArmoryMainMenu == none)
	{
		`REDSCREEN("Update Armory MainMenu event triggered with invalid event source.");
		return ELR_NoInterrupt;
	}

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ArmoryMainMenu.UnitReference.ObjectID));
	if (class'LWOTC_DLCHelpers'.static.IsUnitOnMission(Unit))
	{
		//ButtonToDisableMCNames.AddItem('ArmoryMainMenu_LoadoutButton'); // adding ability to view loadout, but not modifiy it

		// If this unit isn't a haven adviser, or is a haven adviser that is locked, disable loadout
		// changing. (Allow changing equipment on haven advisers in regions where you can change the
		// adviser to save some clicks).
		/*
		if (!`LWOUTPOSTMGR.IsUnitAHavenLiaison(Unit.GetReference()) ||
			`LWOUTPOSTMGR.IsUnitALockedHavenLiaison(Unit.GetReference()))
		{
			ButtonToDisableMCNames.AddItem('ArmoryMainMenu_PCSButton');
			ButtonToDisableMCNames.AddItem('ArmoryMainMenu_WeaponUpgradeButton');

			//update the Loadout button handler to one that locks all of the items
			CurrentButton = FindButton(0, 'ArmoryMainMenu_LoadoutButton', ArmoryMainMenu);
			CurrentButton.ButtonBG.OnClickedDelegate = OnLoadoutLocked;
		}
		*/

		// Dismiss is still disabled for all on-mission units, including liaisons.
		ButtonToDisableMCNames.AddItem('ArmoryMainMenu_DismissButton');


		// -------------------------------------------------------------------------------
		// Disable Buttons:
		for (idx = 0; idx < ButtonToDisableMCNames.Length; idx++)
		{
			CurrentButton = FindButton(idx, ButtonToDisableMCNames[idx], ArmoryMainMenu);
			if(CurrentButton != none)
			{
				CurrentButton.SetDisabled(true, default.CannotModifyOnMissionSoldierTooltip);
			}
		}

		return ELR_NoInterrupt;
	}
	switch(Unit.GetStatus())
	{
		case eStatus_PsiTraining:
		case eStatus_PsiTesting:
		case eStatus_Training:
			CurrentButton = FindButton(idx, 'ArmoryMainMenu_DismissButton', ArmoryMainMenu);
			if (CurrentButton != none)
			{
				StaffSlotState = Unit.GetStaffSlot();
				if (StaffSlotState != none)
				{
					CurrentButton.SetDisabled(true, StaffSlotState.GetBonusDisplayString());
				}
				else
				{
					CurrentButton.SetDisabled(true, "");
				}
			}
			break;
		default:
			break;
	}
	return ELR_NoInterrupt;
}

// OnLoadoutLocked(UIButton kButton)
simulated function OnLoadoutLocked(UIButton kButton)
{
	local XComHQPresentationLayer HQPres;
	local array<EInventorySlot> CannotEditSlots;
	local UIArmory_MainMenu MainMenu;

	CannotEditSlots.AddItem(eInvSlot_Utility);
	CannotEditSlots.AddItem(eInvSlot_Armor);
	CannotEditSlots.AddItem(eInvSlot_GrenadePocket);
	CannotEditSlots.AddItem(eInvSlot_GrenadePocket);
	CannotEditSlots.AddItem(eInvSlot_PrimaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_SecondaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_HeavyWeapon);
	CannotEditSlots.AddItem(eInvSlot_TertiaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_QuaternaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_QuinaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_SenaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_SeptenaryWeapon);
	CannotEditSlots.AddItem(eInvSlot_AmmoPocket);

	MainMenu = UIArmory_MainMenu(GetScreenOrChild('UIArmory_MainMenu'));
	if (MainMenu == none) { return; }

	if( UIListItemString(kButton.ParentPanel) != none && UIListItemString(kButton.ParentPanel).bDisabled )
	{
		`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuClickNegative");
		return;
	}

	HQPres = `HQPRES;
	if( HQPres != none )
		HQPres.UIArmory_Loadout(MainMenu.UnitReference, CannotEditSlots);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}

// FindButton(int DefaultIdx, name ButtonName, UIArmory_MainMenu MainMenu)
function UIListItemString FindButton(int DefaultIdx, name ButtonName, UIArmory_MainMenu MainMenu)
{
	if(ButtonName == '')
		return none;

	return UIListItemString(MainMenu.List.GetChildByName(ButtonName, false));
}

// OnGeoscapeEntry(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// this function cleans up some weird objective states by firing specific events
function EventListenerReturn OnGeoscapeEntry(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_MissionSite	MissionState;

	if (`XCOMHQ.GetObjectiveStatus('T2_M1_S1_ResearchResistanceComms') <= eObjectiveState_InProgress)
	{
		if (`XCOMHQ.IsTechResearched ('ResistanceCommunications'))
		{
			foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_MissionSite', MissionState)
			{
				if (MissionState.GetMissionSource().DataName == 'MissionSource_Blacksite')
				{
					`XEVENTMGR.TriggerEvent('ResearchCompleted',,, NewGameState);
					break;
				}
			}
		}
	}

	if (`XCOMHQ.GetObjectiveStatus('T2_M1_S2_MakeContactWithBlacksiteRegion') <= eObjectiveState_InProgress)
	{
		foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_MissionSite', MissionState)
		{
			if (MissionState.GetMissionSource().DataName == 'MissionSource_Blacksite')
			{
				if (MissionState.GetWorldRegion().ResistanceLevel >= eResLevel_Contact)
				{
					`XEVENTMGR.TriggerEvent('OnBlacksiteContacted',,, NewGameState);
					break;
				}
			}
		}
	}

	return ELR_NoInterrupt;
}

// AddSquadSelectStripWeaponsButton (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
//listener that adds an extra NavHelp button
function EventListenerReturn AddSquadSelectStripWeaponsButton (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;
	NavHelp.AddCenterHelp(class'UIUtilities_LWOTC'.default.m_strStripWeaponUpgrades, "", OnStripUpgrades, false, class'UIUtilities_LWOTC'.default.m_strTooltipStripWeapons);
	return ELR_NoInterrupt;
}

// AddArmoryStripWeaponsButton (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn AddArmoryStripWeaponsButton (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;

	// Add a button to make upgrades available.
	NavHelp.AddLeftHelp(class'UIUtilities_LWOTC'.default.m_strStripWeaponUpgrades, "", OnStripUpgrades, false, class'UIUtilities_LWOTC'.default.m_strTooltipStripWeapons);
	// Add a button to strip just the upgrades from this weapon.
	NavHelp.AddLeftHelp(Caps(class'UIScreenListener_ArmoryWeaponUpgrade'.default.strStripWeaponUpgradesButton), "", OnStripWeaponClicked, false, class'UIScreenListener_ArmoryWeaponUpgrade'.default.strStripWeaponUpgradesTooltip);

	return ELR_NoInterrupt;
}

// OnStripUpgrades()
simulated function OnStripUpgrades()
{
	local TDialogueBoxData DialogData;
	DialogData.eType = eDialog_Normal;
	DialogData.strTitle = class'UIUtilities_LWOTC'.default.m_strStripWeaponUpgradesConfirm;
	DialogData.strText = class'UIUtilities_LWOTC'.default.m_strStripWeaponUpgradesConfirmDesc;
	DialogData.fnCallback = OnStripUpgradesDialogCallback;
	DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
	DialogData.strCancel = class'UIDialogueBox'.default.m_strDefaultCancelLabel;
	`HQPRES.UIRaiseDialog(DialogData);
	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();
}

// OnStripUpgradesDialogCallback(name eAction)
simulated function OnStripUpgradesDialogCallback(name eAction)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState UpdateState;
	local array<StateObjectReference> Inventory;
	local array<XComGameState_Unit> Soldiers;
	local int idx;
	local StateObjectReference ItemRef;
	local XComGameState_Item ItemState;
	local X2EquipmentTemplate EquipmentTemplate;
	local TWeaponUpgradeAvailabilityData WeaponUpgradeAvailabilityData;
	local XComGameState_Unit OwningUnitState;
	local UIArmory_Loadout LoadoutScreen;

	LoadoutScreen = UIArmory_Loadout(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory_Loadout'));

	if (eAction == 'eUIAction_Accept')
	{
		History = `XCOMHISTORY;
		XComHQ =`XCOMHQ;

		//strip upgrades from weapons that aren't equipped to any soldier. We need to fetch, strip, and put the items back in the HQ inventory,
		// which will involve de-stacking and re-stacking items, so do each one in an individual gamestate submission.
		Inventory = class'UIUtilities_Strategy'.static.GetXComHQ().Inventory;
		foreach Inventory(ItemRef)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			if (ItemState != none)
			{
				OwningUnitState = XComGameState_Unit(History.GetGameStateForObjectID(ItemState.OwnerStateObject.ObjectID));
				if (OwningUnitState == none) // only if the item isn't owned by a unit
				{
					EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
					if(EquipmentTemplate != none && EquipmentTemplate.InventorySlot == eInvSlot_PrimaryWeapon && ItemState.HasBeenModified()) // primary weapon that has been modified
					{
						UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Strip Unequipped Upgrades");
						XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
						UpdateState.AddStateObject(XComHQ);

						// If this is the only instance of this weapon in the inventory we'll just get back a non-updated state.
						// That's ok, StripWeaponUpgradesFromItem will create/add it if it's not already in the update state. If it
						// is, we'll use that one directly to do the stripping.
						XComHQ.GetItemFromInventory(UpdateState, ItemState.GetReference(), ItemState);
						StripWeaponUpgradesFromItem(ItemState, XComHQ, UpdateState);
						ItemState = XComGameState_Item(UpdateState.GetGameStateForObjectID(ItemState.ObjectID));
						XComHQ.PutItemInInventory(UpdateState, ItemState);
						`GAMERULES.SubmitGameState(UpdateState);
					}
				}
			}
		}

		// strip upgrades from weapons on soldiers that aren't active. These can all be batched in one state because
		// soldiers maintain their equipped weapon, so there is no stacking of weapons to consider.
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Strip Unequipped Upgrades");
		XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		UpdateState.AddStateObject(XComHQ);
		Soldiers = GetSoldiersToStrip(XComHQ, UpdateState);
		for (idx = 0; idx < Soldiers.Length; idx++)
		{
			class'UIUtilities_Strategy'.static.GetWeaponUpgradeAvailability(Soldiers[idx], WeaponUpgradeAvailabilityData);
			if (!WeaponUpgradeAvailabilityData.bCanWeaponBeUpgraded)
			{
				continue;
			}

			ItemState = Soldiers[idx].GetItemInSlot(eInvSlot_PrimaryWeapon, UpdateState);
			if (ItemState != none && ItemState.HasBeenModified())
			{
				StripWeaponUpgradesFromItem(ItemState, XComHQ, UpdateState);
			}
		}

		`GAMERULES.SubmitGameState(UpdateState);
	}
	if (LoadoutScreen != none)
	{
		LoadoutScreen.UpdateNavHelp();
	}
}

// GetSoldiersToStrip(XComGameState_HeadquartersXCom XComHQ, XComGameState UpdateState)
simulated function array<XComGameState_Unit> GetSoldiersToStrip(XComGameState_HeadquartersXCom XComHQ, XComGameState UpdateState)
{
	local array<XComGameState_Unit> Soldiers;
	local int idx;
	local UIArmory ArmoryScreen;
	local UISquadSelect SquadSelectScreen;

	// Look for an armory screen. This will tell us what soldier we're looking at right now, we never want
	// to strip this one.
	ArmoryScreen = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));

	// Look for a squad select screen. This will tell us which soldiers we shouldn't strip because they're
	// in the active squad.
	SquadSelectScreen = UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));

	// Start with all soldiers: we only want to selectively ignore the ones in XComHQ.Squad if we're
	// in squad select. Otherwise it contains stale unit refs and we can't trust it.
	Soldiers = XComHQ.GetSoldiers(false);

	// LWS : revamped loop to remove multiple soldiers
	for(idx = Soldiers.Length - 1; idx >= 0; idx--)
	{

		// Don't strip items from the guy we're currently looking at (if any)
		if (ArmoryScreen != none)
		{
			if(Soldiers[idx].ObjectID == ArmoryScreen.GetUnitRef().ObjectID)
			{
				Soldiers.Remove(idx, 1);
				continue;
			}
		}
		//LWS: prevent stripping of gear of soldier with eStatus_OnMission
		if(Soldiers[idx].GetStatus() == eStatus_OnMission)
		{
			Soldiers.Remove(idx, 1);
			continue;
		}
		// prevent stripping of soldiers in current XComHQ.Squad if we're in squad
		// select. Otherwise ignore XComHQ.Squad as it contains stale unit refs.
		if (SquadSelectScreen != none)
		{
			if (XComHQ.Squad.Find('ObjectID', Soldiers[idx].ObjectID) != -1)
			{
				Soldiers.Remove(idx, 1);
				continue;
			}
		}
	}

	return Soldiers;
}

// OnStripWeaponClicked()
simulated function OnStripWeaponClicked()
{
	local XComPresentationLayerBase Pres;
	local TDialogueBoxData DialogData;

	Pres = `PRESBASE;
	Pres.PlayUISound(eSUISound_MenuSelect);

	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = class'UIScreenListener_ArmoryWeaponUpgrade'.default.strStripWeaponUpgradeDialogueTitle;
	DialogData.strText = class'UIScreenListener_ArmoryWeaponUpgrade'.default.strStripWeaponUpgradeDialogueText;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNO;
	DialogData.fnCallback = ConfirmStripSingleWeaponUpgradesCallback;
	Pres.UIRaiseDialog(DialogData);
}

// ConfirmStripSingleWeaponUpgradesCallback(name eAction)
simulated function ConfirmStripSingleWeaponUpgradesCallback(name eAction)
{
	local XComGameState_Item ItemState;
	local UIArmory_Loadout LoadoutScreen;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit Soldier;
	local XComGameState UpdateState;

	if (eAction == 'eUIAction_Accept')
	{
		LoadoutScreen = UIArmory_Loadout(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory_Loadout'));
		if (LoadoutScreen != none)
		{
			Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(LoadoutScreen.GetUnitRef().ObjectID));
			ItemState = Soldier.GetItemInSlot(eInvSlot_PrimaryWeapon);
			if (ItemState != none && ItemState.HasBeenModified())
			{
				UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Strip Weapon Upgrades");
				XComHQ = `XCOMHQ;
				XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
				UpdateState.AddStateObject(XComHQ);
				StripWeaponUpgradesFromItem(ItemState, XComHQ, UpdateState);
				`GAMERULES.SubmitGameState(UpdateState);
				LoadoutScreen.UpdateData(true);
			}
		}
	}
}

// StripWeaponUpgradesFromItem(XComGameState_Item ItemState, XComGameState_HeadquartersXCom XComHQ, XComGameState UpdateState)
function StripWeaponUpgradesFromItem(XComGameState_Item ItemState, XComGameState_HeadquartersXCom XComHQ, XComGameState UpdateState)
{
	local int k;
	local array<X2WeaponUpgradeTemplate> UpgradeTemplates;
	local XComGameState_Item UpdateItemState, UpgradeItemState;

	UpdateItemState = XComGameState_Item(UpdateState.GetGameStateForObjectID(ItemState.ObjectID));
	if (UpdateItemState == none)
	{
		UpdateItemState = XComGameState_Item(UpdateState.CreateStateObject(class'XComGameState_Item', ItemState.ObjectID));
		UpdateState.AddStateObject(UpdateItemState);
	}

	UpgradeTemplates = ItemState.GetMyWeaponUpgradeTemplates();
	for (k = 0; k < UpgradeTemplates.length; k++)
	{
		UpgradeItemState = UpgradeTemplates[k].CreateInstanceFromTemplate(UpdateState);
		UpdateState.AddStateObject(UpgradeItemState);
		XComHQ.PutItemInInventory(UpdateState, UpgradeItemState);
	}

	UpdateItemState.NickName = "";
	UpdateItemState.WipeUpgradeTemplates();
}

// OnRefreshCrewPhotographs(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
// It's school picture day. Add all the rebels.
function EventListenerReturn OnRefreshCrewPhotographs(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	/*
    local XComLWTuple Tuple;
    local XComLWTValue Value;
    local XComGameState_LWOutpost Outpost;
    local XComGameState_WorldRegion Region;
    local int i;

    Tuple = XComLWTuple(EventData);
    if (Tuple == none)
    {
        return ELR_NoInterrupt;
    }

    Value.Kind = XComLWTVInt;
    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_LWOutpost', Outpost)
    {
        Region = Outpost.GetWorldRegionForOutPost();
        if (!Region.HaveMadeContact())
            continue;

        for (i = 0; i < Outpost.Rebels.Length; ++i)
        {
            Value.i = Outpost.Rebels[i].Unit.ObjectID;
            Tuple.Data.AddItem(Value);
        }
    }
	*/
    return ELR_NoInterrupt;
}