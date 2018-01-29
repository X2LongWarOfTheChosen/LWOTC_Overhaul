class Override_TemplateMods_RewireTechTree extends X2StrategyElement config(LWOTC_Overrides);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct TechTableEntry
{
	var name TechTemplateName;
	var bool ProvingGround;
	var int ResearchPointCost;
	var bool ModPointsToCompleteOnly;
	var name PrereqTech1;
	var name PrereqTech2;
	var name PrereqTech3;
	var int SupplyCost;
	var int AlloyCost;
	var int CrystalCost;
	var int CoreCost;
	var name ReqItemTemplateName1;
	var int ReqItemCost1;
	var name ReqItemTemplateName2;
	var int ReqItemCost2;
	var name ItemGranted;
	var int RequiredScienceScore;
	var int RequiredEngineeringScore;

	structdefaultproperties
	{
		TechTemplateName=None
		ProvingGround=false
		ResearchPointCost=0
		ModPointsToCompleteOnly=true
		PrereqTech1=None
		PrereqTech2=None
		PrereqTech3=None
		SupplyCost=0
		AlloyCost=0
		CrystalCost=0
		CoreCost=0
		ReqItemTemplateName1=None
		ReqItemCost1=0
		ReqItemTemplateName2=None
		ReqItemCost2=0
		ItemGranted=none
		RequiredScienceScore=0
		RequiredEngineeringScore=0
	}
};

var config array<TechTableEntry> TechTable;

var config int ResistanceCommunicationsIntelCost;
var config int ResistanceRadioIntelCost;
var config int AlienEncryptionIntelCost;
var config int CodexBrainPt1IntelCost;
var config int CodexBrainPt2IntelCost;
var config int BlacksiteDataIntelCost;
var config int ForgeStasisSuitIntelCost;
var config int PsiGateIntelCost;
var config int AutopsyAdventPsiWitchIntelCost;

var config int ALIEN_FACILITY_LEAD_RP_INCREMENT;
var config int ALIEN_FACILITY_LEAD_INTEL;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.Additem(CreateRewireTechTreeTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateRewireTechTreeTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'RewireTechTree');
	Template.StrategyElementTemplateModFn = RewireTechTree;
	return Template;
}

