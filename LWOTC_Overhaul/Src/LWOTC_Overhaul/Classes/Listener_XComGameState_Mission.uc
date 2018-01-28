class Listener_XComGameState_Mission extends Object config(LWOTC_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct ClassMissionExperienceWeighting
{
	var name SoldierClass;
	var float MissionExperienceWeight;
};

struct MinimumInfilForConcealEntry
{
	var string MissionType;
	var float MinInfiltration;
};

var localized string strTimeRemainingHoursOnly;
var localized string strTimeRemainingDaysAndHours;
var localized string ResistanceHQBodyText;

var config float DEFAULT_MISSION_EXPERIENCE_WEIGHT;
var config array<ClassMissionExperienceWeighting> CLASS_MISSION_EXPERIENCE_WEIGHTS;
var config float MAX_RATIO_MISSION_XP_ON_FAILED_MISSION;
var config int SQUAD_SIZE_MIN_FOR_XP_CALCS;
var config float TOP_RANK_XP_TRANSFER_FRACTION;

var config array<MinimumInfilForConcealEntry> MINIMUM_INFIL_FOR_CONCEAL;

function InitListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	//Special First Mission Icon handling -- only for replacing the Resistance HQ icon functionality
	EventMgr.RegisterForEvent(ThisObj, 'OnInsertFirstMissionIcon', OnInsertFirstMissionIcon, ELD_Immediate,,,true);
	//Mission Icon handling -- several sub events handled under this one
	EventMgr.RegisterForEvent(ThisObj, 'OverrideMissionIcon', OnOverrideMissionIcon, ELD_Immediate,,,true);
	 //activity-related listeners
 	EventMgr.RegisterForEvent(ThisObj, 'OnMissionSelectedUI', SelectMissionUIListener,,,,true);
	//xp system modifications -- handles assigning of mission "encounters" as well as adding to effective kills based on the value
	EventMgr.RegisterForEvent(ThisObj, 'OnDistributeTacticalGameEndXP', OnAddMissionEncountersToUnits, ELD_OnStateSubmitted,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'GetNumKillsForRankUpSoldier', OnGetNumKillsForMissionEncounters, ELD_Immediate,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'ShouldShowPromoteIcon', OnCheckForPsiPromotion, ELD_Immediate,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'XpKillShot', OnRewardKillXp, ELD_Immediate,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'OverrideCollectorActivation', OverrideCollectorActivation, ELD_Immediate,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'OverrideScavengerActivation', OverrideScavengerActivation, ELD_Immediate,,,true);
	// Mission summary civilian counts
    EventMgr.RegisterForEvent(ThisObj, 'GetNumCiviliansKilled', OnNumCiviliansKilled, ELD_Immediate,,,true);
	// listener for when squad conceal is set
	EventMgr.RegisterForEvent(ThisObj, 'OnSetMissionConceal', CheckForConcealOverride, ELD_Immediate,,, true);
	//listener to interrupt OnSkyrangerArrives to not play narrative event -- we will manually trigger it when appropriate in screen listener
	EventMgr.RegisterForEvent(ThisObj, 'OnSkyrangerArrives', OnSkyrangerArrives, ELD_OnStateSubmitted, 100,,true);
	// Evac timer modifiers -- modifiers for squad size, infiltration status, number of concurrent missions
	EventMgr.RegisterForEvent(ThisObj, 'GetEvacPlacementDelay', OnPlacedDelayedEvacZone, ELD_Immediate,,,true);
	// listener for turn change
	EventMgr.RegisterForEvent(ThisObj, 'PlayerTurnBegun', LW2OnPlayerTurnBegun);
	// Tactical mission cleanup hook
    EventMgr.RegisterForEvent(ThisObj, 'CleanupTacticalMission', OnCleanupTacticalMission, ELD_Immediate,,, true);
    // VIP Recovery screen
    EventMgr.RegisterForEvent(ThisObj, 'GetRewardVIPStatus', OnGetRewardVIPStatus, ELD_Immediate,,, true);
}

// OnInsertFirstMissionIcon(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnInsertFirstMissionIcon(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple Tuple;
	local UIStrategyMap_MissionIcon MissionIcon;
	local UIStrategyMap StrategyMap;

	Tuple = XComLWTuple(EventData);
	if(Tuple == none)
		return ELR_NoInterrupt;

	StrategyMap = UIStrategyMap(EventSource);
	if(StrategyMap == none)
	{
		`REDSCREEN("OnInsertFirstMissionIcon event triggered with invalid event source.");
		return ELR_NoInterrupt;
	}

	MissionIcon = StrategyMap.MissionItemUI.MissionIcons[0];
	MissionIcon.LoadIcon("img:///UILibrary_StrategyImages.X2StrategyMap.MissionIcon_ResHQ");
	MissionIcon.OnClickedDelegate = SelectOutpostManager;
	MissionIcon.HideTooltip();
	MissionIcon.SetMissionIconTooltip(StrategyMap.m_ResHQLabel, ResistanceHQBodyText);

	MissionIcon.Show();

	Tuple.Data[0].b = true; // skip to the next mission icon

	return ELR_NoInterrupt;
}

// SelectOutpostManager()
function SelectOutpostManager()
{
	/*
    //local XComGameState_LWOutpostManager OutpostMgr;
	local UIResistanceManagement_LW TempScreen;
    local XComHQPresentationLayer HQPres;

    HQPres = `HQPRES;

    //OutpostMgr = class'XComGameState_LWOutpostManager'.static.GetOutpostManager();
	//OutpostMgr.GoToResistanceManagement();

    if(HQPres.ScreenStack.IsNotInStack(class'UIResistanceManagement_LW'))
    {
        TempScreen = HQPres.Spawn(class'UIResistanceManagement_LW', HQPres);
		TempScreen.EnableCameraPan = false;
        HQPres.ScreenStack.Push(TempScreen, HQPres.Get3DMovie());
    }
	*/
}

