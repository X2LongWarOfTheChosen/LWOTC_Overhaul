class Override_TemplateMods_ModifyAbilities extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int SPIDER_GRAPPLE_COOLDOWN;
var config int WRAITH_GRAPPLE_COOLDOWN;
var config int SHIELDWALL_MITIGATION_AMOUNT;
var config int SHIELDWALL_DEFENSE_AMOUNT;
var config int HAIL_OF_BULLETS_AMMO_COST;
var config int SATURATION_FIRE_AMMO_COST;
var config int DEMOLITION_AMMO_COST;
var config int THROW_GRENADE_COOLDOWN;
var config int AID_PROTOCOL_COOLDOWN;
var config int FUSE_COOLDOWN;
var config int INSANITY_MIND_CONTROL_DURATION;
var config bool INSANITY_ENDS_TURN;
var config int RUPTURE_CRIT_BONUS;
var config int FACEOFF_CHARGES;
var config int CONCEAL_ACTION_POINTS;
var config bool CONCEAL_ENDS_TURN;
var config int SERIAL_CRIT_MALUS_PER_KILL;
var config int SERIAL_AIM_MALUS_PER_KILL;
var config bool SERIAL_DAMAGE_FALLOFF;

var config int ALIEN_RULER_ACTION_BONUS_APPLY_CHANCE;

var config bool USE_ACTION_ICON_COLORS;
var config string ICON_COLOR_OBJECTIVE;
var config string ICON_COLOR_PSIONIC_2;
var config string ICON_COLOR_PSIONIC_END;
var config string ICON_COLOR_PSIONIC_1;
var config string ICON_COLOR_PSIONIC_FREE;
var config string ICON_COLOR_COMMANDER_ALL;
var config string ICON_COLOR_2;
var config string ICON_COLOR_END;
var config string ICON_COLOR_1;
var config string ICON_COLOR_FREE;

var config array<Name> OffensiveReflexAbilities;
var config array<Name> DefensiveReflexAbilities;
var config array<Name> DoubleTapAbilities;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateModifyAbilitiesGeneralTemplate());

    return Templates;
}

