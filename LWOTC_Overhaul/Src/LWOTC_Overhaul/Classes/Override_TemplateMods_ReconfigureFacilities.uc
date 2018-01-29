class Override_TemplateMods_ReconfigureFacilities extends X2StrategyElement config(LWOTC_Overrides);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct FacilityTableEntry
{
	var name FacilityTemplateName;
	var int BuildDays;
	var int Power;
	var int UpkeepCost;
	var name RequiredTech;
	var int SupplyCost;
	var int AlloyCost;
	var int CrystalCost;
	var int CoreCost;
	structdefaultproperties
	{
		FacilityTemplateName=none
		BuildDays=1
		Power=0
		UpkeepCost=0
		RequiredTech=none
		SupplyCost=0
		AlloyCost=0
		CrystalCost=0
		CoreCost=0
	}
};

struct FacilityUpgradeTableEntry
{
	var name FacilityUpgradeTemplateName;
	var int PointsToComplete;
	var int iPower;
	var int UpkeepCost;
	var int SupplyCost;
	var int AlloyCost;
	var int CrystalCost;
	var int CoreCost;
	var name RequiredTech;
	var name ReqItemTemplateName1;
	var int ReqItemCost1;
	var name ReqItemTemplateName2;
	var int ReqItemCost2;
	var int MaxBuild;
	var int RequiredEngineeringScore;
	var int RequiredScienceScore;
	structdefaultproperties
	{
		FacilityUpgradeTemplateName=none
		PointsToComplete=0
		iPower=0
		UpkeepCost=0
		SupplyCost=0
		AlloyCost=0
		CrystalCost=0
		CoreCost=0
		RequiredTech=none
		ReqItemTemplateName1=None
		ReqItemCost1=0
		ReqItemTemplateName2=None
		ReqItemCost2=0
		MaxBuild=1
		RequiredEngineeringScore=0
		RequiredScienceScore=0
	}
};

var config array<FacilityTableEntry> FacilityTable;
var config array<FacilityUpgradeTableEntry> FacilityUpgradeTable;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateReconfigFacilitiesTemplate());
	Templates.AddItem(CreateReconfigFacilityUpgradesTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateReconfigFacilitiesTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ReconfigFacilities');
	Template.StrategyElementTemplateModFn = ReconfigFacilities;
	return Template;
}

