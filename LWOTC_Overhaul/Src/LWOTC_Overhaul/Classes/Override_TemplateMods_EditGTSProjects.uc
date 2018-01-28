class Override_TemplateMods_EditGTSProjects extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct GTSTableEntry
{
	var name	GTSProjectTemplateName;
	var	int		SupplyCost;
	var int		RankRequired;
	var	bool	HideifInsufficientRank;
	var name	UniqueClass;
	structdefaultproperties
	{
		GTSProjectTemplateName=None
		SupplyCost=0
		RankRequired=0
		HideifInsufficientRank=false
		UniqueClass=none
	}
};

var config array<GTSTableEntry> GTSTable;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateEditGTSProjectsTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateEditGTSProjectsTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'EditGTSProjectsTree');
	Template.StrategyElementTemplateModFn = EditGTSProjects;
	return Template;
}

function EditGTSProjects(X2StrategyElementTemplate Template, int Difficulty)
{
	local int						i;
	local ArtifactCost				Resources;
	local X2SoldierUnlockTemplate	GTSTemplate;

	GTSTemplate = X2SoldierUnlockTemplate (Template);
	if (GTSTemplate != none)
	{
		for (i=0; i < GTSTable.Length; ++i)
		{
			if (GTSTemplate.DataName == GTSTable[i].GTSProjectTemplateName)
			{
				GTSTemplate.Cost.ResourceCosts.Length=0;
				if (GTSTable[i].SupplyCost > 0)
				{
					Resources.ItemTemplateName = 'Supplies';
					Resources.Quantity = GTSTable[i].SupplyCost;
					GTSTemplate.Cost.ResourceCosts.AddItem(Resources);
				}
				GTSTemplate.Requirements.RequiredHighestSoldierRank = GTSTable[i].RankRequired;
				//bVisibleIfSoldierRankGatesNotMet does not work
				GTSTemplate.Requirements.bVisibleIfSoldierRankGatesNotMet = !GTSTable[i].HideIfInsufficientRank;
				GTSTemplate.AllowedClasses.Length = 0;
				GTSTemplate.Requirements.RequiredSoldierClass = '';
				if (GTSTable[i].UniqueClass != '')
				{
					GTSTemplate.Requirements.RequiredSoldierRankClassCombo = true;
					GTSTemplate.AllowedClasses.AddItem(GTSTable[i].UniqueClass);
					GTSTemplate.Requirements.RequiredSoldierClass = GTSTable[i].UniqueClass;
				}
				else
				{
					GTSTemplate.bAllClasses=true;
				}
			}
		}
	}
}