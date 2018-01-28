//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWListenerManager.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//  PURPOSE: This singleton object manages general persistent listeners that should live for both strategy and tactical play
//---------------------------------------------------------------------------------------
class Listener_XComGameState_Manager extends XComGameState_BaseObject config(LWOTC_Overhaul) dependson(Squad_XComGameState);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array<float> BLACK_MARKET_PROFIT_MARGIN;
var config int BLACK_MARKET_2ND_SOLDIER_FL;
var config int BLACK_MARKET_3RD_SOLDIER_FL;
var config float BLACK_MARKET_PERSONNEL_INFLATION_PER_FORCE_LEVEL;
var config float BLACK_MARKET_SOLDIER_DISCOUNT;

var Listener_XComGameState_EndOfMonth EndOfMonthListener;
var Listener_XComGameState_Avenger AvengerListener;
var Listener_XComGameState_Units UnitListener;
var Listener_XComGameState_Mission MissionListener;

// GetListenerManager(optional bool AllowNULL = false)
static function Listener_XComGameState_Manager GetListenerManager(optional bool AllowNULL = false)
{
	return Listener_XComGameState_Manager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'Listener_XComGameState_Manager', AllowNULL));
}

// OnCreation( optional X2DataTemplate InitTemplate )
event OnCreation( optional X2DataTemplate InitTemplate )
{
	EndOfMonthListener = new class'Listener_XComGameState_EndOfMonth';
	AvengerListener = new class'Listener_XComGameState_Avenger';
	UnitListener = new class'Listener_XComGameState_Units';
	MissionListener = new class'Listener_XComGameState_Mission';
}

