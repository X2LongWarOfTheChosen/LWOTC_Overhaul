//---------------------------------------------------------------------------------------
//  FILE:    Utilities_LW
//  AUTHOR:  tracktwo (Pavonis Interactive)
//
//  PURPOSE: Miscellaneous helper routines.
//--------------------------------------------------------------------------------------- 

class Utilities_LWOTC extends Object dependson(X2StrategyElement_DefaultAlienActivities);

function static XComGameState_Unit CreateProxyUnit(XComGameState_Unit OriginalUnit, Name ProxyTemplateName, bool GiveAbilities, XComGameState NewGameState, optional Name Loadout)
{
    local XComGameState_Unit ProxyUnit;
	local X2CharacterTemplate ProxyTemplate;
    local X2CharacterTemplateManager TemplateManager;
	local XComGameState_LWToolboxOptions ToolboxOptions;
	local bool bEnabled;

    TemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	ProxyTemplate = TemplateManager.FindCharacterTemplate(ProxyTemplateName);

	ProxyUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit'));
	NewGameState.AddStateObject(ProxyUnit);
	ProxyUnit.OnCreation(ProxyTemplate);
	ProxyUnit.SetTAppearance(OriginalUnit.kAppearance);
	ProxyUnit.SetUnitName(OriginalUnit.GetFirstName(), OriginalUnit.GetLastName(), OriginalUnit.GetNickName());
    if (Loadout != '')
        ProxyUnit.ApplyInventoryLoadout(NewGameState, Loadout);
    if (GiveAbilities)
        ProxyUnit.AWCAbilities = OriginalUnit.AWCAbilities;

    // Apply NCE if necessary
	ToolboxOptions = class'XComGameState_LWToolboxOptions'.static.GetToolboxOptions();
	if (ToolboxOptions != none)
	{
		bEnabled = ToolboxOptions.bRandomizedInitialStatsEnabled;
	}
	if (bEnabled)
	{
		ApplyRandomizedInitialStatsToProxyUnit (bEnabled, ProxyUnit, OriginalUnit, NewGameState);
	}

	return ProxyUnit;
}

function static ApplyRandomizedInitialStatsToProxyUnit (bool bEnabled, XComGameState_Unit ProxyUnit, XComGameState_Unit OriginalUnit , XComGameState NewGameState)
{
	local XComGameState_Unit_LWRandomizedStats RandomizedStatsState, SearchRandomizedStats, ProxyRandomizedStatsState;
    local XComGameState_Unit UpdatedOriginalUnit;

	//first look in the supplied gamestate
	foreach NewGameState.IterateByClassType(class'XComGameState_Unit_LWRandomizedStats', SearchRandomizedStats)
	{
		if(SearchRandomizedStats.OwningObjectID == OriginalUnit.ObjectID)
		{
			RandomizedStatsState = SearchRandomizedStats;
			break;
		}
	}
	if(RandomizedStatsState == none)
	{
		//try and pull it from the history
		RandomizedStatsState = XComGameState_Unit_LWRandomizedStats(OriginalUnit.FindComponentObject(class'XComGameState_Unit_LWRandomizedStats'));
		if(RandomizedStatsState != none)
		{
			//if found in history, create an update copy for submission
			RandomizedStatsState = XComGameState_Unit_LWRandomizedStats(NewGameState.CreateStateObject(RandomizedStatsState.Class, RandomizedStatsState.ObjectID));
			NewGameState.AddStateObject(RandomizedStatsState);
		}
	}
	if(RandomizedStatsState == none)
	{
		//first time randomizing, create component gamestate and attach it
		RandomizedStatsState = XComGameState_Unit_LWRandomizedStats(NewGameState.CreateStateObject(class'XComGameState_Unit_LWRandomizedStats'));
		NewGameState.AddStateObject(RandomizedStatsState);

		UpdatedOriginalUnit = XComGameState_Unit(NewGameState.GetGameStateForObjectID(OriginalUnit.ObjectID));
		if (UpdatedOriginalUnit == none)
		{
			UpdatedOriginalUnit = XComGameState_Unit(NewGameState.CreateStateObject(OriginalUnit.Class, OriginalUnit.ObjectID));
			NewGameState.AddStateObject (UpdatedOriginalUnit);
			UpdatedOriginalUnit.AddComponentObject(RandomizedStatsState);
		}
	}
	ProxyRandomizedStatsState = XComGameState_Unit_LWRandomizedStats(NewGameState.CreateStateObject(RandomizedStatsState.Class, RandomizedStatsState.ObjectID));
	NewGameState.AddStateObject (ProxyRandomizedStatsState);
	ProxyUnit.AddComponentObject (ProxyRandomizedStatsState);
	ProxyRandomizedStatsState.bInitialStatsApplied = false; // hardwire here to avoid the compatibility checking used for regular units
	ProxyRandomizedStatsState.ApplyRandomInitialStats(ProxyUnit, bEnabled);

	ProxyUnit.HighestHP = ProxyUnit.GetCurrentStat(eStat_HP);
}

