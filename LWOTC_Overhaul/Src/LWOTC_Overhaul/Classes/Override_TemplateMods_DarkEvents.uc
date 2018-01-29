class Override_TemplateMods_DarkEvents extends X2StrategyElement;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateModifyDarkEventsTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateModifyDarkEventsTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ModifyDarkEvents');
	Template.StrategyElementTemplateModFn = ModifyDarkEvents;
	return Template;
}

function ModifyDarkEvents (X2StrategyElementTemplate Template, int Difficulty)
{
	local X2DarkEventTemplate DarkEventTemplate;
	
	DarkEventTemplate = X2DarkEventTemplate (Template);
	if (DarkEventTemplate != none)
	{
		DarkEventTemplate.bNeverShowObjective = true; // this is added so no Dark Events show in the objective list, since it would get overwhelmed
		switch (DarkEventTemplate.DataName)
		{
			case 'DarkEvent_AlloyPadding': DarkEventTemplate.bInfiniteDuration = true; DarkEventTemplate.bRepeatable = false; DarkEventTemplate.CanActivateFn = class 'DarkEvents_X2StrategyElement'.static.CanActivateCodexUpgrade; break;
			case 'DarkEvent_ViperRounds': DarkEventTemplate.bInfiniteDuration = true; DarkEventTemplate.bRepeatable = false; break;
			case 'DarkEvent_NewConstruction': DarkEventTemplate.StartingWeight = 0; DarkEventTemplate.MinWeight = 0; DarkEventTemplate.MaxWeight = 0; break; //REMOVES FROM PLAY, I THINK
			case 'DarkEvent_RuralCheckpoints':  DarkEventTemplate.StartingWeight = 0; DarkEventTemplate.MinWeight = 0; DarkEventTemplate.MaxWeight = 0; break; //REMOVES FROM PLAY, I THINK
			case 'DarkEvent_AlienCypher': 
				DarkEventTemplate.OnActivatedFn = class'DarkEvents_X2StrategyElement'.static.ActivateAlienCypher_LW; 
				DarkEventTemplate.OnDeactivatedFn = class'DarkEvents_X2StrategyElement'.static.DeactivateAlienCypher_LW;
				break;
			case 'DarkEvent_ResistanceInformant':
				DarkEventTemplate.MinDurationDays = 21;
				DarkEventTemplate.MaxDurationDays = 28;
				DarkEventTemplate.GetSummaryFn = GetResistanceInformantSummary;
				break;
			case 'DarkEvent_MinorBreakthrough':
				DarkEventTemplate.MinActivationDays = 15;
				DarkEventTemplate.MaxActivationDays = 20;
				DarkEventTemplate.MutuallyExclusiveEvents.AddItem('DarkEvent_MinorBreakthrough2');
				DarkEventTemplate.MutuallyExclusiveEvents.AddItem('DarkEvent_MajorBreakthrough2');
				DarkEventTemplate.CanActivateFn = class'DarkEvents_X2StrategyElement'.static.CanActivateMinorBreakthroughAlt; // Will check for whether avatar project has been revealed
				DarkEventTemplate.OnActivatedFn = class'DarkEvents_X2StrategyElement'.static.ActivateMinorBreakthroughMod;
				`LWTRACE("Redefined Minor Breakthrough Dark Event Template");
				break;
			case 'DarkEvent_MajorBreakthrough':
				DarkEventTemplate.MutuallyExclusiveEvents.AddItem('DarkEvent_MinorBreakthrough2');
				DarkEventTemplate.MutuallyExclusiveEvents.AddItem('DarkEvent_MajorBreakthrough2');
				DarkEventTemplate.CanActivateFn = class'DarkEvents_X2StrategyElement'.static.CanActivateMajorBreakthroughAlt;
				DarkEventTemplate.OnActivatedFn = class'DarkEvents_X2StrategyElement'.static.ActivateMajorBreakthroughMod;
				`LWTRACE("Redefined Major Breakthrough Dark Event Template");
				break;
			case 'DarkEvent_HunterClass':
				DarkEventTemplate.CanActivateFn = class'DarkEvents_X2StrategyElement'.static.CanActivateHunterClass_LW;
				break;
			case 'DarkEvent_RapidResponse':
				DarkEventTEmplate.CanActivateFn = class'DarkEvents_X2StrategyElement'.static.CanActivateAdvCaptainM2Upgrade;
				DarkEventTemplate.bRepeatable = true;
				break;
			default: break;
		}
	}
}

function string GetResistanceInformantSummary(string strSummaryText)
{
	local XGParamTag ParamTag;
	local float Divider, TempFloat;
	local int TempInt;

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

	Divider = class'ActivityDetectionCalc_Terror'.default.RESISTANCE_INFORMANT_DETECTION_DIVIDER[`CAMPAIGNDIFFICULTYSETTING];
	TempInt = Round(Divider);
	if (float(TempInt) ~= Divider)
	{
		ParamTag.StrValue0 = string(TempInt);
	}
	else
	{
		TempFloat = Round(Divider * 10.0) / 10.0;
		ParamTag.StrValue0 = Repl(string(TempFloat), "0", "");
	}

	return `XEXPAND.ExpandString(strSummaryText);
}