// OnOverrideMissionIcon(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnOverrideMissionIcon(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple Tuple;
	local AlienActivity_XComGameState AlienActivity;
	local UIStrategyMap_MissionIcon MissionIcon;
	local Squad_XComGameState InfiltratingSquad;
	local string Title, Body;

	Tuple = XComLWTuple(EventData);
	if(Tuple == none)
		return ELR_NoInterrupt;

	MissionIcon = UIStrategyMap_MissionIcon(EventSource);
	if(MissionIcon == none)
	{
		`REDSCREEN("OverrideMissionIcon event triggered with invalid event source.");
		return ELR_NoInterrupt;
	}

	switch (Tuple.Id)
	{
		case 'OverrideMissionIcon_MissionTooltip':
			if (Tuple.Data.Length == 0)
			{
				Tuple.Data.Add(3);
				Tuple.Data[0].Kind = XComLWTVBool;
				Tuple.Data[0].b = true; // override the base-game values
				GetMissionSiteUIButtonToolTip(Title, Body, MissionIcon);
				Tuple.Data[1].Kind = XComLWTVString;
				Tuple.Data[1].s = Title;
				Tuple.Data[2].Kind = XComLWTVString;
				Tuple.Data[2].s = Body;
			}
			break;
		case 'OverrideMissionIcon_SetMissionSite':
			InfiltratingSquad = `SQUADMGR.Squads.GetSquadOnMission(MissionIcon.MissionSite.GetReference());
			if(InfiltratingSquad != none && UIStrategyMapItem_Mission_LWOTC(MissionIcon.MapItem) != none)
			{
				MissionIcon.OnClickedDelegate = UIStrategyMapItem_Mission_LWOTC(MissionIcon.MapItem).OpenInfiltrationMissionScreen;  // UIMission_LWDelayedLaunch, to actually start it
			}
			AlienActivity = class'AlienActivity_XComGameState_Manager'.static.FindAlienActivityByMission(MissionIcon.MissionSite);
			if (AlienActivity != none )
				MissionIcon.LoadIcon(AlienActivity.UpdateMissionIcon(MissionIcon, MissionIcon.MissionSite));

			GetMissionSiteUIButtonToolTip(Title, Body, MissionIcon);
			MissionIcon.SetMissionIconTooltip(Title, Body);
			break;
		case 'OverrideMissionIcon_ScanSiteTooltip': // we don't do anything with this currently
		case 'OverrideMissionIcon_SetScanSite': // we don't do anything with this currently
		default:
			break;
	}

	return ELR_NoInterrupt;
}

// GetMissionSiteUIButtonToolTip(out string Title, out string Body, UIStrategyMap_MissionIcon MissionIcon)
function GetMissionSiteUIButtonToolTip(out string Title, out string Body, UIStrategyMap_MissionIcon MissionIcon)
{
	local Squad_XComGameState InfiltratingSquad;
	local X2MissionTemplate MissionTemplate;
	local float RemainingSeconds;
	local int Hours, Days;
	local AlienActivity_XComGameState AlienActivity;
	local XGParamTag ParamTag;
	local XComGameState_MissionSite MissionSite;

	MissionSite = MissionIcon.MissionSite;

	InfiltratingSquad = `SQUADMGR.Squads.GetSquadOnMission(MissionSite.GetReference());
	if(InfiltratingSquad != none)
	{
		Title = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(InfiltratingSquad.sSquadName);
	}
	else
	{
		MissionTemplate = class'X2MissionTemplateManager'.static.GetMissionTemplateManager().FindMissionTemplate(MissionSite.GeneratedMission.Mission.MissionName);
		Title = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(MissionTemplate.PostMissionType);
	}

	AlienActivity = class'AlienActivity_XComGameState_Manager'.static.FindAlienActivityByMission(MissionSite);
	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	if(AlienActivity != none)
		RemainingSeconds = AlienActivity.SecondsRemainingCurrentMission();
	else
		if (MissionSite.ExpirationDateTime.m_iYear >= 2050)
			RemainingSeconds = 2147483640;
		else
			RemainingSeconds = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInSeconds(MissionSite.ExpirationDateTime, class'XComGameState_GeoscapeEntity'.static.GetCurrentTime());

	Days = int(RemainingSeconds / 86400.0);
	Hours = int(RemainingSeconds / 3600.0) % 24;

	if(Days < 730)
	{
		Title $= ": ";

		ParamTag.IntValue0 = Hours;
		ParamTag.IntValue1 = Days;

		if(Days >= 1)
			Title $= `XEXPAND.ExpandString(strTimeRemainingDaysAndHours);
		else
			Title $= `XEXPAND.ExpandString(strTimeRemainingHoursOnly);
	}

	Body = MissionSite.GetMissionObjectiveText();
}

// SelectMissionUIListener(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn SelectMissionUIListener(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_MissionSite		MissionSite;
	local AlienActivity_XComGameState ActivityState;
	//local X2MissionSourceTemplate		MissionSource;

	MissionSite = XComGameState_MissionSite(EventData);
	if(MissionSite == none)
		return ELR_NoInterrupt;

	ActivityState = `ACTIVITYMGR.FindAlienActivityByMission(MissionSite);

	//MissionSource = MissionSite.GetMissionSource();
	if(ActivityState != none)
		ActivityState.TriggerMissionUI(MissionSite);

	return ELR_NoInterrupt;
}

