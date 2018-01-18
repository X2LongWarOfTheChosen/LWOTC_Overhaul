class Squad_Static_Infiltration_Helper extends Object config(LWOTC_Infiltration);

struct EquipmentCovertnessContainer
{
	var name ItemName;
	var float CovertnessValue;
	var float CovertnessWeight;
	var float IndividualMultiplier;
};
var config array<EquipmentCovertnessContainer> EquipmentCovertness;

struct CategoryCovertnessContainer
{
	var name CategoryName;  // should match configured category from 
	var float CovertnessValue;
	var float CovertnessWeight;
};
var config array<CategoryCovertnessContainer> ItemCategoryCovertness;
var config array<CategoryCovertnessContainer> WeaponCategoryCovertness;

struct AbilityCovertnessContainer
{
	var name AbilityName;
	var float IndividualMultiplier;
	var float SquadMultiplier;
};
var config array<AbilityCovertnessContainer> AbilityCovertness;

var config array<float>		InfiltrationTime_BaselineHours;
var config array<float>		InfiltrationTime_BlackSite;
var config array<float>		InfiltrationTime_Forge;
var config array<float>		InfiltrationTime_PsiGate;

var config float			InfiltrationTime_MinHours;
var config float			InfiltrationTime_MaxHours;

var config array<float>		SquadSizeInfiltrationFactor;
var config float			InfiltrationCovertness_Baseline;
var config float			InfiltrationCovertness_RateUp;
var config float			InfiltrationCovertness_RateDown;

var config array<float>		GTSInfiltration1Modifier;
var config array<float>		GTSInfiltration2Modifier;

var config array<name>		MissionsAffectedByLiberationStatus;
var config array<float>		InfiltrationLiberationFactor;				// multiplier for baseline infiltration factor based on region's liberation status

var config float			EMPTY_UTILITY_SLOT_WEIGHT;

var config float			LEADERSHIP_COVERTNESS_PER_MISSION;
var config float			LEADERSHIP_COVERTNESS_CAP;

// GetHoursToFullInfiltration(array<StateObjectReference> Soldiers, StateObjectReference MissionRef, optional out int SquadSizeHours, optional out int CovertnessHours, optional out int LiberationHours)
static function float GetHoursToFullInfiltration(array<StateObjectReference> Soldiers, StateObjectReference MissionRef, optional out int SquadSizeHours, optional out int CovertnessHours, optional out int LiberationHours)
{
	local float BaseHours;
	local float SquadSize;
	local float Covertness;
	local float SquadSizeFactor, CovertnessFactor, LiberationFactor;
	local float ReturnHours;
	local XComGameState_MissionSite MissionState;

	SquadSize = float(GetSquadCount(Soldiers));
	Covertness = GetSquadCovertness(Soldiers);

	if(SquadSize >= default.SquadSizeInfiltrationFactor.Length)
		SquadSizeFactor = default.SquadSizeInfiltrationFactor[default.SquadSizeInfiltrationFactor.Length - 1];
	else
		SquadSizeFactor = default.SquadSizeInfiltrationFactor[SquadSize];

	if (`XCOMHQ.SoldierUnlockTemplates.Find('Infiltration1Unlock') != -1)
		SquadSizeFactor -= default.GTSInfiltration1Modifier[SquadSize];

	if (`XCOMHQ.SoldierUnlockTemplates.Find('Infiltration2Unlock') != -1)
		SquadSizeFactor -= default.GTSInfiltration2Modifier[SquadSize];
	//if(SquadSize < default.InfiltrationSquadSize_Baseline)
		//SquadSizeFactor -= (default.InfiltrationSquadSize_Baseline - SquadSize) * InfiltrationSquadSize_RateDown;
	//else
		//SquadSizeFactor += (SquadSize- default.InfiltrationSquadSize_Baseline) * InfiltrationSquadSize_RateUp;

	BaseHours = GetBaselineHoursToInfiltration(MissionRef);

	SquadSizeFactor = FClamp(SquadSizeFactor, 0.05, 10.0);
	SquadSizeHours = Round(BaseHours * (SquadSizeFactor - 1.0));

	CovertnessFactor = 1.0;
	if(Covertness < default.InfiltrationCovertness_Baseline)
		CovertnessFactor -= (default.InfiltrationCovertness_Baseline - Covertness) * default.InfiltrationCovertness_RateDown / 100.0;
	else
		CovertnessFactor += (Covertness - default.InfiltrationCovertness_Baseline) * default.InfiltrationCovertness_RateUp / 100.0;

	CovertnessFactor = FClamp(CovertnessFactor, 0.05, 10.0);
	CovertnessHours = Round((BaseHours + FMax(0.0, SquadSizeHours)) * (CovertnessFactor - 1.0));

	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));
	if (default.MissionsAffectedByLiberationStatus.Find (MissionState.GeneratedMission.Mission.MissionName) != -1)
	{
		LiberationFactor = GetLiberationFactor(MissionState);
		LiberationHours = Round(BaseHours * (LiberationFactor - 1.0));
	}
	else
	{
		LiberationFactor = 1.0;
		LiberationHours = 0;
	}
	ReturnHours = BaseHours;
	ReturnHours += SquadSizeHours;
	ReturnHours += CovertnessHours;
	ReturnHours += LiberationHours;
	ReturnHours = FClamp(ReturnHours, default.InfiltrationTime_MinHours, default.InfiltrationTime_MaxHours);

	return ReturnHours;
}

