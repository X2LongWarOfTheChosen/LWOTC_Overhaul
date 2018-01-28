class Listener_XComGameState_Units extends Object config(LWOTC_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct ToHitAdjustments
{
	var int ConditionalCritAdjust;	// reduction in bonus damage chance from it being conditional on hitting
	var int DodgeCritAdjust;		// reduction in bonus damage chance from enemy dodge
	var int DodgeHitAdjust;			// reduction in hit chance from dodge converting graze to miss
	var int FinalCritChance;
	var int FinalSuccessChance;
	var int FinalGrazeChance;
	var int FinalMissChance;
};

var localized string strCritReductionFromConditionalToHit;

var config array<float> MINIMUM_INFIL_FOR_GREEN_ALERT;

var config bool ALLOW_NEGATIVE_DODGE;
var config bool DODGE_CONVERTS_GRAZE_TO_MISS;
var config bool GUARANTEED_HIT_ABILITIES_IGNORE_GRAZE_BAND;

var config bool TIERED_RESPEC_TIMES;
var config bool AI_PATROLS_WHEN_SIGHTED_BY_HIDDEN_XCOM;

var config bool USE_ALT_BLEEDOUT_RULES;
var config int BLEEDOUT_CHANCE_BASE;
var config int DEATH_CHANCE_PER_OVERKILL_DAMAGE;

var config array<float> REFLEX_ACTION_CHANCE_YELLOW;
var config array<float> REFLEX_ACTION_CHANCE_GREEN;
var config float REFLEX_ACTION_CHANCE_REDUCTION;

var config array<float> LOW_INFILTRATION_MODIFIER_ON_REFLEX_ACTIONS;
var config array<float> HIGH_INFILTRATION_MODIFIER_ON_REFLEX_ACTIONS;

var config int PSI_SQUADDIE_BONUS_ABILITIES;
var config array<int>INITIAL_PSI_TRAINING;

const OffensiveReflexAction = 'OffensiveReflexActionPoint_LW';
const DefensiveReflexAction = 'DefensiveReflexActionPoint_LW';
const NoReflexActionUnitValue = 'NoReflexAction_LW';

// Transient helper vars for alien reflex actions. These are not persisted.
var transient int LastReflexGroupId;          // ObjectID of the last group member we processed
var transient int NumSuccessfulReflexActions; // The number of successful reflex actions we've added for the current pod

function InitListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	//to hit
	EventMgr.RegisterForEvent(ThisObj, 'OnFinalizeHitChance', ToHitOverrideListener,,,,true);
	// Override KilledbyExplosion variable to conditionally allow loot to survive
	EventMgr.RegisterForEvent(ThisObj, 'KilledbyExplosion', OnKilledByExplosion,,,,true);
	//Override Bleed Out Chance
	EventMgr.RegisterForEvent(ThisObj, 'OverrideBleedoutChance', OnOverrideBleedOutChance, ELD_Immediate,,, true);
    // Unit taking damage
    EventMgr.RegisterForEvent(ThisObj, 'UnitTakeEffectDamage', OnUnitTookDamage, ELD_OnStateSubmitted);

    // AI Patrol/Intercept behavior override
    EventMgr.RegisterForEvent(ThisObj, 'ShouldMoveToIntercept', OnShouldMoveToIntercept, ELD_Immediate,,,true);
	// Override IsUnRevealedAI in patrol manager in XGAIplayer so aliens don't stop patrolling when an unrevealed soldier sees them
	EventMgr.RegisterForEvent(ThisObj, 'ShouldUnitPatrolUnderway', OnShouldUnitPatrol, ELD_Immediate,,, true);
    // Alert visibility overrides
    EventMgr.RegisterForEvent(ThisObj, 'IsCauseAllowedForNonvisibleUnits', OnIsCauseAllowedForNonvisibleUnits, ELD_Immediate,,, true);
    // Scamper
    EventMgr.RegisterForEvent(ThisObj, 'ProcessReflexMove', OnProcessReflexMove, ELD_Immediate,,, true);
	// listener for when an enemy unit's alert status is set -- not working
	//EventMgr.RegisterForEvent(ThisObj, 'OnSetUnitAlert', CheckForUnitAlertOverride, ELD_Immediate,,, true);
	EventMgr.RegisterForEvent(ThisObj, 'SpawnReinforcementsComplete', OnSpawnReinforcementsComplete, ELD_OnStateSubmitted,,, true);

	// Recalculate respec time so it goes up with soldier rank
	EventMgr.RegisterForEvent(ThisObj, 'SoldierRespecced', OnSoldierRespecced,,,,true);
	// initial psi training time override
	EventMgr.RegisterForEvent(ThisObj, 'PsiTrainingBegun', OnOverrideInitialPsiTrainingTime, ELD_Immediate,,, true);
	EventMgr.RegisterForEvent(ThisObj, 'PostPsiProjectCompleted', OnPsiProjectCompleted, ELD_Immediate,,, true);

	//General Use, currently used for alert change to red
	EventMgr.RegisterForEvent(ThisObj, 'AbilityActivated', OnAbilityActivated, ELD_OnStateSubmitted,,, true);
	// Attempt to tame Serial
	EventMgr.RegisterForEvent(ThisObj, 'SerialKiller', OnSerialKill, ELD_OnStateSubmitted);
}