function ReconfigFacilities(X2StrategyElementTemplate Template, int Difficulty)
{
	local int						i;
	local ArtifactCost				Resources;
	local X2FacilityTemplate		FacilityTemplate;

	FacilityTemplate = X2FacilityTemplate (Template);
	if (FacilityTemplate != none)
	{
		if (FacilityTemplate.DataName == 'OfficerTrainingSchool')
		{
			FacilityTemplate.SoldierUnlockTemplates.RemoveItem('HuntersInstinctUnlock');
			FacilityTemplate.SoldierUnlockTemplates.RemoveItem('HitWhereItHurtsUnlock');
			FacilityTemplate.SoldierUnlockTemplates.RemoveItem('CoolUnderPressureUnlock');
			FacilityTemplate.SoldierUnlockTemplates.RemoveItem('BiggestBoomsUnlock');
			FacilityTemplate.SoldierUnlockTemplates.RemoveItem('SquadSizeIUnlock');
			FacilityTemplate.SoldierUnlockTemplates.RemoveItem('SquadSizeIIUnlock');
			FacilityTemplate.SoldierUnlockTemplates.AddItem('Infiltration1Unlock');
			FacilityTemplate.SoldierUnlockTemplates.AddItem('Infiltration2Unlock');
		}
		if (FacilityTemplate.DataName == 'Laboratory')
		{
			/* TODO
			FacilityTemplate.StaffSlots.AddItem('LaboratoryStaffSlot');
			FacilityTemplate.StaffSlots.AddItem('LaboratoryStaffSlot');
			FacilityTemplate.Upgrades.AddItem('Laboratory_AdditionalResearchStation2');
			FacilityTemplate.Upgrades.AddItem('Laboratory_AdditionalResearchStation3');
			FacilityTemplate.StaffSlotsLocked = 3;
			*/
		}
		if (FacilityTemplate.DataName == 'ProvingGround')
		{
			// TODO : FacilityTemplate.StaffSlots.AddItem('ProvingGroundStaffSlot');
		}
		if (FacilityTemplate.DataName == 'PsiChamber')
		{
			/* TODO
			FacilityTemplate.StaffSlots.Length = 0;
			FacilityTemplate.StaffSlots.AddItem('PsiChamberScientistStaffSlot');
			FacilityTemplate.StaffSlots.AddItem('PsiChamberScientistStaffSlot');
			FacilityTemplate.StaffSlots.AddItem('PsiChamberSoldierStaffSlot');
			FacilityTemplate.StaffSlots.AddItem('PsiChamberSoldierStaffSlot');
			FacilityTemplate.StaffSlotsLocked = 1;
			*/
		}
		//if (FacilityTemplate.DataName == 'Storage') Didn't work
		//{
			//FacilityTemplate.StaffSlots.AddItem('SparkStaffSlot');
			//FacilityTemplate.StaffSlots.AddItem('SparkStaffSlot');
			//FacilityTemplate.StaffSlotsLocked = 3;
		//}

        // --- HACK HACK HACK --- 
        //
        // To allow debugging XcomGame with AH installed you need to uncomment this to strip the aux map from the hangar template.
        // The game will loop forever in the avenger waiting for the aux content to load unless this is done, because the content
        // is provided only in a cooked seek-free package and debugging always loads -noseekfreepackages. Thus the package is never
        // loaded and the process will never complete. I am not leaving this uncommented because doing so will leave a gap in the
        // avenger map where the hangar is supposed to be. Even with this expect a bazillion redscreens about missing content for
        // DLC1/2/3. If you need to do a lot of debugging in XComGame consider uninstalling the DLCs first to cut down redscreen spam.
        //
        // --- HACK HACK HACK ---
        /*
        if (FacilityTemplate.DataName == 'Hangar')
        {
            `Log("Found hangar with " $ FacilityTemplate.AuxMaps.Length $ " aux maps");
            for( i = 0; i < FacilityTemplate.AuxMaps.length; ++i)
            {
                `Log("Aux map: " $ FacilityTemplate.AuxMaps[i].MapName);
                if (InStr(FacilityTemplate.AuxMaps[i].MapName, "DLC2") >= 0)
                {
                    FacilityTemplate.AuxMaps.Remove(i, 1);
                    --i;
                }
            }
            FacilityTemplate.AuxMaps.Length = 0;
        }
        */

		for (i=0; i < FacilityTable.Length; ++i)
		{
			if (FacilityTemplate.DataName == FacilityTable[i].FacilityTemplateName)
			{
				FacilityTemplate.PointsToComplete = class'X2StrategyElement_DefaultFacilities'.static.GetFacilityBuildDays(FacilityTable[i].BuildDays);
				FacilityTemplate.iPower = FacilityTable[i].Power;
				FacilityTemplate.UpkeepCost = FacilityTable[i].UpkeepCost;
				FacilityTemplate.Requirements.RequiredTechs.length = 0;
				if (FacilityTable[i].RequiredTech != '')
					FacilityTemplate.Requirements.RequiredTechs.AddItem(FacilityTable[i].RequiredTech);
				
				FacilityTemplate.Cost.ResourceCosts.Length = 0;
				FacilityTemplate.Cost.ArtifactCosts.Length = 0;				

				if (FacilityTable[i].SupplyCost > 0)
				{
					Resources.ItemTemplateName = 'Supplies';
					Resources.Quantity = FacilityTable[i].SupplyCost;
					FacilityTemplate.Cost.ResourceCosts.AddItem(Resources);
				}
				if (FacilityTable[i].AlloyCost > 0)
				{
					Resources.ItemTemplateName = 'AlienAlloy';
					Resources.Quantity = FacilityTable[i].AlloyCost;
					FacilityTemplate.Cost.ResourceCosts.AddItem(Resources);
				}
				if (FacilityTable[i].CrystalCost > 0)
				{
					Resources.ItemTemplateName = 'EleriumDust';
					Resources.Quantity = FacilityTable[i].CrystalCost;
					FacilityTemplate.Cost.ResourceCosts.AddItem(Resources);
				}
				if (FacilityTable[i].CoreCost > 0)
				{
					Resources.ItemTemplateName = 'EleriumCore';
					Resources.Quantity = FacilityTable[i].CoreCost;
					FacilityTemplate.Cost.ResourceCosts.AddItem(Resources);
				}
			}
		}
	}
}

