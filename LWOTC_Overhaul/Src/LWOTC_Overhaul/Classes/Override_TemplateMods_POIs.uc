class Override_TemplateMods_POIs extends X2StrategyElement;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateModifyPOIsTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateModifyPOIsTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ModifyPOIs');
	Template.StrategyElementTemplateModFn = ModifyPOIs;
	return Template;
}

// This also modifies the description of hte city center in invasion missions
function ModifyPOIs (X2StrategyElementTemplate Template, int Difficulty)
{
    local X2PointOfInterestTemplate POITemplate;
	local X2MissionSiteDescriptionTemplate MissionSiteDescription;

	POITemplate = X2PointofInterestTemplate(Template);
	if (POITemplate != none)
	{
		switch (POITemplate.DataName)
		{
			case 'POI_FacilityLead':
			case 'POI_GuerillaOp':
			case 'POI_HeavyWeapon':
			case 'POI_SupplyRaid':
			case 'POI_IncreaseIncome':
				POITemplate.CanAppearFn = DisablePOI;
				break;
			case 'POI_GrenadeAmmo':
				POITemplate.CanAppearFn = DelayGrenades;
				break;
			default:
				break;
		}
	}
	MissionSiteDescription = X2MissionSiteDescriptionTemplate(Template);
	if (MissionSiteDescription != none)
	{
		if (MissionSiteDescription.DataName == 'CityCenter')
		{
			MissionSiteDescription.GetMissionSiteDescriptionFn = class'X2StrategyElement_MissionSiteDescriptions_LWOTC'.static.GetCityCenterMissionSiteDescription_LWOTC;
		}
	}
}

function bool DelayGrenades(XComGameState_PointOfInterest POIState)
{
	local XComGameState_HeadquartersAlien AlienHQ;

	AlienHQ = XComGameState_HeadquartersAlien(`XCOMHistory.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	if (AlienHQ == none)
	{
		return false;
	}
	if (AlienHQ.GetForceLevel() <= 10)
	{
		return false;
	}
	return true;
}

function bool DisablePOI(XComGameState_PointOfInterest POIState)
{
    return false;
}