// various small changes to vanilla abilities
static function Override_TemplateMods_Template CreateModifyAbilitiesGeneralTemplate()
{
   local Override_TemplateMods_Template Template;
   
   `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ModifyAbilitiesGeneral');
   Template.AbilityTemplateModFn = ModifyAbilitiesGeneral;
   return Template;
}

function ModifyAbilitiesGeneral(X2AbilityTemplate Template, int Difficulty)
{
	local X2Effect_PersistentStatChange		PersistentStatChangeEffect;
	//local X2Condition_UnitEffects			UnitEffects;
	local X2AbilityToHitCalc_StandardAim	StandardAim;
	local X2AbilityCharges_RevivalProtocol	RPCharges;
	local X2Condition_UnitInventory			InventoryCondition, InventoryCondition2;
	local X2Condition_UnitEffects			SuppressedCondition, UnitEffectsCondition, NotHaywiredCondition;
	local int								k;
	local X2AbilityCost_Ammo				AmmoCost;
	local X2AbilityCost_ActionPoints		ActionPointCost;
	local X2EFfect_HuntersInstinctDamage_LW	DamageModifier;
	local X2AbilityCooldown					Cooldown;
	//local X2AbilityCost_QuickdrawActionPoints_LW	QuickdrawActionPointCost; TODO
	local X2Effect_Squadsight				Squadsight;
	local X2Effect_ToHitModifier			ToHitModifier;
	local X2Effect_Persistent				Effect, PersistentEffect, HaywiredEffect;
	local X2Effect_VolatileMix				MixEffect;
	local X2Effect_ModifyReactionFire		ReactionFire;
	local X2Effect_DamageImmunity	 		DamageImmunity;
	local X2Effect_HunkerDown_LW			HunkerDownEffect;
	local X2Effect_CancelLongRangePenalty	DFAEffect;
	local X2Condition_Visibility			VisibilityCondition, TargetVisibilityCondition;
	local X2Condition_UnitProperty			UnitPropertyCondition;
	//local X2AbilityTarget_Single			PrimaryTarget;
	//local X2AbilityMultiTarget_Radius		RadiusMultiTarget;
	local X2Effect_SerialCritReduction		SerialCritReduction;
    local X2AbilityCharges					Charges;
    local X2AbilityCost_Charges				ChargeCost;
	//local X2Effect_SoulSteal_LW			StealEffect;
	local X2Effect_Guardian_LW				GuardianEffect;
	//local X2Effect							ShotEffect;
	local X2Effect_MaybeApplyDirectionalWorldDamage WorldDamage;
	local X2Effect_DeathFromAbove_LW		DeathEffect;
	local X2Effect_ApplyWeaponDamage		WeaponDamageEffect;

	if (Template.DataName == 'Grapple')
	{
		Template.AbilityCooldown.iNumTurns = default.SPIDER_GRAPPLE_COOLDOWN;
	}
	if (Template.DataName == 'GrapplePowered')
	{
		Template.AbilityCooldown.iNumTurns = default.WRAITH_GRAPPLE_COOLDOWN;
	}
	if (Template.DataName == 'MediumPlatedArmorStats')
	{
		PersistentStatChangeEffect = new class'X2Effect_PersistentStatChange';
		PersistentStatChangeEffect.BuildPersistentEffect(1, true, false, false);
		PersistentStatChangeEffect.AddPersistentStatChange(eStat_ArmorChance, 100.0);
		PersistentStatChangeEffect.AddPersistentStatChange(eStat_ArmorMitigation, float(class'Override_TemplateMods_ReconfigureGear'.default.MEDIUM_PLATED_MITIGATION_AMOUNT));
		Template.AddTargetEffect(PersistentStatChangeEffect);
	}
	//HighCoverGenerator()
	if (Template.DataName == 'HighCoverGenerator')
	{
		PersistentStatChangeEffect = new class'X2Effect_PersistentStatChange';
		PersistentStatChangeEffect.BuildPersistentEffect(1, false, true, false, eGameRule_PlayerTurnBegin);
		PersistentStatChangeEffect.AddPersistentStatChange(eStat_Defense, default.SHIELDWALL_DEFENSE_AMOUNT);
		PersistentStatChangeEffect.AddPersistentStatChange(eStat_ArmorChance, 100.0);
		PersistentStatChangeEffect.AddPersistentStatChange(eStat_ArmorMitigation, default.SHIELDWALL_MITIGATION_AMOUNT);
		Template.AddShooterEffect (PersistentStatChangeEffect);
	}

	if (Template.DataName == 'HailofBullets')
	{
		InventoryCondition = new class'X2Condition_UnitInventory';
		InventoryCondition.RelevantSlot=eInvSlot_PrimaryWeapon;
		InventoryCondition.ExcludeWeaponCategory = 'shotgun';
		Template.AbilityShooterConditions.AddItem(InventoryCondition);
	
		InventoryCondition2 = new class'X2Condition_UnitInventory';
		InventoryCondition2.RelevantSlot=eInvSlot_PrimaryWeapon;
		InventoryCondition2.ExcludeWeaponCategory = 'sniper_rifle';
		Template.AbilityShooterConditions.AddItem(InventoryCondition2);

		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			AmmoCost = X2AbilityCost_Ammo(Template.AbilityCosts[k]);
			if (AmmoCost != none)
			{
				X2AbilityCost_Ammo(Template.AbilityCosts[k]).iAmmo = default.HAIL_OF_BULLETS_AMMO_COST;
			}
		}
	}

	if (Template.DataName == 'Demolition')
	{
		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			AmmoCost = X2AbilityCost_Ammo(Template.AbilityCosts[k]);
			if (AmmoCost != none)
			{
				X2AbilityCost_Ammo(Template.AbilityCosts[k]).iAmmo = default.DEMOLITION_AMMO_COST;
			}
		}
	}

	if (Template.DataName == 'InTheZone')
	{
		SerialCritReduction = new class 'X2Effect_SerialCritReduction';
		SerialCritReduction.BuildPersistentEffect(1, false, true, false, 8);
		SerialCritReduction.CritReductionPerKill = default.SERIAL_CRIT_MALUS_PER_KILL;
		SerialCritReduction.AimReductionPerKill = default.SERIAL_AIM_MALUS_PER_KILL;
		SerialCritReduction.Damage_Falloff = default.SERIAL_DAMAGE_FALLOFF;
		SerialCritReduction.SetDisplayInfo (ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage, true,, Template.AbilitySourceName);
		Template.AbilityTargetEffects.AddItem(SerialCritReduction);
	}

	// Disasbles the effect so they get full turns on alien turn
	if (Template.DataName == 'AlienRulerInitialState')
	{
		Template.AbilityTargetEffects.length = 0;
		DamageImmunity = new class'X2Effect_DamageImmunity';
	    DamageImmunity.BuildPersistentEffect(1, true, true, true);
	    DamageImmunity.ImmuneTypes.AddItem('Unconscious');
	    DamageImmunity.EffectName = 'RulerImmunity';
	    Template.AddTargetEffect(DamageImmunity);

		//Requires listeners set up so that "RULER REACTION" overlay gets removed
		Template.AddTargetEffect(new class'X2Effect_DLC2_HideSpecialTurnOverlay');
	}

	// Use alternate DFA effect so it's compatible with Double Tap 2, and add additional ability of canceling long-range sniper rifle penalty
	if (Template.DataName == 'DeathFromAbove')
	{
		Template.AbilityTargetEffects.Length = 0;
		DFAEffect = New class'X2Effect_CancelLongRangePenalty';
		DFAEffect.BuildPersistentEffect (1, true, false);
		DFAEffect.SetDisplayInfo (0, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, false,, Template.AbilitySourceName);
		Template.AddTargetEffect(DFAEffect);
		DeathEffect = new class'X2Effect_DeathFromAbove_LW';
		DeathEffect.BuildPersistentEffect(1, true, false, false);
		DeathEffect.SetDisplayInfo(0, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, true,, Template.AbilitySourceName);
		Template.AddTargetEffect(DeathEffect);
	}

	// and partial turns only sometimes
	if (Template.DataName == 'AlienRulerActionSystem')
	{
		for (k = 0; k < Template.AbilityTargetEffects.length; k++)
		{
			if (Template.AbilityTargetEffects[k].IsA ('X2Effect_DLC_2RulerActionPoint'))
			{
				Template.AbilityTargetEffects[k].ApplyChance = default.ALIEN_RULER_ACTION_BONUS_APPLY_CHANCE;
			}
		}
	}

	if (Template.DataName == 'Insanity')
	{
		for (k = 0; k < Template.AbilityTargetEffects.length; k++)
		{
			if (Template.AbilityTargetEffects[k].IsA ('X2Effect_MindControl'))
			{
				X2Effect_MindControl(Template.AbilityTargetEffects[k]).iNumTurns = default.INSANITY_MIND_CONTROL_DURATION;
			}
		}
		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			ActionPointCost = X2AbilityCost_ActionPoints(Template.AbilityCosts[k]);
			if (ActionPointCost != none)
			{
				X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).bConsumeAllPoints = default.INSANITY_ENDS_TURN;
			}
		}
	}

	if (Template.DataName == 'Fuse')
	{
		Template.PrerequisiteAbilities.AddItem ('Fortress');
	}

	if (Template.DataName == 'StasisShield')
	{
		Template.PrerequisiteAbilities.AddItem ('Fortress');
	}

	if (Template.DataName == 'Domination')
	{
		Template.PrerequisiteAbilities.AddItem ('Solace_LW');
		Template.PrerequisiteAbilities.AddItem ('Stasis');
	}

	if (Template.DataName == 'VoidRift')
	{
		Template.PrerequisiteAbilities.AddItem ('Fortress');
		Template.PrerequisiteAbilities.AddItem ('Solace_LW');
	}

	if (Template.DataName == 'NullLance')
	{
		Template.PrerequisiteAbilities.AddItem ('Stasis');
	}
	
	if (Template.DataName == 'PoisonSpit' || Template.DataName == 'MicroMissiles')
	{
		VisibilityCondition = new class'X2Condition_Visibility';
		VisibilityCondition.bVisibletoAnyAlly = true;
		VisibilityCondition.bAllowSquadsight = true;
		Template.AbilityTargetConditions.AddItem(VisibilityCondition);
		Template.AbilityMultiTargetConditions.AddItem(VisibilityCondition);
	}

	// should allow covering fire at micromissiles and ADVENT rockets
	if (Template.DataName == 'MicroMissiles' || Template.DataName == 'RocketLauncher')
	{
		Template.BuildInterruptGameStateFn = class'X2Ability'.static.TypicalAbility_BuildInterruptGameState;
	}

	if (Template.DataName == 'Stealth' && default.CONCEAL_ACTION_POINTS > 0)
	{
		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			ActionPointCost = X2AbilityCost_ActionPoints(Template.AbilityCosts[k]);
			if (ActionPointCost != none)
			{
				X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).iNumPoints = default.CONCEAL_ACTION_POINTS;
				X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).bConsumeAllPoints = default.CONCEAL_ENDS_TURN;
				X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).bFreeCost = false;
			}
		}
	}

	// get rid of barfy screen shake on Berserker Rage
	if (Template.DataName == 'TriggerRage')
	{
		Template.CinescriptCameraType = "Archon_Frenzy";
	}

	// bugfix for Flashbangs doing damage
	if (Template.DataName == 'HuntersInstinct')
	{
		Template.AbilityTargetEffects.length = 0;
		DamageModifier = new class'X2Effect_HuntersInstinctDamage_LW';
		DamageModifier.BonusDamage = class'X2Ability_RangerAbilitySet'.default.INSTINCT_DMG;
		DamageModifier.BonusCritChance = class'X2Ability_RangerAbilitySet'.default.INSTINCT_CRIT;
		DamageModifier.BuildPersistentEffect(1, true, false, true);
		DamageModifier.SetDisplayInfo(0, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
		Template.AddTargetEffect(DamageModifier);
	}

	// bugfix for several vanilla perks being lost after bleeding out/revive
	if (Template.DataName == 'Squadsight')
	{
		Template.AbilityTargetEffects.length = 0;
	    Squadsight = new class'X2Effect_Squadsight';
	    Squadsight.BuildPersistentEffect(1, true, false, true);
		Squadsight.SetDisplayInfo(0, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage,,, Template.AbilitySourceName);
		Template.AddTargetEffect(Squadsight);
	}

	if (Template.DataName == 'HitWhereItHurts')
	{
		Template.AbilityTargetEffects.length = 0;
		ToHitModifier = new class'X2Effect_ToHitModifier';
		ToHitModifier.BuildPersistentEffect(1, true, false, true);
		ToHitModifier.SetDisplayInfo(0, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage,,, Template.AbilitySourceName);
		ToHitModifier.AddEffectHitModifier(1, class'X2Ability_SharpshooterAbilitySet'.default.HITWHEREITHURTS_CRIT, Template.LocFriendlyName,, false, true, true, true);
		Template.AddTargetEffect(ToHitModifier);
	}

	if (Template.DataName == 'HoloTargeting')
	{
		Template.AbilityTargetEffects.length = 0;
	    PersistentEffect = new class'X2Effect_Persistent';
		PersistentEffect.BuildPersistentEffect(1, true, false);
		PersistentEffect.SetDisplayInfo(0, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, true,, Template.AbilitySourceName);
		Template.AddTargetEffect(PersistentEffect);
	}

	if (Template.DataName == 'VolatileMix')
	{
		Template.AbilityTargetEffects.length = 0;
	    MixEffect = new class'X2Effect_VolatileMix';
	    MixEffect.BuildPersistentEffect(1, true, false, true);
	    MixEffect.SetDisplayInfo(0, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage,,, Template.AbilitySourceName);
	    MixEffect.BonusDamage = class'X2Ability_GrenadierAbilitySet'.default.VOLATILE_DAMAGE;
	    Template.AddTargetEffect(MixEffect);
	}	
	
	if (Template.DataName == 'CoolUnderPressure')
	{
		Template.AbilityTargetEffects.length = 0;
		ReactionFire = new class'X2Effect_ModifyReactionFire';
		ReactionFire.bAllowCrit = true;
		ReactionFire.ReactionModifier = class'X2Ability_SpecialistAbilitySet'.default.UNDER_PRESSURE_BONUS;
		ReactionFire.BuildPersistentEffect(1, true, false, true);
		ReactionFire.SetDisplayInfo(0, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage,,, Template.AbilitySourceName);
		Template.AddTargetEffect(ReactionFire);
	}	

	if (Template.DataName == 'BulletShred')
	{
		StandardAim = new class'X2AbilityToHitCalc_StandardAim';
		StandardAim.bHitsAreCrits = false;
		StandardAim.BuiltInCritMod = default.RUPTURE_CRIT_BONUS;
		Template.AbilityToHitCalc = StandardAim;
		Template.AbilityToHitOwnerOnMissCalc = StandardAim;

		for (k = 0; k < Template.AbilityTargetConditions.Length; k++)
		{
			TargetVisibilityCondition = X2Condition_Visibility(Template.AbilityTargetConditions[k]);
			if (TargetVisibilityCondition != none)
			{
				// Allow rupture to work from SS
				TargetVisibilityCondition = new class'X2Condition_Visibility';
				TargetVisibilityCondition.bRequireGameplayVisible  = true;
				TargetVisibilityCondition.bAllowSquadsight = true;
				Template.AbilityTargetConditions[k] = TargetVisibilityCondition;
			}
		}
	}

	// Bump up skulljack damage, the default 20 will fail to kill advanced units
	// and glitches out the animations.
	if (Template.DataName == 'FinalizeSKULLJACK')
	{
		for (k = 0; k < Template.AbilityTargetEffects.Length; ++k)
		{
			WeaponDamageEffect = X2Effect_ApplyWeaponDamage(Template.AbilityTargetEffects[k]);
			if (WeaponDamageEffect != none)
			{
				WeaponDamageEffect.EffectDamageValue.Pierce = 99;
				WeaponDamageEffect.EffectDamageValue.Damage = 99;
			}
		}
	}

	// Removes Threat Assessment increase
	if (Template.DataName == 'AidProtocol')
	{
		Cooldown = new class'X2AbilityCooldown';
		Cooldown.iNumTurns = default.AID_PROTOCOL_COOLDOWN;
		Template.AbilityCooldown = Cooldown;
	}

	if (Template.DataName == 'KillZone' || Template.DataName == 'Deadeye' || Template.DataName == 'BulletShred')
	{
		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			ActionPointCost = X2AbilityCost_ActionPoints(Template.AbilityCosts[k]);
			if (ActionPointCost != none)
			{
				X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).iNumPoints = 0;
				X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).bAddWeaponTypicalCost = true;
			}
		}
	}

	// Steady Hands
	// Stasis Vest
	// Air Controller

	//if (Template.DataName == 'HunterProtocolShot')
	//{
		//Cooldown = new class'X2AbilityCooldown';
		//Cooldown.iNumTurns = 1;
		//Template.AbilityCooldown = Cooldown;
	//}

	// lets RP gain charges from gremlin tech
	if (Template.DataName == 'RevivalProtocol')
	{
		RPCharges = new class 'X2AbilityCharges_RevivalProtocol';
		RPCharges.InitialCharges = class'X2Ability_SpecialistAbilitySet'.default.REVIVAL_PROTOCOL_CHARGES;
		Template.AbilityCharges = RPCharges;
	}

	// adds config to ammo cost and fixes vanilla bug in which 
	if (Template.DataName == 'SaturationFire')
	{
		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			AmmoCost = X2AbilityCost_Ammo(Template.AbilityCosts[k]);
			if (AmmoCost != none)
			{
				X2AbilityCost_Ammo(Template.AbilityCosts[k]).iAmmo = default.SATURATION_FIRE_AMMO_COST;
			}
		}
		Template.AbilityMultiTargetEffects.length = 0;
		Template.AddMultiTargetEffect(class'X2Ability_GrenadierAbilitySet'.static.ShredderDamageEffect());
		WorldDamage = new class'X2Effect_MaybeApplyDirectionalWorldDamage';
		WorldDamage.bUseWeaponDamageType = true;
		WorldDamage.bUseWeaponEnvironmentalDamage = false;
		WorldDamage.EnvironmentalDamageAmount = 30;
		WorldDamage.bApplyOnHit = true;
		WorldDamage.bApplyOnMiss = true;
		WorldDamage.bApplyToWorldOnHit = true;
		WorldDamage.bApplyToWorldOnMiss = true;
		WorldDamage.bHitAdjacentDestructibles = true;
		WorldDamage.PlusNumZTiles = 1;
		WorldDamage.bHitTargetTile = true;
		WorldDamage.ApplyChance = class'X2Ability_GrenadierAbilitySet'.default.SATURATION_DESTRUCTION_CHANCE;
		Template.AddMultiTargetEffect(WorldDamage);
	}

	if (Template.DataName == 'CarryUnit' || Template.DataName == 'Interact_OpenChest' || Template.DataName == 'Interact_StasisTube')
	{
		Template.ConcealmentRule = eConceal_Never;
	}

	// can't shoot when on FIRE

	/* TODO
	if (class'X2Ability_PerkPackAbilitySet'.default.NO_STANDARD_ATTACKS_WHEN_ON_FIRE)
	{
		switch (Template.DataName)
		{
			case 'StandardShot':
			case 'PistolStandardShot':
			case 'SniperStandardFire':
			case 'Shadowfall':
			// Light Em Up and Snap Shot are handled in the template
				UnitEffects = new class'X2Condition_UnitEffects';
				UnitEffects.AddExcludeEffect(class'X2StatusEffects'.default.BurningName, 'AA_UnitIsBurning');
				Template.AbilityShooterConditions.AddItem(UnitEffects);
				break;
			default:
				break;
		}	
	}
	if (class'X2Ability_PerkPackAbilitySet'.default.NO_MELEE_ATTACKS_WHEN_ON_FIRE)
	{
		if (Template.IsMelee())
		{			
			UnitEffects = new class'X2Condition_UnitEffects';
			UnitEffects.AddExcludeEffect(class'X2StatusEffects'.default.BurningName, 'AA_UnitIsBurning');
			Template.AbilityShooterConditions.AddItem(UnitEffects);
		}
	}
	*/

	if (Template.DataName == 'StandardShot')
	{
		`LOG ("Adding ReflexShotModifier to StandardShot");
		Template.AdditionalAbilities.AddItem('ReflexShotModifier');
	}

	// Gives names to unnamed effects so they can later be referenced)
	switch (Template.DataName)
	{
		case 'HackRewardBuffEnemy':
			for (k = 0; k < Template.AbilityTargetEffects.length; k++)
			{
				Effect = X2Effect_Persistent (Template.AbilityTargetEffects[k]);
				if (Effect != none)
				{
					if (k == 0)
					{
						X2Effect_Persistent(Template.AbilityTargetEffects[k]).EffectName = 'HackRewardBuffEnemy0';
					}
					if (k == 1)
					{
						X2Effect_Persistent(Template.AbilityTargetEffects[k]).EffectName = 'HackRewardBuffEnemy1';
					}
				}
			}
			break;
		default:
			break;
	}

	// centralizing suppression rules. first batch is new vanilla abilities restricted by suppress.
	// second batch is abilities affected by vanilla suppression that need area suppression change
	// Third batch are vanilla abilities that need suppression limits AND general shooter effect exclusions
	// Mod abilities have restrictions in template defintions
	switch (Template.DataName)
	{
		case 'ThrowGrenade':
		case 'LaunchGrenade':
		case 'MicroMissiles':
		case 'RocketLauncher':
		case 'PoisonSpit':
		case 'GetOverHere':
		case 'Bind':
		case 'AcidBlob':
		case 'BlazingPinionsStage1':
		case 'HailOfBullets':
		case 'SaturationFire':
		case 'Demolition':
		case 'PlasmaBlaster':
		case 'ShredderGun':
		case 'ShredstormCannon':
		case 'BladestormAttack':
		case 'Grapple':
		case 'GrapplePowered':
		case 'IntheZone':
		case 'Reaper':
		case 'Suppression':
			SuppressedCondition = new class'X2Condition_UnitEffects';
			SuppressedCondition.AddExcludeEffect(class'X2Effect_Suppression'.default.EffectName, 'AA_UnitIsSuppressed');
			// TODO: SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
			Template.AbilityShooterConditions.AddItem(SuppressedCondition);
			break;
		case 'Overwatch':
		case 'PistolOverwatch':
		case 'SniperRifleOverwatch':
		case 'LongWatch':
		case 'Killzone':		
			SuppressedCondition = new class'X2Condition_UnitEffects';
			// TODO: SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
			Template.AbilityShooterConditions.AddItem(SuppressedCondition);
			break;
		case 'MarkTarget':
		case 'EnergyShield':
		case 'EnergyShieldMk3':
		case 'BulletShred':
		case 'Stealth':
			Template.AddShooterEffectExclusions();
			SuppressedCondition = new class'X2Condition_UnitEffects';
			SuppressedCondition.AddExcludeEffect(class'X2Effect_Suppression'.default.EffectName, 'AA_UnitIsSuppressed');
			// TODO: SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
			Template.AbilityShooterConditions.AddItem(SuppressedCondition);
			break;
		default:
			break;
	}

	if (Template.DataName == 'Shadowfall')
	{
		StandardAim = X2AbilityToHitCalc_StandardAim(Template.AbilityToHitCalc);
		if (StandardAim != none)
		{
			StandardAim.bGuaranteedHit = false;
			StandardAim.bAllowCrit = true;
			Template.AbilityToHitCalc = StandardAim;
			Template.AbilityToHitOwnerOnMissCalc = StandardAim;
		}
	}

	if (Template.DataName == class'X2Ability_Viper'.default.BindAbilityName)
	{
		SuppressedCondition = new class'X2Condition_UnitEffects';
		SuppressedCondition.AddExcludeEffect(class'X2Effect_Suppression'.default.EffectName, 'AA_UnitIsSuppressed');
		// TODO: SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
		SuppressedCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.StunnedName, 'AA_UnitIsStunned');
		Template.AbilityTargetConditions.AddItem(SuppressedCondition);
	}

	if (Template.DataName == 'Mindspin' || Template.DataName == 'Domination' || Template.DataName == class'X2Ability_PsiWitch'.default.MindControlAbilityName)
	{
		UnitEffectsCondition = new class'X2Condition_UnitEffects';
		UnitEffectsCondition.AddExcludeEffect(class'X2AbilityTemplateManager'.default.StunnedName, 'AA_UnitIsStunned');
		Template.AbilityTargetConditions.AddItem(UnitEffectsCondition);
	}

	if (Template.DataName == 'ThrowGrenade')
	{
		Cooldown = new class'X2AbilityCooldown_AllInstances';
		Cooldown.iNumTurns = default.THROW_GRENADE_COOLDOWN;
		Template.AbilityCooldown = Cooldown;
		X2AbilityToHitCalc_StandardAim(Template.AbilityToHitCalc).bGuaranteedHit = true;
	}

	if (Template.DataName == 'LaunchGrenade')
	{
		X2AbilityToHitCalc_StandardAim(Template.AbilityToHitCalc).bGuaranteedHit = true;
	}

	if (Template.DataName == 'PistolStandardShot')
	{
		// TODO
		//Template.AbilityCosts.length = 0;
		//QuickdrawActionPointCost = new class'X2AbilityCost_QuickdrawActionPoints_LW';
		//QuickdrawActionPointCost.iNumPoints = 1;
		//QuickdrawActionPointCost.bConsumeAllPoints = true;
		//Template.AbilityCosts.AddItem(QuickdrawActionPointCost);
		AmmoCost = new class'X2AbilityCost_Ammo';
		AmmoCost.iAmmo = 1;
		Template.AbilityCosts.AddItem(AmmoCost);
	}

	if (Template.DataName == 'Faceoff')
	{
		//Template.AbilityCooldown = none;
		if (default.FACEOFF_CHARGES > 0)
		{
			Charges = new class'X2AbilityCharges';
			Charges.InitialCharges = default.FACEOFF_CHARGES;
			Template.AbilityCharges = Charges;
			ChargeCost = new class'X2AbilityCost_Charges';
			ChargeCost.NumCharges = 1;
			Template.AbilityCosts.AddItem(ChargeCost);
		}
		UnitPropertyCondition=new class'X2Condition_UnitProperty';
		UnitPropertyCondition.ExcludeConcealed = true;
		Template.AbilityShooterConditions.AddItem(UnitPropertyCondition);
	}

	if (Template.DataName == 'HunkerDown')
	{
		Template.AbilityTargetEffects.length = 0;
		HunkerDownEffect = new class 'X2Effect_HunkerDown_LW';
		HunkerDownEffect.EffectName = 'HunkerDown';
		HunkerDownEffect.DuplicateResponse = eDupe_Refresh;
		HunkerDownEFfect.BuildPersistentEffect (1,,,, 7);
		HunkerDownEffect.SetDisplayInfo (ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage);
		Template.AddTargetEffect(HunkerDownEffect);
		Template.AddTargetEffect(class'X2Ability_SharpshooterAbilitySet'.static.SharpshooterAimEffect());
	}

	if (Template.DataName == 'Fuse' && default.FUSE_COOLDOWN > 0)
	{
		Cooldown = new class 'X2AbilityCooldown';
		Cooldown.iNumTurns = default.FUSE_COOLDOWN;
		Template.AbilityCooldown = Cooldown;
	}

	// Sets to one shot per target a turn
	if (Template.DataName == 'Sentinel')
	{
		Template.AbilityTargetEffects.length = 0;
	    GuardianEffect = new class'X2Effect_Guardian_LW';
	    GuardianEffect.BuildPersistentEffect(1, true, false);
	    GuardianEffect.SetDisplayInfo(0, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
	    GuardianEffect.ProcChance = class'X2Ability_SpecialistAbilitySet'.default.GUARDIAN_PROC;
	    Template.AddTargetEffect(GuardianEffect);
	}

	// Adds shieldHP bonus
	if (Template.DataName == 'SoulSteal')
	{
		Template.AdditionalAbilities.AddItem('SoulStealTriggered2');
	}

	// When completeing a control robot hack remove any previous disorient effects as is done for dominate.
	if (Template.DataName == 'HackRewardControlRobot' || Template.DataName == 'HackRewardControlRobotWithStatBoost')
	{
		`Log("Adding disorient removal to " $ Template.DataName);
		Template.AddTargetEffect(class'X2StatusEffects'.static.CreateMindControlRemoveEffects());
		Template.AddTargetEffect(class'X2StatusEffects'.static.CreateStunRecoverEffect());
	}

	if (Template.DataName == 'FinalizeHaywire')
	{
		HaywiredEffect = new class'X2Effect_Persistent';
		HaywiredEffect.EffectName = 'Haywired';
		HaywiredEffect.BuildPersistentEffect(1, true, false);
		HaywiredEffect.bDisplayInUI = false;
		HaywiredEffect.bApplyOnMiss = true;
		Template.AddTargetEffect(HaywiredEffect);
	}

	if (Template.DataName == 'HaywireProtocol') 
	{
		NotHaywiredCondition = new class 'X2Condition_UnitEffects';
		NotHaywiredCondition.AddExcludeEffect ('Haywired', 'AA_NoTargets'); 
		Template.AbilityTargetConditions.AddItem(NotHaywiredCondition);
	}

	if (Template.DataName == 'Evac')
	{
		// Only mastered mind-controlled enemies can evac. Insert this one first, as it will return
		// 'AA_AbilityUnavailable' if they can't use the ability, so it will be hidden on any MC'd
		// alien instead of being shown but disabled when they aren't in an evac zone due to that
		// condition returning a different code.
		Template.AbilityShooterConditions.InsertItem(0, new class'X2Condition_MasteredEnemy');
	}

	switch (Template.DataName)
	{
		case 'OverwatchShot':
		case 'LongWatchShot':
		case 'GunslingerShot':
		case 'KillZoneShot':
		case 'PistolOverwatchShot':
		case 'SuppressionShot_LW':
		case 'SuppressionShot':
		case 'AreaSuppressionShot_LW':
		case 'CloseCombatSpecialistAttack':
			/* TODO
			ShotEffect = class'X2Ability_PerkPackAbilitySet'.static.CoveringFireMalusEffect();
			ShotEffect.TargetConditions.AddItem(class'X2Ability_DefaultAbilitySet'.static.OverwatchTargetEffectsCondition());
			Template.AddTargetEffect(ShotEffect);
			*/
	}

	if (default.USE_ACTION_ICON_COLORS)
	{
		for (k = 0; k < Template.AbilityCosts.length; k++)
		{
			ActionPointCost = X2AbilityCost_ActionPoints(Template.AbilityCosts[k]);
			if (ActionPointCost != none)
			{
				if (X2AbilityCost_ActionPoints(Template.AbilityCosts[k]).bAddWeaponTypicalCost)
				{
					Template.AbilityIconColor = "Variable";
				}
			}
		}

		switch (Template.DataName)
		{
			case 'LaunchGrenade':				// Salvo, Rapid Deployment
			case 'ThrowGrenade':				// Salvo, Rapid Deployment
			case 'LWFlamethrower':				// Quickburn
			case 'Roust':						// Quickburn
			case 'Firestorm':					// Quickburn
			case 'LWRocketLauncher':			// Salvo
			case 'LWBlasterLauncher':			// Salvo
			case 'RocketLauncher':				// Salvo
			case 'ConcussionRocket':			// Salvo
			case 'ShredderGun':					// Salvo
			case 'PlasmaBlaster':				// Salvo
			case 'ShredstormCannon':			// Salvo
			case 'Flamethrower':				// Salvo
			case 'FlamethrowerMk2':				// Salvo
			case 'Holotarget':					// Rapid Targeting (passive)
			case 'Reload':						// Weapon Upgrade
			case 'PlaceEvacZone':
			case 'PlaceDelayedEvacZone':
			case 'PistolStandardShot':			// Quickdraw
			case 'ClutchShot':					// Quickdraw
			case 'KillZone':					// Varies by weapon type
			case 'DeadEye':						// Varies by weapon type
			case 'Flush':						// Varies by weapon type
			case 'PrecisionShot':				// Varies by weapon type
			case 'BulletShred':					// varies by weapon type
				Template.AbilityIconColor = "Variable"; break; // This calls a function that changes the color on the fly
			case 'EVAC': 
				Template.AbilityIconColor = default.ICON_COLOR_FREE; break;
			case 'IntrusionProtocol':
			case 'IntrusionProtocol_Chest':
			case 'Hack_Chest':
				Template.AbilityIconColor = default.ICON_COLOR_1; break;
			case 'IntrusionProtocol_ObjectiveChest':
			case 'Hack_Workstation':
			case 'Hack_ObjectiveChest':
			case 'PlantExplosiveMissionDevice':
			case 'GatherEvidence':
			case 'Interact_PlantBomb':
			case 'Interact_TakeVial':
			case 'Interact_StasisTube':
			case 'IntrusionProtocol_Workstation':
			case 'Interact_SmashNGrab':
				Template.AbilityIconColor = default.ICON_COLOR_OBJECTIVE; break;
			case 'HaywireProtocol':
			case 'FullOverride':
			case 'SKULLJACKAbility':
			case 'SKULLMINEAbility':
			case 'Bombard':
				Template.AbilityIconColor = default.ICON_COLOR_END; break;
			default:
				Template.AbilityIconColor = GetIconColorByActionPoints (Template); break;
		}
	}

    // Yellow alert scamper ability table. Search these abilities for an X2AbilityCost_ActionPoints
    // and add the special 'ReflexActionPoint_LW' to the list of valid action points that can be used
    // for these actions. These special action points are awarded to some units during a scamper, and
    // they will only be able to use the abilities configured here.
    if (OffensiveReflexAbilities.Find(Template.DataName) >= 0)
    {
        AddReflexActionPoint(Template, class'Listener_XComGameState_Units'.const.OffensiveReflexAction);
    }

    if (DefensiveReflexAbilities.Find(Template.DataName) >= 0)
    {
        AddReflexActionPoint(Template, class'Listener_XComGameState_Units'.const.DefensiveReflexAction);
    }

	if (DoubleTapAbilities.Find(Template.DataName) >= 0)
	{
		`LOG ("Adding Double Tap to" @ Template.DataName);
		//TODO: AddDoubleTapActionPoint (Template, class'X2Ability_LW_SharpshooterAbilitySet'.default.DoubleTapActionPoint);
	}

	// bugfix, hat tip to BountyGiver, needs test
	if (Template.DataName == 'SkullOuch')
	{
		Template.BuildNewGameStateFn = SkullOuch_BuildGameState;
	}
}

