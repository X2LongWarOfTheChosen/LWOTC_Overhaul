class WorldRegion_XComGameState_AlienStrategyAI_Con extends Object config(LWOTC_AlienActivities);

var config array<int>	START_REGION_FORCE_LEVEL;
var config array<int>	START_REGION_ALERT_LEVEL;
var config array<int>	TOTAL_STARTING_FORCE_LEVEL;
var config array<int>	TOTAL_STARTING_ALERT_LEVEL;

var config int			STARTING_LOCAL_MIN_FORCE_LEVEL;
var config int			STARTING_LOCAL_MIN_ALERT_LEVEL;
var config int			STARTING_LOCAL_MIN_VIGILANCE_LEVEL;

var config int			STARTING_LOCAL_MAX_FORCE_LEVEL;
var config int			STARTING_LOCAL_MAX_ALERT_LEVEL;
var config int			STARTING_LOCAL_MAX_VIGILANCE_LEVEL;

// Initialize Regional AIs
static function InitializeRegionalAIs(optional XComGameState StartState)
{
	local XComGameState NewGameState;
	local bool bNeedsGameState;
	local array<XComGameState_WorldRegion> RegionStates;
	local array<WorldRegion_XComGameState_AlienStrategyAI> NewRegionalAIs;
	local int TotalForceLevelToAdd, TotalAlertLevelToAdd;

	if(StartState == none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating Regional AI components");
		bNeedsGameState = true;
		RegionStates = GetAllRegionStates();
	}
	else
	{
		NewGameState = StartState;
		bNeedsGameState = false;
		RegionStates = GetAllRegionStates(NewGameState);
	}

	NewRegionalAIs = GenerateRegionalAIsForRegions(RegionStates, RegionStates, bNeedsGameState);

	TotalForceLevelToAdd = default.TOTAL_STARTING_FORCE_LEVEL[`DIFFICULTYSETTING];
	TotalAlertLevelToAdd = default.TOTAL_STARTING_ALERT_LEVEL[`DIFFICULTYSETTING];

	//adjustments in case for some reason only some of the components are initialized
	if(NewRegionalAIs.Length < RegionStates.Length)
	{
		TotalForceLevelToAdd *= NewRegionalAIs.Length;
		TotalForceLevelToAdd /= RegionStates.Length;
		TotalAlertLevelToAdd *= NewRegionalAIs.Length;
		TotalAlertLevelToAdd /= RegionStates.Length;
	}

	//randomize the order to avoid applying patters
	NewRegionalAIs = RandomizeOrder(NewRegionalAIs);
	SetRegionValues(NewRegionalAIs, NewGameState, TotalForceLevelToAdd, TotalAlertLevelToAdd);

	if(bNeedsGameState)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
}

// Get All Region States
static function array<XComGameState_WorldRegion> GetAllRegionStates(optional XComGameState NewGameState = none)
{
	local array<XComGameState_WorldRegion> RegionStates;
	local XComGameState_WorldRegion RegionState;

	if(NewGameState == none)
	{
		foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
		{
			RegionStates.AddItem(RegionState);
		}
	}
	else
	{
		foreach NewGameState.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
		{
			RegionStates.AddItem(RegionState);
		}
	}
	return RegionStates;
}

// Generate Regional AIs from Region States
static function array<WorldRegion_XComGameState_AlienStrategyAI> GenerateRegionalAIsForRegions(array<XComGameState_WorldRegion> RegionStates, XComGameState NewGameState, bool bNeedsGameState)
{
	local array<WorldRegion_XComGameState_AlienStrategyAI> NewRegionalAIs;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;
	local XComGameState_WorldRegion RegionState;

	foreach RegionStates(RegionState)
	{
		//double check it doesn't already exist
		RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);
		if(RegionalAIState == none)
		{
			RegionalAIState = WorldRegion_XComGameState_AlienStrategyAI(NewGameState.CreateStateObject(class'WorldRegion_XComGameState_AlienStrategyAI'));
			NewGameState.AddStateObject(RegionalAIState);
			if(bNeedsGameState)
			{
				UpdatedRegionState = XComGameState_WorldRegion(NewGameState.CreateStateObject(class'XComGameState_WorldRegion', RegionState.ObjectID));
				NewGameState.AddStateObject(UpdatedRegionState);
			}
			else
			{
				UpdatedRegionState = RegionState;
			}
			UpdatedRegionState.AddComponentObject(RegionalAIState);
			NewRegionalAIs.AddItem(RegionalAIState);
		}
	}
	return NewRegionalAIs;
}