function RewireTechTree(X2StrategyElementTemplate Template, int Difficulty)
{
	local int						i;
	local ArtifactCost				Resources;
	local X2TechTemplate			TechTemplate;
	
	TechTemplate=X2TechTemplate(Template);
	If (TechTemplate != none)
	{
		//required by objective rework
		if (TechTemplate.DataName == 'ResistanceCommunications')
		{
			TechTemplate.Requirements.RequiredObjectives.length = 0;
			Resources.ItemTemplateName = 'Intel';
			Resources.Quantity = default.ResistanceCommunicationsIntelCost;
			TechTemplate.Cost.ResourceCosts.AddItem(Resources);
		}

		if (TechTemplate.DataName == 'ResistanceRadio')
		{
			TechTemplate.Requirements.RequiredObjectives.length = 0;
			Resources.ItemTemplateName = 'Intel';
			Resources.Quantity = default.ResistanceRadioIntelCost;
			TechTemplate.Cost.ResourceCosts.AddItem(Resources);
		}

		switch (TechTemplate.DataName)
		{
			case 'AlienEncryption':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.AlienEncryptionIntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			case 'CodexBrainPt1':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.CodexBrainPt1IntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			case 'CodexBrainPt2':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.CodexBrainPt2IntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			case 'BlacksiteData':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.BlacksiteDataIntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			case 'ForgeStasisSuit':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.ForgeStasisSuitIntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			case 'PsiGate':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.PsiGateIntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			case 'AutopsyAdventPsiWitch':
				Resources.ItemTemplateName = 'Intel';
				Resources.Quantity = default.AutopsyAdventPsiWitchIntelCost;
				if (Resources.Quantity > 0)
					TechTemplate.Cost.ResourceCosts.AddItem(Resources);
				break;
			default:
				break;
		}
		
		if (TechTemplate.DataName == 'Tech_AlienFacilityLead')
		{
			TechTemplate.ResearchCompletedFn = class'Mission_X2StrategyElement_RegionalAvatarResearch'.static.FacilityLeadCompleted;
			TechTemplate.Requirements.SpecialRequirementsFn = none; // remove the base-game requirement, since it is now handled elsewhere
			TechTemplate.RepeatPointsIncrease = default.ALIEN_FACILITY_LEAD_RP_INCREMENT;
			TechTemplate.Cost.ResourceCosts.Length = 0;
			Resources.ItemTemplateName = 'Intel';
			Resources.Quantity = default.ALIEN_FACILITY_LEAD_INTEL;
			TechTemplate.Cost.ResourceCosts.AddItem(Resources);
		}

		if (TechTemplate.DataName == 'SpiderSuit')
			TechTemplate.bRepeatable = false;
		if (TechTemplate.DataName == 'ExoSuit')
			TechTemplate.bRepeatable = false;
		if (TechTemplate.DataName == 'WraithSuit')
			TechTemplate.bRepeatable = false;
		if (TechTemplate.DataName == 'WarSuit')
			TechTemplate.bRepeatable = false;
		if (TechTemplate.DataName == 'ShredstormCannonProject')
			TechTemplate.bRepeatable = false;
		if (TechTemplate.DataName == 'PlasmaBlasterProject')
			TechTemplate.bRepeatable = false;
		if (TechTemplate.DataName == 'Skulljack')
			TechTemplate.bRepeatable = false;

		if (TechTemplate.DataName == 'HeavyWeapons') // remove the alternative access to the heavy weapons proving ground project for sparks
			TechTemplate.AlternateRequirements.Length = 0;

		// remove the alternative access to the advanced heavy weapons proving ground project HeavyAlienArmorMk2_Schematic
		// from Alien Hunters.
		if (TechTemplate.DataName == 'AdvancedHeavyWeapons')
			TechTemplate.AlternateRequirements.Length = 0;

		for (i=0; i < TechTable.Length; ++i)
		{
			if (TechTemplate.DataName == TechTable[i].TechTemplateName)
			{
				TechTemplate.bProvingGround = TechTable[i].ProvingGround;
				TechTemplate.PointsToComplete = TechTable[i].ResearchPointCost;
				TechTemplate.Requirements.RequiredScienceScore=TechTable[i].RequiredScienceScore;
				TechTemplate.Requirements.RequiredEngineeringScore=TechTable[i].RequiredEngineeringScore;
				if (TechTable[i].RequiredScienceScore == 99999)
				{
					TechTemplate.Requirements.bVisibleIfPersonnelGatesNotMet = false;
				}
				else
				{
					TechTemplate.Requirements.bVisibleIfPersonnelGatesNotMet = true;
				}
				if (!TechTable[i].ModPointsToCompleteOnly)
				{
					TechTemplate.Cost.ResourceCosts.Length = 0;
					TechTemplate.Cost.ArtifactCosts.Length = 0;
					TechTemplate.Requirements.RequiredItems.Length = 0;
					if (TechTable[i].SupplyCost > 0)
					{
						Resources.ItemTemplateName = 'Supplies';
						Resources.Quantity = TechTable[i].SupplyCost;
						TechTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (TechTable[i].AlloyCost > 0)
					{
						Resources.ItemTemplateName = 'AlienAlloy';
						Resources.Quantity = TechTable[i].AlloyCost;
						TechTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (TechTable[i].CrystalCost > 0)
					{
						Resources.ItemTemplateName = 'EleriumDust';
						Resources.Quantity = TechTable[i].CrystalCost;
						TechTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (TechTable[i].CoreCost > 0)
					{
						Resources.ItemTemplateName = 'EleriumCore';
						Resources.Quantity = TechTable[i].CoreCost;
						TechTemplate.Cost.ResourceCosts.AddItem(Resources);
					}
					if (TechTable[i].ReqItemTemplateName1 != '' && TechTable[i].ReqItemCost1 > 0)
					{
						Resources.ItemTemplateName = TechTable[i].ReqItemTemplateName1;
						Resources.Quantity = TechTable[i].ReqItemCost1;
						TechTemplate.Cost.ArtifactCosts.AddItem(Resources);
						if (!TechTemplate.bProvingGround)
						{
							TechTemplate.Requirements.RequiredItems.AddItem(TechTable[i].ReqItemTemplateName1);
						}
					}
					TechTemplate.bCheckForceInstant = false;
					if (TechTable[i].ReqItemTemplateName2 != '' && TechTable[i].ReqItemCost2 > 0)
					{
						if (TechTable[i].ReqItemTemplateName2 == 'Instant')
						{
							Resources.ItemTemplateName = TechTable[i].ReqItemTemplateName1;
							Resources.Quantity = TechTable[i].ReqItemCost1 * TechTable[i].ReqItemCost2;
							TechTemplate.InstantRequirements.RequiredItemQuantities.AddItem(Resources);
							TechTemplate.bCheckForceInstant = true;
						}
						else
						{
							Resources.ItemTemplateName = TechTable[i].ReqItemTemplateName2;
							Resources.Quantity = TechTable[i].ReqItemCost2;
							TechTemplate.Cost.ArtifactCosts.AddItem(Resources);
							if (!TechTemplate.bProvingGround)
							{
								TechTemplate.Requirements.RequiredItems.AddItem(TechTable[i].ReqItemTemplateName2);
							}
						}
					}
					TechTemplate.Requirements.RequiredTechs.Length = 0;
					if (TechTable[i].PrereqTech1 != '')
						TechTemplate.Requirements.RequiredTechs.AddItem(TechTable[i].PrereqTech1);
					if (TechTable[i].PrereqTech2 != '')
						TechTemplate.Requirements.RequiredTechs.AddItem(TechTable[i].PrereqTech2);
					if (TechTable[i].PrereqTech3 != '')
						TechTemplate.Requirements.RequiredTechs.AddItem(TechTable[i].PrereqTech3);
					if (TechTable[i].ItemGranted != '')
					{
						if (TechTable[i].ItemGranted != 'nochange')
						{
							TechTemplate.ResearchCompletedFn = none;
							TechTemplate.ItemRewards.Length = 0;
							if (TechTable[i].ItemGranted != 'clear')
							{
								TechTemplate.ResearchCompletedFn = class'X2StrategyElement_DefaultTechs'.static.GiveRandomItemReward;
								TechTemplate.ItemRewards.AddItem(TechTable[i].ItemGranted);
							}
						}
					}
				}
			}
		}
	}
}