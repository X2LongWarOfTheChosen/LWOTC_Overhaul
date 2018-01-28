class Override_TemplateMods_ReconfigureGear extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct ItemTableEntry
{
	var name ItemTemplateName;
	var int Slots;
	var bool Starting;
	var bool Infinite;
	var bool Buildable;
	var name RequiredTech1;
	var name RequiredTech2;
	var int SupplyCost;
	var int AlloyCost;
	var int CrystalCost;
	var int CoreCost;
	var name SpecialItemTemplateName;
	var int SpecialItemCost;
	var int TradingPostValue;
	var int RequiredEngineeringScore;
	var int PointsToComplete;
	var int Weight;
	var int Tier;
	var string InventoryImage;
	
	structdefaultproperties
	{
		ItemTemplateName=None
		Slots=3
		Starting=false
		Infinite=false
		Buildable=false
		RequiredTech1=none
		RequiredTech2=none
		SupplyCost=0
		AlloyCost=0
		CrystalCost=0
		CoreCost=0
		SpecialItemTemplateName=None
		SpecialItemCost=0
		TradingPostValue=0
		RequiredEngineeringScore=0
		PointsToComplete=0
		Weight = 0
		Tier = -1
		InventoryImage = ""
	}
};

var config array<ItemTableEntry> ItemTable;

var config int MEDIUM_PLATED_MITIGATION_AMOUNT;
var config int DRAGON_ROUNDS_APPLY_CHANCE;
var config int VENOM_ROUNDS_APPLY_CHANCE;
var config int FIREBOMB_FIRE_APPLY_CHANCE;
var config int FIREBOMB_2_FIRE_APPLY_CHANCE;
var config int FUSION_SWORD_FIRE_CHANCE;

var config array<name> SchematicsToPreserve;

var config bool EARLY_TURRET_SQUADSIGHT;
var config bool MID_TURRET_SQUADSIGHT;
var config bool LATE_TURRET_SQUADSIGHT;

var config bool EXPLOSIVES_NUKE_CORPSES;

var config int SMALL_INTEL_CACHE_REWARD;
var config int LARGE_INTEL_CACHE_REWARD;

var config bool INSTANT_BUILD_TIMES;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.Additem(CreateReconfigGearTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateReconfigGearTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ReconfigGear');
	Template.ItemTemplateModFn = ReconfigGear;
	return Template;
}

