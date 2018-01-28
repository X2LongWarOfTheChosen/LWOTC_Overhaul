class Override_TemplateMods_DelayedEvac extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateDelayedEvacTemplate());

    return Templates;
}

// Replace the base game "PlaceEvacZone" ability with a new "PlaceDelayedEvacZone" ability.
static function Override_TemplateMods_Template CreateDelayedEvacTemplate()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'DelayedEvacMod');

    // We need to modify character templates
    Template.CharacterTemplateModFn = ReplacePlaceEvacAbility;
    return Template;
}

// Remove the 'PlaceEvacZone' ability from all characters. This has been replaced by
// the 'PlaceDelayedEvacZone', which is technically an item-granted ability to permit
// it to be visualized as a thrown flare (grenade). See X2Item_EvacFlare.
function ReplacePlaceEvacAbility(X2CharacterTemplate Template, int Difficulty)
{
    if (Template.Abilities.Find('PlaceEvacZone') != -1)
    {
        Template.Abilities.RemoveItem('PlaceEvacZone');
    }
}