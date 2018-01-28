class Listener_XComGameState_EndOfMonth extends Object;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

function InitListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	//end of month and reward soldier handling of new soldiers
	EventMgr.RegisterForEvent(ThisObj, 'OnMonthlyReportAlert', OnMonthEnd, ELD_OnStateSubmitted,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'SoldierCreatedEvent', OnSoldierCreatedEvent, ELD_OnStateSubmitted,,,true);

    // Various end of month handling, especially for supply income determination.
    // Note: this is very fiddly. There are several events fired from different parts of the end-of-month processing
    // in the HQ. For most of this, there is an outstanding game state being generated but which hasn't yet been added
    // to the history. This state persists over several of these events before finally being submitted, so care must be
    // taken to check if the object we want to change is already present in the game state rather than fetching the
    // latest submitted one from the history, which would be stale.

    // Pre end of month. Called before we begin any end of month processing, but after the new game state is created.
    // This is used to make sure we trigger one last update event on all the outposts so the income for the last
    // day of the month is computed. This updates the outpost but the won't be submitted yet.
    // EventMgr.RegisterForEvent(ThisObj, 'PreEndOfMonth', PreEndOfMonth, ELD_Immediate,,,true);

    // A request was made for the real monthly supply reward. This is called twice: first from the HQ to get the true
    // number of supplies to reward, and then again by UIResistanceReport to display the value in the report screen.
    // The first one is called while the game state is still pending and so needs to pull the outpost from the pending
    // game state. The second is called after the update is submitted and is passed a null game state, so it can read the
    // outpost from the history.
    // EventMgr.RegisterForEvent(ThisObj, 'OnMonthlySuppliesReward', OnMonthlySuppliesReward, ELD_Immediate,,,true);

	//process negative monthly income -- this happens after deductions for maint, so can't go into the OnMonthlySuppliesReward
    EventMgr.RegisterForEvent(ThisObj, 'OnMonthlyNegativeSupplies', OnMonthlyNegativeSupplyIncome, ELD_Immediate,,,true);

    // After closing the monthly report dialog. This is responsible for doing outpost end-of-month processing including
    // resetting the supply state.
    // EventMgr.RegisterForEvent(ThisObj, 'OnClosedMonthlyReportAlert', PostEndOfMonth, ELD_OnStateSubmitted,,,true);

	// Supply decrease monthly report string replacement
    // EventMgr.RegisterForEvent(ThisObj, 'GetSupplyDropDecreaseStrings', OnGetSupplyDropDecreaseStrings, ELD_Immediate,,, true);
}

// OnMonthEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
// Recruit updating utility items.
function EventListenerReturn OnMonthEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
    local XComGameState_HeadquartersResistance ResistanceHQ;
	local XComGameState_Unit UnitState;
	local StateObjectReference UnitRef;

	History = `XCOMHISTORY;
	ResistanceHQ = XComGameState_HeadquartersResistance(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("");

    // Add utility items to each recruit
	foreach ResistanceHQ.Recruits(UnitRef)
	{
		UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
		NewGameState.AddStateObject(UnitState);
		GiveDefaultUtilityItemsToSoldier(UnitState, NewGameState);
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
		`GAMERULES.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);

	return ELR_NoInterrupt;
}