// OnAddMissionEncountersToUnits(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnAddMissionEncountersToUnits(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_BattleData BattleState;
	local XComGameState_MissionSite MissionState;
	local XComGameStateHistory History;
	local XComGameState_XpManager XpManager;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState NewGameState;
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local array<XComGameState_Unit> UnitStates;
	local UnitValue Value, TestValue;//, Value2;
	local float MissionWeight, UnitShare, /*MissionExperienceWeighting,*/ UnitShareDivisor;
    local MissionSettings_LW Settings;
    //local XComGameState_LWOutpost Outpost;
	//local bool TBFInEffect;
	// local int TrialByFireKills, KillsNeededForLevelUp, WeightedBonusKills, idx;
	//local XComGameState_Unit_LWOfficer OfficerState;
	local X2MissionSourceTemplate MissionSource;
	local bool PlayerWonMission;

	//`LWTRACE ("OnAddMissionEncountersToUnits triggered");

	XComHQ = XComGameState_HeadquartersXCom(EventData);
	if(XComHQ == none)
		return ELR_NoInterrupt;

	XpManager = XComGameState_XpManager(EventSource);
	if(XpManager == none)
	{
		`REDSCREEN("OnAddMissionEncountersToUnits event triggered with invalid event source.");
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	BattleState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleState.m_iMissionID != XComHQ.MissionRef.ObjectID)
	{
		`REDSCREEN("LongWar: Mismatch in BattleState and XComHQ MissionRef when assigning XP");
		return ELR_NoInterrupt;
	}

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleState.m_iMissionID));
	if(MissionState == none)
		return ELR_NoInterrupt;

	MissionWeight = GetMissionWeight(History, XComHQ, BattleState, MissionState);

	//Build NewGameState change container
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add Mission Encounter Values");
	foreach XComHQ.Squad(UnitRef)
	{
		if (UnitRef.ObjectID == 0)
			continue;

		UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
		if (UnitState.IsSoldier())
		{
			NewGameState.AddStateObject(UnitState);
			UnitStates.AddItem(UnitState);
		}
		else
		{
			NewGameState.PurgeGameStateForObjectID(UnitState.ObjectID);
		}
	}

    // Include the adviser if they were on this mission too
    if (class'Utilities_LWOTC'.static.GetMissionSettings(MissionState, Settings))
    {
		/*
        if (Settings.RestrictsLiaison)
        {
            Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(MissionState.GetWorldRegion());
            UnitRef = Outpost.GetLiaison();
            if (UnitRef.ObjectID > 0)
            {
                UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
                if (UnitState.IsSoldier())
                {
                    NewGameState.AddStateObject(UnitState);
                    UnitStates.AddItem(UnitState);
                    // Set the liaison as not ranked up. This is handled in DistributeTacticalGameEndXp but only
                    // for members of the squad.
                    if (!class'X2ExperienceConfig'.default.bUseFullXpSystem)
                    {
                        UnitState.bRankedUp = false;
                    }
                }
                else
                {
                    NewGameState.PurgeGameStateForObjectID(UnitState.ObjectID);
                }
            }
        }
		*/
    }

	PlayerWonMission = true;
	MissionSource = MissionState.GetMissionSource();
	if(MissionSource.WasMissionSuccessfulFn != none)
	{
		PlayerWonMission = MissionSource.WasMissionSuccessfulFn(BattleState);
	}


	// TBFInEffect = false;

	if (PlayerWonMission)
	{
		foreach UnitStates(UnitState)
		{
			if (UnitState.IsSoldier() && !UnitState.IsDead() && !UnitState.bCaptured)
			{
				/*
				if (class'LWOfficerUtilities'.static.IsOfficer(UnitState))
				{
					if (class'LWOfficerUtilities'.static.IsHighestRankOfficerinSquad(UnitState))
					{
						OfficerState = class'LWOfficerUtilities'.static.GetOfficerComponent(UnitState);
						if (OfficerState.HasOfficerAbility('TrialByFire'))
						{
							TBFInEffect = true;
							`LWTRACE ("TBFInEffect set from" @ UnitState.GetLastName());
						}
					}
				}
				*/
			}
		}
	}

	UnitShareDivisor = UnitStates.Length;

	// Count top rank
	foreach UnitStates(UnitState)
	{
		if (UnitState.IsSoldier() && !UnitState.IsDead() && !UnitState.bCaptured)
		{
			if (UnitState.GetRank() >= class'X2ExperienceConfig'.static.GetMaxRank())
			{
				UnitShareDivisor -= default.TOP_RANK_XP_TRANSFER_FRACTION;
			}
		}
	}

	UnitShareDivisor = Max (UnitShareDivisor, default.SQUAD_SIZE_MIN_FOR_XP_CALCS);

	if (UnitShareDivisor < 1) 
		UnitShareDivisor = 1;

	UnitShare = MissionWeight / UnitShareDivisor;

	foreach UnitStates(UnitState)
	{

		// Zero out any previous value from an earlier iteration: GetUnitValue will return without zeroing
		// the out param if the value doesn't exist on the unit. If this is the first mission this unit went
		// on they will "inherit" the total XP of the unit immediately before them in the squad unless this
		// is cleared.
		Value.fValue = 0;
		UnitState.GetUnitValue('MissionExperience', Value);
		UnitState.SetUnitFloatValue('MissionExperience', UnitShare + Value.fValue, eCleanup_Never);
		UnitState.GetUnitValue('MissionExperience', TestValue);
		`LWTRACE("MissionXP: PreXp=" $ Value.fValue $ ", PostXP=" $ TestValue.fValue $ ", UnitShare=" $ UnitShare $ ", Unit=" $ UnitState.GetFullName());

		/*
		if (TBFInEffect)
		{
			if (class'LWOfficerUtilities'.static.IsOfficer(UnitState))
			{
				if (class'LWOfficerUtilities'.static.IsHighestRankOfficerinSquad(UnitState))
				{
					`LWTRACE (UnitState.GetLastName() @ "is the TBF officer.");
					continue;
				}
			}

			if (UnitState.GetRank() < class'LW_OfficerPack_Integrated.X2Ability_OfficerAbilitySet'.default.TRIAL_BY_FIRE_RANK_CAP)
			{
				idx = CLASS_MISSION_EXPERIENCE_WEIGHTS.Find('SoldierClass', UnitState.GetSoldierClassTemplateName());
				if (idx != -1)
					MissionExperienceWeighting = CLASS_MISSION_EXPERIENCE_WEIGHTS[idx].MissionExperienceWeight;
				else
					MissionExperienceWeighting = DEFAULT_MISSION_EXPERIENCE_WEIGHT;

				WeightedBonusKills = Round(Value.fValue * MissionExperienceWeighting);

				Value2.fValue = 0;
				UnitState.GetUnitValue ('OfficerBonusKills', Value2);
				TrialByFireKills = int(Value2.fValue);
				KillsNeededForLevelUp = class'X2ExperienceConfig'.static.GetRequiredKills(UnitState.GetRank() + 1);
				`LWTRACE (UnitState.GetLastName() @ "needs" @ KillsNeededForLevelUp @ "kills to level up. Base kills:" @UnitState.GetNumKills() @ "Mission Kill-eqivalents:" @  WeightedBonusKills @ "Old TBF Kills:" @ TrialByFireKills);

				// Replace tracking num kills for XP with our own custom kill tracking
				//KillsNeededForLevelUp -= UnitState.GetNumKills();
				KillsNeededForLevelUp -= GetUnitValue(UnitState, 'XpKills');
				KillsNeededForLevelUp -= Round(float(UnitState.WetWorkKills) * class'X2ExperienceConfig'.default.NumKillsBonus);
				KillsNeededForLevelUp -= UnitState.GetNumKillsFromAssists();
				KillsNeededForLevelUp -= class'X2ExperienceConfig'.static.GetRequiredKills(UnitState.StartingRank);
				KillsNeededForLevelUp -= WeightedBonusKills;
				KillsNeededForLevelUp -= TrialByFireKills;

				if (KillsNeededForLevelUp > 0)
				{
					`LWTRACE ("Granting" @ KillsNeededForLevelUp @ "TBF kills to" @ UnitState.GetLastName());
					TrialByFireKills += KillsNeededForLevelUp;
					UnitState.SetUnitFloatValue ('OfficerBonusKills', TrialByFireKills, eCleanup_Never);
					`LWTRACE (UnitState.GetLastName() @ "now has" @ TrialByFireKills @ "total TBF bonus Kills");
				}
				else
				{
					`LWTRACE (UnitState.GetLastName() @ "already ranking up so TBF has no effect.");
				}
			}
			else
			{
				`LWTRACE (UnitState.GetLastName() @ "rank too high for TBF");
			}
		}
		*/
	}
	`GAMERULES.SubmitGameState(NewGameState);
	return ELR_NoInterrupt;
}