// GetSquadCovertness(array<StateObjectReference> Soldiers)
static function float GetSquadCovertness(array<StateObjectReference> Soldiers)
{
	local StateObjectReference UnitRef;
	local float CumulativeCovertness, AveCovertness;
	local float SquadCovertnessMultiplier, SquadCovertnessMultiplierDelta;

	SquadCovertnessMultiplier = 1.0;
	CumulativeCovertness = 0.0;
	foreach Soldiers(UnitRef)
	{
		SquadCovertnessMultiplierDelta = 1.0;
		CumulativeCovertness += GetSoldierCovertness(Soldiers, UnitRef, SquadCovertnessMultiplierDelta);
		SquadCovertnessMultiplier *= SquadCovertnessMultiplierDelta;
	}

	// this is for squad-wide ability/item effects
	CumulativeCovertness *= SquadCovertnessMultiplier;

	//each soldier is equally weighted
	AveCovertness = CumulativeCovertness / float(GetSquadCount(Soldiers));

	return AveCovertness;
}

// GetSquadCount(array<StateObjectReference> Soldiers)
static function int GetSquadCount(array<StateObjectReference> Soldiers)
{
	local int idx, Count;

	for(idx = 0; idx < Soldiers.Length; idx++)
	{
		if(Soldiers[idx].ObjectID > 0)
			Count++;
	}
	return Count;
}

// GetSoldierCovertness(array<StateObjectReference> Soldiers, StateObjectReference UnitRef, out float SquadCovertnessMultiplierDelta)
static function float GetSoldierCovertness(array<StateObjectReference> Soldiers, StateObjectReference UnitRef, out float SquadCovertnessMultiplierDelta)
{
	local XComGameState_Unit UnitState;
	local array<XComGameState_Item> EquippedUtilityItems;
	local float CumulativeUnitCovertness, CumulativeWeight;
	local float CumulativeUnitMultiplier, UnitCovertness;

	//this can happen if the player leaves gaps in SquadSelect, so just don't count this as anything
	if(UnitRef.ObjectID <= 0)
		return 0.0;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	//This is to support including non-soldiers on missions eventually
	if(!UnitState.IsASoldier())
		return default.InfiltrationCovertness_Baseline;

	CumulativeUnitMultiplier = 1.0;
	CumulativeUnitCovertness = 0.0;
	CumulativeWeight = 0.0;

	EquippedUtilityItems = UnitState.GetAllItemsInSlot(eInvSlot_Utility,,,true);
	CumulativeWeight += (UnitState.GetNumUtilitySlots() - EquippedUtilityItems.Length) * default.EMPTY_UTILITY_SLOT_WEIGHT;

	UpdateConvertnessForInventory(UnitState, CumulativeUnitCovertness, CumulativeWeight, CumulativeUnitMultiplier);
	UpdateCovertnessForAbilities(UnitState, CumulativeUnitCovertness, CumulativeUnitMultiplier);
	//UpdateCovertnessForOfficers(Soldiers, UnitState, CumulativeUnitMultiplier); OFFICER PACK

	CumulativeUnitCovertness *= CumulativeUnitMultiplier;

	if(CumulativeWeight > 0.0)  // avoid divide-by-zero errors
		UnitCovertness = CumulativeUnitCovertness/CumulativeWeight;
	else
		UnitCovertness = default.InfiltrationCovertness_Baseline;

	return UnitCovertness;
}