// OnSoldierCreatedEvent(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
// Updates utility items
function EventListenerReturn OnSoldierCreatedEvent(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComGameState_Unit Unit, UpdatedUnit;
	local XComGameState NewGameState;

	Unit = XComGameState_Unit(EventData);
	if(Unit == none)
	{
		`REDSCREEN("OnSoldierCreatedEvent with no UnitState EventData");
		return ELR_NoInterrupt;
	}

	//Build NewGameState change container
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update newly created soldier");
	UpdatedUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', Unit.ObjectID));
	NewGameState.AddStateObject(UpdatedUnit);
	GiveDefaultUtilityItemsToSoldier(UpdatedUnit, NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

// GiveDefaultUtilityItemsToSoldier(XComGameState_Unit UnitState, XComGameState NewGameState)
static function GiveDefaultUtilityItemsToSoldier(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local array<XComGameState_Item> CurrentInventory;
	local XComGameState_Item InventoryItem;
	local array<X2EquipmentTemplate> DefaultEquipment;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComGameState_Item ItemState;
	local X2ItemTemplateManager ItemTemplateManager;
	local InventoryLoadout RequiredLoadout;
	local array<name> RequiredNames;
	local InventoryLoadoutItem LoadoutItem;
	local bool bRequired;
	local int idx;

	UnitState.bIgnoreItemEquipRestrictions = true;

	//first remove any existing utility slot items the unit has, that aren't on the RequiredLoadout
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	idx = ItemTemplateManager.Loadouts.Find('LoadoutName', UnitState.GetMyTemplate().RequiredLoadout);
	if(idx != -1)
	{
		RequiredLoadout = ItemTemplateManager.Loadouts[idx];
		foreach RequiredLoadout.Items(LoadoutItem)
		{
			RequiredNames.AddItem(LoadoutItem.Item);
		}
	}
	CurrentInventory = UnitState.GetAllInventoryItems(NewGameState);
	foreach CurrentInventory(InventoryItem)
	{
		bRequired = RequiredNames.Find(InventoryItem.GetMyTemplateName()) != -1;
		if(!bRequired && InventoryItem.InventorySlot == eInvSlot_Utility)
		{
			UnitState.RemoveItemFromInventory(InventoryItem, NewGameState);
		}
	}

	//equip the default loadout
	DefaultEquipment = GetCompleteDefaultLoadout(UnitState);
	foreach DefaultEquipment(EquipmentTemplate)
	{
		if(EquipmentTemplate.InventorySlot == eInvSlot_Utility)
		{
			ItemState = EquipmentTemplate.CreateInstanceFromTemplate(NewGameState);
			NewGameState.AddStateObject(ItemState);
			UnitState.AddItemToInventory(ItemState, eInvSlot_Utility, NewGameState);
		}
	}
	UnitState.bIgnoreItemEquipRestrictions = false;
}

// GetCompleteDefaultLoadout(XComGameState_Unit UnitState)
// Combines rookie and squaddie loadouts so that things like kevlar armor and grenades are included
// but without the silliness of "only one item per slot type"
static function array<X2EquipmentTemplate> GetCompleteDefaultLoadout(XComGameState_Unit UnitState)
{
	local X2ItemTemplateManager ItemTemplateManager;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local InventoryLoadout Loadout;
	local InventoryLoadoutItem LoadoutItem;
	local X2EquipmentTemplate EquipmentTemplate;
	local array<X2EquipmentTemplate> CompleteDefaultLoadout;
	local int idx;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	// First grab squaddie loadout if possible
	SoldierClassTemplate = UnitState.GetSoldierClassTemplate();

	if(SoldierClassTemplate != none && SoldierClassTemplate.SquaddieLoadout != '')
	{
		idx = ItemTemplateManager.Loadouts.Find('LoadoutName', SoldierClassTemplate.SquaddieLoadout);
		if(idx != -1)
		{
			Loadout = ItemTemplateManager.Loadouts[idx];
			foreach Loadout.Items(LoadoutItem)
			{
				EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(LoadoutItem.Item));
				if(EquipmentTemplate != none)
					CompleteDefaultLoadout.AddItem(EquipmentTemplate);
			}
		}
		return CompleteDefaultLoadout;
	}

	// Grab default loadout
	idx = ItemTemplateManager.Loadouts.Find('LoadoutName', UnitState.GetMyTemplate().DefaultLoadout);
	if(idx != -1)
	{
		Loadout = ItemTemplateManager.Loadouts[idx];
		foreach Loadout.Items(LoadoutItem)
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(LoadoutItem.Item));
			if(EquipmentTemplate != none)
					CompleteDefaultLoadout.AddItem(EquipmentTemplate);
		}
	}

	return CompleteDefaultLoadout;
}

// PreEndOfMonth(Object EventData, Object EventSource, XComGameState NewGameState, Name EventID, Object CallbackObject)
// Pre end-of month processing. The HQ object responsible for triggering end of month gets ticked before our outposts, so
// we haven't yet run the update routine for the last day of the month. Run it now.
function EventListenerReturn PreEndOfMonth(Object EventData, Object EventSource, XComGameState NewGameState, Name EventID, Object CallbackObject)
{
	/*
    local XComGameState_LWOutpost Outpost, NewOutpost;
    local XComGameState_WorldRegion WorldRegion;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_LWOutpost', Outpost)
    {
        WorldRegion = Outpost.GetWorldRegionForOutpost();

        // Skip uncontacted regions.
        if (WorldRegion.ResistanceLevel < eResLevel_Contact)
        {
            continue;
        }

        // See if we already have an outstanding state for this outpost, and create one if not. (This shouldn't ever
        // be the case as this is the first thing done in the end-of-month processing.)
        NewOutpost = XComGameState_LWOutpost(NewGameState.GetGameStateForObjectID(Outpost.ObjectID));
        if (NewOutpost != none)
        {
            `LWTrace("PreEndOfMonth: Found existing outpost");
            Outpost = NewOutpost;
        }
        else
        {
            Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));
            NewGameState.AddStateObject(Outpost);
        }

        if (Outpost.Update(NewGameState))
        {
            `LWTrace("Update succeeded");
        }
        else
        {
            `LWTrace("Update failed");
        }
    }
	*/
    return ELR_NoInterrupt;
}

