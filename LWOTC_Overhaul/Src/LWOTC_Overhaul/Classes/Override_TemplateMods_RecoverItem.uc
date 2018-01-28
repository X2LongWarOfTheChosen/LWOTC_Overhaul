class Override_TemplateMods_RecoverItem extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(CreateRecoverItemTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateRecoverItemTemplate()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'RecoverItem');
    Template.MissionNarrativeTemplateModFn = RecoverItemNarrativeMod;
    return Template;
}

function RecoverItemNarrativeMod(X2MissionNarrativeTemplate Template)
{
    switch(Template.DataName)
    {
    case 'DefaultRecover':
    case 'DefaultRecover_ADV':
    case 'DefaultRecover_Train':
    case 'DefaultRecover_Vehicle':
        if (ExpectNarrativeCount(Template, 24))
        {
            Template.NarrativeMoments[24] = "X2NarrativeMoments.TACTICAL.Blacksite.BlackSite_SecureRetreat";
        }
        break;
    case 'DefaultHack':
    case 'DefaultHack_ADV':
    case 'DefaultHack_Train':
        if (ExpectNarrativeCount(Template, 22))
        {
            Template.NarrativeMoments[22] = "X2NarrativeMoments.TACTICAL.Blacksite.BlackSite_SecureRetreat";
        }
        break;
    case 'DefaultDestroyRelay':
        if (ExpectNarrativeCount(Template, 20))
        {
            Template.NarrativeMoments[20] = "X2NarrativeMoments.TACTICAL.Blacksite.BlackSite_SecureRetreat";
            Template.NarrativeMoments[21] = "X2NarrativeMoments.TACTICAL.General.CEN_Gen_SecureRetreat_03";
        }
    default:
        break;
    }
}

function bool ExpectNarrativeCount(X2MissionNarrativeTemplate Template, int Cnt)
{
    // We better have 24 items as the narrative # we want is in the objective map Kismet.
    if(Template.NarrativeMoments.Length != Cnt)
    {
        `redscreen("LWTemplateMods: Found too many narrative moments for " $ Template.DataName);
		`log("LWTemplateMods: Found too many narrative moments for " $ Template.DataName);
        return false;
    }

    return true;
}