// ToHitOverrideListener(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// TODO: Figure out how to fix this
function EventListenerReturn ToHitOverrideListener(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple						OverrideToHit;
	local X2AbilityToHitCalc				ToHitCalc;
	local X2AbilityToHitCalc_StandardAim	StandardAim;
	local ToHitAdjustments					Adjustments;
	local ShotModifierInfo					ModInfo;

	//`LWTRACE("OverrideToHit : Starting listener delegate.");
	OverrideToHit = XComLWTuple(EventData);
	if(OverrideToHit == none)
	{
		`REDSCREEN("ToHitOverride event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//`LWTRACE("OverrideToHit : Parsed XComLWTuple.");

	ToHitCalc = X2AbilityToHitCalc(EventSource);
	if(ToHitCalc == none)
	{
		`REDSCREEN("ToHitOverride event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}
	//`LWTRACE("OverrideToHit : EventSource valid.");

	StandardAim = X2AbilityToHitCalc_StandardAim(ToHitCalc);
	if(StandardAim == none)
	{
		//exit silently with no error, since we're just intercepting StandardAim
		return ELR_NoInterrupt;
	}
	//`LWTRACE("OverrideToHit : Is StandardAim.");

	if(OverrideToHit.Id != 'FinalizeHitChance')
		return ELR_NoInterrupt;

	//`LWTRACE("OverrideToHit : XComLWTuple ID matches, ready to override!");

	GetUpdatedHitChances(StandardAim, Adjustments);

	/*
	StandardAim.m_ShotBreakdown.FinalHitChance = StandardAim.m_ShotBreakdown.ResultTable[eHit_Success] + Adjustments.DodgeHitAdjust;
	StandardAim.m_ShotBreakdown.ResultTable[eHit_Crit] = Adjustments.FinalCritChance;
	StandardAim.m_ShotBreakdown.ResultTable[eHit_Success] = Adjustments.FinalSuccessChance;
	StandardAim.m_ShotBreakdown.ResultTable[eHit_Graze] = Adjustments.FinalGrazeChance;
	StandardAim.m_ShotBreakdown.ResultTable[eHit_Miss] = Adjustments.FinalMissChance;

	if(Adjustments.DodgeHitAdjust != 0)
	{
		ModInfo.ModType = eHit_Success;
		ModInfo.Value   = Adjustments.DodgeHitAdjust;
		ModInfo.Reason  = class'XLocalizedData'.default.DodgeStat;
		StandardAim.m_ShotBreakdown.Modifiers.AddItem(ModInfo);
	}
	if(Adjustments.ConditionalCritAdjust != 0)
	{
		ModInfo.ModType = eHit_Crit;
		ModInfo.Value   = Adjustments.ConditionalCritAdjust;
		ModInfo.Reason  = strCritReductionFromConditionalToHit;
		StandardAim.m_ShotBreakdown.Modifiers.AddItem(ModInfo);
	}
	if(Adjustments.DodgeCritAdjust != 0)
	{
		ModInfo.ModType = eHit_Crit;
		ModInfo.Value   = Adjustments.DodgeCritAdjust;
		ModInfo.Reason  = class'XLocalizedData'.default.DodgeStat;
		StandardAim.m_ShotBreakdown.Modifiers.AddItem(ModInfo);
	}
	*/

	OverrideToHit.Data[0].b = true;

	return ELR_NoInterrupt;
}

// GetUpdatedHitChances(X2AbilityToHitCalc_StandardAim ToHitCalc, out ToHitAdjustments Adjustments)
//doesn't actually assign anything to the ToHitCalc, just computes relative to-hit adjustments
function GetUpdatedHitChances(X2AbilityToHitCalc_StandardAim ToHitCalc, out ToHitAdjustments Adjustments)
{
	/*
	local int GrazeBand;
	local int CriticalChance, DodgeChance;
	local int MissChance, HitChance, CritChance;
	local int GrazeChance, GrazeChance_Hit, GrazeChance_Miss;
	local int CritPromoteChance_HitToCrit;
	local int CritPromoteChance_GrazeToHit;
	local int DodgeDemoteChance_CritToHit;
	local int DodgeDemoteChance_HitToGraze;
	local int DodgeDemoteChance_GrazeToMiss;
	local int i;
	local EAbilityHitResult HitResult;
	local bool bLogHitChance;

	bLogHitChance = false;

	if(bLogHitChance)
	{
		`LWTRACE("==" $ GetFuncName() $ "==\n");
		`LWTRACE("Starting values...", bLogHitChance);
		for (i = 0; i < eHit_MAX; ++i)
		{
			HitResult = EAbilityHitResult(i);
			`LWTRACE(HitResult $ ":" @ ToHitCalc.m_ShotBreakdown.ResultTable[i]);
		}
	}

	// STEP 1 "Band of hit values around nominal to-hit that results in a graze
	//GrazeBand = `LWOVERHAULOPTIONS.GetGrazeBand();
	GrazeBand = 1;

	// options to zero out the band for certain abilities -- either GuaranteedHit or an ability-by-ability
	if (default.GUARANTEED_HIT_ABILITIES_IGNORE_GRAZE_BAND && ToHitCalc.bGuaranteedHit)
	{
		GrazeBand = 0;
	}

	HitChance = ToHitCalc.m_ShotBreakdown.ResultTable[eHit_Success];
	if(HitChance < 0)
	{
		GrazeChance = Max(0, GrazeBand + HitChance); // if hit drops too low, there's not even a chance to graze
	} else if(HitChance > 100)
	{
		GrazeChance = Max(0, GrazeBand - (HitChance-100));  // if hit is high enough, there's not even a chance to graze
	} else {
		GrazeChance_Hit = Clamp(HitChance, 0, GrazeBand); // captures the "low" side where you just barely hit
		GrazeChance_Miss = Clamp(100 - HitChance, 0, GrazeBand);  // captures the "high" side where  you just barely miss
		GrazeChance = GrazeChance_Hit + GrazeChance_Miss;
	}
	if(bLogHitChance)
		`LWTRACE("Graze Chance from band = " $ GrazeChance, bLogHitChance);

	//STEP 2 Update Hit Chance to remove GrazeChance -- for low to-hits this can be zero
	HitChance = Clamp(Min(100, HitChance)-GrazeChance_Hit, 0, 100-GrazeChance);
	if(bLogHitChance)
		`LWTRACE("HitChance after graze graze band removal = " $ HitChance, bLogHitChance);

	//STEP 3 "Crits promote from graze to hit, hit to crit
	CriticalChance = ToHitCalc.m_ShotBreakdown.ResultTable[eHit_Crit];
	if (ALLOW_NEGATIVE_DODGE && ToHitCalc.m_ShotBreakdown.ResultTable[eHit_Graze] < 0)
	{
		// negative dodge acts like crit, if option is enabled
		CriticalChance -= ToHitCalc.m_ShotBreakdown.ResultTable[eHit_Graze];
	}
	CriticalChance = Clamp(CriticalChance, 0, 100);
	CritPromoteChance_HitToCrit = Round(float(HitChance) * float(CriticalChance) / 100.0);

	//if (!ToHitCalc.bAllowCrit) JL -- Took this out b/c it was impacting biggest booms, hopefully we don't need it
	//{
		//CritPromoteChance_HitToCrit = 0;
	//}

	CritPromoteChance_GrazeToHit = Round(float(GrazeChance) * float(CriticalChance) / 100.0);
	if(bLogHitChance)
	{
		`LWTRACE("CritPromoteChance_HitToCrit = " $ CritPromoteChance_HitToCrit, bLogHitChance);
		`LWTRACE("CritPromoteChance_GrazeToHit = " $ CritPromoteChance_GrazeToHit, bLogHitChance);
	}

	CritChance = CritPromoteChance_HitToCrit; // crit chance is the chance you promoted to crit
	HitChance = HitChance + CritPromoteChance_GrazeToHit - CritPromoteChance_HitToCrit;  // add chance for promote from dodge, remove for promote to crit
	GrazeChance = GrazeChance - CritPromoteChance_GrazeToHit; // remove chance for promote to hit
	if(bLogHitChance)
	{
		`LWTRACE("PostCrit:", bLogHitChance);
		`LWTRACE("CritChance  = " $ CritChance, bLogHitChance);
		`LWTRACE("HitChance   = " $ HitChance, bLogHitChance);
		`LWTRACE("GrazeChance = " $ GrazeChance, bLogHitChance);
	}

	//save off loss of crit due to conditional on to-hit
	Adjustments.ConditionalCritAdjust = -(CriticalChance - CritPromoteChance_HitToCrit);

	//STEP 4 "Dodges demotes from crit to hit, hit to graze, (optional) graze to miss"
	if (ToHitCalc.m_ShotBreakdown.ResultTable[eHit_Graze] > 0)
	{
		DodgeChance = Clamp(ToHitCalc.m_ShotBreakdown.ResultTable[eHit_Graze], 0, 100);
		DodgeDemoteChance_CritToHit = Round(float(CritChance) * float(DodgeChance) / 100.0);
		DodgeDemoteChance_HitToGraze = Round(float(HitChance) * float(DodgeChance) / 100.0);
		if(DODGE_CONVERTS_GRAZE_TO_MISS)
		{
			DodgeDemoteChance_GrazeToMiss = Round(float(GrazeChance) * float(DodgeChance) / 100.0);
		}
		CritChance = CritChance - DodgeDemoteChance_CritToHit;
		HitChance = HitChance + DodgeDemoteChance_CritToHit - DodgeDemoteChance_HitToGraze;
		GrazeChance = GrazeChance + DodgeDemoteChance_HitToGraze - DodgeDemoteChance_GrazeToMiss;

		if(bLogHitChance)
		{
			`LWTRACE("DodgeDemoteChance_CritToHit   = " $ DodgeDemoteChance_CritToHit);
			`LWTRACE("DodgeDemoteChance_HitToGraze  = " $ DodgeDemoteChance_HitToGraze);
			`LWTRACE("DodgeDemoteChance_GrazeToMiss = " $DodgeDemoteChance_GrazeToMiss);
			`LWTRACE("PostDodge:");
			`LWTRACE("CritChance  = " $ CritChance);
			`LWTRACE("HitChance   = " $ HitChance);
			`LWTRACE("GrazeChance = " $ GrazeChance);
		}

		//save off loss of crit due to dodge demotion
		Adjustments.DodgeCritAdjust = -DodgeDemoteChance_CritToHit;

		//save off loss of to-hit due to dodge demotion of graze to miss
		Adjustments.DodgeHitAdjust = -DodgeDemoteChance_GrazeToMiss;
	}

	//STEP 5 Store
	Adjustments.FinalCritChance = CritChance;
	Adjustments.FinalSuccessChance = HitChance;
	Adjustments.FinalGrazeChance = GrazeChance;

	//STEP 6 Miss chance is what is left over
	MissChance = 100 - (CritChance + HitChance + GrazeChance);
	Adjustments.FinalMissChance = MissChance;
	if(MissChance < 0)
	{
		//This is an error so flag it
		`REDSCREEN("OverrideToHit : Negative miss chance!");
	}
	*/
}

// OnKilledByExplosion(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnKilledByExplosion(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple				OverrideTuple;
	local XComGameState_Unit		Killer, Target;

	//`LOG ("Firing OnKilledByExplosion");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OnKilledByExplosion event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//`LOG("OverrideTuple : Parsed XComLWTuple.");

	Target = XComGameState_Unit(EventSource);
	if(Target == none)
		return ELR_NoInterrupt;
	//`LOG("OverrideTuple : EventSource valid.");

	if(OverrideTuple.Id != 'OverrideKilledbyExplosion')
		return ELR_NoInterrupt;

	Killer = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OverrideTuple.Data[1].i));

	if (OverrideTuple.Data[0].b && Killer.HasSoldierAbility('NeedleGrenades', true))
	{
		OverrideTuple.Data[0].b = false;
		//`LOG ("Converting to non explosive kill");
	}

	return ELR_NoInterrupt;
}

