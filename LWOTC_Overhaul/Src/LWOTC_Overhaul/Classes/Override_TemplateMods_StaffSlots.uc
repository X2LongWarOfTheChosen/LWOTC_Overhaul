class Override_TemplateMods_StaffSlots extends X2StrategyElement config(LWOTC_Overrides);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config array<float> AWCHealingBonus;

var config int RESCOMMS_1ST_ENGINEER_BONUS;
var config int RESCOMMS_2ND_ENGINEER_BONUS;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateReconfigStaffSlotsTemplate());
	Templates.AddItem(CreateModifyStaffSlotsTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateReconfigStaffSlotsTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ReconfigStaffSlots');
	Template.StrategyElementTemplateModFn = ReconfigStaffSlots;
	return Template;
}

function ReconfigStaffSlots(X2StrategyElementTemplate Template, int Difficulty)
{
	local X2StaffSlotTemplate	StaffSlotTemplate;

	StaffSlotTemplate = X2StaffSlotTemplate (Template);
	if (StaffSlotTemplate != none)
	{
		if (StaffSlotTemplate.DataName == 'AWCScientistStaffSlot')
		{
			StaffSlotTemplate.bEngineerSlot = false;
			StaffSlotTemplate.bScientistSlot = true;
			StaffSlotTemplate.MatineeSlotName = "Scientist";
		}
		else if (StaffSlotTemplate.DataName == 'PsiChamberScientistStaffSlot')
		{
			StaffSlotTemplate.bEngineerSlot = false;
			StaffSlotTemplate.bScientistSlot = true;
			StaffSlotTemplate.MatineeSlotName = "Scientist";
		}
		else if(StaffSlotTemplate.DataName == 'OTSStaffSlot')
		{
			StaffSlotTemplate.IsUnitValidForSlotFn = IsUnitValidForOTSSoldierSlot;
		}
		else if(StaffSlotTemplate.DataName == 'PsiChamberSoldierStaffSlot')
		{
			StaffSlotTemplate.IsUnitValidForSlotFn = IsUnitValidForPsiChamberSoldierSlot;
		}
		else if (StaffSlotTemplate.DataName == 'AWCSoldierStaffSlot')
		{
			StaffSlotTemplate.IsUnitValidForSlotFn = IsUnitValidForAWCSoldierSlot;
		}
		else if (StaffSlotTemplate.DataName == 'ResCommsStaffSlot')
		{
			StaffSlotTemplate.GetContributionFromSkillFn = SubstitueResCommStaffFn;
		}
		else if (StaffSlotTemplate.DataName == 'ResCommsBetterStaffSlot')
		{
			StaffSlotTemplate.GetContributionFromSkillFn = SubstitueBetterResCommStaffFn;
		}
		else if (StaffSlotTemplate.DataName == 'SparkStaffSlot')
		{
			StaffSlotTemplate.IsUnitValidForSlotFn = IsUnitValidForSparkSlotWithInfiltration;
		}
	}
}

static function int SubstitueResCommStaffFn(XComGameState_Unit Unit)
{
	return default.RESCOMMS_1ST_ENGINEER_BONUS;
}

static function int SubstitueBetterResCommStaffFn(XComGameState_Unit Unit)
{
	return default.RESCOMMS_2ND_ENGINEER_BONUS;
}
	
// this is an override for the rookie training slot, to disallow training of soldiers currently on a mission
static function bool IsUnitValidForOTSSoldierSlot(XComGameState_StaffSlot SlotState, StaffUnitInfo UnitInfo)
{
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID));
	
	if(class'LWOTC_DLCHelpers'.static.IsUnitOnMission(Unit))
		return false;

	return class'X2StrategyElement_DefaultStaffSlots'.static.IsUnitValidForOTSSoldierSlot(SlotState, UnitInfo);
}

// this is an override for the psi training slot, to disallow training of soldiers currently on a mission
static function bool IsUnitValidForPsiChamberSoldierSlot(XComGameState_StaffSlot SlotState, StaffUnitInfo UnitInfo)
{
	local XComGameState_Unit Unit;
	//local X2SoldierClassTemplate SoldierClassTemplate;
	//local SCATProgression ProgressAbility;
	//local name AbilityName;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID));
	
	if(class'LWOTC_DLCHelpers'.static.IsUnitOnMission(Unit)) // needed to work with infiltration system
		return false;

	if (Unit.CanBeStaffed()
		&& Unit.IsSoldier()
		&& !Unit.IsInjured()
		&& !Unit.IsTraining()
		&& !Unit.IsPsiTraining()
		&& !Unit.IsPsiAbilityTraining()
		&& SlotState.GetMyTemplate().ExcludeClasses.Find(Unit.GetSoldierClassTemplateName()) == INDEX_NONE)
	{
		if (Unit.GetRank() == 0 && !Unit.CanRankUpSoldier()) // All rookies who have not yet ranked up can be trained as Psi Ops
		{
			return true;
		}
		else if (Unit.IsPsiOperative()) // Psi Ops can only train if there are abilities leftes
		{ 
			/* TODO
			SoldierClassTemplate = Unit.GetSoldierClassTemplate();
			if (class'Utilities_PP_LW'.static.CanRankUpPsiSoldier(Unit)) // LW2 override, this limits to 8 abilities
			{
				foreach Unit.PsiAbilities(ProgressAbility)
				{
					AbilityName = SoldierClassTemplate.GetAbilityName(ProgressAbility.iRank, ProgressAbility.iBranch);
					if (AbilityName != '' && !Unit.HasSoldierAbility(AbilityName))
					{
						return true; // If we find an ability that the soldier hasn't learned yet, they are valid
					}
				}
			}
			*/
		}
	}
	return false;
}

