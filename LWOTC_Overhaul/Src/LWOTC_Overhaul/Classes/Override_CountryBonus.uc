class Override_CountryBonus extends Object;

static function UpdateLockAndLoadBonus(optional XComGameState StartState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local XComGameState_Continent ContinentState, LockAndLoadContinent, SuitUpContinent, FireWhenReadyContinent;
	local array<X2StrategyElementTemplate> ContinentBonuses;
	local array<name> ContinentBonusNames;
	local X2StrategyElementTemplateManager StratMgr;
	local int idx, RandIndex;
	local bool bNeedsUpdate;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	// Grab All Continent Bonuses
	ContinentBonuses = StratMgr.GetAllTemplatesOfClass(class'X2GameplayMutatorTemplate');
	for(idx = 0; idx < ContinentBonuses.Length; idx++)
	{
		ContinentBonusNames.AddItem(ContinentBonuses[idx].DataName);
	}
	for(idx = 0; idx < ContinentBonuses.Length; idx++)
	{
		if(X2GameplayMutatorTemplate(ContinentBonuses[idx]).Category != "ContinentBonus" ||
			ContinentBonuses[idx].DataName == 'ContinentBonus_LockAndLoad' ||
			ContinentBonuses[idx].DataName == 'ContinentBonus_SuitUp' ||
			ContinentBonuses[idx].DataName == 'ContinentBonus_FireWhenReady')
		{
			ContinentBonusNames.RemoveItem(ContinentBonuses[idx].DataName);
			ContinentBonuses.Remove(idx, 1);
			idx--;
		}
	}

	bNeedsUpdate = StartState == none;

	if(!bNeedsUpdate)
	{
		foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
		{
			break;
		}
		XComHQ.bReuseUpgrades = true;
		foreach StartState.IterateByClassType(class'XComGameState_Continent', ContinentState)
		{
			ContinentBonusNames.RemoveItem(ContinentState.ContinentBonus);
			if(ContinentState.ContinentBonus == 'ContinentBonus_LockAndLoad')
				LockAndLoadContinent = ContinentState;
			else if(ContinentState.ContinentBonus == 'ContinentBonus_SuitUp')
				SuitUpContinent = ContinentState;
			else if(ContinentState.ContinentBonus == 'ContinentBonus_FireWhenReady')
				FireWhenReadyContinent = ContinentState;
		}
	}
	else
	{
		History = `XCOMHISTORY;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating HQ to set ReuseUpgrades");
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
		XComHQ.bReuseUpgrades = true;

		foreach History.IterateByClassType(class'XComGameState_Continent', ContinentState)
		{
			ContinentBonusNames.RemoveItem(ContinentState.GetMyTemplateName());
			if(ContinentState.ContinentBonus == 'ContinentBonus_LockAndLoad')
				LockAndLoadContinent = ContinentState;
			else if(ContinentState.ContinentBonus == 'ContinentBonus_SuitUp')
				SuitUpContinent = ContinentState;
			else if(ContinentState.ContinentBonus == 'ContinentBonus_FireWhenReady')
				FireWhenReadyContinent = ContinentState;
		}
		if (LockAndLoadContinent != none)
		{
			LockAndLoadContinent = XComGameState_Continent(NewGameState.CreateStateObject(class'XComGameState_Continent', LockAndLoadContinent.ObjectID));
			NewGameState.AddStateObject(LockAndLoadContinent);
		}
		if (SuitUpContinent != none)
		{
			SuitUpContinent = XComGameState_Continent(NewGameState.CreateStateObject(class'XComGameState_Continent', SuitUpContinent.ObjectID));
			NewGameState.AddStateObject(SuitUpContinent);
		}
		if (FireWhenReadyContinent != none)
		{
			FireWhenReadyContinent = XComGameState_Continent(NewGameState.CreateStateObject(class'XComGameState_Continent', SuitUpContinent.ObjectID));
			NewGameState.AddStateObject(FireWhenReadyContinent);
		}

	}
	if(LockAndLoadContinent != none)
	{
		// assign a new continent bonus
		RandIndex = `SYNC_RAND_STATIC(ContinentBonusNames.Length);
		LockAndLoadContinent.ContinentBonus = ContinentBonusNames[RandIndex];
		ContinentBonusNames.RemoveItem(LockAndLoadContinent.ContinentBonus);
	}
	if(SuitUpContinent != none)
	{
		// assign a new continent bonus
		RandIndex = `SYNC_RAND_STATIC(ContinentBonusNames.Length);
		SuitUpContinent.ContinentBonus = ContinentBonusNames[RandIndex];
		ContinentBonusNames.RemoveItem(SuitUpContinent.ContinentBonus);
	}
	if(FireWhenReadyContinent != none)
	{
		// assign a new continent bonus
		RandIndex = `SYNC_RAND_STATIC(ContinentBonusNames.Length);
		FireWhenReadyContinent.ContinentBonus = ContinentBonusNames[RandIndex];
		ContinentBonusNames.RemoveItem(FireWhenReadyContinent.ContinentBonus);
	}
	if (bNeedsUpdate)
		History.AddGameStateToHistory(NewGameState);
}