// OnOverrideBleedOutChance (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnOverrideBleedOutChance(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple	OverrideTuple;
	local int			BleedOutChance;

	if (!default.USE_ALT_BLEEDOUT_RULES)
		return ELR_NoInterrupt;

	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OnOverrideAbilityIconColor event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//
	BleedOutChance = default.BLEEDOUT_CHANCE_BASE - (OverrideTuple.Data[1].i * default.DEATH_CHANCE_PER_OVERKILL_DAMAGE);
	OverrideTuple.Data[0].i = BleedOutChance;

	return ELR_NoInterrupt;

}

// OnUnitTookDamage(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnUnitTookDamage(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComGameState_Unit Unit;
    local XComGameState NewGameState;

    Unit = XComGameState_Unit(EventSource);
    if (Unit.ControllingPlayerIsAI() &&
        Unit.IsInjured() &&
        `BEHAVIORTREEMGR.IsScampering() &&
        Unit.ActionPoints.Find(OffensiveReflexAction) >= 0)
    {
        // This unit has taken damage, is scampering, and has an 'offensive' reflex action point. Replace it with
        // a defensive action point.
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Replacing reflex action for injured unit");
        Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', Unit.ObjectID));
        NewGameState.AddStateObject(Unit);
        Unit.ActionPoints.RemoveItem(OffensiveReflexAction);
        Unit.ActionPoints.AddItem(DefensiveReflexAction);
        `TACTICALRULES.SubmitGameState(NewGameState);
    }

    return ELR_NoInterrupt;
}