// OnMonthlySuppliesReward(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
// Retreive the amount of supplies to reward for the month by summing up the income pools in each region. This is called twice:
// first to get the value to put in the supply cache, and then again to get the string to display in the UI report. The first
// time will have a non-none GameState that must be used to get the latest outpost states rather than the history, as the history
// won't yet have the state including the last day update from the pre event above.
function EventListenerReturn OnMonthlySuppliesReward(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	/*
	local XComGameStateHistory History;
    local XComGameState_LWOutpost Outpost, NewOutpost;
    local XComLWTuple Tuple;
    local int Supplies;

    History = `XCOMHISTORY;
    Tuple = XComLWTuple(EventData);
    if (Tuple == none || Tuple.Id != 'OverrideSupplyDrop' || Tuple.Data[0].kind != XComLWTVBool || Tuple.Data[0].b == true)
    {
        // Not an expected tuple, or another mod has already done the override: return
        return ELR_NoInterrupt;
    }

    foreach History.IterateByClassType(class'XComGameState_LWOutpost', Outpost)
    {
        // Look for a more recent version in the outstanding game state, if one exists. We don't need to add this to the
        // pending game state if one doesn't exist cause this is a read-only operation on the outpost. We should generally
        // find an existing state here cause the pre event above should have created one and added it.
        if (GameState != none)
        {
            NewOutpost = XComGameState_LWOutpost(GameState.GetGameStateForObjectID(Outpost.ObjectID));
            if (NewOutpost != none)
            {
                `LWTrace("OnMonthlySuppliesReward: Found existing outpost");
                Outpost = NewOutpost;
            }
        }
        Supplies += Outpost.GetEndOfMonthSupply();
    }

    `LWTrace("OnMonthlySuppliesReward: Returning " $ Supplies);
    Tuple.Data[1].i = Supplies;
    Tuple.Data[0].b = true;
	*/

    return ELR_NoInterrupt;
}