function ReconfigGear(X2ItemTemplate Template, int Difficulty)
{
	local X2WeaponTemplate WeaponTemplate;
	local X2SchematicTemplate SchematicTemplate;
	local X2EquipmentTemplate EquipmentTemplate;
	local X2WeaponUpgradeTemplate WeaponUpgradeTemplate;
	local X2GrenadeTemplate GrenadeTemplate;
	local X2AmmoTemplate AmmoTemplate;
	local int i, k;
	local ArtifactCost Resources;
	local X2ArmorTemplate ArmorTemplate;
    local StrategyRequirement AltReq;
	local X2GremlinTemplate GremlinTemplate;
	local delegate<X2StrategyGameRulesetDataStructures.SpecialRequirementsDelegate> SpecialRequirement;
	local X2Effect_Persistent Effect;

	// Reconfig Weapons and Weapon Schematics
	WeaponTemplate = X2WeaponTemplate(Template);
	if (WeaponTemplate != none)
	{
		// substitute cannon range table
		if (WeaponTemplate.WeaponCat == 'cannon')
		{		
			WeaponTemplate.RangeAccuracy = class'X2Item_DefaultWeaponMods_LW'.default.LMG_ALL_RANGE;
		}
		if (WeaponTemplate.DataName == 'Medikit')
		{
			WeaponTemplate.HideIfResearched = '';
		}
		if (WeaponTemplate.DataName == 'Medikit' || WeaponTemplate.DataName == 'NanoMedikit')
		{
			WeaponTemplate.Abilities.AddItem('Sedate');
		}
		if (WeaponTemplate.DataName == 'AdvTurretM1_WPN' && default.EARLY_TURRET_SQUADSIGHT)
		{
			WeaponTemplate.Abilities.AddItem('Squadsight');
		}
		if (WeaponTemplate.DataName == 'AdvTurretM2_WPN' && default.MID_TURRET_SQUADSIGHT)
		{
			WeaponTemplate.Abilities.AddItem('Squadsight');
		}
		if (WeaponTemplate.DataName == 'AdvTurretM3_WPN' && default.LATE_TURRET_SQUADSIGHT)
		{
			WeaponTemplate.Abilities.AddItem('Squadsight');
		}

		//if (WeaponTemplate.Abilities.Find('StandardShot') != -1)
		//{
			//WeaponTemplate.Abilities.AddItem('ReflexShot');
			//`LWTRACE ("Adding ReflexShot to" @ WeaponTemplate.DataName);
		//}

		//switch (WeaponTemplate.DataName)
		//{
			//case 'MutonM2_LW_WPN':
			//case 'MutonM3_LW_WPN':
			//case 'NajaM1_WPN':
			//case 'NajaM2_WPN':
			//case 'NajaM3_WPN':
			//case 'SidewinderM1_WPN':
			//case 'SidewinderM2_WPN':
			//case 'SidewinderM3_WPN':
				//break;
			//default;
				//break;
		//}
		for (i=0; i < ItemTable.Length; ++i)
		{
			if (WeaponTemplate.DataName == ItemTable[i].ItemTemplateName)
			{
				WeaponTemplate.NumUpgradeSlots = ItemTable[i].Slots;
			}
		}
		switch (WeaponTemplate.DataName)
		{
			case 'Muton_MeleeAttack':
			case 'AndromedonRobot_MeleeAttack':
			case 'ArchonStaff':
			case 'Viper_Tongue_WPN':
			case 'PsiZombie_MeleeAttack':
				WeaponTemplate.iEnvironmentDamage = 0;
				break;
			case 'Faceless_MeleeAoE':
				WeaponTemplate.iEnvironmentDamage = 5;
				break;
			default:
				break;
		}
		if (WeaponTemplate.DataName == 'Sword_BM')
		{
			for (k = 0; k < WeaponTemplate.BonusWeaponEffects.length; k++)
			{
				Effect = X2Effect_Persistent(WeaponTemplate.BonusWeaponEffects[k]);
				if (Effect != none)
				{
					if (Effect.EffectName == class'X2StatusEffects'.default.BurningName)
					{
						Effect.ApplyChance = default.FUSION_SWORD_FIRE_CHANCE;
					}
				}
			}

		}
	}	

	GremlinTemplate = X2GremlinTemplate(Template);
	if (GremlinTemplate != none)
	{
		if (GremlinTemplate.DataName == 'Gremlin_MG')
		{
			GremlinTemplate.RevivalChargesBonus = 1;
			GremlinTemplate.ScanningChargesBonus = 1;
			GremlinTemplate.AidProtocolBonus = 5;
		}
		if (GremlinTemplate.DataName == 'Gremlin_BM')
		{
			GremlinTemplate.RevivalChargesBonus = 2;
			GremlinTemplate.ScanningChargesBonus = 2;
			GremlinTemplate.AidProtocolBonus = 10;
		}
		if (GremlinTemplate.DataName == 'SparkBit_MG')
		{
			GremlinTemplate.HealingBonus = 1;
		}
		if (GremlinTemplate.DataName == 'SparkBit_BM')
		{
			GremlinTemplate.HealingBonus = 2;
		}
	}
	
	// KILL SCHEMATICS
	SchematicTemplate = X2SchematicTemplate(Template);
	if (SchematicTemplate != none && default.SchematicsToPreserve.Find(SchematicTemplate.DataName) == -1)
	{
		SchematicTemplate.CanBeBuilt = false;
		SchematicTemplate.PointsToComplete = 999999;
		SchematicTemplate.Requirements.RequiredEngineeringScore = 999999;
		SchematicTemplate.Requirements.bVisibleifPersonnelGatesNotMet = false;
		SchematicTemplate.OnBuiltFn = none;
		SchematicTemplate.Cost.ResourceCosts.Length = 0;
		SchematicTemplate.Cost.ArtifactCosts.Length = 0;
	}
	// special handling of DLC2 schematics so that they can't be used when units with them are deployed
	if (SchematicTemplate != none)
	{
		switch (SchematicTemplate.DataName)
		{
			case 'HunterRifle_MG_Schematic':
			case 'HunterRifle_BM_Schematic':
			case 'HunterPistol_MG_Schematic':
			case 'HunterPistol_BM_Schematic':
			case 'HunterAxe_MG_Schematic':
			case 'HunterAxe_BM_Schematic':
				class'LWOTC_DLCHelpers'.static.GetAlienHunterWeaponSpecialRequirementFunction(SpecialRequirement, SchematicTemplate.DataName);
				SchematicTemplate.Requirements.SpecialRequirementsFn = SpecialRequirement;
				SchematicTemplate.AlternateRequirements[0].SpecialRequirementsFn = SpecialRequirement;
				break;
			default:
				break;
		}

	}
	// ALL ITEMS, including resources -- config art and trading post value
	for (i=0; i < ItemTable.Length; ++i)
	{			
		if (Template.DataName == ItemTable[i].ItemTemplateName)
		{
			if (ItemTable[i].TradingPostValue != 0)
				Template.TradingPostValue = ItemTable[i].TradingPostValue;
			if (ItemTable[i].InventoryImage != "")
				Template.strInventoryImage = ItemTable[i].InventoryImage;
			if (ItemTable[i].Tier > -1)
			{
				Template.Tier = ItemTable[i].Tier;
			}
		}
	}

	if (default.EXPLOSIVES_NUKE_CORPSES)
	{
		// NOTE: Leaving off Codex and Avatar for plot reasons
		switch (Template.DataName)
		{
			case 'CorpseSectoid':
			case 'CorpseViper':
			case 'CorpseMuton':
			case 'CorpseBerserker':
			case 'CorpseArchon':
			case 'CorpseAndromedon':
			case 'CorpseFaceless':
			case 'CorpseChryssalid':
			case 'CorpseGatekeeper':
			case 'CorpseAdventTrooper':
			case 'CorpseAdventOfficer':
			case 'CorpseAdventTurret':
			case 'CorpseAdventMEC':
			case 'CorpseAdventStunLancer':
			case 'CorpseAdventShieldbearer':
			case 'CorpseDrone':
			case 'CorpseMutonElite':
				Template.LeavesExplosiveRemains = false;
				break;
			default:
				break;
		}
	}

	if (Template.DataName == 'SmallIntelCache')
	{
		Template.ResourceQuantity = default.SMALL_INTEL_CACHE_REWARD;
		`LWTRACE("SETTING SMALL INTEL CACHE REWARD TO" @ Template.ResourceQuantity);
	}
	if (Template.DataName == 'BigIntelCache')
	{
		Template.ResourceQuantity = default.LARGE_INTEL_CACHE_REWARD;
		`LWTRACE("SETTING LARGE INTEL CACHE REWARD TO" @ Template.ResourceQuantity);
	}

	EquipmentTemplate = X2EquipmentTemplate(Template);
	if (EquipmentTemplate != none)
	{
		if (EquipmentTemplate.DataName == 'HazmatVest') // BUGFIX TO INCLUDE ACID IMMUNITY
		{
			EquipmentTemplate.Abilities.Length = 0;
			EquipmentTemplate.Abilities.AddItem ('HazmatVestBonus_LW');
		}
		if (EquipmentTemplate.DataName == 'NanofiberVest') // THIS JUST MAKES IT BETTER
		{
			EquipmentTemplate.Abilities.Length = 0;
			EquipmentTemplate.Abilities.AddItem ('NanofiberVestBonus_LW');
		}
		///Add an ability icon for all of these so people can keep ammo straight
		if (EquipmentTemplate.DataName == 'APRounds')
		{
			if (EquipmentTemplate.Abilities.Find('AP_Rounds_Ability_PP') == -1)
			{
				EquipmentTemplate.Abilities.AddItem('AP_Rounds_Ability_PP');
			}
		}
		if (EquipmentTemplate.DataName == 'TalonRounds')
		{
			if (EquipmentTemplate.Abilities.Find('Talon_Rounds_Ability_PP') == -1)
			{
				EquipmentTemplate.Abilities.AddItem('Talon_Rounds_Ability_PP');
			}
		}
		if (EquipmentTemplate.DataName == 'VenomRounds')
		{
			if (EquipmentTemplate.Abilities.Find('Venom_Rounds_Ability_PP') == -1)
			{
				EquipmentTemplate.Abilities.AddItem('Venom_Rounds_Ability_PP');
			}
		}
		if (EquipmentTemplate.DataName == 'IncendiaryRounds')
		{
			if (EquipmentTemplate.Abilities.Find('Dragon_Rounds_Ability_PP') == -1)
			{
				EquipmentTemplate.Abilities.AddItem('Dragon_Rounds_Ability_PP');
			}
		}
		if (EquipmentTemplate.DataName == 'BluescreenRounds')
		{
			if (EquipmentTemplate.Abilities.Find('Bluescreen_Rounds_Ability_PP') == -1)
			{
				EquipmentTemplate.Abilities.AddItem('Bluescreen_Rounds_Ability_PP');
			}
		}
		if (EquipmentTemplate.DataName == 'TracerRounds')
		{
			if (EquipmentTemplate.Abilities.Find('Tracer_Rounds_Ability_PP') == -1)
			{
				EquipmentTemplate.Abilities.AddItem('Tracer_Rounds_Ability_PP');
			}
		}
		// Adds stat markup for medium plated armor
		ArmorTemplate = X2ArmorTemplate(Template);
		if (ArmorTemplate != none)
		{
			if (ArmorTemplate.DataName == 'MediumPlatedArmor')
			{
			    ArmorTemplate.SetUIStatMarkup(class'XLocalizedData'.default.ArmorLabel, 14, default.MEDIUM_PLATED_MITIGATION_AMOUNT);
			}
			if (ArmorTemplate.DataName == 'SparkArmor')
			{
				ArmorTemplate.Abilities.AddItem('Carapace_Plating_Ability');
			}
			if (ArmorTemplate.DataName == 'PlatedSparkArmor')
			{
				ArmorTemplate.Abilities.AddItem('Carapace_Plating_Ability');
			}
			if (ArmorTemplate.DataName == 'PoweredSparkArmor')
			{
				ArmorTemplate.Abilities.AddItem('Carapace_Plating_Ability');
			}
		}

		GrenadeTemplate = X2GrenadeTemplate(Template);
		if (GrenadeTemplate != none)
		{
			if (GrenadeTemplate.DataName == 'ProximityMine')
			{
				GrenadeTemplate.iEnvironmentDamage = class'X2Item_DefaultWeaponMods_LW'.default.PROXIMITYMINE_iENVIRONMENTDAMAGE;
			}
			if (GrenadeTemplate.DataName == 'MutonGrenade')
			{
				GrenadeTemplate.iEnvironmentDamage = class'X2Item_DefaultWeaponMods_LW'.default.MUTONGRENADE_iENVIRONMENTDAMAGE;
			}
			if (GrenadeTemplate.DataName == 'FragGrenade')
			{
				GrenadeTemplate.HideIfResearched = '';
			}
			if (GrenadeTemplate.DataName == 'SmokeGrenade')
			{
				GrenadeTemplate.HideIfResearched = '';
			}
			if (GrenadeTemplate.DataName == 'EMPGrenade')
			{
				GrenadeTemplate.HideIfResearched = '';
			}
			if (GrenadeTemplate.DataName == 'FireBomb' || GrenadeTemplate.DataName == 'FireBombMk2')
			{
				for (k = 0; k < GrenadeTemplate.ThrownGrenadeEffects.length; k++)
				{
					if (GrenadeTemplate.ThrownGrenadeEffects[k].IsA ('X2Effect_Burning'))
					{
						GrenadeTemplate.ThrownGrenadeEffects[k].ApplyChance = default.FIREBOMB_FIRE_APPLY_CHANCE;
					}
				}
				for (k = 0; k < GrenadeTemplate.LaunchedGrenadeEffects.length; k++)
				{
					if (GrenadeTemplate.LaunchedGrenadeEffects[k].IsA ('X2Effect_Burning'))
					{
						GrenadeTemplate.LaunchedGrenadeEffects[k].ApplyChance = default.FIREBOMB_2_FIRE_APPLY_CHANCE;
					}
				}
			}


			switch (GrenadeTemplate.DataName) 
			{
				case 'AlienGrenade' :
				case 'MutonGrenade' :
				case 'MutonM2_LWGrenade' :
				case 'MutonM3_LWGrenade' :
					GrenadeTemplate.AddAbilityIconOverride('ThrowGrenade', "img:///UILibrary_LW_Overhaul.UIPerk_grenade_aliengrenade");
					GrenadeTemplate.AddAbilityIconOverride('LaunchGrenade', "img:///UILibrary_LW_Overhaul.UIPerk_grenade_aliengrenade");
					`LWTRACE("Added Ability Icon Override for Alien Grenade");
					break;
				default :
					break;
			}
		}

		AmmoTemplate = X2AmmoTemplate(Template);
		if (AmmoTemplate != none)
		{
			if (AmmoTemplate.DataName == 'IncendiaryRounds')
			{
				for (k = 0; k < AmmoTemplate.TargetEffects.length; k++)
				{
					if (AmmoTemplate.TargetEffects[k].IsA ('X2Effect_Burning'))
					{
						AmmoTemplate.TargetEffects[k].ApplyChance = default.DRAGON_ROUNDS_APPLY_CHANCE;
					}
				}
			}
			if (AmmoTemplate.DataName == 'VenomRounds')
			{
				for (k = 0; k < AmmoTemplate.TargetEffects.length; k++)
				{
					if (AmmoTemplate.TargetEffects[k].IsA ('X2Effect_PersistentStatChange'))
					{
						AmmoTemplate.TargetEffects[k].ApplyChance = default.VENOM_ROUNDS_APPLY_CHANCE;
					}
				}
			}
		}


		switch (EquipmentTemplate.DataName)
		{
			case 'AlienHunterPistol_CV':
			case 'AlienHunterPistol_MG':
			case 'AlienHunterPistol_BM':
				EquipmentTemplate.InventorySlot = eInvSlot_Utility;
				// TODO: X2WeaponTemplate(EquipmentTemplate).RangeAccuracy = class'X2Item_SMGWeapon'.default.MIDSHORT_BEAM_RANGE;
				X2WeaponTemplate(EquipmentTemplate).StowedLocation = eSlot_RearBackPack;
				EquipmentTemplate.Abilities.AddItem('PistolStandardShot'); // in base-game, this ability is a class ability, so need it added for utility slot pistols
				break;
			case 'Cannon_CV': // replace archetype with non-suppression shaking variant
				EquipmentTemplate.GameArchetype = "Cannon_NoShake_LW.Archetypes.WP_Cannon_NoShake_CV";
				break;
			case 'Cannon_MG': // replace archetype with non-suppression shaking variant
				EquipmentTemplate.GameArchetype = "Cannon_NoShake_LW.Archetypes.WP_Cannon_NoShake_MG";
				break;
			case 'Cannon_BM': // replace archetype with non-suppression shaking variant
				EquipmentTemplate.GameArchetype = "Cannon_NoShake_LW.Archetypes.WP_Cannon_NoShake_BM";
				break;
			default:
				break;
		}
		// KILL THE SCHEMATICS! (but only the schematics we want to kill)
		if (EquipmentTemplate.CreatorTemplateName != '' && default.SchematicsToPreserve.Find(EquipmentTemplate.CreatorTemplateName) == -1)
		{
			EquipmentTemplate.CreatorTemplateName = '';
			EquipmentTemplate.BaseItem = '';
			EquipmentTemplate.UpgradeItem = '';
		}
		// Mod
		for (i=0; i < ItemTable.Length; ++i)
		{			
			if (EquipmentTemplate.DataName == ItemTable[i].ItemTemplateName)
			{
				EquipmentTemplate.StartingItem = ItemTable[i].Starting;
				EquipmentTemplate.bInfiniteItem = ItemTable[i].Infinite;
				if (!ItemTable[i].Buildable)
					EquipmentTemplate.CanBeBuilt = false;

				if (ItemTable[i].Buildable)
				{
					EquipmentTemplate.CanBeBuilt = true;
					EquipmentTemplate.Requirements.RequiredEngineeringScore = ItemTable[i].RequiredEngineeringScore;
					EquipmentTemplate.PointsToComplete = ItemTable[i].PointsToComplete;
					if (default.INSTANT_BUILD_TIMES)
					{
						EquipmentTemplate.PointsToComplete = 0;
					}
					EquipmentTemplate.Requirements.bVisibleifPersonnelGatesNotMet = true;
					EquipmentTemplate.Cost.ResourceCosts.Length = 0;
					EquipmentTemplate.Cost.ArtifactCosts.Length = 0;
					EquipmentTemplate.Requirements.RequiredTechs.Length = 0;
					if (ItemTable[i].RequiredTech1 != '')
						EquipmentTemplate.Requirements.RequiredTechs.AddItem(ItemTable[i].RequiredTech1);
					if (ItemTable[i].RequiredTech2 != '')
						EquipmentTemplate.Requirements.RequiredTechs.AddItem(ItemTable[i].RequiredTech2);
					if (ItemTable[i].SupplyCost > 0)
					{
						Resources.ItemTemplateName = 'Supplies';
						Resources.Quantity = ItemTable[i].SupplyCost;
						EquipmentTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].AlloyCost > 0)
					{
						Resources.ItemTemplateName = 'AlienAlloy';
						Resources.Quantity = ItemTable[i].AlloyCost;
						EquipmentTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].CrystalCost > 0)
					{
						Resources.ItemTemplateName = 'EleriumDust';
						Resources.Quantity = ItemTable[i].CrystalCost;
						EquipmentTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].CoreCost > 0)
					{
						Resources.ItemTemplateName = 'EleriumCore';
						Resources.Quantity = ItemTable[i].CoreCost;
						EquipmentTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].SpecialItemTemplateName != '' && ItemTable[i].SpecialItemCost > 0)
					{
						Resources.ItemTemplateName = ItemTable[i].SpecialItemTemplateName;
						Resources.Quantity = ItemTable[i].SpecialItemCost;
						EquipmentTemplate.Cost.ArtifactCosts.AddItem(Resources);
					}
					if (EquipmentTemplate.InventorySlot == eInvSlot_CombatSim)
					{
						EquipmentTemplate.Requirements.RequiredFacilities.AddItem('OfficerTrainingSchool');
					}
				}
				if (EquipmentTemplate.Abilities.Find('SmallItemWeight') == -1)
				{
					if (ItemTable[i].Weight > 0)
					{
						EquipmentTemplate.Abilities.AddItem ('SmallItemWeight');
						EquipmentTemplate.SetUIStatMarkup(class'XLocalizedData'.default.MobilityLabel, eStat_Mobility, -ItemTable[i].Weight, true);

						//`LOG ("Adding Weight to" @ EquipmentTemplate.DataName);
					}
				}
				//special handling for SLG DLC items
				switch (EquipmentTemplate.DataName)
				{
					case 'SparkRifle_MG':
					case 'SparkRifle_BM':
					case 'PlatedSparkArmor':
					case 'PoweredSparkArmor':
					case 'SparkBit_MG':
					case 'SparkBit_BM':
						AltReq.SpecialRequirementsFn = class'LWOTC_DLCHelpers'.static.IsLostTowersNarrativeContentComplete;
						if (ItemTable[i].RequiredTech1 != '')
							AltReq.RequiredTechs.AddItem(ItemTable[i].RequiredTech1);
						Template.AlternateRequirements.AddItem(AltReq);
						break;
					default:
						break;
				}
			}
		}
	}
	
	WeaponUpgradeTemplate = X2WeaponUpgradeTemplate(Template);
	if (WeaponUpgradeTemplate != none)
	{
		//specific alterations
		if (WeaponUpgradeTemplate.DataName == 'AimUpgrade_Bsc')
		{
			WeaponUpgradeTemplate.AimBonus = 0;
			// WeaponUpgradeTemplate.AimBonusNoCover = 0;
			WeaponUpgradeTemplate.AddHitChanceModifierFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Scope_LW_Bsc_Ability');
		}
		if (WeaponUpgradeTemplate.DataName == 'AimUpgrade_Adv')
		{
			WeaponUpgradeTemplate.AimBonus = 0;
			// WeaponUpgradeTemplate.AimBonusNoCover = 0;
			WeaponUpgradeTemplate.AddHitChanceModifierFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Scope_LW_Adv_Ability');
		}
		if (WeaponUpgradeTemplate.DataName == 'AimUpgrade_Sup')
		{
			WeaponUpgradeTemplate.AimBonus = 0;
			// WeaponUpgradeTemplate.AimBonusNoCover = 0;
			WeaponUpgradeTemplate.AddHitChanceModifierFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Scope_LW_Sup_Ability');
		}

		if (WeaponUpgradeTemplate.DataName == 'FreeFireUpgrade_Bsc')
		{
			WeaponUpgradeTemplate.FreeFireChance = 0;
			WeaponUpgradeTemplate.FreeFireCostFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Hair_Trigger_LW_Bsc_Ability');
		}
		if (WeaponUpgradeTemplate.DataName == 'FreeFireUpgrade_Adv')
		{
			WeaponUpgradeTemplate.FreeFireChance = 0;
			WeaponUpgradeTemplate.FreeFireCostFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Hair_Trigger_LW_Adv_Ability');
		}
		if (WeaponUpgradeTemplate.DataName == 'FreeFireUpgrade_Sup')
		{
			WeaponUpgradeTemplate.FreeFireChance = 0;
			WeaponUpgradeTemplate.FreeFireCostFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Hair_Trigger_LW_Sup_Ability');
		}

		if (WeaponUpgradeTemplate.DataName == 'MissDamageUpgrade_Bsc')
		{
			WeaponUpgradeTemplate.BonusDamage.Damage = 0;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Stock_LW_Bsc_Ability');
		}
		if (WeaponUpgradeTemplate.DataName == 'MissDamageUpgrade_Adv')
		{
			WeaponUpgradeTemplate.BonusDamage.Damage = 0;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Stock_LW_Adv_Ability');
		}
		if (WeaponUpgradeTemplate.DataName == 'MissDamageUpgrade_Sup')
		{
			WeaponUpgradeTemplate.BonusDamage.Damage = 0;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			WeaponUpgradeTemplate.BonusAbilities.length = 0;
			WeaponUpgradeTemplate.BonusAbilities.AddItem ('Stock_LW_Sup_Ability');
		}
		
		if (WeaponUpgradeTemplate.DataName == 'FreeKillUpgrade_Bsc' || WeaponUpgradeTemplate.DataName == 'FreeKillUpgrade_Adv' || WeaponUpgradeTemplate.DataName == 'FreeKillUpgrade_Sup')
		{
			WeaponUpgradeTemplate.FreeKillChance = 0;
			WeaponUpgradeTemplate.FreeKillFn = none;
			WeaponUpgradeTemplate.GetBonusAmountFn = none;
			//Abilities are caught elsewhere
		}

		//Config-able items array -- Weapon Upgrades
		for (i=0; i < ItemTable.Length; ++i)
		{			
			if (WeaponUpgradeTemplate.DataName == ItemTable[i].ItemTemplateName)
			{
				WeaponUpgradeTemplate.StartingItem = ItemTable[i].Starting;
				WeaponUpgradeTemplate.bInfiniteItem = ItemTable[i].Infinite;
				if (!ItemTable[i].Buildable)
					WeaponUpgradeTemplate.CanBeBuilt = false;
				if (ItemTable[i].Buildable)
				{
					WeaponUpgradeTemplate.CanBeBuilt = true;
					WeaponUpgradeTemplate.Requirements.RequiredEngineeringScore = ItemTable[i].RequiredEngineeringScore;
					WeaponUpgradeTemplate.PointsToComplete = ItemTable[i].PointsToComplete;
					WeaponUpgradeTemplate.Requirements.bVisibleifPersonnelGatesNotMet = true;
					WeaponUpgradeTemplate.Cost.ResourceCosts.Length = 0;
					WeaponUpgradeTemplate.Cost.ArtifactCosts.Length = 0;
					WeaponUpgradeTemplate.Requirements.RequiredTechs.Length = 0;
					if (ItemTable[i].RequiredTech1 != '')
					{
						WeaponUpgradeTemplate.Requirements.RequiredTechs.AddItem(ItemTable[i].RequiredTech1);
					}
					if (ItemTable[i].RequiredTech2 != '')
						WeaponUpgradeTemplate.Requirements.RequiredTechs.AddItem(ItemTable[i].RequiredTech2);
					if (ItemTable[i].SupplyCost > 0)
					{
						Resources.ItemTemplateName = 'Supplies';
						Resources.Quantity = ItemTable[i].SupplyCost;
						WeaponUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].AlloyCost > 0)
					{
						Resources.ItemTemplateName = 'AlienAlloy';
						Resources.Quantity = ItemTable[i].AlloyCost;
						WeaponUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].CrystalCost > 0)
					{
						Resources.ItemTemplateName = 'EleriumDust';
						Resources.Quantity = ItemTable[i].CrystalCost;
						WeaponUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[i].CoreCost > 0)
					{
						Resources.ItemTemplateName = 'EleriumCore';
						Resources.Quantity = ItemTable[i].CoreCost;
						WeaponUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (ItemTable[1].SpecialItemTemplateName != '' && ItemTable[i].SpecialItemCost > 0)
					{
						Resources.ItemTemplateName = ItemTable[i].SpecialItemTemplateName;
						Resources.Quantity = ItemTable[i].SpecialItemCost;
						WeaponUpgradeTemplate.Cost.ArtifactCosts.AddItem(Resources);
					}

					if (default.INSTANT_BUILD_TIMES)
					{		
						WeaponUpgradeTemplate.PointsToComplete = 0;
					}

				}
			}
		}
	}
}