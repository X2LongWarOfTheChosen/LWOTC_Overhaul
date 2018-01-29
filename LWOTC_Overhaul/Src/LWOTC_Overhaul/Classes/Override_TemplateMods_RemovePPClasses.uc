class Override_TemplateMods_RemovePPClasses extends X2StrategyElement;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateRemovePPClassesTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateRemovePPClassesTemplate()
{
	local Override_TemplateMods_Template Template;

	//`LOG("PP: 0");
	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'RemovePPClasses');
	Template.SoldierClassTemplateModFn = RemovePPClasses;
	return Template;
}

//this makes sure perkpack classes do not show up
function RemovePPClasses(X2SoldierClassTemplate Template, int Difficulty)
{
	//`LOG ("PP: 1");
	if (Template != none)
	{
		//`LOG ("PP: 2");
		switch (Template.DataName)
		{
			case 'LW_Assault':
			case 'LW_Shinobi':
			case 'LW_Sharpshooter':
			case 'LW_Ranger':
			case 'LW_Gunner':
			case 'LW_Grenadier':
			case 'LW_Specialist':
				//`LOG ("PP: 3");
				Template.NumInForcedDeck = 0;
				Template.NumInDeck = 0;
				break;
			default:
				break;
		}
		Template.KillAssistsPerKill = 0;
	}
}