// OnMonthlyNegativeSupplyIncome(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
// Process Negative Supply income events on EndOfMonth processing
function EventListenerReturn OnMonthlyNegativeSupplyIncome(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComGameStateHistory History;
    local XComLWTuple Tuple;
    local int RemainingSupplyLoss, AvengerSupplyLoss;
	local int CacheSupplies;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_ResourceCache CacheState;

    History = `XCOMHISTORY;
    Tuple = XComLWTuple(EventData);
    if (Tuple == none || Tuple.Id != 'NegativeMonthlyIncome')
    {
        // Not an expected tuple
        return ELR_NoInterrupt;
    }
    Tuple.Data[0].b = true; // allow display of negative supplies

	if (Tuple.Data[2].b) { return ELR_NoInterrupt; } // if DisplayOnly, return immediately with no other changes

	// retrieve XComHQ object, since we'll be modifying supplies resource
	foreach GameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ == none)
	{
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		GameState.AddStateObject(XComHQ);
	}

	RemainingSupplyLoss = -Tuple.Data[1].i;
	AvengerSupplyLoss = Min (RemainingSupplyLoss, XComHQ.GetResourceAmount('Supplies'));
	XComHQ.AddResource(GameState, 'Supplies', -AvengerSupplyLoss);
    `LWTrace("OnNegativeMonthlySupplies : Removed " $ AvengerSupplyLoss $ " supplies from XComHQ");

	RemainingSupplyLoss -= AvengerSupplyLoss;
	if (RemainingSupplyLoss <= 0) { return ELR_NoInterrupt; }

	// retrieve supplies cache, in case there are persisting supplies to be removed
	foreach GameState.IterateByClassType(class'XComGameState_ResourceCache', CacheState)
	{
		break;
	}
	if (CacheState == none)
	{
		CacheState = XComGameState_ResourceCache(History.GetSingleGameStateObjectForClass(class'XComGameState_ResourceCache'));
		GameState.AddStateObject(CacheState);
	}
	CacheSupplies = CacheState.ResourcesRemainingInCache + CacheState.ResourcesToGiveNextScan;

	if (CacheSupplies > 0)
	{
		if (RemainingSupplyLoss > CacheSupplies) // unlikely, but just in case
		{
			// remove all resources, and hide it
			CacheState.ResourcesToGiveNextScan = 0;
			CacheState.ResourcesRemainingInCache = 0;
			CacheState.bNeedsScan = false;
			CacheState.NumScansCompleted = 999;
			`LWTrace("OnNegativeMonthlySupplies : Removed existing supply cache");
		}
		else
		{
			CacheState.ShowResourceCache(GameState, -RemainingSupplyLoss); // just reduce the existing one
			`LWTrace("OnNegativeMonthlySupplies : Removed " $ RemainingSupplyLoss $ " supplies from existing supply cache");
		}
	}

    return ELR_NoInterrupt;
}

// PostEndOfMonth(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
// Post end of month processing: called after closing the report UI.
function EventListenerReturn PostEndOfMonth(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	/*
    local XComGameStateHistory History;
	local XComGameState NewGameState;
    local XComGameState_LWOutpost Outpost, NewOutpost;

    History = `XCOMHISTORY;
    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("");

    `LWTrace("Running post end of month update");

    // Do end-of-month processing on each outpost.
    foreach History.IterateByClassType(class'XComGameState_LWOutpost', Outpost)
	{
        // Check for existing game states (there shouldn't be any, since this is invoked after the HQ updates are
        // submitted to history.)
        NewOutpost = XComGameState_LWOutpost(NewGameState.GetGameStateForObjectID(Outpost.ObjectID));
        if (NewOutpost != none)
        {
            Outpost = NewOutpost;
            `LWTrace("PostEndOfMonth: Found existing outpost");
        }
        else
        {
		    Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));
            NewGameState.AddStateObject(Outpost);
        }

        Outpost.OnMonthEnd(NewGameState);
	}

    if (NewGameState.GetNumGameStateObjects() > 0)
		`GAMERULES.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);
	*/
	return ELR_NoInterrupt;
}

// OnGetSupplyDropDecreaseStrings(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnGetSupplyDropDecreaseStrings(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	/*
    local XComGameState_LWOutpost Outpost;
    local XComGameStateHistory History;
    local XComLWTuple Tuple;
    local XComLWTValue Value;
    local int NetSupplies;
    local int GrossSupplies;
    local int SupplyDelta;

    Tuple = XComLWTuple(EventData);
    if (Tuple == none || Tuple.Data.Length > 0)
    {
        return ELR_NoInterrupt;
    }

    // Figure out how many supplies we have lost.
    History = `XCOMHISTORY;
    foreach History.IterateByClassType(class'XComGameState_LWOutpost', Outpost)
    {
        GrossSupplies += Outpost.GetIncomePoolForJob('Resupply');
        NetSupplies += Outpost.GetEndOfMonthSupply();
    }

    SupplyDelta = GrossSupplies - NetSupplies;

    if (SupplyDelta > 0)
    {
        Value.Kind = XComLWTVString;
        Value.s = class'UIBarMemorial_Details'.default.m_strUnknownCause;
        Tuple.Data.AddItem(Value);
        Value.s = "-" $ class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ String(int(Abs(SupplyDelta)));
        Tuple.Data.AddItem(Value);
    }
	*/
    return ELR_NoInterrupt;
}