// CreateListenerManager(optional XComGameState StartState)
static function CreateListenerManager(optional XComGameState StartState)
{
	local Listener_XComGameState_Manager ListenerMgr;
	local XComGameState NewGameState;

	//first check that there isn't already a singleton instance of the listener manager
	if(GetListenerManager(true) != none)
		return;

	if(StartState != none)
	{
		ListenerMgr = Listener_XComGameState_Manager(StartState.CreateStateObject(class'Listener_XComGameState_Manager'));
		StartState.AddStateObject(ListenerMgr);
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating LW Listener Manager Singleton");
		ListenerMgr = Listener_XComGameState_Manager(NewGameState.CreateStateObject(class'Listener_XComGameState_Manager'));
		NewGameState.AddStateObject(ListenerMgr);
		`XCOMHISTORY.AddGameStateToHistory(NewGameState);
	}

	ListenerMgr.InitListeners();
}

// RefreshListeners()
static function RefreshListeners()
{
	local Listener_XComGameState_Manager ListenerMgr;
	local SquadManager_XComGameState    SquadMgr;

	ListenerMgr = GetListenerManager(true);
	if(ListenerMgr == none)
		CreateListenerManager();
	else
		ListenerMgr.InitListeners();

	SquadMgr = class'SquadManager_XComGameState'.static.GetSquadManager(true);
	if (SquadMgr != none)
		SquadMgr.InitSquadManagerListeners();
}

// InitListeners()
function InitListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	`LWTrace ("Init Listeners Firing!");

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	EndOfMonthListener.InitListeners();
	AvengerListener.InitListeners();
	UnitListener.InitListeners();
	MissionListener.InitListeners();

	//Override the BlackMarket Sale Items -- 	`XEVENTMGR.TriggerEvent('OverrideBlackMarketGoods', OverrideTuple, self);
	EventMgr.RegisterForEvent(ThisObj, 'OverrideBlackMarketGoods', OnOverrideBlackMarketGoods, ELD_OnStateSubmitted,,,true);
	// Override Ability Icons with the special color set as "variable." This enables on-the-fly changes to ability icons
	EventMgr.RegisterForEvent(ThisObj, 'OverrideAbilityIconColor', OnOverrideAbilityIconColor, ELD_Immediate,,, true);
	EventMgr.RegisterForEvent(ThisObj, 'OverrideObjectiveAbilityIconColor', OnOverrideObjectiveAbilityIconColor, ELD_Immediate,,, true);
	//PCS Images
	EventMgr.RegisterForEvent(ThisObj, 'OnGetPCSImage', GetPCSImage,,,,true);
    // Outpost built
    EventMgr.RegisterForEvent(ThisObj, 'RegionBuiltOutpost', OnRegionBuiltOutpost, ELD_OnStateSubmitted,,, true);
    // Version check
    EventMgr.RegisterForEvent(ThisObj, 'GetLWVersion', OnGetLWVersion, ELD_Immediate,,, true);
    // Override UFO interception time (since base-game uses Calendar, which no longer works for us)
    EventMgr.RegisterForEvent(ThisObj, 'PostUFOSetInterceptionTime', OnUFOSetInfiltrationTime, ELD_Immediate,,, true);
}

// OnOverrideBlackMarketGoods(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
// override black market to make items be purchasable with supplies, remove the supplies reward from being purchasable
function EventListenerReturn OnOverrideBlackMarketGoods(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_BlackMarket BlackMarket;
	local XComGameState_Reward RewardState;
	local int ResourceIdx, Idx, ItemIdx;
 	local bool bStartState;
	local XComGameState_Item ItemState;
    //local XComPhotographer_Strategy Photo;
	local X2StrategyElementTemplateManager StratMgr;
	local X2RewardTemplate RewardTemplate;
	local array<XComGameState_Tech> TechList;
	local Commodity ForSaleItem, EmptyForSaleItem;
	local array<name> PersonnelRewardNames;
	local array<XComGameState_Item> ItemList;
	local ArtifactCost ResourceCost;
	local XComGameState_HeadquartersAlien AlienHQ;
	//local array<StateObjectReference> AllItems, InterestCandidates;
	//local name InterestName;
	//local int i,k;


	BlackMarket = XComGameState_BlackMarket(EventData);
    if (BlackMarket == none)
    {
        `REDSCREEN("OverrideBlackMarketGoods called with no object");
        return ELR_NoInterrupt;
    }

	History = `XCOMHISTORY;
	bStartState = (GameState.GetContext().IsStartState());

	//Build NewGameState change container
	if (bStartState)
	{
		NewGameState = GameState;
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Black Market ForSale and interest Items");
		BlackMarket = XComGameState_BlackMarket(NewGameState.CreateStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));
		NewGameState.AddStateObject(BlackMarket);
	}
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	BlackMarket.ForSaleItems.Length = 0;

	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_TechRush'));
	TechList = BlackMarket.RollForTechRushItems();

	// Tech Rush Rewards
	for(idx = 0; idx < TechList.Length; idx++)
	{
		ForSaleItem = EmptyForSaleItem;
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		NewGameState.AddStateObject(RewardState);
		RewardState.SetReward(TechList[idx].GetReference());
		ForSaleItem.RewardRef = RewardState.GetReference();

		ForSaleItem.Title = RewardState.GetRewardString();
		ForSaleItem.Cost = BlackMarket.GetTechRushCost(TechList[idx], NewGameState);
		for (ResourceIdx = 0; ResourceIdx < ForSaleItem.Cost.ResourceCosts.Length; ResourceIdx ++)
		{
			if (ForSaleItem.Cost.ResourceCosts[ResourceIdx].ItemTemplateName == 'Intel')
			{
				ForSaleItem.Cost.ResourceCosts[ResourceIdx].ItemTemplateName = 'Supplies';
			}
		}
		ForSaleItem.Desc = RewardState.GetBlackMarketString();
		ForSaleItem.Image = RewardState.GetRewardImage();
		ForSaleItem.CostScalars = BlackMarket.GoodsCostScalars;
		ForSaleItem.DiscountPercent = BlackMarket.GoodsCostPercentDiscount;

		BlackMarket.ForSaleItems.AddItem(ForSaleItem);
	}

	// TODO: fix photo
	//if (class'Engine'.static.GetCurrentWorldInfo().Game != none)
	//	Photo = XComHeadquartersGame(class'Engine'.static.GetCurrentWorldInfo().Game).GetGameCore().StrategyPhotographer;

	// Dudes, one each per month
	PersonnelRewardNames.AddItem('Reward_Scientist');
    PersonnelRewardNames.AddItem('Reward_Engineer');
    PersonnelRewardNames.AddItem('Reward_Soldier');

    AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	if (AlienHQ.GetForceLevel() >= default.BLACK_MARKET_2ND_SOLDIER_FL)
		PersonnelRewardNames.AddItem('Reward_Soldier');

	if (AlienHQ.GetForceLevel() >= default.BLACK_MARKET_3RD_SOLDIER_FL)
		PersonnelRewardNames.AddItem('Reward_Soldier');

	for (idx=0; idx < PersonnelRewardNames.Length; idx++)
	{
		ForSaleItem = EmptyForSaleItem;
		RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate(PersonnelRewardNames[idx]));
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		NewGameState.AddStateObject(RewardState);
        RewardState.GenerateReward(NewGameState,, BlackMarket.Region);
        ForSaleItem.RewardRef = RewardState.GetReference();
        ForSaleItem.Title = RewardState.GetRewardString();
        ForSaleItem.Cost = BlackMarket.GetPersonnelForSaleItemCost();

		for (ResourceIdx = 0; ResourceIdx < ForSaleItem.Cost.ResourceCosts.Length; ResourceIdx ++)
		{
			if (ForSaleItem.Cost.ResourceCosts[ResourceIdx].ItemTemplateName == 'Intel')
			{
				ForSaleItem.Cost.ResourceCosts[ResourceIdx].ItemTemplateName = 'Supplies'; // add 10% per force level, soldiers 1/4 baseline, baseline
				ForSaleItem.Cost.ResourceCosts[ResourceIdx].Quantity *= 1 + ((AlienHQ.GetForceLevel() - 1) * default.BLACK_MARKET_PERSONNEL_INFLATION_PER_FORCE_LEVEL);
				if (PersonnelRewardNames[idx] == 'Reward_Soldier')
					ForSaleItem.Cost.ResourceCosts[ResourceIdx].Quantity *= default.BLACK_MARKET_SOLDIER_DISCOUNT;
			}
		}

        ForSaleItem.Desc = RewardState.GetBlackMarketString();
        ForSaleItem.Image = RewardState.GetRewardImage();
		ForSaleItem.CostScalars = BlackMarket.GoodsCostScalars;
		ForSaleItem.DiscountPercent = BlackMarket.GoodsCostPercentDiscount;

		/* TODO fix photo
        if(ForSaleItem.Image == "" && Photo != none)
        {
            if(!Photo.HasPendingHeadshot(RewardState.RewardObjectReference, BlackMarket.OnUnitHeadCaptureFinished))
            {
                Photo.AddHeadshotRequest(RewardState.RewardObjectReference, 'UIPawnLocation_ArmoryPhoto', 'SoldierPicture_Head_Armory', 512, 512, BlackMarket.OnUnitHeadCaptureFinished);
            }
        }
		*/
        BlackMarket.ForSaleItems.AddItem(ForSaleItem);
	}

	ItemList = BlackMarket.RollForBlackMarketLoot (NewGameState);

	//`LOG ("ItemList Length:" @ string(ItemList.Length));

	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Item'));
	for (Idx = 0; idx < ItemList.Length; idx++)
    {
        ForSaleItem = EmptyForSaleItem;
        RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
        NewGameState.AddStateObject(RewardState);
        RewardState.SetReward(ItemList[Idx].GetReference());
        ForSaleItem.RewardRef = RewardState.GetReference();
        ForSaleItem.Title = RewardState.GetRewardString();

		//ForSaleItem.Title = class'UIUtilities_Text_LW'.static.StripHTML (ForSaleItem.Title); // StripHTML not needed and doesn't work yet

		ItemState = XComGameState_Item (History.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));
        ForSaleItem.Desc = RewardState.GetBlackMarketString() $ "\n\n" $ ItemState.GetMyTemplate().GetItemBriefSummary();// REPLACE WITH ITEM DESCRIPTION!
        ForSaleItem.Image = RewardState.GetRewardImage();
        ForSaleItem.CostScalars = BlackMarket.GoodsCostScalars;
        ForSaleItem.DiscountPercent = BlackMarket.GoodsCostPercentDiscount;

		ResourceCost.ItemTemplateName = 'Supplies';
		ResourceCost.Quantity = ItemState.GetMyTemplate().TradingPostValue * default.BLACK_MARKET_PROFIT_MARGIN[`CAMPAIGNDIFFICULTYSETTING];

		`LWTRACE (ForSaleItem.Title @ ItemState.Quantity);

		if (ItemState.Quantity > 1)
		{
			ResourceCost.Quantity *= ItemState.Quantity;
		}
		ForSaleItem.Cost.ResourceCosts.AddItem (ResourceCost);
        BlackMarket.ForSaleItems.AddItem(ForSaleItem);
    }

	// switch to supplies cost, fix items sale price to TPV
	for (ItemIdx = BlackMarket.ForSaleItems.Length - 1; ItemIdx >= 0; ItemIdx--)
	{
		if (bStartState)
		{
			RewardState = XComGameState_Reward(NewGameState.GetGameStateForObjectID(BlackMarket.ForSaleItems[ItemIdx].RewardRef.ObjectID));
		}
		else
		{
			RewardState = XComGameState_Reward(History.GetGameStateForObjectID(BlackMarket.ForSaleItems[ItemIdx].RewardRef.ObjectID));
		}
		if (RewardState.GetMyTemplateName() == 'Reward_Supplies')
		{
			BlackMarket.ForSaleItems.Remove(ItemIdx, 1);
			RewardState.CleanUpReward(NewGameState);
			NewGameState.RemoveStateObject(RewardState.ObjectID);
		}
	}

	if (!bStartState)
		History.AddGameStateToHistory(NewGameState);

	return ELR_NoInterrupt;

	// restricts BM interest items to corpses only
//	BlackMarket.InterestTemplates.length = 0;
//	AllItems = `XCOMHQ.GetTradingPostItems();

//	`LWTRACE ("Setting corpses, testing #" @ AllItems.Length);
//	for (k = 0; k < AllItems.Length; k++)
//	{
	//	ItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(AllItems[k].ObjectID));
//		if(ItemState != none)
		//{
			//InterestName = ItemState.GetMyTemplateName();
			//`LWTRACE ("Testing" @ InterestName @ "for Interest Candidate list");
			//if (Instr (string(InterestName), "Corpse") != -1)
			//{
				//`LWTRACE ("ADDING" @ interestname @ "to Interest Candidate list");
				//InterestCandidates.AddItem(ItemState.GetReference());
			//}
			//if (InterestName == 'AlienAlloy' || InterestName == 'EleriumDust')
			//{
				//`LWTRACE ("ADDING" @ "to Interest Candidate list");
				//InterestCandidates.AddItem(ItemState.GetReference());
			//}
		//}
	//}

	//for (k = 0; k < class'XComGameState_BlackMarket'.default.NumInterestItems[`CAMPAIGNDIFFICULTYSETTING]; k++)
//	{
	//	if(InterestCandidates.Length > 0)
//		{
			// Get Random Interesting Candidate
	//		i = `SYNC_RAND(InterestCandidates.Length);
		//	ItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(InterestCandidates[i].ObjectID));
//			if(ItemState != none)
	//		{
		//		InterestName = ItemState.GetMyTemplateName();
			///	`LWTRACE ("INTEREST TEMPLATE SET:" @ InterestName);
			//	BlackMarket.InterestTemplates.AddItem(InterestName);
//				InterestCandidates.Remove(i, 1);
			//}
		//}
	//}
	//BlackMarket.UpdateBuyPrices();
}