// OnShouldMoveToIntercept(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
// Override AI intercept/patrol behavior. The base game uses a function to control pod movement.
//
// For the overhaul mod we will not use either upthrottling or the 'intercept' behavior if XCOM passes
// the pod along the LoP. Instead we will use the pod manager to control movement. But we still want pods
// with no jobs to patrol as normal.
function EventListenerReturn OnShouldMoveToIntercept(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
    local XComLWTuple Tuple;
    local XComLWTValue Value;
    local XComGameState_AIGroup Group;

    Tuple = XComLWTuple(EventData);
    if (Tuple == none || Tuple.Data.Length != 2 || Tuple.Data[0].Kind != XComLWTVObject || Tuple.Data[1].Kind != XComLWTVBool)
    {
        // Not ours or someone already modded it.
        `LWTrace("OnShouldMoveToIntercept: Bad Tuple");
        return ELR_NoInterrupt;
    }

    Group = XComGameState_AIGroup(Tuple.Data[0].o);

    if (Group != none && `PODMGR.PodHasJob(Group) || `PODMGR.GroupIsInYellowAlert(Group))
    {
        // This pod has a job, or is in yellow alert. Don't let the base game alter its alert.
		// For pods with jobs, we want the game to use the throttling beacon we have set for them.
		// For yellow alert pods, either they have a job, in which case they should go where that job
		// says they should, or they should be investigating their yellow alert cause.
        Value.i = 0;
        Value.Kind = XComLWTVInt;
        Tuple.Data.AddItem(Value);
        return ELR_NoInterrupt;
    }
    else
    {
        // No job. Let the base game patrol, but don't try to use the intercept mechanic.
        Value.i = 1;
        Value.Kind = XComLWTVInt;
        Tuple.Data.AddItem(Value);
        return ELR_NoInterrupt;
    }
}

// OnShouldUnitPatrol (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnShouldUnitPatrol (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple				OverrideTuple;
	local XComGameState_Unit		UnitState;
	local XComGameState_AIUnitData	AIData;
	local int						AIUnitDataID, idx;
	local XComGameState_Player		ControllingPlayer;
	local bool						bHasValidAlert;

	//`LOG ("Firing OnShouldUnitPatrol");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("OnShouldUnitPatrol event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	UnitState = XComGameState_Unit(OverrideTuple.Data[1].o);
	if (default.AI_PATROLS_WHEN_SIGHTED_BY_HIDDEN_XCOM)
	{
		if (UnitState.GetCurrentStat(eStat_AlertLevel) <= `ALERT_LEVEL_YELLOW)
		{
			if (UnitState.GetCurrentStat(eStat_AlertLevel) == `ALERT_LEVEL_YELLOW)
			{
				// don't do normal patrolling if the unit has current AlertData
				AIUnitDataID = UnitState.GetAIUnitDataID();
				if (AIUnitDataID > 0)
				{
					if (NewGameState != none)
						AIData = XComGameState_AIUnitData(NewGameState.GetGameStateForObjectID(AIUnitDataID));

					if (AIData == none)
					{
						AIData = XComGameState_AIUnitData(`XCOMHISTORY.GetGameStateForObjectID(AIUnitDataID));
					}
					if (AIData != none)
					{
						if (AIData.GetAlertCount() == 0)
						{
							OverrideTuple.Data[0].b = true;
						}
						else // there is some alert data, but how old ?
						{
							ControllingPlayer = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID));
							for (idx = 0; idx < AIData.GetAlertCount(); idx++)
							{
								if (ControllingPlayer.PlayerTurnCount - AIData.GetAlertData(idx).PlayerTurn < 3)
								{
									bHasValidAlert = true;
									break;
								}
							}
							if (!bHasValidAlert)
							{
								OverrideTuple.Data[0].b = true;
							}
						}
					}
				}
			}
			OverrideTuple.Data[0].b = true;
		}
	}
	return ELR_NoInterrupt;
}

// OnIsCauseAllowedForNonvisibleUnits(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnIsCauseAllowedForNonvisibleUnits(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	/* fix this somehow
    local XComLWTuple Tuple;
    local EAlertCause AlertCause;
    local XComLWTValue Value;

    Tuple = XComLWTuple(EventData);
    
	
	if (Tuple != none && Tuple.Data.Length == 1 && class'Helpers_LW'.static.YellowAlertEnabled())
    {
        AlertCause = EAlertCause(Tuple.Data[0].i);
        switch(AlertCause)
        {
            case eAC_DetectedSound:
            case eAC_DetectedAllyTakingDamage:
            case eAC_DetectedNewCorpse:
            case eAC_SeesExplosion:
            case eAC_SeesSmoke:
            case eAC_SeesFire:
            case eAC_AlertedByYell:
                Value.Kind = XComLWTVBool;
                Value.b = true;
                Tuple.Data.AddItem(Value);
        }
    }
	*/

    return ELR_NoInterrupt;
}

// OnProcessReflexMove(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnProcessReflexMove(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComGameState_Unit Unit;
	local XComGameState_Unit PreviousUnit;
	local XComGameStateHistory History;
	local XComGameState_AIGroup Group;
    local bool IsYellow;
    local float Chance;
	local UnitValue Value;
	local XComGameState_MissionSite			MissionState;
	local Squad_XComGameState				SquadState;
	local XComGameState_BattleData			BattleData;

    Unit = XComGameState_Unit(GameState.GetGameStateForObjectID(XComGameState_Unit(EventData).ObjectID));
    `LWTrace(GetFuncName() $ ": Processing reflex move for unit " $ Unit.GetMyTemplateName());
	History = `XCOMHISTORY;

	// Note: We don't currently support reflex actions on XCOM's turn. Doing so requires
	// adjustments to how scampers are processed so the units would use their extra action
	// point. Also note that giving units a reflex action point while it's not their turn
	// can break stun animations unless those action points are used: see X2Effect_Stunned
	// where action points are only removed if it's the units turn, and the effect actions
	// (including the stunned idle anim override) are only visualized if the unit has no
	// action points left. If the unit has stray reflex actions they haven't used they
	// will stand back up and perform the normal idle animation (although they are still
	// stunned and won't act).
    if (Unit.ControllingPlayer != `TACTICALRULES.GetCachedUnitActionPlayerRef())
    {
        `LWTrace(GetFuncName() $ ": Not the alien turn: aborting");
        return ELR_NoInterrupt;
    }

	Group = Unit.GetGroupMembership();
    if (Group == none)
    {
        `LWTrace(GetFuncName() $ ": Can't find group: aborting");
        return ELR_NoInterrupt;
    }

    if (Unit.GetCurrentStat(eStat_AlertLevel) <= 1)
	{
		// This unit isn't in red alert. If a scampering unit is not in red, this generally means they're a reinforcement
		// pod. Skip them.
		`LWTrace(GetFuncName() $ ": Reinforcement unit: aborting");
		return ELR_NoInterrupt;
	}

	// Look for the special 'NoReflexAction' unit value. If present, this unit isn't allowed to take an action.
	// This is typically set on reinforcements on the turn they spawn. But if they spawn out of LoS they are
	// eligible, just like any other yellow unit, on subsequent turns. Both this check and the one above are needed.
	Unit.GetUnitValue(NoReflexActionUnitValue, Value);
 	if (Value.fValue == 1)
	{
		`LWTrace(GetFuncName() $ ": Unit with no reflex action value: aborting");
		return ELR_NoInterrupt;
	}

	// Walk backwards through history for this unit until we find a state in which this unit wasn't in red
	// alert to see if we entered from yellow or from green.
	PreviousUnit = Unit;
	while (PreviousUnit != none && PreviousUnit.GetCurrentStat(eStat_AlertLevel) > 1)
	{
		PreviousUnit = XComGameState_Unit(History.GetPreviousGameStateForObject(PreviousUnit));
	}

    IsYellow = PreviousUnit != none && PreviousUnit.GetCurrentStat(eStat_AlertLevel) == 1;
    Chance = IsYellow ? REFLEX_ACTION_CHANCE_YELLOW[`CAMPAIGNDIFFICULTYSETTING] : REFLEX_ACTION_CHANCE_GREEN[`CAMPAIGNDIFFICULTYSETTING];

    // Did our current pod change? If so reset the number of successful reflex actions we've had so far.
    if (Group.ObjectID != LastReflexGroupID)
    {
        NumSuccessfulReflexActions = 0;
        LastReflexGroupId = Group.ObjectID;
    }

	// if is infiltration mission, get infiltration % and modify yellow and green alert chances by how much you missed 100%, diff modifier, positive boolean
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(BattleData.m_iMissionID));

	// Infiltration modifier
	if (`SQUADMGR.IsValidInfiltrationMission(MissionState.GetReference()))
	{
		SquadState = `SQUADMGR.Squads.GetSquadOnMission(MissionState.GetReference());
		if (SquadState.InfiltrationState.CurrentInfiltration <= 1)
		{
			Chance += (1.0 - SquadState.InfiltrationState.CurrentInfiltration) * default.LOW_INFILTRATION_MODIFIER_ON_REFLEX_ACTIONS[`CAMPAIGNDIFFICULTYSETTING];
		}
		else
		{
			Chance -= (SquadState.InfiltrationState.CurrentInfiltration - 1.0) * default.HIGH_INFILTRATION_MODIFIER_ON_REFLEX_ACTIONS[`CAMPAIGNDIFFICULTYSETTING];
		}
	}

    if (REFLEX_ACTION_CHANCE_REDUCTION > 0 && NumSuccessfulReflexActions > 0)
    {
        `LWTrace(GetFuncName() $ ": Reducing reflex chance due to " $ NumSuccessfulReflexActions $ " successes");
        Chance -= NumSuccessfulReflexActions * REFLEX_ACTION_CHANCE_REDUCTION;
    }

    if (`SYNC_FRAND() < Chance)
    {
        `LWTrace(GetFuncName() $ ": Awarding an extra action point to unit");
        // Award the unit a special kind of action point. These are more restricted than standard action points.
        // See the 'OffensiveReflexAbilities' and 'DefensiveReflexAbilities' arrays in LW_Overhaul.ini for the list
        // of abilities that have been modified to allow these action points.
        //
        // Damaged units, and units in green (if enabled) get 'defensive' action points. Others get 'offensive' action points.
        if (Unit.IsInjured() || !IsYellow)
        {
            Unit.ActionPoints.AddItem(DefensiveReflexAction);
        }
        else
        {
            Unit.ActionPoints.AddItem(OffensiveReflexAction);
        }

        ++NumSuccessfulReflexActions;
    }

    return ELR_NoInterrupt;
}

// CheckForUnitAlertOverride(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn CheckForUnitAlertOverride(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XCOMLWTuple						OverrideTuple;
	local XComGameState_MissionSite			MissionState;
	local Squad_XComGameState				SquadState;
	local XComGameState_BattleData			BattleData;

	//`LWTRACE("CheckForUnitAlertOverride : Starting listener.");

	OverrideTuple = XCOMLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("CheckForUnitAlertOverride event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	// If within a configurable list of mission types, and infiltration below a set value, set it to true
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(BattleData.m_iMissionID));

    if (MissionState == none)
    {
        return ELR_NoInterrupt;
    }

	SquadState = `SQUADMGR.Squads.GetSquadOnMission(MissionState.GetReference());

	if (`SQUADMGR.IsValidInfiltrationMission(MissionState.GetReference()))
	{
		if (SquadState.InfiltrationState.CurrentInfiltration < default.MINIMUM_INFIL_FOR_GREEN_ALERT[`CAMPAIGNDIFFICULTYSETTING])
		{
			if (OverrideTuple.Data[0].i == `ALERT_LEVEL_GREEN)
			{
				OverrideTuple.Data[0].i = `ALERT_LEVEL_YELLOW;
				`LWTRACE ("Changing unit alert to yellow");
			}
		}
	}

	return ELR_NoInterrupt;
}

// OnSpawnReinforcementsComplete (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
// A RNF pod has spawned. Mark the units with a special marker to indicate they shouldn't be eligible for
// reflex actions this turn.
function EventListenerReturn OnSpawnReinforcementsComplete (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_Unit Unit;
	local XComGameState NewGameState;
	local XComGameState_AIReinforcementSpawner Spawner;
	local int i;

	Spawner = XComGameState_AIReinforcementSpawner(EventSource);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Prevent RNF units from getting yellow actions");
	for (i = 0; i < Spawner.SpawnedUnitIDs.Length; ++i)
	{
		Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', Spawner.SpawnedUnitIDs[i]));
		NewGameState.AddStateObject(Unit);
		Unit.SetUnitFloatValue(NoReflexActionUnitValue, 1, eCleanup_BeginTurn);
	}

	`TACTICALRULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

// OnSoldierRespecced (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnSoldierRespecced (Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple OverrideTuple;

	//`LOG ("Firing OnSoldierRespecced");
	OverrideTuple = XComLWTuple(EventData);
	if(OverrideTuple == none)
	{
		`REDSCREEN("On Soldier Respecced event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//`LOG("OverrideTuple : Parsed XComLWTuple.");

	if(OverrideTuple.Id != 'OverrideRespecTimes')
		return ELR_NoInterrupt;

	//`LOG ("Point 2");

	if (default.TIERED_RESPEC_TIMES)
	{
		//Respec days = rank * difficulty setting
		OverrideTuple.Data[1].i = OverrideTuple.Data[0].i * class'XComGameState_HeadquartersXCom'.default.XComHeadquarters_DefaultRespecSoldierDays[`CAMPAIGNDIFFICULTYSETTING] * 24;
		//`LOG ("Point 3" @ OverrideTuple.Data[1].i @ OverrideTuple.Data[0].i);
	}

	return ELR_NoInterrupt;

}

// OnOverrideInitialPsiTrainingTime(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnOverrideInitialPsiTrainingTime(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
	{
		return ELR_NoInterrupt;
	}
	Tuple.Data[0].i=default.INITIAL_PSI_TRAINING[`CAMPAIGNDIFFICULTYSETTING];
	return ELR_NoInterrupt;
}

// OnPsiProjectCompleted (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
// Grants bonus psi abilities after promotion to squaddie
function EventListenerReturn OnPsiProjectCompleted (Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local StateObjectReference ProjectFocus;
	local XComGameState_Unit UnitState;
	local X2SoldierClassTemplate SoldierClassTemplate;
	local int BonusAbilityRank, BonusAbilityBranch, BonusAbilitiesGranted, Tries;
	local name BonusAbility;
	local XComGameState NewGameState;

	if (XComGameState_HeadquartersProjectPsiTraining(EventSource) == none)
	{
		`LWTRACE ("OnPsiProjectCompleted called with invalid EventSource.");
		return ELR_NoInterrupt;
	}
	ProjectFocus = XComGameState_HeadquartersProjectPsiTraining(EventSource).ProjectFocus;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ProjectFocus.ObjectID));

	if (UnitState == none || UnitState.GetRank() != 1)
	{
		`LWTRACE ("OnPsiProjectCompleted could not find valid unit state.");
		return ELR_NoInterrupt;
	}

	BonusAbilitiesGranted = 0;

	SoldierClassTemplate = UnitState.GetSoldierClassTemplate();
	if (SoldierClassTemplate == none)
	{
		`LWTRACE ("OnPsiProjectCompleted could not find valid class template for unit.");
		return ELR_NoInterrupt;
	}

	Tries = 0;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Granting Bonus Psi Starter abilities");
	while (BonusAbilitiesGranted < default.PSI_SQUADDIE_BONUS_ABILITIES)
	{
		BonusAbilityRank = `SYNC_RAND(1 + (default.PSI_SQUADDIE_BONUS_ABILITIES / 2));
		BonusAbilityBranch = `SYNC_RAND(2);
		BonusAbility = SoldierClassTemplate.GetAbilitySlots(BonusAbilityRank)[BonusAbilityBranch].AbilityType.AbilityName;

		Tries += 1;

		if (!UnitState.HasSoldierAbility(BonusAbility, true))
		{
			if (UnitState.BuySoldierProgressionAbility(NewGameState,BonusAbilityRank,BonusAbilityBranch))
			{
				BonusAbilitiesGranted += 1;
				`LWTRACE("OnPsiProjectCompleted granted bonus ability " $ string(BonusAbility));
			}
		}
		if (Tries > 999)
		{
			`LWTRACE ("OnPsiProjectCompleted Can't find an ability");
			break;
		}
	}

	if (BonusAbilitiesGranted > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		`LWTRACE("OnPsiProjectCompleted granted unit " $ UnitState.GetFullName() @ string(BonusAbilitiesGranted) $ " extra psi abilities.");
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

// OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
    local XComGameState_Ability ActivatedAbilityState;
	local Reinforcements_XComGameState Reinforcements;
	local XComGameState NewGameState;

	//ActivatedAbilityStateContext = XComGameStateContext_Ability(GameState.GetContext());
	ActivatedAbilityState = XComGameState_Ability(EventData);
	if (ActivatedAbilityState.GetMyTemplate().DataName == 'RedAlert')
	{
		Reinforcements = Reinforcements_XComGameState(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'Reinforcements_XComGameState', true));
		if (Reinforcements == none)
			return ELR_NoInterrupt;

		if (Reinforcements.RedAlertTriggered)
			return ELR_NoInterrupt;

		Reinforcements.RedAlertTriggered = true;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Check for reinforcements");
		Reinforcements = Reinforcements_XComGameState(NewGameState.CreateStateObject(class'Reinforcements_XComGameState', Reinforcements.ObjectID));
		NewGameState.AddStateObject(Reinforcements);
		`TACTICALRULES.SubmitGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

// OnSerialKill(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
function EventListenerReturn OnSerialKill(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackObject)
{
	local XComGameState_Unit ShooterState;
    local UnitValue UnitVal;

	ShooterState = XComGameState_Unit (EventSource);
	If (ShooterState == none)
	{
		return ELR_NoInterrupt;
	}
	ShooterState.GetUnitValue ('SerialKills', UnitVal);
	ShooterState.SetUnitFloatValue ('SerialKills', UnitVal.fValue + 1.0, eCleanup_BeginTurn);
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