// OnGetNumKillsForMissionEncounters(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnGetNumKillsForMissionEncounters(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit UnitState;
	local UnitValue MissionExperienceValue, OfficerBonusKillsValue;
	local float MissionExperienceWeighting;
	local int WeightedBonusKills, idx, TrialByFireKills, XpKills, UnitKills;

	Tuple = XComLWTuple(EventData);
	if(Tuple == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if(UnitState == none)
	{
		`REDSCREEN("OnGetNumKillsForMissionEncounters event triggered with invalid event source.");
		return ELR_NoInterrupt;
	}

	if (Tuple.Data[0].kind != XComLWTVInt)
		return ELR_NoInterrupt;

	UnitState.GetUnitValue('MissionExperience', MissionExperienceValue);

	idx = CLASS_MISSION_EXPERIENCE_WEIGHTS.Find('SoldierClass', UnitState.GetSoldierClassTemplateName());
	if (idx != -1)
		MissionExperienceWeighting = CLASS_MISSION_EXPERIENCE_WEIGHTS[idx].MissionExperienceWeight;
	else
		MissionExperienceWeighting = DEFAULT_MISSION_EXPERIENCE_WEIGHT;

	WeightedBonusKills = Round(MissionExperienceValue.fValue * MissionExperienceWeighting);

	//check for officer with trial by and folks under rank, give them sufficient kills to level-up

	OfficerBonusKillsValue.fValue = 0;
	UnitState.GetUnitValue ('OfficerBonusKills', OfficerBonusKillsValue);
	TrialByFireKills = int(OfficerBonusKillsValue.fValue);

	//`LWTRACE (UnitState.GetLastName() @ "has" @ WeightedBonusKills @ "bonus kills from Mission XP and" @ TrialByFireKills @ "bonus kills from Trial By Fire.");

	// We need to add in our own xp tracking and remove the unit kills
	// that are added by vanilla
	XpKills = GetUnitValue(UnitState, 'KillXp');
	UnitKills = UnitState.GetNumKills();

	Tuple.Data[0].i = WeightedBonusKills + TrialByFireKills + XpKills - UnitKills;

	return ELR_NoInterrupt;
}

// OnCheckForPsiPromotion(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnCheckForPsiPromotion(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit UnitState;

	Tuple = XComLWTuple(EventData);
	if(Tuple == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if(UnitState == none)
	{
		`REDSCREEN("OnCheckForPsiPromotion event triggered with invalid event source.");
		return ELR_NoInterrupt;
	}

	if (Tuple.Data[0].kind != XComLWTVBool)
		return ELR_NoInterrupt;

	if (UnitState.IsPsiOperative())
	{
		/* TODO
		if (class'Utilities_PP_LW'.static.CanRankUpPsiSoldier(UnitState))
		{
			Tuple.Data[0].B = true;
		}
		*/
	}
	return ELR_NoInterrupt;
}

/*  OnRewardKillXp(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
    Triggered by XpKillShot event so that we can increment the kill xp for the
	killer as long as the total gained kill xp does not exceed the number of
	enemy units that were initially spawned. */
function EventListenerReturn OnRewardKillXp(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_Unit NewUnitState;
	local XpEventData XpEvent;

	XpEvent = XpEventData(EventData);

	// Create a new unit state if we need one.
	NewUnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(XpEvent.XpEarner.ObjectID));
	if(NewUnitState == none)
	{
		NewUnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', XpEvent.XpEarner.ObjectID));
		NewGameState.AddStateObject(NewUnitState);
	}

	// Ensure we don't award xp kills beyond what was originally on the mission
	if(!KillXpIsCapped())
	{
		NewUnitState.SetUnitFloatValue('MissionKillXp', GetUnitValue(NewUnitState, 'MissionKillXp') + 1, eCleanup_BeginTactical);
		NewUnitState.SetUnitFloatValue('KillXp', GetUnitValue(NewUnitState, 'KillXp') + 1, eCleanup_Never);
	}

	return ELR_NoInterrupt;
}

// OverrideCollectorActivation(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OverrideCollectorActivation(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple OverrideActivation;

	OverrideActivation = XComLWTuple(EventData);

	if(OverrideActivation != none && OverrideActivation.Id == 'OverrideCollectorActivation' && OverrideActivation.Data[0].kind == XComLWTVBool)
	{
		OverrideActivation.Data[0].b = KillXpIsCapped();
	}

	return ELR_NoInterrupt;
}

// OverrideScavengerActivation(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OverrideScavengerActivation(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple OverrideActivation;

	OverrideActivation = XComLWTuple(EventData);

	if(OverrideActivation != none && OverrideActivation.Id == 'OverrideScavengerActivation' && OverrideActivation.Data[0].kind == XComLWTVBool)
	{
		OverrideActivation.Data[0].b = KillXpIsCapped();
	}

	return ELR_NoInterrupt;
}

// OnNumCiviliansKilled(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnNumCiviliansKilled(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
    local XComLWTuple Tuple;
    local XComLWTValue Value;
    local XGBattle_SP Battle;
    local XComGameState_BattleData BattleData;
    local array<XComGameState_Unit> arrUnits;
    local bool RequireEvac;
    local bool PostMission;
	local bool RequireTriadObjective;
    local int i, Total, Killed;
	local array<Name> TemplateFilter;

    Tuple = XComLWTuple(EventData);
    if (Tuple == none || Tuple.Id != 'GetNumCiviliansKilled' || Tuple.Data.Length > 1)
    {
        return ELR_NoInterrupt;
    }

    PostMission = Tuple.Data[0].b;

    switch(class'Utilities_LWOTC'.static.CurrentMissionType())
    {
        case "Terror_LW":
            // For terror, all neutral units are interesting, and we save anyone
            // left on the map if we win the triad objective (= sweep). Rebels left on
			// the map if sweep wasn't completed are lost.
			RequireTriadObjective = true;
            break;
        case "Defend_LW":
            // For defend, all neutral units are interesting, but we don't count
            // anyone left on the map, regardless of win.
            RequireEvac = true;
            break;
        case "Invasion_LW":
            // For invasion, we only want to consider civilians with the 'Rebel' or
            // 'FacelessRebelProxy' templates.
			TemplateFilter.AddItem('Rebel');
            break;
        case "Jailbreak_LW":
            // For jailbreak we only consider evac'd units as 'saved' regardless of whether
            // we have won or not. We also only consider units with the template 'Rebel' or
			// 'Soldier_VIP', and don't count any regular civvies in the mission.
            RequireEvac = true;
            TemplateFilter.AddItem('Rebel');
			TemplateFilter.AddItem('Soldier_VIP');
            break;
        default:
            return ELR_NoInterrupt;
    }

    Battle = XGBattle_SP(`BATTLE);
    BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

    if (Battle != None)
    {
        Battle.GetCivilianPlayer().GetOriginalUnits(arrUnits);
    }

    for (i = 0; i < arrUnits.Length; ++i)
    {
        if (arrUnits[i].GetMyTemplateName() == 'FacelessRebelProxy')
        {
            // A faceless rebel proxy: we only want to count this guy if it isn't removed from play: they can't
            // be evac'd so if they're removed they must have been revealed so we don't want to count them.
            if (arrUnits[i].bRemovedFromPlay)
            {
                arrUnits.Remove(i, 1);
                --i;
                continue;
            }
        }
        else if (TemplateFilter.Length > 0 && TemplateFilter.Find(arrUnits[i].GetMyTemplateName()) == -1)
        {
            arrUnits.Remove(i, 1);
            --i;
            continue;
        }
    }

    // Compute the number killed
    Total = arrUnits.Length;

    for (i = 0; i < Total; ++i)
    {
        if (arrUnits[i].IsDead())
        {
            ++Killed;
        }
        else if (PostMission && !arrUnits[i].bRemovedFromPlay)
        {
			// If we require the triad objective, units left behind on the map
			// are lost unless it's completed.
			if (RequireTriadObjective && !BattleData.AllTriadObjectivesCompleted())
			{
				++Killed;
			}
            // If we lose or require evac, anyone left on map is killed.
            else if (!BattleData.bLocalPlayerWon || RequireEvac)
			{
                ++Killed;
			}
        }
    }

    Value.Kind = XComLWTVInt;
    Value.i = Killed;
    Tuple.Data.AddItem(Value);

    Value.i = Total;
    Tuple.Data.AddItem(Value);

    return ELR_NoInterrupt;
}

// CheckForConcealOverride(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
// return true to override XComSquadStartsConcealed=true setting in mission schedule and have the game function as if it was false
function EventListenerReturn CheckForConcealOverride(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XCOMLWTuple						OverrideTuple;
	local XComGameState_MissionSite			MissionState;
	local Squad_XComGameState				SquadState;
	local XComGameState_BattleData			BattleData;
	local int k;

	//`LWTRACE("CheckForConcealOverride : Starting listener.");

	OverrideTuple = XCOMLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("CheckForConcealOverride event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	OverrideTuple.Data[0].b = false;

	// If within a configurable list of mission types, and infiltration below a set value, set it to true
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(BattleData.m_iMissionID));

    if (MissionState == none)
    {
        return ELR_NoInterrupt;
    }

	//`LWTRACE ("CheckForConcealOverride: Found MissionState");

	for (k = 0; k < default.MINIMUM_INFIL_FOR_CONCEAL.length; k++)
    if (MissionState.GeneratedMission.Mission.sType == MINIMUM_INFIL_FOR_CONCEAL[k].MissionType)
	{
		SquadState = `SQUADMGR.Squads.GetSquadOnMission(MissionState.GetReference());
		//`LWTRACE ("CheckForConcealOverride: Mission Type correct. Infiltration:" @ SquadState.CurrentInfiltration);
		If (SquadState.InfiltrationState.CurrentInfiltration < MINIMUM_INFIL_FOR_CONCEAL[k].MinInfiltration)
		{
			//`LWTRACE ("CheckForConcealOverride: Conditions met to start squad revealed");
			OverrideTuple.Data[0].b = true;
		}
	}
	return ELR_NoInterrupt;
}

// OnSkyrangerArrives(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnSkyrangerArrives(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	return ELR_InterruptListeners;
}