// UpdateConvertnessForInventory(XComGameState_Unit UnitState, out float CumulativeUnitCovertness, out float CumulativeWeight, out float CumulativeUnitMultiplier)
static function UpdateConvertnessForInventory(XComGameState_Unit UnitState, out float CumulativeUnitCovertness, out float CumulativeWeight, out float CumulativeUnitMultiplier)
{
	local array<XComGameState_Item> CurrentInventory;
	local XComGameState_Item InventoryItem;
	local array<X2WeaponUpgradeTemplate> WeaponUpgradeTemplates;
	local X2WeaponUpgradeTemplate WeaponUpgradeTemplate;

	CurrentInventory = UnitState.GetAllInventoryItems();

	foreach CurrentInventory(InventoryItem)
	{
		UpdateCovertnessForItem(InventoryItem.GetMyTemplate(), CumulativeUnitCovertness, CumulativeWeight, CumulativeUnitMultiplier);

		//  Gather covertness from any weapon upgrades
		WeaponUpgradeTemplates = InventoryItem.GetMyWeaponUpgradeTemplates();
		foreach WeaponUpgradeTemplates(WeaponUpgradeTemplate)
		{
			UpdateCovertnessForItem(WeaponUpgradeTemplate, CumulativeUnitCovertness, CumulativeWeight, CumulativeUnitMultiplier);
		}
	}
}

// UpdateCovertnessForItem(X2ItemTemplate ItemTemplate, out float CumulativeUnitCovertness, out float CumulativeWeight, out float CumulativeUnitMultiplier)
static function UpdateCovertnessForItem(X2ItemTemplate ItemTemplate, out float CumulativeUnitCovertness, out float CumulativeWeight, out float CumulativeUnitMultiplier)
{
	local int ListIdx;
	local X2WeaponTemplate WeaponTemplate;
	local name WeaponCategory;
	local float Weight;

	//look for a specific equipment configuration
	ListIdx = default.EquipmentCovertness.Find('ItemName', ItemTemplate.DataName);
	if(ListIdx != -1) // found a specific equipment definition
	{
		Weight = default.EquipmentCovertness[ListIdx].CovertnessWeight;
		CumulativeUnitCovertness += Weight * default.EquipmentCovertness[ListIdx].CovertnessValue;
		CumulativeWeight += Weight;
		if(default.EquipmentCovertness[ListIdx].IndividualMultiplier > 0.0)
		{
			CumulativeUnitMultiplier *= default.EquipmentCovertness[ListIdx].IndividualMultiplier;
		}
		return;
	}
	//look for a specific weapon configuration
	WeaponTemplate = X2WeaponTemplate(ItemTemplate);
	if(WeaponTemplate != none)
	{
		WeaponCategory = WeaponTemplate.WeaponCat;
		if(WeaponCategory != '') // sanity check
		{
			ListIdx = default.WeaponCategoryCovertness.Find('CategoryName', WeaponCategory);
		}
		if(ListIdx != -1)
		{
			Weight = default.WeaponCategoryCovertness[ListIdx].CovertnessWeight;
			CumulativeUnitCovertness += Weight * default.WeaponCategoryCovertness[ListIdx].CovertnessValue;
			CumulativeWeight += default.WeaponCategoryCovertness[ListIdx].CovertnessWeight;
			return;
		}
	}
	//look for a specific item configuration
	ListIdx = default.ItemCategoryCovertness.Find('CategoryName', ItemTemplate.ItemCat);
	if(ListIdx != -1)
	{
		Weight = default.ItemCategoryCovertness[ListIdx].CovertnessWeight;
		CumulativeUnitCovertness += Weight * default.ItemCategoryCovertness[ListIdx].CovertnessValue;
		CumulativeWeight += Weight;
		return;
	}

	`REDSCREEN("COVERTNESS CALCULATION : No valid item or category found for item=" $ ItemTemplate.DataName);
}

// UpdateCovertnessForAbilities(XComGameState_Unit UnitState, out float CumulativeUnitCovertness, out float CumulativeUnitMultiplier)
static function UpdateCovertnessForAbilities(XComGameState_Unit UnitState, out float CumulativeUnitCovertness, out float CumulativeUnitMultiplier)
{
	local AbilityCovertnessContainer AbilityCov;
	
	foreach default.AbilityCovertness(AbilityCov)
	{
		if(UnitState.HasSoldierAbility(AbilityCov.AbilityName))
		{
			if(AbilityCov.IndividualMultiplier > 0.0)
				CumulativeUnitMultiplier *= AbilityCov.IndividualMultiplier;

			if(AbilityCov.SquadMultiplier > 0.0)
				SquadCovertnessMultiplierDelta *= AbilityCov.SquadMultiplier;
		}
	}
}

// UpdateCovertnessForOfficers(array<StateObjectReference> Soldiers, XComGameState_Unit UnitState, out float CumulativeUnitMultiplier)
static function UpdateCovertnessForOfficers(array<StateObjectReference> Soldiers, XComGameState_Unit UnitState, out float CumulativeUnitMultiplier)
{
	local StateObjectReference SoldierRef;
	local XComGameState_Unit OfficerCandidateState;
	local XComGameState_Unit_LWOfficer OfficerState;
	local array<LeadershipEntry> LeadershipHistory;
	local LeadershipEntry Entry;

	// find the officer and missions together
	foreach Soldiers(SoldierRef)
	{
		OfficerCandidateState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierRef.ObjectID));
		if (class'LWOfficerUtilities'.static.IsHighestRankOfficerinSquad(OfficerCandidateState))
		{
			OfficerState = class'LWOfficerUtilities'.static.GetOfficerComponent(OfficerCandidateState);
			break;
		}
	}

	//`LOG ("LeadershipCovertness 0");

	if (OfficerState != none && UnitState != none && !class'LWOfficerUtilities'.static.IsOfficer(UnitState))
	{
		//`LOG ("LeadershipCovertness 1");

		LeadershipHistory = OfficerState.GetLeadershipData_MissionSorted();
		foreach LeadershipHistory(Entry)
		{
			if (Entry.UnitRef == UnitState.GetReference())
			{
				CumulativeUnitMultiplier *= (1.00 - (fMin (Entry.SuccessfulMissionCount * default.LEADERSHIP_COVERTNESS_PER_MISSION, default.LEADERSHIP_COVERTNESS_CAP)));
				//`LOG ("ADDING LEADERSHIP COVERTNESS MODIFIER:" @ UnitState.GetLastName() @ string(CumulativeUnitMultiplier));
				//`LOG (string (1.00 - (fMin (LeadershipHistory[k].SuccessfulMissionCount * default.LEADERSHIP_COVERTNESS_PER_MISSION, default.LEADERSHIP_COVERTNESS_CAP))));
				break;
			}
		}
	}
}