// OnOverrideAbilityIconColor (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// This takes on a bunch of exceptions to color ability icons
function EventListenerReturn OnOverrideAbilityIconColor (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple				OverrideTuple;
	local Name						AbilityName;
	local XComGameState_Ability		AbilityState;
	local X2AbilityTemplate			AbilityTemplate;
	local XComGameState_Unit		UnitState;
	local string					IconColor;
	local XComGameState_Item		WeaponState;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local int k, k2;
	local bool Changed;
	local UnitValue FreeReloadValue;
	local X2AbilityCost_ActionPoints		ActionPoints;

	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OnOverrideAbilityIconColor event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	AbilityState = XComGameState_Ability (EventSource);
	//OverrideTuple.Data[0].o;

	if (AbilityState == none)
	{
		`LWTRACE ("No ability state fed to OnOverrideAbilityIconColor");
		return ELR_NoInterrupt;
	}

	Changed = false;
	AbilityTemplate = AbilityState.GetMyTemplate();
	AbilityName = AbilityState.GetMyTemplateName();
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
	WeaponState = AbilityState.GetSourceWeapon();

	if (UnitState == none)
	{
		`LWTRACE ("No unitstate found for OnOverrideAbilityIconColor");
		return ELR_NoInterrupt;
	}

	// Salvo, Quickburn, Holotarget
	for (k = 0; k < AbilityTemplate.AbilityCosts.Length; k++)
	{
		ActionPoints = X2AbilityCost_ActionPoints(AbilityTemplate.AbilityCosts[k]);
		if (ActionPoints != none)
		{
			if (ActionPoints.bConsumeAllPoints)
			{
				for (k2 = 0; k2 < ActionPoints.DoNotConsumeAllSoldierAbilities.Length; k2++)
				{
					if (UnitState.HasSoldierAbility(ActionPoints.DoNotConsumeAllSoldierAbilities[k2], true))
					{
						IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_1;
						Changed = true;
						break;
					}
				}
			}
			if (ActionPoints.bAddWeaponTypicalCost)
			{
				if (X2WeaponTemplate(WeaponState.GetMyTemplate()).iTypicalActionCost >= 2)
				{
					IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_2; // yellow
					Changed = true;
					break;
				}
				else
				{
					if (ActionPoints.bConsumeAllPoints)
					{
						IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_END; // cyan
						Changed = true;
						break;
					}
					else
					{
						IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_1;
						Changed = true;
						break;
					}
				}
			}
		}
	}

	//`LWTRACE ("Testing variable icon color for" @ AbilityName);

	switch (AbilityName)
	{
		case 'ThrowGrenade':
			if (UnitState.AffectedByEffectNames.Find('RapidDeploymentEffect') != -1)
			{
				/*
				if (class'X2Effect_RapidDeployment'.default.VALID_GRENADE_TYPES.Find(WeaponState.GetMyTemplateName()) != -1)
				{
					IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_FREE;
					Changed = true;
				}
				*/
			}
			break;
		case 'LaunchGrenade':
			if (UnitState.AffectedByEffectNames.Find('RapidDeploymentEffect') != -1)
			{
				/*
				if (class'X2Effect_RapidDeployment'.default.VALID_GRENADE_TYPES.Find(WeaponState.GetLoadedAmmoTemplate(AbilityState).DataName) != -1)
				{
					IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_FREE;
					Changed = true;
				}
				*/
			}
			break;
		case 'LWFlamethrower':
		case 'Roust':
		case 'Firestorm':
			if (UnitState.AffectedByEffectNames.Find('QuickburnEffect') != -1)
			{
					IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_FREE;
					Changed = true;
			}
			break;
		case 'Reload':
			WeaponUpgrades = WeaponState.GetMyWeaponUpgradeTemplates();
			for (k = 0; k < WeaponUpgrades.Length; k++)
			{
				if (WeaponUpgrades[k].NumFreeReloads > 0)
				{
					UnitState.GetUnitValue ('FreeReload', FreeReloadValue);
					if (FreeReloadValue.fValue < WeaponUpgrades[k].NumFreeReloads)
					{
						IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_FREE;
						Changed = true;
					}
					break;
				}
			}
			break;
		case 'PistolStandardShot':
		case 'ClutchShot':
			if (UnitState.HasSoldierAbility('Quickdraw'))
			{
				IconColor = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_1;
				Changed = true;
			}
			break;
		case 'PlaceEvacZone':
		case 'PlaceDelayedEvacZone':
			`LWTRACE ("Attempting to change EVAC color");
			class'XComGameState_BattleData'.static.HighlightObjectiveAbility(AbilityName, true);
			return ELR_NoInterrupt;
			break;
		default: break;
	}

	if (Changed)
	{
		OverrideTuple.Data[0].s = IconColor;
	}
	else
	{
		OverrideTuple.Data[0].s = class'Override_TemplateMods_ModifyAbilities'.static.GetIconColorByActionPoints(AbilityTemplate);
	}

	return ELR_NoInterrupt;
}

// OnOverrideObjectiveAbilityIconColor (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnOverrideObjectiveAbilityIconColor (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple				OverrideTuple;
	//local Name						AbilityName;
	local XComGameState_Ability		AbilityState;
	//local X2AbilityTemplate			AbilityTemplate;

	OverrideTuple = XComLWTuple(EventData);
	AbilityState = XComGameState_Ability (EventSource);
	if (AbilityState == none)
	{
		`LWTRACE ("No ability state fed to OnOverrideObjectiveAbilityIconColor");
		return ELR_NoInterrupt;
	}

	//AbilityTemplate = AbilityState.GetMyTemplate();
	//AbilityName = AbilityState.GetMyTemplateName();

	//`LOG ("CHECKING Objective icon color for" @ AbilityName);

	if(OverrideTuple == none)
	{
		`REDSCREEN("OnOverrideAbilityIconColor event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	if (class'Override_TemplateMods_ModifyAbilities'.default.USE_ACTION_ICON_COLORS)
	{
		OverrideTuple.Data[0].b = true;
		OverrideTuple.Data[1].s = class'Override_TemplateMods_ModifyAbilities'.default.ICON_COLOR_OBJECTIVE;
		//`LOG ("Changing Objective icon color for" @ AbilityName @ "to" @ OverrideTuple.Data[1].s);
	}
	return ELR_NoInterrupt;
}

