//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCondition_NumberActivities.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Conditionals on the number of other activities currently active
//---------------------------------------------------------------------------------------
class ActivityCondition_NumberActivities extends ActivityCondition_LWOTC;

var int MaxActivitiesInWorld;
var int MaxActivitiesInRegion;
var int MaxCategoriesInRegion;

defaultProperties
{
	MaxActivitiesInWorld=-1
	MaxActivitiesInRegion=-1
	MaxCategoriesInRegion=-1
}

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	local AlienActivity_XComGameState ActivityState;
	local int Count;
	local bool bMeetsCondition;

	bMeetsCondition = true;
	if(MaxActivitiesInWorld >= 0)
	{
		Count = 0;
		foreach ActivityCreation.ActivityStates(ActivityState)
		{
			if(ActivityState.GetMyTemplateName() == ActivityCreation.ActivityTemplate.DataName)
			{
				Count++;
			}
		}
		if(Count >= MaxActivitiesInWorld)
			bMeetsCondition = false;

		ActivityCreation.NumActivitiesToCreate = Min(ActivityCreation.NumActivitiesToCreate, MaxActivitiesInWorld-Count);
	}
	return bMeetsCondition;
}

simulated function bool MeetsConditionWithRegion(ActivityCreation_LWOTC ActivityCreation, XComGameState_WorldRegion Region, XComGameState NewGameState)
{
	local AlienActivity_XComGameState ActivityState;
	local int Count;
	local bool bMeetsCondition;

	bMeetsCondition = true;
	if(MaxActivitiesInRegion >= 0)
	{
		Count = 0;
		foreach ActivityCreation.ActivityStates(ActivityState)
		{
			if(ActivityState.PrimaryRegion.ObjectID == Region.ObjectID && ActivityState.GetMyTemplateName() == ActivityCreation.ActivityTemplate.DataName)
			{
				Count++;
			}
		}
		if(Count >= MaxActivitiesInRegion)
			bMeetsCondition = false;
	}
	if(MaxCategoriesInRegion >= 0)
	{
		Count = 0;
		foreach ActivityCreation.ActivityStates(ActivityState)
		{
			if(ActivityState.PrimaryRegion.ObjectID == Region.ObjectID && ActivityState.GetMyTemplate().ActivityCategory == ActivityCreation.ActivityTemplate.ActivityCategory)
			{
				Count++;
			}
		}
		if(Count >= MaxCategoriesInRegion)
			bMeetsCondition = false;
	}
	return bMeetsCondition;
}