// OnPlacedDelayedEvacZone(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
//handles modification of evac timer based on various conditions
function EventListenerReturn OnPlacedDelayedEvacZone(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComLWTuple EvacDelayTuple;
	local XComGameState_HeadquartersXCom XComHQ;
	local SquadManager_XComGameState SquadMgr;
	local Squad_XComGameState Squad;
	local XComGameState_MissionSite MissionState;
	local AlienActivity_XComGameState CurrentActivity;

	EvacDelayTuple = XComLWTuple(EventData);
	if(EvacDelayTuple == none)
		return ELR_NoInterrupt;

	if(EvacDelayTuple.Id != 'DelayedEvacTurns')
		return ELR_NoInterrupt;

	if(EvacDelayTuple.Data[0].Kind != XComLWTVInt)
		return ELR_NoInterrupt;

	XComHQ = `XCOMHQ;
	SquadMgr = class'SquadManager_XComGameState'.static.GetSquadManager();
	if(SquadMgr == none)
		return ELR_NoInterrupt;

	Squad = SquadMgr.Squads.GetSquadOnMission(XComHQ.MissionRef);

	`LWTRACE("**** Evac Delay Calculations ****");
	`LWTRACE("Base Delay : " $ EvacDelayTuple.Data[0].i);

	// adjustments based on squad size
	EvacDelayTuple.Data[0].i += Squad.Soldiers.EvacDelayModifier();
	`LWTRACE("After Squadsize Adjustment : " $ EvacDelayTuple.Data[0].i);

	// adjustments based on infiltration
	EvacDelayTuple.Data[0].i += Squad.InfiltrationState.EvacDelayModifier();
	`LWTRACE("After Infiltration Adjustment : " $ EvacDelayTuple.Data[0].i);

	// adjustments based on number of active missions engaged with
	EvacDelayTuple.Data[0].i += Squad.EvacDelayModifier();
	`LWTRACE("After NumMissions Adjustment : " $ EvacDelayTuple.Data[0].i);

	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(`XCOMHQ.MissionRef.ObjectID));
	CurrentActivity = class'AlienActivity_XComGameState_Manager'.static.FindAlienActivityByMission(MissionState);

	EvacDelayTuple.Data[0].i += CurrentActivity.GetMyTemplate().MissionTree[CurrentActivity.CurrentMissionLevel].EvacModifier;

	`LWTRACE("After Activity Adjustment : " $ EvacDelayTuple.Data[0].i);

	return ELR_NoInterrupt;
}

// LW2OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn LW2OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_Player PlayerState;

	PlayerState = XComGameState_Player (EventData);
	if (PlayerState == none)
	{
		`LOG ("LW2OnPlayerTurnBegun: PlayerState Not Found");
		return ELR_NoInterrupt;
	}

	if(PlayerState.GetTeam() == eTeam_XCom)
	{
		`XEVENTMGR.TriggerEvent('XComTurnBegun', PlayerState, PlayerState);
	}
	if(PlayerSTate.GetTeam() == eTeam_Alien)
	{
		`XEVENTMGR.TriggerEvent('AlienTurnBegun', PlayerState, PlayerState);
	}

	return ELR_NoInterrupt;
}

// OnCleanupTacticalMission(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnCleanupTacticalMission(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
    local XComGameState_BattleData BattleData;
    local XComGameState_Unit Unit;
    local XComGameStateHistory History;
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;
	local bool AwardWrecks;

    History = `XCOMHISTORY;
    BattleData = XComGameState_BattleData(EventData);
    BattleData = XComGameState_BattleData(NewGameState.GetGameStateForObjectID(BattleData.ObjectID));

	// If we completed this mission with corpse recovery, you get the wreck/loot from any turret
	// left on the map as well as any Mastered unit that survived but is not eligible to be
	// transferred to a haven.
	AwardWrecks = BattleData.AllTacticalObjectivesCompleted();

    if (AwardWrecks)
    {
        // If we have completed the tactical objectives (e.g. sweep) we are collecting corpses.
        // Generate wrecks for each of the turrets left on the map that XCOM didn't kill before
        // ending the mission.
        foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
        {
            if (Unit.IsTurret() && !Unit.IsDead())
            {
                // We can't call the RollForAutoLoot() function here because we have a pending
                // gamestate with a modified BattleData already. Just add a corpse to the list
                // of pending auto loot.
                BattleData.AutoLootBucket.AddItem('CorpseAdventTurret');
            }
        }
    }

	// Handle effects that can only be performed at mission end:
	//
	// Handle full override mecs. Look for units with a full override effect that are not dead
	// or captured. This is done here instead of in an OnEffectRemoved hook, because effect removal
	// isn't fired when the mission ends on a sweep, just when they evac. Other effect cleanup
	// typically happens in UnitEndedTacticalPlay, but since we need to update the haven gamestate
	// we can't use that: we don't get a reference to the current XComGameState being submitted.
	// This works because the X2Effect_TransferMecToOutpost code sets up its own UnitRemovedFromPlay
	// event listener, overriding the standard one in XComGameState_Effect, so the effect won't get
	// removed when the unit is removed from play and we'll see it here.
	//
	// Handle Field Surgeon. We can't let the effect get stripped on evac via OnEffectRemoved because
	// the surgeon themself may die later in the mission. We need to wait til mission end and figure out
	// which effects to apply.
	//
	// Also handle units that are still living but are affected by mind-control - if this is a corpse
	// recovering mission, roll their auto-loot so that corpses etc. are granted despite them not actually
	// being killed.

	foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		if(Unit.IsAlive() && !Unit.bCaptured)
		{
			foreach Unit.AffectedByEffects(EffectRef)
			{
				EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
				if (EffectState.GetX2Effect().EffectName == class'X2Effect_TransferMecToOutpost'.default.EffectName)
				{
					X2Effect_TransferMecToOutpost(EffectState.GetX2Effect()).AddMECToOutpostIfValid(EffectState, Unit, NewGameState, AwardWrecks);
				}
				/*else if (EffectState.GetX2Effect().EffectName == class'X2Effect_FieldSurgeon'.default.EffectName)
				{
					X2Effect_FieldSurgeon(EffectState.GetX2Effect()).ApplyFieldSurgeon(EffectState, Unit, NewGameState);
				}*/
				else if (EffectState.GetX2Effect().EffectName == class'X2Effect_MindControl'.default.EffectName && AwardWrecks)
				{
					Unit.RollForAutoLoot(NewGameState);

					// Super hacks for andromedon, since only the robot drops a corpse.
					if (Unit.GetMyTemplateName() == 'Andromedon')
					{
						BattleData.AutoLootBucket.AddItem('CorpseAndromedon');
					}
				}
			}
		}
	}

    return ELR_NoInterrupt;
}