// GetPCSImage(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn GetPCSImage(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple			OverridePCSImageTuple;
	local string				ReturnImagePath;
	local XComGameState_Item	ItemState;
	//local UIUtilities_Image		Utility;

	OverridePCSImageTuple = XComLWTuple(EventData);
	if(OverridePCSImageTuple == none)
	{
		`REDSCREEN("OverrideGetPCSImage event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//`LOG("OverridePCSImageTuple : Parsed XComLWTuple.");

	ItemState = XComGameState_Item(EventSource);
	if(ItemState == none)
		return ELR_NoInterrupt;
	//`LOG("OverridePCSImageTuple : EventSource valid.");

	if(OverridePCSImageTuple.Id != 'OverrideGetPCSImage')
		return ELR_NoInterrupt;

	switch (ItemState.GetMyTemplateName())
	{
		case 'DepthPerceptionPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_depthperception"; break;
		case 'HyperReactivePupilsPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_hyperreactivepupils"; break;
		case 'CombatAwarenessPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_threatassessment"; break;
		case 'DamageControlPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_damagecontrol"; break;
		case 'AbsorptionFieldsPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_impactfield"; break;
		case 'BodyShieldPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_bodyshield"; break;
		case 'EmergencyLifeSupportPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_emergencylifesupport"; break;
		case 'IronSkinPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_ironskin"; break;
		case 'SmartMacrophagesPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_smartmacrophages"; break;
		case 'CombatRushPCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_combatrush"; break;
		case 'CommonPCSDefense': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_defense"; break;
		case 'RarePCSDefense': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_defense"; break;
		case 'EpicPCSDefense': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_defense"; break;
		case 'CommonPCSAgility': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_dodge"; break;
		case 'RarePCSAgility': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_dodge"; break;
		case 'EpicPCSAgility': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_dodge"; break;
		case 'CommonPCSHacking': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_hacking"; break;
		case 'RarePCSHacking': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_hacking"; break;
		case 'EpicPCSHacking': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_hacking"; break;
		case 'FireControl25PCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_firecontrol"; break;
		case 'FireControl50PCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_firecontrol"; break;
		case 'FireControl75PCS': OverridePCSImageTuple.Data[0].b = true; OverridePCSImageTuple.Data[1].s = "img:///UILibrary_LW_Overhaul.implants_firecontrol"; break;

		default:  OverridePCSImageTuple.Data[0].b = false;
	}
	ReturnImagePath = OverridePCSImageTuple.Data[1].s;  // anything set by any other listener that went first
	ReturnImagePath = ReturnImagePath;

	//`LOG("GetPCSImage Override : working!.");

	return ELR_NoInterrupt;
}

