class Override_Tech extends Object;

static function UpdateTechs()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local array<X2StrategyElementTemplate> arrTechTemplates;
	local XComGameState_Tech TechStateObject;
	local X2TechTemplate TechTemplate;
	local int idx;
	//local array<XComGameState_Tech> AllTechGameStates;
	local array<name> AllTechGameStateNames;
	local XComGameState_Tech TechState;
	local bool bUpdatedAnyTech;

	History = `XCOMHISTORY;

	// Grab all existing tech gamestates
	foreach History.IterateByClassType(class'XComGameState_Tech', TechState)
	{
		//AllTechGameStates.AddItem(TechState);
		AllTechGameStateNames.AddItem(TechState.GetMyTemplateName());
	}

	// Grab all Tech Templates
	arrTechTemplates = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().GetAllTemplatesOfClass(class'X2TechTemplate');

	if(arrTechTemplates.Length == AllTechGameStateNames.Length)
		return;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding new tech gamestates");

	// Iterate through the templates and build each Tech State Object, if it hasn't been already built
	for(idx = 0; idx < arrTechTemplates.Length; idx++)
	{
		TechTemplate = X2TechTemplate(arrTechTemplates[idx]);

		if(AllTechGameStateNames.Find(TechTemplate.DataName) != -1)
			continue;

		if (TechTemplate.RewardDeck != '')
		{
			class'XComGameState_Tech'.static.SetUpTechRewardDeck(TechTemplate);
		}

		bUpdatedAnyTech = true;

		`LOG("Adding new tech gamestate: " $ TechTemplate.DataName);

		TechStateObject = XComGameState_Tech(NewGameState.CreateStateObject(class'XComGameState_Tech'));
		TechStateObject.OnCreation(X2TechTemplate(arrTechTemplates[idx]));
		NewGameState.AddStateObject(TechStateObject);
	}

	if(bUpdatedAnyTech)
		History.AddGameStateToHistory(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);
}