function static string CurrentMissionType()
{
    local XComGameStateHistory History;
    local XComGameState_BattleData BattleData;
    local GeneratedMissionData GeneratedMission;
    local XComGameState_HeadquartersXCom XComHQ;

    History = `XCOMHISTORY;
    XComHQ = `XCOMHQ;

    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    GeneratedMission = XComHQ.GetGeneratedMissionData(BattleData.m_iMissionID);
    if (GeneratedMission.Mission.sType == "")
    {
        // No mission type set. This is probably a tactical quicklaunch.
        return `TACTICALMISSIONMGR.arrMissions[BattleData.m_iMissionType].sType;
    }

    return GeneratedMission.Mission.sType;
}

// Is this an evac-only mission? All mission types except 'no evac' and 'escape' missions are.
function static bool IsEvacMission()
{
	return class'UIUtilities_LW'.default.EvacFlareEscapeMissions.Find(Name(class'Utilities_LW'.static.CurrentMissionType())) == -1 &&
			 class'UIUtilities_LW'.default.NoEvacMissions.Find(Name(class'Utilities_LW'.static.CurrentMissionType())) == -1;
}

function static string CurrentMissionFamily()
{
    local XComGameStateHistory History;
    local XComGameState_BattleData BattleData;
    local GeneratedMissionData GeneratedMission;
    local XComGameState_HeadquartersXCom XComHQ;

    History = `XCOMHISTORY;
    XComHQ = `XCOMHQ;

    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    GeneratedMission = XComHQ.GetGeneratedMissionData(BattleData.m_iMissionID);
    if (GeneratedMission.Mission.MissionFamily == "")
    {
        // No mission type set. This is probably a tactical quicklaunch.
        return `TACTICALMISSIONMGR.arrMissions[BattleData.m_iMissionType].MissionFamily;
    }

    return GeneratedMission.Mission.MissionFamily;
}


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
    idx = class'X2StrategyElement_DefaultAlienActivities'.default.MissionSettings.Find('MissionOrFamilyName', MissionName);
	if(idx != -1)
    {
		Settings = class'X2StrategyElement_DefaultAlienActivities'.default.MissionSettings[idx];
        return true;
    }

    // Failing that, look for the family name.
	idx = class'X2StrategyElement_DefaultAlienActivities'.default.MissionSettings.Find('MissionOrFamilyName', name(MissionFamilyName));
	if(idx != -1)
	{
		Settings = class'X2StrategyElement_DefaultAlienActivities'.default.MissionSettings[idx];
        return true;
    }

    // Neither
    `redscreen("GetMissionSettings: No entry for " $ MissionName $ " / " $ MissionFamilyName);
    return false;
}

function static bool CurrentMissionIsRetaliation()
{
    local String MissionType;

    MissionType = CurrentMissionType();
    return (MissionType == "Terror_LW" || MissionType == "Invasion_LW" || MissionType=="Defend_LW");
}

// Attempt to find a tile near the given tile to spawn a unit. Will attempt one within "FirstRange"
// radius first, and then "SecondRange" if it fails to locate one. Returns false if we can't find a tile.
function static bool GetSpawnTileNearTile(out TTile Tile, int FirstRange, int SecondRange)
{
    local XComWorldData WorldData;
    local array<TTile> TilePossibilities;

    WorldData = `XWORLD;
    // Try to find a valid tile near the randomly chosen tile, and spawn there.
    WorldData.GetSpawnTilePossibilities(Tile, FirstRange, FirstRange, FirstRange, TilePossibilities);
    class'Utilities_LW'.static.RemoveInvalidTiles(TilePossibilities);

    if (TilePossibilities.Length == 0) 
    {
        // Try again, widening the search quite a bit
        WorldData.GetSpawnTilePossibilities(Tile, SecondRange, SecondRange, SecondRange, TilePossibilities);
        class'Utilities_LW'.static.RemoveInvalidTiles(TilePossibilities);
    }

    if (TilePossibilities.Length != 0)
    {
        Tile = TilePossibilities[`SYNC_RAND_STATIC(TilePossibilities.Length)];
        return true;
    }

    // Still no good!
    `LWDebug("*** Failed to find a valid position for unit");
    return false;
}


function static RemoveInvalidTiles(out array<TTile> Tiles)
{
    local XComWorldData WorldData;
    local TTile Tile;
    local int i;

    WorldData = `XWORLD;
    i = 0;
    while (i < Tiles.Length)
    {
        Tile = Tiles[i];
        if (WorldData.IsTileOutOfRange(Tile))
        {
            Tiles.Remove(i, 1);
        }
        else
        {
            ++i;
        }
    }
}

function static XComGameState_Player FindPlayer(ETeam team)
{
    local XComGameState_Player PlayerState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Player', PlayerState)
    {
        if(PlayerState.GetTeam() == team)
        {
            return PlayerState;
        }
    }

    return none;
}

static function ApplyLoadout(XComGameState_Unit Unit, name UseLoadoutName, XComGameState ModifyGameState)
{
	local X2ItemTemplateManager ItemTemplateManager;
	local InventoryLoadout Loadout;
	local InventoryLoadoutItem LoadoutItem;
	local bool bFoundLoadout;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComGameState_Item NewItem;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach ItemTemplateManager.Loadouts(Loadout)
	{
		if (Loadout.LoadoutName == UseLoadoutName)
		{
			bFoundLoadout = true;
			break;
		}
	}

	if (bFoundLoadout)
	{
		foreach Loadout.Items(LoadoutItem)
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemTemplateManager.FindItemTemplate(LoadoutItem.Item));
			if (EquipmentTemplate != none)
			{
				NewItem = EquipmentTemplate.CreateInstanceFromTemplate(ModifyGameState);

				//Transfer settings that were configured in the character pool with respect to the weapon. Should only be applied here
				//where we are handing out generic weapons.
				if(EquipmentTemplate.InventorySlot == eInvSlot_PrimaryWeapon || EquipmentTemplate.InventorySlot == eInvSlot_SecondaryWeapon)
				{
					NewItem.WeaponAppearance.iWeaponTint = Unit.kAppearance.iWeaponTint;
					NewItem.WeaponAppearance.nmWeaponPattern = Unit.kAppearance.nmWeaponPattern;
				}

				Unit.AddItemToInventory(NewItem, EquipmentTemplate.InventorySlot, ModifyGameState);
				ModifyGameState.AddStateObject(NewItem);
			}
		}
	}
}

// Create a soldier proxy for the given rebel, set them as on-mission, and give them a loadout. All done within the
// provided game state.
function static XComGameState_Unit CreateRebelSoldier(StateObjectReference RebelRef, StateObjectReference OutpostRef, XComGameState NewGameState, optional name Loadout)
{
    local XComGameState_LWOutpost Outpost;
    local XComGameState_Unit Proxy;
    local Name TemplateName;
	local int LaserChance, MagChance, iRand;
	local string LoadoutStr;

   
    Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));
    switch(Outpost.GetRebelLevel(RebelRef))
    {
        case 0:
            TemplateName = 'RebelSoldierProxy';
            break;
        case 1:
            TemplateName = 'RebelSoldierProxyM2';
            break;
        case 2:
            TemplateName = 'RebelSoldierProxyM3';
            break;
        default:
            `Redscreen("CreateRebelSoldier: Unsupported rebel level " $ Outpost.GetRebelLevel(RebelRef));
            TemplateName = 'RebelSoldierProxy';
    }

    Proxy = CreateRebelProxy(RebelRef, OutpostRef, TemplateName, true, NewGameState);
    Proxy.SetSoldierClassTemplate('LWS_RebelSoldier');

	LaserChance = 0;
	MagChance = 0;
	
    if (Loadout == '')
	{
        LoadoutStr = "RebelSoldier";
		if (class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('MagnetizedWeapons') && class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('AdvancedLasers'))
		{
			LaserChance += (20 * (Outpost.GetRebelLevel(RebelRef) + 1)); // 20/40/60
		}
		if (class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('GaussWeapons') && class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('AdvancedLasers'))
		{
			LaserChance += (20 * (Outpost.GetRebelLevel(RebelRef) + 1)); // 40/80/100
		}
		if (class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('Coilguns') && class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('GaussWeapons'))
		{
			if (class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('AdvancedLasers'))
			{
				LaserChance = 100;
			}
			MagChance += (20 * (Outpost.GetRebelLevel(RebelRef) + 1)); //20/40/60
		}
		if (class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('AdvancedCoilguns') && class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('GaussWeapons'))
		{
			MagChance += (20 * (Outpost.GetRebelLevel(RebelRef) + 1)); //40/80/100
		}
		if (class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('PlasmaRifle') && class'UIUtilities_Strategy'.static.GetXComHQ().IsTechResearched('GaussWeapons'))
		{
			MagChance += (20 * (Outpost.GetRebelLevel(RebelRef) + 1)); //60/100/100
		}
		if (`SYNC_RAND_STATIC(100) < MagChance)
		{
			LoadoutStr $= "3";
		}
		else
		{
			if (`SYNC_RAND_STATIC(100) < LaserChance)
			{
				LoadoutStr $= "2";
			}
		}
		iRand = `SYNC_RAND_STATIC(100);
		if (iRand < 20)
		{
			LoadoutStr $= "SMG";
		}
		else
		{
			if (iRand < 40 && Outpost.GetRebelLevel(RebelRef) < 2)
			{
				LoadoutStr $= "Shotgun";
			}
		}
		//`LWTRACE ("Rebel Loadout" @ LoadoutStr);
		Loadout = name(LoadOutStr);
	}

    ApplyLoadout(Proxy, Loadout, NewGameState);

    return Proxy;
}