// OnRegionBuiltOutpost(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnRegionBuiltOutpost(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComGameStateHistory History;
    local XComGameState_WorldRegion Region;
    local XComGameState NewGameState;

    History = `XCOMHISTORY;
    foreach History.IterateByClassType(class'XComGameState_WorldRegion', Region)
    {
        // Look for regions that have an outpost built, which have their "bScanforOutpost" flag reset
        // (this is cleared by XCGS_WorldRegion.Update() when the scan finishes) and the scan has begun.
        // For these regions, reset the scan. This will reset the scanner UI to "empty". The reset
        // call will reset the scan started flag so subsequent triggers will not redo this change
        // for this region.
        if (Region.ResistanceLevel == eResLevel_Outpost &&
            !Region.bCanScanForOutpost &&
            Region.GetScanPercentComplete() > 0)
        {
            NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Reset outpost scanner");
            Region = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', Region.ObjectID));
            NewGameState.AddStateObject(Region);
            Region.ResetScan();
            `GAMERULES.SubmitGameState(NewGameState);
        }
    }

    return ELR_NoInterrupt;
}

// OnGetLWVersion(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
// Allow mods to query the LW version number. Trigger the 'GetLWVersion' event with an empty tuple as the eventdata and it will
// return a 3-tuple of ints with Data[0]=Major, Data[1]=Minor, and Data[2]=Build.
function EventListenerReturn OnGetLWVersion(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComLWTuple Tuple;
    local int Major, Minor, Build;
    Tuple = XComLWTuple(EventData);
    if (Tuple == none)
    {
        return ELR_NoInterrupt;
    }

    class'LWOTC_Version'.static.GetVersionNumber(Major, Minor, Build);
    Tuple.Data.Add(3);
    Tuple.Data[0].Kind = XComLWTVInt;
    Tuple.Data[0].i = Major;
    Tuple.Data[1].Kind = XComLWTVInt;
    Tuple.Data[1].i = Minor;
    Tuple.Data[2].Kind = XComLWTVInt;
    Tuple.Data[2].i = Build;

    return ELR_NoInterrupt;
}

