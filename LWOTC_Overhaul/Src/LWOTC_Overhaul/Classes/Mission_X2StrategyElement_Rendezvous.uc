class Mission_X2StrategyElement_Rendezvous extends Mission_X2StrategyElement_Generic config(LWOTC_Missions);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int RENDEZVOUS_GLOBAL_COOLDOWN_HOURS_MIN;
var config int RENDEZVOUS_GLOBAL_COOLDOWN_HOURS_MAX;
var config float RENDEZVOUS_FL_MULTIPLIER;

var name RendezvousName;

defaultProperties
{
    RendezvousName="Rendezvous";
}

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> AlienActivities;
	
	// AlienActivities.AddItem(CreateRendezvousTemplate());
	
	return AlienActivities;
}

// CreateRendezvousTemplate()
static function X2DataTemplate CreateRendezvousTemplate()
{
	local AlienActivity_X2StrategyElementTemplate Template;
	local ActivityCondition_RegionStatus RegionStatus;
    local ActivityCooldown_LWOTC Cooldown;
	local ActivityCondition_HasAdviserofClass AdviserStatus;

	`CREATE_X2TEMPLATE(class'AlienActivity_X2StrategyElementTemplate', Template, default.RendezvousName);

    // Faceless can still exist in liberated regions.
	Template.CanOccurInLiberatedRegion = true;
	Template.ActivityCreation = new class'ActivityCreation_LWOTC';

	Template.DetectionCalc = new class'X2LWActivityDetectionCalc_Rendezvous';

    // Allow only in contacted regions.
	RegionStatus = new class'ActivityCondition_RegionStatus';
	RegionStatus.bAllowInLiberated = true;
	RegionStatus.bAllowInAlien = true;
	RegionStatus.bAllowInContacted = true;
	Template.ActivityCreation.Conditions.AddItem(RegionStatus);

	Template.ActivityCreation.Conditions.AddItem(class'Mission_X2StrategyElement_LWOTC'.static.GetSingleActivityInRegion());

    // Allow only if the region contains faceless
    Template.ActivityCreation.Conditions.AddItem(new class'ActivityCondition_HasFaceless');

	AdviserStatus = new class'ActivityCondition_HasAdviserofClass';
	AdviserStatus.SpecificType = true;
	AdviserStatus.AdviserType = 'Soldier';
	Template.ActivityCreation.Conditions.AddItem(AdviserStatus);

	Cooldown = new class'ActivityCooldown_LWOTC';
	Cooldown.Cooldown_Hours = default.RENDEZVOUS_GLOBAL_COOLDOWN_HOURS_MIN;
	Cooldown.RandCooldown_Hours = default.RENDEZVOUS_GLOBAL_COOLDOWN_HOURS_MAX - default.RENDEZVOUS_GLOBAL_COOLDOWN_HOURS_MIN;
	Template.ActivityCooldown = Cooldown;

	Template.OnMissionSuccessFn = TypicalEndActivityOnMissionSuccess;
	Template.OnMissionFailureFn = TypicalAdvanceActivityOnMissionFailure;

	Template.WasMissionSuccessfulFn = none;  // always one objective
	Template.GetMissionForceLevelFn = GetRendezvousForceLevel;
	Template.GetMissionAlertLevelFn = GetTypicalMissionAlertLevel;

	Template.GetTimeUpdateFn = none;
	Template.OnActivityUpdateFn = none;
	Template.OnMissionExpireFn = OnRendezvousExpired;
	Template.GetMissionRewardsFn = none;
    Template.GetMissionSiteFn = GetRendezvousMissionSite;

	Template.CanBeCompletedFn = none;  // can always be completed
	Template.OnActivityCompletedFn = none;

	return Template;
}

// GetRendezvousForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
static function int GetRendezvousForceLevel(AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionSite, XComGameState NewGameState)
{
	local XComGameState_WorldRegion RegionState;
	local WorldRegion_XComGameState_AlienStrategyAI RegionalAIState;

	RegionState = MissionSite.GetWorldRegion();
	RegionalAIState = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(RegionState, NewGameState);
	return int (RegionalAIState.LocalForceLevel * default.RENDEZVOUS_FL_MULTIPLIER) + ActivityState.GetMyTemplate().ForceLevelModifier;
}

// GetRendezvousMissionSite(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
static function XComGameState_MissionSite GetRendezvousMissionSite(AlienActivity_XComGameState ActivityState, name MissionFamily, XComGameState NewGameState)
{
	/*
    local XComGameState_LWOutpost Outpost;
    local XComGameState_WorldRegion Region;
    local XComGameStateHistory History;
    local XComGameState_MissionSiteRendezvous_LW RendezvousMission;
    local WorldRegion_XComGameState_AlienStrategyAI RegionalAI;
    local array<StateObjectReference> arrFaceless;
    local int i;

    History = `XCOMHISTORY;

    Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
    //Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
    RegionalAI = class'WorldRegion_XComGameState_AlienStrategyAI'.static.GetRegionalAIFromRegion(Region);

    for (i = 0; i < Outpost.Rebels.Length; ++i)
    {
        if (Outpost.Rebels[i].IsFaceless)
        {
            arrFaceless.AddItem(Outpost.Rebels[i].Unit);
        }
    }

    if (arrFaceless.Length == 0)
    {
        `redscreen("GetRendezvousMissionSite: Failed to locate any faceless in outpost");
    }

    if (MissionFamily == 'Rendezvous_LW')
    {
        RendezvousMission = XComGameState_MissionSiteRendezvous_LW(NewGameState.CreateStateobject(class'XComGameState_MissionSiteRendezvous_LW'));

		// There's always at least one faceless
        i = `SYNC_RAND_STATIC(arrFaceless.Length);
        RendezvousMission.FacelessSpies.AddItem(arrFaceless[i]);
        arrFaceless.Remove(i, 1);

		// Add additional faceless from the haven up to the local force level
        while (arrFaceless.Length > 0 && RendezvousMission.FacelessSpies.Length < RegionalAI.LocalForceLevel)
        {
            // Choose another
            i = `SYNC_RAND_STATIC(arrFaceless.Length);
            RendezvousMission.FacelessSpies.AddItem(arrFaceless[i]);
			arrFaceless.Remove(i, 1);
        }
        return RendezvousMission;
    }
    else
    {
        return XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite'));
    }
	*/
	return XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite'));
}

// OnRendezvousExpired (AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
static function OnRendezvousExpired (AlienActivity_XComGameState ActivityState, XComGameState_MissionSite MissionState, XComGameState NewGameState)
{
	/*
	local int k;
	local XComGameState_MissionSiteRendezvous_LW RendezvousState;
	local XComGameSTate_WorldRegion Region;
	local XComGameState_LWOutpost OutPost;

	if (!ActivityState.bDiscovered)
	{
		// Nothing to do if this mission wasn't detected
		return;
	}

	RendezvousState = XComGameState_MissionSiteRendezvous_LW(MissionState);
	if (RendezvousState != none)
	{
		Region = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(ActivityState.PrimaryRegion.ObjectID));
		//Outpost = `LWOUTPOSTMGR.GetOutpostForRegion(Region);
		Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', OutPost.ObjectID));
		NewGameState.AddStateObject(Outpost);

		// Remove all faceless that were on this mission from the haven: the adviser detected this mission
		// and knows who they are, so their cover is blown.
		for (k=0; k < RendezvousState.FacelessSpies.Length; k++)
		{
			OutPost.RemoveRebel(RendezvousState.FacelessSpies[k], NewGameState);
		}
	}
	*/
}