static function Override_TemplateMods_Template CreateReconfigFacilityUpgradesTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ModifyFacilityUpgrades');
	Template.StrategyElementTemplateModFn = ModifyFacilityUpgrades;
	return Template;
}

// THIS DOES NOT MODIFY REQUIREMENTS (TECHS, SPECIAL ARTIFACTS, RANK ACHIEVED) WHICH ARE HARDCODED, CAN ADD SCI/ENG SCORE REQUIREMENT IF SET
function ModifyFacilityUpgrades(X2StrategyElementTemplate Template, int Difficulty)
{
	local X2FacilityUpgradeTemplate	FacilityUpgradeTemplate;
	local int k;
	local ArtifactCost Resources;

	FacilityUpgradeTemplate = X2FacilityUpgradeTemplate(Template);
	if (FacilityUpgradeTemplate != none)
	{
		for (k = 0; k < FacilityUpgradeTable.length; k++)
		{
			If (FacilityUpgradeTable[k].FacilityUpgradeTemplateName == FacilityUpgradeTemplate.DataName)
			{
				FacilityUpgradeTemplate.PointsToComplete = FacilityUpgradeTable[k].PointsToComplete;
				FacilityUpgradeTemplate.iPower = FacilityUpgradeTable[k].iPower;
				FacilityUpgradeTemplate.UpkeepCost = FacilityUpgradeTable[k].UpkeepCost;
				
				FacilityUpgradeTemplate.Cost.ResourceCosts.Length = 0;
				FacilityUpgradeTemplate.Cost.ArtifactCosts.Length = 0;
				FacilityUpgradeTemplate.Requirements.RequiredTechs.Length = 0;

				if (FacilityUpgradeTable[k].RequiredTech != '')
				{
					FacilityUpgradeTemplate.Requirements.RequiredTechs.AddItem(FacilityUpgradeTable[k].RequiredTech);
				}
				if (FacilityUpgradeTable[k].SupplyCost > 0)
				{
					Resources.ItemTemplateName = 'Supplies';
					Resources.Quantity = FacilityUpgradeTable[k].SupplyCost;
					FacilityUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);					
				}
				if (FacilityUpgradeTable[k].AlloyCost > 0)
				{
					Resources.ItemTemplateName = 'AlienAlloy';
					Resources.Quantity = FacilityUpgradeTable[k].AlloyCost;
					FacilityUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);					
				}
				if (FacilityUpgradeTable[k].CrystalCost > 0)
				{
					Resources.ItemTemplateName = 'EleriumDust';
					Resources.Quantity = FacilityUpgradeTable[k].CrystalCost;
					FacilityUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);					
				}
				if (FacilityUpgradeTable[k].CoreCost > 0)
				{
					Resources.ItemTemplateName = 'EleriumCore';
					Resources.Quantity = FacilityUpgradeTable[k].CoreCost;
					FacilityUpgradeTemplate.Cost.ResourceCosts.AddItem(Resources);					
				}
				if (FacilityUpgradeTable[k].ReqItemCost1 > 0)
				{
					Resources.ItemTemplateName = FacilityUpgradeTable[k].ReqItemTemplateName1;
					Resources.Quantity = FacilityUpgradeTable[k].ReqItemCost1;
					FacilityUpgradeTemplate.Cost.ArtifactCosts.AddItem(Resources);
				}
				if (FacilityUpgradeTable[k].ReqItemCost2 > 0)
				{
					Resources.ItemTemplateName = FacilityUpgradeTable[k].ReqItemTemplateName2;
					Resources.Quantity = FacilityUpgradeTable[k].ReqItemCost2;
					FacilityUpgradeTemplate.Cost.ArtifactCosts.AddItem(Resources);
				}
				FacilityUpgradeTemplate.MaxBuild = FacilityUpgradeTable[k].MaxBuild;
				if (FacilityUpgradeTable[k].RequiredEngineeringScore > 0)
				{
					FacilityUpgradeTemplate.Requirements.RequiredEngineeringScore = FacilityUpgradeTable[k].RequiredEngineeringScore;
				}
				if (FacilityUpgradeTable[k].RequiredScienceScore > 0)
				{
					FacilityUpgradeTemplate.Requirements.RequiredScienceScore = FacilityUpgradeTable[k].RequiredScienceScore;
				}
			}
		}
	}
}