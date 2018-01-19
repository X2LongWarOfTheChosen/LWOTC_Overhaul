//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCreation.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Basic creation mechanics for alien activities
//---------------------------------------------------------------------------------------
class ActivityCreation_LWOTC extends Object;

var array<StateObjectReference>		PrimaryRegions;
var array<StateObjectReference>		SecondaryRegions;
var array<ActivityCondition_LWOTC>	Conditions;
var int								NumActivitiesToCreate;

var protectedwrite array<AlienActivity_XComGameState>		ActivityStates;
var protectedwrite AlienActivity_X2StrategyElementTemplate	ActivityTemplate;

// InitActivityCreation(AlienActivity_X2StrategyElementTemplate Template, XComGameState NewGameState)
simulated function InitActivityCreation(AlienActivity_X2StrategyElementTemplate Template, XComGameState NewGameState)
{
	NumActivitiesToCreate = 999;
	ActivityTemplate = Template;
	ActivityStates = class'AlienActivity_XComGameState_Manager'.static.GetAllActivities(NewGameState);
}

// GetNumActivitiesToCreate(XComGameState NewGameState)
simulated function int GetNumActivitiesToCreate(XComGameState NewGameState)
{
	PrimaryRegions = FindValidRegions(NewGameState);
	NumActivitiesToCreate = Min(NumActivitiesToCreate, PrimaryRegions.Length);
	return NumActivitiesToCreate;
}

// FindValidRegions(XComGameState NewGameState)
simulated function array<StateObjectReference> FindValidRegions(XComGameState NewGameState)
{
	local ActivityCondition_LWOTC					Condition;
	local array<StateObjectReference>				ValidActivityRegions;
	local XComGameState_WorldRegion					RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI	RegionalAI;
	local bool										bValidRegion;

	foreach Conditions(Condition)
	{
		if(!Condition.MeetsCondition(self, NewGameState))
		{
			return ValidActivityRegions;
		}
	}

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		bValidRegion = true;
		foreach Conditions(Condition)
		{
			if(!Condition.MeetsConditionWithRegion(self,  RegionState, NewGameState))
			{
				bValidRegion = false;
				break;
			}
			RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);
			if(RegionalAI.RegionalCooldowns.Find('ActivityName', ActivityTemplate.DataName) != -1)
			{
				bValidRegion = false;
				break;
			}
		}
		
		if(bValidRegion)
			ValidActivityRegions.AddItem(RegionState.GetReference());
	}

	return ValidActivityRegions;
}

// GetBestPrimaryRegion(XComGameState NewGameState)
simulated function StateObjectReference GetBestPrimaryRegion(XComGameState NewGameState)
{
	local StateObjectReference SelectedRegion;

	SelectedRegion = FindBestPrimaryRegion(NewGameState);
	PrimaryRegions.RemoveItem(SelectedRegion);

	return SelectedRegion;
}

// FindBestPrimaryRegion(XComGameState NewGameState)
simulated function StateObjectReference FindBestPrimaryRegion(XComGameState NewGameState)
{
	local StateObjectReference NullRef;

	if (PrimaryRegions.Length > 0)
	{
		return PrimaryRegions[`SYNC_RAND(PrimaryRegions.Length)];
	}
	return NullRef;
}

simulated function array<StateObjectReference> GetSecondaryRegions(XComGameState NewGameState, AlienActivity_XComGameState ActivityState);

// LinkDistanceToClosestContactedRegion(XComGameState_WorldRegion FromRegion)
function int LinkDistanceToClosestContactedRegion(XComGameState_WorldRegion FromRegion)
{
	local array<XComGameState_WorldRegion> arrSearchRegions;
	local XComGameState_WorldRegion RegionState;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		if(RegionState.ResistanceLevel >= eResLevel_Contact)
		{
			arrSearchRegions.AddItem(RegionState);
		}
	}

	return FromRegion.FindClosestRegion(arrSearchRegions, RegionState);
}