static function string GetIconColorByActionPoints (X2AbilityTemplate Template)
{
	local int k, k2;
	local bool pass, found;
	local X2AbilityCost_ActionPoints		ActionPoints;
	local string AbilityIconColor;

	AbilityIconColor = "";
	for (k = 0; k < Template.AbilityCosts.Length; ++k)
	{	
		ActionPoints = X2AbilityCost_ActionPoints(Template.AbilityCosts[k]);
		if (ActionPoints != none)
		{
			Found = true;
			if (Template.AbilityIconColor == "53b45e") //Objective
			{
				AbilityIconColor = default.ICON_COLOR_OBJECTIVE; // orange
			} 
			else 
			{
				if (Template.AbilitySourceName == 'eAbilitySource_Psionic') 
				{
					if (ActionPoints.iNumPoints >= 2) 
					{
						AbilityIconColor = default.ICON_COLOR_PSIONIC_2;
					}
					else 
					{
						if (ActionPoints.bConsumeAllPoints) 
						{
							AbilityIconColor = default.ICON_COLOR_PSIONIC_END;
						} 
						else 
						{
							if (ActionPoints.iNumPoints == 1 && !ActionPoints.bFreeCost)
							{
								AbilityIconColor = default.ICON_COLOR_PSIONIC_1; // light lavender
							}
							else
							{	
								AbilityIconColor = default.ICON_COLOR_PSIONIC_FREE; // lavender-white
							}
						}
					}
				} 
				else 
				{
					if (ActionPoints.iNumPoints >= 2) 
					{
						AbilityIconColor = default.ICON_COLOR_2; // yellow
					}
					else 
					{
						if (ActionPoints.bConsumeAllPoints) 
						{
							AbilityIconColor = default.ICON_COLOR_END; // cyan
						} 
						else 
						{
							if (ActionPoints.iNumPoints == 1 && !ActionPoints.bFreeCost)
							{
								AbilityIconColor = default.ICON_COLOR_1; // white
							}
							else
							{
								AbilityIconColor = default.ICON_COLOR_FREE; //green
							}
						}
					}
				}
			}
			break;
		}
	}
	if (!found)
	{
		pass= false;
		for (k2 = 0; k2 < Template.AbilityTriggers.Length; k2++)
		{
	       if(Template.AbilityTriggers[k2].IsA('X2AbilityTrigger_PlayerInput'))
			{
				pass = true;
			}
		}
		if (pass)
		{
			if (Template.AbilitySourceName == 'eAbilitySource_Psionic') 
			{
				AbilityIconColor = default.ICON_COLOR_PSIONIC_FREE;
			}
			else
			{
				AbilityIconColor = default.ICON_COLOR_FREE;
			}
		}
	}
	return AbilityIconColor;
}