// Create a rebel proxy for the given unit and set them on mission in the given
// game state. Does not copy over abilities, so this can be used to create
// civilian rebels in the required missions
// (retaliations/invasions/jailbreaks/defends/recruitraids) without redscreens
// regarding trying to add abilities without a primary weapon equipped.
function static XComGameState_Unit CreateRebelProxy(StateObjectReference RebelRef, 
                                                    StateObjectReference OutpostRef, 
                                                    Name TemplateName, 
                                                    bool GiveAbilities,
                                                    XComGameState NewGameState)
{
    local XComGameStateHistory History;
    local XComGameState_LWOutpost Outpost;
    local XComGameState_Unit Unit;
    local XComGameState_Unit Proxy;

    History = `XCOMHISTORY;
    Outpost = XComGameState_LWOutpost(NewGameState.GetGameStateForObjectID(OutpostRef.ObjectID));
    if (Outpost == none)
    {
        Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', OutpostRef.ObjectID));
        NewGameState.AddStateObject(Outpost);
    }

    Unit = XComGameState_Unit(History.GetGameStateForObjectID(RebelRef.ObjectID));
    `LWTrace("Creating proxy for " $ Unit.GetFullName() $ " with template " $ TemplateName);
    Proxy = CreateProxyUnit(Unit, TemplateName, GiveAbilities, NewGameState);
    NewGameState.AddStateObject(Proxy);
    Outpost.SetRebelProxy(Unit.GetReference(), Proxy.GetReference());
    Outpost.SetRebelOnMission(Unit.GetReference());

    return Proxy;
}