// OnGetRewardVIPStatus(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnGetRewardVIPStatus(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComLWTuple Tuple;
    local XComLWTValue Value;
    local XComGameState_Unit Unit;
    local XComGameState_MissionSite MissionSite;

    Tuple = XComLWTuple(EventData);
    // Not a tuple or already filled out?
    if (Tuple == none || Tuple.Data.Length != 1 || Tuple.Data[0].Kind != XComLWTVObject)
    {
        return ELR_NoInterrupt;
    }

    // Make sure we have a unit
    Unit = XComGameState_Unit(Tuple.Data[0].o);
    if (Unit == none)
    {
        return ELR_NoInterrupt;
    }

    // Make sure we have a mission site
    MissionSite = XComGameState_MissionSite(EventSource);
    if (MissionSite == none)
    {
        return ELR_NoInterrupt;
    }

    if (MissionSite.GeneratedMission.Mission.sType == "Jailbreak_LW")
    {
        // Jailbreak mission: Only evac'd units are considered rescued.
        // (But dead ones are still dead!)
        Value.Kind = XComLWTVInt;
        if (Unit.IsDead())
        {
            Value.i = eVIPStatus_Killed;
        }
        else
        {
            Value.i = Unit.bRemovedFromPlay ? eVIPStatus_Recovered : eVIPStatus_Lost;
        }
        Tuple.Data.AddItem(Value);
    }

    return ELR_NoInterrupt;
}