// GetBaselineHoursToInfiltration(StateObjectReference MissionRef)
static function float GetBaselineHoursToInfiltration(StateObjectReference MissionRef)
{
	local AlienActivity_XComGameState ActivityState;
	local AlienActivity_X2StrategyElementTemplate ActivityTemplate;
	local XComGameState_MissionSite MissionState;
	local float BaseHours;
	local int MissionIdx;

	BaseHours = default.InfiltrationTime_BaselineHours[`DIFFICULTYSETTING];

	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));
	switch (MissionState.Source)
	{
		case 'MissionSource_Blacksite': 
			BaseHours = default.InfiltrationTime_BlackSite[`DIFFICULTYSETTING];
			break;
		case 'MissionSource_Forge':
			BaseHours = default.InfiltrationTime_Forge[`DIFFICULTYSETTING];
			break;
		case 'MissionSource_PsiGate':
			BaseHours = default.InfiltrationTime_PsiGate[`DIFFICULTYSETTING];
			break;
		default:
			break;
	}
	if (MissionRef.ObjectID != 0)
	{
		ActivityState = class'AlienActivity_XComGameState_Manager'.static.FindAlienActivityByMissionRef(MissionRef);
	}
	if (ActivityState == none)
	{
		return BaseHours;
	}
	ActivityTemplate = ActivityState.GetMyTemplate();
	if (ActivityTemplate == none)
	{
		return BaseHours;
	}
	MissionIdx = ActivityState.CurrentMissionLevel;
	if (MissionIdx < 0 || MissionIdx >= ActivityTemplate.MissionTree.Length)
	{
		return BaseHours;
	}
	BaseHours += ActivityTemplate.MissionTree[MissionIdx].BaseInfiltrationModifier_Hours;
	return BaseHours;
}

// GetLiberationFactor(XComGameState_MissionSite MissionState)
static function float GetLiberationFactor(XComGameState_MissionSite MissionState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionAI;
	local AlienActivity_XComGameState ActivityState;
	local float LiberationFactor;

	RegionState = MissionState.GetWorldRegion();
	RegionAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAI(RegionState);
	LiberationFactor = default.InfiltrationLiberationFactor[0];
	if (RegionAI.LiberateStage1Complete)
	{
		LiberationFactor = default.InfiltrationLiberationFactor[1];
	}
	if (RegionAI.LiberateStage2Complete)
	{
		LiberationFactor = default.InfiltrationLiberationFactor[2];
		foreach `XCOMHISTORY.IterateByClassType(class'AlienActivity_XComGameState', ActivityState)
		{
			if(ActivityState.GetMyTemplateName() == class'X2StrategyElement_DefaultAlienActivities'.default.ProtectRegionName)
			{
				if (ActivityState.PrimaryRegion.ObjectID == RegionState.ObjectID)
				{
					if (ActivityState.CurrentMissionLevel > 0)
					{
						LiberationFactor = default.InfiltrationLiberationFactor[3];
					}
					if (ActivityState.CurrentMissionLevel > 1)
					{
						LiberationFactor = default.InfiltrationLiberationFactor[4];
					}
				}
			}
		}
	}
	if (RegionAI.bLiberated)
	{
		LiberationFactor = default.InfiltrationLiberationFactor[5];
	}
	return LiberationFactor;
}