// Create a soldier proxy for the given rebel, set them as on-mission, and give them a loadout. Must be called from within
// a tactical mission: this function will add them to the mission via a UnitAdded tactical change.
function static XComGameState_Unit AddRebelSoldierToMission(StateObjectReference RebelRef, StateObjectReference OutpostRef, out TTile Tile, optional name Loadout)
{
    local XComGameStateContext_TacticalGameRule NewGameStateContext;
    local XComGameState NewGameState;
    local XComGameState_Unit Proxy;
    local XComGameState_Player Player;
    local X2TacticalGameRuleset Rules;
    local XComGameStateHistory History;
   
    Rules = `TACTICALRULES;
    History = `XCOMHISTORY;
    NewGameStateContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitAdded);
    NewGameState = History.CreateNewGameState(true, NewGameStateContext);
    Proxy = CreateRebelSoldier(RebelRef, OutpostRef, NewGameState, Loadout);
    Proxy.SetVisibilityLocation(Tile);
    Player = FindPlayer(eTeam_XCom);
    Proxy.SetControllingPlayer(Player.GetReference());
    Rules.InitializeUnitAbilities(NewGameState, Proxy);
    class'XGUnit'.static.CreateVisualizer(NewGameState, Proxy, Player, none);
    XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Proxy.GetReference();
	Rules.SubmitGameState(NewGameState);
    Proxy.OnBeginTacticalPlay();
    return Proxy;
}