/* GetMissionWeight(XComGameStateHistory History, XComGameState_HeadquartersXCom XComHQ, XComGameState_BattleData BattleState, XComGameState_MissionSite MissionState)
 * Finds the number of aliens that should be used in determining distributed mission xp.
 * If the mission was a failure then it will scale the amount down by the ratio of the
 * number of aliens killed to the number originally on the mission, and a further configurable
 * amount.
 */
function float GetMissionWeight(XComGameStateHistory History, XComGameState_HeadquartersXCom XComHQ, XComGameState_BattleData BattleState, XComGameState_MissionSite MissionState)
{
	local X2MissionSourceTemplate MissionSource;
	local bool PlayerWonMission;
	local float fTotal;
	local int AliensSeen, AliensKilled, OrigMissionAliens;

	AliensKilled = class'UIMissionSummary'.static.GetNumEnemiesKilled(AliensSeen);
	OrigMissionAliens = GetNumEnemiesOnMission(MissionState);

	PlayerWonMission = true;
	MissionSource = MissionState.GetMissionSource();
	if(MissionSource.WasMissionSuccessfulFn != none)
	{
		PlayerWonMission = MissionSource.WasMissionSuccessfulFn(BattleState);
	}

	fTotal = float (OrigMissionAliens);

	if (!PlayerWonMission)
	{
		fTotal *= default.MAX_RATIO_MISSION_XP_ON_FAILED_MISSION * FMin (1.0, float (AliensKilled) / float(OrigMissionAliens));
	}

	return fTotal;
}