// Randomize Order
static function array<WorldRegion_XComGameState_AlienStrategyAI> RandomizeOrder(const array<WorldRegion_XComGameState_AlienStrategyAI> SourceRegions)
{
	local array<WorldRegion_XComGameState_AlienStrategyAI> Regions;
	local array<WorldRegion_XComGameState_AlienStrategyAI> RemainingRegions;
	local int ArrayLength, idx, Selection;

	ArrayLength = SourceRegions.Length;
	RemainingRegions = SourceRegions;

	for(idx = 0; idx < ArrayLength; idx++)
	{
		Selection = `SYNC_RAND_STATIC(RemainingRegions.Length);
		Regions.AddItem(RemainingRegions[Selection]);
		RemainingRegions.Remove(Selection, 1);
	}

	return Regions;
}

// Set Region Force, Alert and Vigilance levels
static function SetRegionValues(array<WorldRegion_XComGameState_AlienStrategyAI> NewRegionalAIs, XComGameState NewGameState, int TotalForceLevelToAdd, int TotalAlertLevelToAdd)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;
	local int RegionCount, RemainingRegions;
	local int NumVigilanceToDeviate;
	local int ForceLevelToAdd, AlertLevelToAdd, VigilanceLevelToAdd;
	local ing NumVigilanceUp, NumVigilanceDown;

	if(NewGameState != none)
	{
		foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
		{
			break;
		}
	}
	if(XComHQ == none)
	{
		XComHQ = `XCOMHQ;
	}

	NumVigilanceToDeviate = GetVigilanceDeviation(NewRegionalAIs.Length);

	foreach NewRegionalAIs(RegionalAIState, RegionCount)
	{
		if(RegionalAIState.OwningObjectId == XComHQ.StartingRegion.ObjectID)
		{
			ForceLevelToAdd = default.START_REGION_FORCE_LEVEL[`DIFFICULTYSETTING];
			AlertLevelToAdd = default.START_REGION_ALERT_LEVEL[`DIFFICULTYSETTING];
			VigilanceLevelToAdd = Clamp (AlertLevelToAdd, 1, default.STARTING_LOCAL_MAX_VIGILANCE_LEVEL);
		}
		else
		{
			RemainingRegions = NewRegionalAIs.Length - RegionCount;

			ForceLevelToAdd = TotalForceLevelToAdd / RemainingRegions;
			if(RemainingRegions > 1)
			{
				ForceLevelToAdd += `SYNC_RAND_STATIC(3) - 1;
			}
			ForceLevelToAdd = Clamp(ForceLevelToAdd, default.STARTING_LOCAL_MIN_FORCE_LEVEL, default.STARTING_LOCAL_MAX_FORCE_LEVEL);
			TotalForceLevelToAdd -= ForceLevelToAdd;

			AlertLevelToAdd = TotalAlertLevelToAdd / RemainingRegions;
			if(RemainingRegions > 1)
			{
				AlertLevelToAdd += `SYNC_RAND_STATIC(3) - 1;
			}
			AlertLevelToAdd = Clamp(AlertLevelToAdd, default.STARTING_LOCAL_MIN_ALERT_LEVEL, default.STARTING_LOCAL_MAX_ALERT_LEVEL);
			TotalAlertLevelToAdd -= AlertLevelToAdd;

			VigilanceLevelToAdd = AlertLevelToAdd;
			if(NumVigilanceUp++ < NumVigilanceToDeviate)
				VigilanceLevelToAdd += 1;
			else if(NumVigilanceDown++ < NumVigilanceToDeviate)
				VigilanceLevelToAdd -= 1;

			VigilanceLevelToAdd = Clamp (VigilanceLevelToAdd, 1, default.STARTING_LOCAL_MAX_VIGILANCE_LEVEL);

		}
		RegionalAIState.LocalForceLevel = ForceLevelToAdd;
		RegionalAIState.LocalAlertLevel = AlertLevelToAdd;
		RegionalAIState.LocalVigilanceLevel = VigilanceLevelToAdd;
		RegionalAIState.LastVigilanceUpdateTime = class'XComGameState_GeoscapeEntity'.static.GetCurrentTime();
	}
}

// Get Vigilance Deviation
static function int GetVigilanceDeviation(int RegionCount)
{
	local int MinVigilanceToDeviate, MaxVigilanceToDeviate;

	MinVigilanceToDeviate = (RegionCount * 1) / 8;
	MaxVigilanceToDeviate = (RegionCount * 3) / 8;
	return MinVigilanceToDeviate + `SYNC_RAND_STATIC(MaxVigilanceToDeviate - MinVigilanceToDeviate + 1);
}