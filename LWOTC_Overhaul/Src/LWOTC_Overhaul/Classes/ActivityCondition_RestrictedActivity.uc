//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_RestrictedActivity.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Conditionals on the which other activities can't exist
//---------------------------------------------------------------------------------------
class ActivityCondition_RestrictedActivity extends ActivityCondition_LWOTC;

var array<name> ActivityNames;
var int MaxRestricted;

var array<name> CategoryNames;
var int MaxRestricted_Category;

var array<name> ActivityNames_Global;
var int MaxRestricted_Global;

defaultProperties
{
	MaxRestricted=9999
	MaxRestricted_Category=9999
	MaxRestricted_Global=9999
}

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local AlienActivity_XComGameState ActivityState;
	local int Count;
	local bool bMeetsCondition;

	bMeetsCondition = true;
	if(MaxRestricted_Global < default.MaxRestricted_Global)
	{
		Count = 0;
		foreach ActivityCreation.ActivityStates(ActivityState)
		{
			if(ActivityNames_Global.Find(ActivityState.GetMyTemplateName()) != -1)
			{
				Count++;
			}
		}
		if(Count >= MaxRestricted_Global)
			bMeetsCondition = false;
		ActivityCreation.NumActivitiesToCreate = Min(ActivityCreation.NumActivitiesToCreate, MaxRestricted_Global-Count);
	}
	return bMeetsCondition;
}

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local AlienActivity_XComGameState ActivityState;
	local int Count;
	local bool bMeetsCondition;

	bMeetsCondition = true;
	if(MaxRestricted_Category < default.MaxRestricted_Category)
	{
		Count = 0;
		foreach ActivityCreation.ActivityStates(ActivityState)
		{
			if(CategoryNames.Find(ActivityState.GetMyTemplate().ActivityCategory) != -1)
			{
				if(ActivityState.PrimaryRegion.ObjectID == Region.ObjectID)
					Count++;
			}
		}
		if(Count >= MaxRestricted_Category)
			bMeetsCondition = false;
	}
	if(MaxRestricted < default.MaxRestricted)
	{
		Count = 0;
		foreach ActivityCreation.ActivityStates(ActivityState)
		{
			if(ActivityNames.Find(ActivityState.GetMyTemplateName()) != -1)
			{
				if(ActivityState.PrimaryRegion.ObjectID == Region.ObjectID)
					Count++;
			}
		}
		if(Count >= MaxRestricted)
			bMeetsCondition = false;
	}
	return bMeetsCondition;
}