// this is an override for the AWC class ability re-training slot, to disallow training of soldiers currently on a mission
static function bool IsUnitValidForAWCSoldierSlot(XComGameState_StaffSlot SlotState, StaffUnitInfo UnitInfo)
{
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID));
	
	if(class'LWOTC_DLCHelpers'.static.IsUnitOnMission(Unit))
		return false;

	return class'X2StrategyElement_DefaultStaffSlots'.static.IsUnitValidForAWCSoldierSlot(SlotState, UnitInfo);
}

// this is an override for the DLC3 spark healing slot, to disallow healing of sparks currently on a mission
static function bool IsUnitValidForSparkSlotWithInfiltration(XComGameState_StaffSlot SlotState, StaffUnitInfo UnitInfo)
{
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID));
	
    if(Unit.CanBeStaffed() 
		&& Unit.GetReference().ObjectID != SlotState.GetAssignedStaffRef().ObjectID
		&& Unit.IsSoldier()
		&& Unit.IsInjured()
		&& Unit.GetMyTemplateName() == 'SparkSoldier'
		&& !class'LWOTC_DLCHelpers'.static.IsUnitOnMission(Unit)) // added condition to prevent healing spark units on mission here
    {
        return true;
    }

	return false;
}

// Update StaffSlotTemplates as needed
static function Override_TemplateMods_Template CreateModifyStaffSlotsTemplate()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'UpdateStaffSlots');

    // We need to modify grenade items and ability templates
    Template.StrategyElementTemplateModFn = UpdateStaffSlotTemplate;
    return Template;
}

function UpdateStaffSlotTemplate(X2StrategyElementTemplate Template, int Difficulty)
{
	local X2StaffSlotTemplate StaffSlotTemplate;

	StaffSlotTemplate = X2StaffSlotTemplate(Template);
	if(StaffSlotTemplate == none)
		return;
	
	switch (StaffSlotTemplate.DataName)
	{
		case 'AWCScientistStaffSlot':
			StaffSlotTemplate.GetContributionFromSkillFn = GetAWCContribution_LW;
			StaffSlotTemplate.FillFn = FillAWCSciSlot_LW;
			StaffSlotTemplate.EmptyFn = EmptyAWCSciSlot_LW;
			StaffSlotTemplate.GetAvengerBonusAmountFn = GetAWCAvengerBonus_LW;
			StaffSlotTemplate.GetBonusDisplayStringFn = GetAWCBonusDisplayString_LW;
			StaffSlotTemplate.MatineeSlotName = "Scientist";
			break;
		default:
			break;
	}
}

static function int GetAWCContribution_LW(XComGameState_Unit UnitState)
{
	return class'X2StrategyElement_DefaultStaffSlots'.static.GetContributionDefault(UnitState) * (GetXComBaseHealRate() / 5) * (default.AWCHealingBonus[`CAMPAIGNDIFFICULTYSETTING] / 100.0);
}

static function int GetAWCAvengerBonus_LW(XComGameState_Unit UnitState, optional bool bPreview)
{
	local float PercentIncrease;

	// Need to return the percent increase in overall healing speed provided by this unit
	PercentIncrease = (GetAWCContribution_LW(UnitState) * 100.0) / (GetXComBaseHealRate());

	return Round(PercentIncrease);
}

static function FillAWCSciSlot_LW(XComGameState NewGameState, StateObjectReference SlotRef, StaffUnitInfo UnitInfo, optional bool bTemporary = false)
{
	local XComGameState_HeadquartersXCom NewXComHQ;
	local XComGameState_Unit NewUnitState;
	local XComGameState_StaffSlot NewSlotState;

	class'X2StrategyElement_DefaultStaffSlots'.static.FillSlot(NewGameState, SlotRef, UnitInfo, NewSlotState, NewUnitState);
	NewXComHQ = class'X2StrategyElement_DefaultStaffSlots'.static.GetNewXComHQState(NewGameState);
	
	NewXComHQ.HealingRate += GetAWCContribution_LW(NewUnitState);
}

static function EmptyAWCSciSlot_LW(XComGameState NewGameState, StateObjectReference SlotRef)
{
	local XComGameState_HeadquartersXCom NewXComHQ;
	local XComGameState_StaffSlot NewSlotState;
	local XComGameState_Unit NewUnitState;

	class'X2StrategyElement_DefaultStaffSlots'.static.EmptySlot(NewGameState, SlotRef, NewSlotState, NewUnitState);
	NewXComHQ = class'X2StrategyElement_DefaultStaffSlots'.static.GetNewXComHQState(NewGameState);

	NewXComHQ.HealingRate -= GetAWCContribution_LW(NewUnitState);

	if (NewXComHQ.HealingRate < `ScaleGameLengthArrayInt(NewXComHQ.default.XComHeadquarters_BaseHealRates))
	{
		NewXComHQ.HealingRate = `ScaleGameLengthArrayInt(NewXComHQ.default.XComHeadquarters_BaseHealRates);
	}
}

static function string GetAWCBonusDisplayString_LW(XComGameState_StaffSlot SlotState, optional bool bPreview)
{
	local string Contribution;

	if (SlotState.IsSlotFilled())
	{
		Contribution = string(GetAWCAvengerBonus_LW(SlotState.GetAssignedStaff(), bPreview));
	}

	return class'X2StrategyElement_DefaultStaffSlots'.static.GetBonusDisplayString(SlotState, "%AVENGERBONUS", Contribution);
}

static function int GetXComBaseHealRate()
{
	local XComGameState_HeadquartersXCom XComHQ;
	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	return `ScaleGameLengthArrayInt(XComHQ.default.XComHeadquarters_BaseHealRates);
}