static function XComGameState SkullOuch_BuildGameState (XComGameStateContext context)
{
	local XComGameState NewGameState;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit UnitState;

	NewGameState = class'X2Ability'.static.TypicalAbility_BuildGameState(context);
	AbilityContext = XComGameStateContext_Ability(NewGameState.GetContext()); // or should it be just context
    UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', AbilityContext.InputContext.SourceObject.ObjectID));
	UnitState.Abilities.RemoveItem(AbilityContext.InputContext.AbilityRef);
	NewGameState.AddStateObject(UnitState);
	return NewGameState;
}

function AddReflexActionPoint(X2AbilityTemplate Template, Name ActionPointName)
{
    local X2AbilityCost_ActionPoints        ActionPointCost;
    local X2AbilityCost                     Cost;

    foreach Template.AbilityCosts(Cost)
    {
        ActionPointCost = X2AbilityCost_ActionPoints(Cost);
        if (ActionPointCost != none)
        {
            ActionPointCost.AllowedTypes.AddItem(ActionPointName);
            `LWTrace("Adding reflex action point " $ ActionPointName $ " to " $ Template.DataName);
            return;
        }
    }

    `Log("Cannot add reflex ability " $ Template.DataName $ ": Has no action point cost");
}

function AddDoubleTapActionPoint(X2AbilityTemplate Template, Name ActionPointName)
{
	local X2AbilityCost_ActionPoints        ActionPointCost;
    local X2AbilityCost                     Cost;

	foreach Template.AbilityCosts(Cost)
    {
        ActionPointCost = X2AbilityCost_ActionPoints(Cost);
        if (ActionPointCost != none)
        {
			ActionPointCost.AllowedTypes.AddItem(ActionPointName);
		}
	}
}
//cyan 9acbcb
//red bf1e2e
//yellow fdce2b
//orange e69831
//green 53b45e
//gray 828282
//purple b6b3e3