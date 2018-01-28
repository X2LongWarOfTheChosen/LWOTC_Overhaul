class Override_TemplateMods_CharacterMod extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateGeneralCharacterModTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateGeneralCharacterModTemplate()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'GeneralCharacterMod');

    // We need to modify character templates
    Template.CharacterTemplateModFn = GeneralCharacterMod;
    return Template;
}

function GeneralCharacterMod(X2CharacterTemplate Template, int Difficulty)
{
	local LootReference Loot;

	if (class'X2Effect_TransferMecToOutpost'.default.VALID_FULLOVERRIDE_TYPES_TO_TRANSFER_TO_OUTPOST.Find(Template.DataName) >= 0)
	{
		`Log("Adding evac to " $ Template.DataName);
		Template.Abilities.AddItem('Evac');
	}

	switch (Template.DataName)
	{
		// Give ADVENT the hunker down ability
		case 'AdvTrooperM1':
		case 'AdvTrooperM2':
		case 'AdvTrooperM3':
		case 'AdvCaptainM1':
		case 'AdvCaptainM2':
		case 'AdvCaptainM3':
		case 'AdvShieldbearerM2':
		case 'AdvShieldbearerM3':
		case 'AdvStunLancerM1':
			Template.Abilities.AddItem('HunkerDown');
			break;
		case 'FacelessCivilian':
			// Set 'FacelessCivilian' as being hostile. These are mostly only used
			// with the Infiltrators DE, and without this set it's trivial to detect
			// which civilians are faceless because they won't have stealth detection
			// tiles around them.
			Template.bIsHostileCivilian = true;
			// Add faceless loot to the faceless civilian template. Ensures a corpse
			// drops if you kill the civvy before they transform (e.g. by stunning them 
			// first, or doing enough damage to kill them from concealment).
			Loot.ForceLevel = 0;
			Loot.LootTableName = 'Faceless_BaseLoot';
			Template.Loot.LootReferences.AddItem(Loot);
			break;
		case 'Gatekeeper':
			Template.ImmuneTypes.AddItem('Poison');
			Template.ImmuneTypes.AddItem(class'X2Item_DefaultDamageTypes'.default.ParthenogenicPoisonType);
			Template.ImmuneTypes.AddItem('Fire');
			break;
		case 'AdvStunLancerM2':
			Template.Abilities.AddItem('HunkerDown');
			Template.Abilities.AddItem('CoupdeGrace2');
			break;
		case 'AdvStunLancerM3':
			Template.Abilities.AddItem('HunkerDown');
			Template.Abilities.AddItem('CoupdeGrace2');
			Template.Abilities.AddItem('Whirlwind2');
			break;
		// Should turn off tick damage every action
		case 'ViperKing':
		case 'BerserkerQueen':
		case 'ArchonKing':
			Template.bCanTickEffectsEveryAction = false;
			break;
		case 'LostTowersSpark':
		case 'SparkSoldier':
			Template.bIgnoreEndTacticalHealthMod = false;		// This means Repair perk won't permanently fix Sparks
			Template.OnEndTacticalPlayFn = none;
			break;
		default:
			break;
	}

	// Any soldier templates get the Interact_SmashNGrab ability
	if (Template.bIsSoldier)
	{
		Template.Abilities.AddItem('Interact_SmashNGrab');
	}
}