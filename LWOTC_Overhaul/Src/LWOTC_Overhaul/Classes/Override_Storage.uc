class Override_Storage extends Object config(LWOTC_Overrides);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array<name> UnlimitedItemsAdded;

// This handles updating storage in order to create new unlimited items of various flavors
static function UpdateStorage()
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local X2ItemTemplateManager ItemTemplateMgr;
	local name ItemName;
	local bool bAddedAnyItem;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating HQ Storage to add items");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	NewGameState.AddStateObject(XComHQ);
	ItemTemplateMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	bAddedAnyItem = false;

	foreach default.UnlimitedItemsAdded(ItemName)
	{
	if(AddItemToStorage(ItemName, ItemTemplateMgr, XComHQ, NewGameState))
		bAddedAnyItem = true;
	}

	if(bAddedAnyItem)
		History.AddGameStateToHistory(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);


	//schematics should be handled already, as the BuildItem UI draws from ItemTemplates, which are automatically loaded
}

static function bool AddItemToStorage(name ItemTemplateName, X2ItemTemplateManager ItemTemplateMgr, XComGameState_HeadquartersXCom XComHQ, XComGameState NewGameState)
{
	local X2ItemTemplate ItemTemplate;
	local XComGameState_Item NewItemState;

	`LWTRACE("Searching for item template:" @ ItemTemplateName);
	ItemTemplate = ItemTemplateMgr.FindItemTemplate(ItemTemplateName);
	if(ItemTemplate != none)
	{
		`LWTRACE("Found item template:" @ ItemTemplateName);
		if (!XComHQ.HasItem(ItemTemplate))
		{
			`LWTRACE(ItemTemplateName $ " not found, adding to inventory");
			NewItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
			NewGameState.AddStateObject(NewItemState);
			XComHQ.AddItemToHQInventory(NewItemState);
			return true;
		} else {
			`LWTRACE(ItemTemplateName $ " found, skipping inventory add");
			return false;
		}
	}
}

static function UpdateAllSoldiers()
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local bool bUpdatedAnySoldier;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Soldier Initial Inventory");
	bUpdatedAnySoldier = false;

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if(UnitState.IsSoldier())
		{
			if(UpdateOneSoldier(UnitState, NewGameState))
				bUpdatedAnySoldier = true;
		}
	}

	if(bUpdatedAnySoldier)
		History.AddGameStateToHistory(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);
}

static function UpdateStartingSoldiers(XComGameState StartState)
{
	local XComGameState_Unit UnitState;

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if(UnitState.IsSoldier())
		{
			UpdateOneSoldier(UnitState, StartState);
		}
	}
}

static function bool UpdateOneSoldier(XComGameState_Unit UnitState, XComGameState StartState)
{
	UnitState.SetBaseMaxStat(eStat_UtilityItems, 3.0f);
	UnitState.SetCurrentStat(eStat_UtilityItems, 3.0f);

	class'Listener_XComGameState_EndOfMonth'.static.GiveDefaultUtilityItemsToSoldier(UnitState, StartState);
	return true;
}