// KillXpIsCapped()
function bool KillXpIsCapped()
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState_BattleData BattleState;
	local XComGameState_MissionSite MissionState;
	local int MissionKillXp, MaxKillXp;

	History = `XCOMHISTORY;

	BattleState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if(BattleState == none)
		return false;

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleState.m_iMissionID));
	if(MissionState == none)
		return false;

	MaxKillXp = GetNumEnemiesOnMission(MissionState);

	// Get the sum of xp kills so far this mission
	MissionKillXp = 0;
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if(UnitState.IsSoldier() && UnitState.IsPlayerControlled())
			MissionKillXp += int(GetUnitValue(UnitState, 'MissionKillXp'));
	}

	return MissionKillXp >= MaxKillXp;
}

/* GetNumEnemiesOnMission(XComGameState_MissionSite MissionState)
 * Find the number of enemies that were on the original mission schedule.
 * If the mission was an RNF-only mission then it returns 8 + the region alert
 * the mission is in.
 */
function int GetNumEnemiesOnMission(XComGameState_MissionSite MissionState)
{
	local int OrigMissionAliens;
	local array<X2CharacterTemplate> UnitTemplatesThatWillSpawn;
	local XComGameState_WorldRegion Region;
	local WorldRegion_XComGameState_AlienStrategyAI RegionAI;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	MissionState.GetShadowChamberMissionInfo(OrigMissionAliens, UnitTemplatesThatWillSpawn);

	// Handle missions built primarily around RNF by granting a minimum alien count
	if (OrigMissionAliens <= 6)
	{
		Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(MissionState.Region.ObjectID));
		RegionAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region);
		OrigMissionAliens = 7 + RegionAI.LocalAlertLevel;
	}

	return OrigMissionAliens;
}

// GetUnitValue(XComGameState_Unit UnitState, Name ValueName)
function float GetUnitValue(XComGameState_Unit UnitState, Name ValueName)
{
	local UnitValue Value;

	Value.fValue = 0.0;
	UnitState.GetUnitValue(ValueName, Value);
	return Value.fValue;
}