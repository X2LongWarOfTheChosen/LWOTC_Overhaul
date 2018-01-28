class Override_TemplateMods_Rewards extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateModifyRewardsTemplate());

    return Templates;
}

// Update StaffSlotTemplates as needed
static function Override_TemplateMods_Template CreateModifyRewardsTemplate()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'UpdateRewards');

    // We need to modify grenade items and ability templates
    Template.StrategyElementTemplateModFn = UpdateRewardTemplate;
    return Template;
}

function UpdateRewardTemplate(X2StrategyElementTemplate Template, int Difficulty)
{
	local X2RewardTemplate RewardTemplate;

	RewardTemplate = X2RewardTemplate(Template);
	if(RewardTemplate == none)
		return;
	
	switch (RewardTemplate.DataName)
	{
		case 'Reward_FacilityLead':
			// change reward string delegate so it returns the template DisplayName
			RewardTemplate.GetRewardStringFn = class'X2StrategyElement_DefaultRewards'.static.GetMissionRewardString; 
			break;
		case 'Reward_Soldier':
			RewardTemplate.GenerateRewardFn = GenerateRandomSoldierReward;
			break;
		default:
			break;
	}
}

function GenerateRandomSoldierReward(XComGameState_Reward RewardState, XComGameState NewGameState, optional float RewardScalar = 1.0, optional StateObjectReference RegionRef)
{
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local XComGameStateHistory History;
	local XComGameState_Unit NewUnitState;
	local XComGameState_WorldRegion RegionState;
	local int idx, NewRank;
	local name nmCountry, SelectedClass;
	local array<name> arrActiveTemplates;
	local X2SoldierClassTemplateManager ClassMgr;
	local array<X2SoldierClassTemplate> arrClassTemplates;
	local X2SoldierClassTemplate ClassTemplate;
	local XComGameState_HeadquartersAlien AlienHQ;

	History = `XCOMHISTORY;
	nmCountry = '';
	RegionState = XComGameState_WorldRegion(History.GetGameStateForObjectID(RegionRef.ObjectID));

	if(RegionState != none)
	{
		nmCountry = RegionState.GetMyTemplate().GetRandomCountryInRegion();
	}

	//Use the character pool's creation method to retrieve a unit
	NewUnitState = `CHARACTERPOOLMGR.CreateCharacter(NewGameState, `XPROFILESETTINGS.Data.m_eCharPoolUsage, RewardState.GetMyTemplate().rewardObjectTemplateName, nmCountry);
	NewUnitState.RandomizeStats();
	NewGameState.AddStateObject(NewUnitState);

	ResistanceHQ = XComGameState_HeadquartersResistance(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	if(!NewGameState.GetContext().IsStartState())
	{
		ResistanceHQ = XComGameState_HeadquartersResistance(NewGameState.CreateStateObject(class'XComGameState_HeadquartersResistance', ResistanceHQ.ObjectID));
		NewGameState.AddStateObject(ResistanceHQ);
	}
	
	// Pick a random class
	ClassMgr = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager();
	arrClassTemplates = ClassMgr.GetAllSoldierClassTemplates(true);
	foreach arrClassTemplates(ClassTemplate)
	{
		if (ClassTemplate.NuminDeck > 0)
		{
			arrActiveTemplates.AddItem(ClassTemplate.DataName);
		}
	}
	if (arrActiveTemplates.length > 0)
	{
		SelectedClass = arrActiveTemplates[`SYNC_RAND(arrActiveTemplates.length)];
	}
	else
	{
		SelectedClass = ResistanceHQ.SelectNextSoldierClass();
	}
	
	NewUnitState.ApplyInventoryLoadout(NewGameState);

	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	NewRank = 1;

	for(idx = 0; idx < class'X2StrategyElement_DefaultRewards'.default.SoldierRewardForceLevelGates.Length; idx++)
	{
		if(AlienHQ.GetForceLevel() >= class'X2StrategyElement_DefaultRewards'.default.SoldierRewardForceLevelGates[idx])
		{
			NewRank++;
		}
	}

	NewUnitState.SetXPForRank(NewRank);
	NewUnitState.StartingRank = NewRank;
	for(idx = 0; idx < NewRank; idx++)
	{
		// Rank up to squaddie
		if(idx == 0)
		{
			NewUnitState.RankUpSoldier(NewGameState, SelectedClass);
			NewUnitState.ApplySquaddieLoadout(NewGameState);
			NewUnitState.bNeedsNewClassPopup = false;
		}
		else
		{
			NewUnitState.RankUpSoldier(NewGameState, NewUnitState.GetSoldierClassTemplate().DataName);
		}
	}	
	RewardState.RewardObjectReference = NewUnitState.GetReference();
}