// Create a (usually civilian) proxy for the given rebel, set them as
// on-mission. Must be called from within a tactical mission. This function
// will add them to the given game state (if provided), which should be within
// a XComGameStateContext_TacticalGameRule context for eGameRule_UnitAdded. If
// no game state is provided one is created and submitted internal to this
// function.
//
// May provide both a template to use for the proxy (generally 'Rebel' or
// 'FacelessRebelProxy'), and optionally can provide a team to assign them to.
function static XComGameState_Unit AddRebelToMission(StateObjectReference RebelRef, 
                                                     StateObjectReference OutpostRef, 
                                                     Name TemplateName, 
                                                     out TTile Tile, 
                                                     optional ETeam team = eTeam_XCom, 
                                                     optional XComGameState NewGameState)
{
    local XComGameStateContext_TacticalGameRule NewGameStateContext;
    local XComGameState_Unit Proxy;
    local XComGameState_Player Player;
    local X2TacticalGameRuleset Rules;
    local XComGameStateHistory History;
    local bool SubmitGameState;

    Rules = `TACTICALRULES;
    History = `XCOMHISTORY;

    if (NewGameState == none)
    {
        NewGameStateContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitAdded);
        NewGameState = History.CreateNewGameState(true, NewGameStateContext);
        SubmitGameState = true;
    }

    // These rebels are civvies, but give them their abilities anyway (some are defensive).
    Proxy = CreateRebelProxy(RebelRef, OutpostRef, TemplateName, true, NewGameState);
    Proxy.SetVisibilityLocation(Tile);
    Player = FindPlayer(Team);
    Proxy.SetControllingPlayer(Player.GetReference());
    
    if (Team == eTeam_Alien)
    {
        XGAIPlayer(XGBattle_SP(`BATTLE).GetAIPlayer()).AddNewSpawnAIData(NewGameState);
    }

    Rules.InitializeUnitAbilities(NewGameState, Proxy);
    class'XGUnit'.static.CreateVisualizer(NewGameState, Proxy, Player, none);
    XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Proxy.GetReference();

    if (SubmitGameState)
    {
	    Rules.SubmitGameState(NewGameState);
    }
    Proxy.OnBeginTacticalPlay();
    return Proxy;
}