// OnUFOSetInfiltrationTime(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
// Override how the UFO interception works, since we don't use the calendar
function EventListenerReturn OnUFOSetInfiltrationTime(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComGameState_UFO UFO;
	local int HoursUntilIntercept;

    UFO = XComGameState_UFO(EventData);
    if (UFO == none)
    {
        return ELR_NoInterrupt;
    }

	if (UFO.bDoesInterceptionSucceed)
	{
		UFO.InterceptionTime == UFO.GetCurrentTime();

		HoursUntilIntercept = (UFO.MinNonInterceptDays * 24) + `SYNC_RAND((UFO.MaxNonInterceptDays * 24) - (UFO.MinNonInterceptDays * 24) + 1);
		class'X2StrategyGameRulesetDataStructures'.static.AddHours(UFO.InterceptionTime, HoursUntilIntercept);
	}

    return ELR_NoInterrupt;
}

// GetUnitValue(XComGameState_Unit UnitState, Name ValueName)
function float GetUnitValue(XComGameState_Unit UnitState, Name ValueName)
{
	local UnitValue Value;

	Value.fValue = 0.0;
	UnitState.GetUnitValue(ValueName, Value);
	return Value.fValue;
}

// -------------- ORPHANED CODE ---------------------

// OnGetSupplyDrop(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
// Fetch the true supply reward for a region. This only gets the value, it doesn't reset the accumulated pool to zero.
function EventListenerReturn OnGetSupplyDrop(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	/*
    local XComGameState_WorldRegion Region;
    local XComGameState_LWOutpostManager OutpostMgr;
    local XComGameState_LWOutpost Outpost;
    local XComLWTuple Tuple;
    local XComLWTValue Value;

    Tuple = XComLWTuple(EventData);
    Region = XComGameState_WorldRegion(EventSource);

    if (Tuple == none || Tuple.Id != 'GetSupplyDropReward' || Tuple.Data.Length > 0)
    {
        // Either this is a tuple we don't recognize or some other mod got here first and defined the reward. Just return.
        return ELR_NoInterrupt;
    }

    OutpostMgr = `LWOUTPOSTMGR;
    Outpost = OutpostMgr.GetOutpostForRegion(Region);
    Value.Kind = XComLWTVInt;
    Value.i = Outpost.GetIncomePoolForJob('Resupply');
    Tuple.Data.AddItem(Value);
	*/
    return ELR_NoInterrupt;
}

// OnOverrideReinforcementsAlert(Object EventData, Object EventSource, XComGameState GameState, Name InEventID)
// This sets a flag that skips the automatic alert placed on the squad when reinfs land.
function EventListenerReturn OnOverrideReinforcementsAlert(Object EventData, Object EventSource, XComGameState GameState, Name InEventID)
{
	/*
	local XComLWTuple Tuple;
	local XComGameState_Player PlayerState;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
	{
		return ELR_NoInterrupt;
	}

	PlayerState = class'Utilities_LWOTC'.static.FindPlayer(eTeam_XCom);
	Tuple.Data[0].b = PlayerState.bSquadIsConcealed;
	*/
	return ELR_NoInterrupt;
}
