//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWEvacSpawner.uc
//  AUTHOR:  tracktwo / Pavonis Interactive
//  PURPOSE: Game state for tracking delayed evac zone deployment.
//---------------------------------------------------------------------------------------

class EvacZone_XComGameState_EvacSpawner extends XComGameState_BaseObject
    config(LWOTC_EvacZone);
    //implements(X2VisualizedInterface);

var config String FlareEffectPathName;
var config String EvacRequestedNarrativePathName;
var config String FirebrandArrivedNarrativePathName;

var privatewrite Vector SpawnLocation;
var privatewrite int Countdown;
var privatewrite bool SkipCreationNarrative;

// Real OOP shit
function InitEvac(int Turns, vector Loc)
{
    Countdown = Turns;
    SpawnLocation = Loc;

    `CONTENT.RequestGameArchetype(FlareEffectPathName);
}

function vector GetLocation()
{
    return SpawnLocation;
}

function TTile GetCenterTile()
{
	return `XWORLD.GetTileCoordinatesFromPosition(SpawnLocation);
}

function int GetCountdown()
{
    return Countdown;
}

function SetCountdown(int NewCountdown)
{
    Countdown = NewCountdown;
}

function ResetCountdown()
{
    // Clear the countdown (effectively disable the spawner)
    Countdown = -1;
}
// End: Real OOP shit

// OnEvacSpawnerCreated(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
// A new evac spawner was created.
function EventListenerReturn OnEvacSpawnerCreated(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameState NewGameState;
    local EvacZone_XComGameState_EvacSpawner NewSpawnerState;
    
    // Set up visualization to drop the flare.
    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
    XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BuildVisualizationForSpawnerCreation;
    NewSpawnerState = EvacZone_XComGameState_EvacSpawner(NewGameState.ModifyStateObject(class'EvacZone_XComGameState_EvacSpawner', ObjectID));
    NewGameState.AddStateObject(NewSpawnerState);
    `TACTICALRULES.SubmitGameState(NewGameState);

    // no countdown specified, spawn the evac zone immediately. Otherwise we'll tick down each turn start (handled in
    // UIScreenListener_TacticalHUD to also display the counter).
    if(Countdown == 0)
    {
        NewSpawnerState.SpawnEvacZone();
    }

    return ELR_NoInterrupt;
}

// BuildVisualizationForSpawnerCreation(XComGameState VisualizeGameState)
// Visualize the spawner creation: drop a flare at the point the evac zone will appear.
function BuildVisualizationForSpawnerCreation(XComGameState VisualizeGameState)
{
    local VisualizationActionMetadata ActionMetadata;
    local XComGameStateHistory History;
    local EvacZone_XComGameState_EvacSpawner EvacSpawnerState;
    local X2Action_PlayEffect EvacSpawnerEffectAction;
    local X2Action_PlayNarrative NarrativeAction;

    History = `XCOMHISTORY;
    EvacSpawnerState = EvacZone_XComGameState_EvacSpawner(History.GetGameStateForObjectID(ObjectID));

	ActionMetadata.StateObject_OldState = EvacSpawnerState;
    ActionMetadata.StateObject_NewState = EvacSpawnerState;

    // Temporary flare effect is the advent reinforce flare. Replace this.
    EvacSpawnerEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
    EvacSpawnerEffectAction.EffectName = FlareEffectPathName;
    EvacSpawnerEffectAction.EffectLocation = EvacSpawnerState.SpawnLocation;

    // Don't take control of the camera, the player knows where they put the zone.
    EvacSpawnerEffectAction.CenterCameraOnEffectDuration = 0; //ContentManager.LookAtCamDuration;
    EvacSpawnerEffectAction.bStopEffect = false;

    if (!EvacSpawnerState.SkipCreationNarrative)
    {
        NarrativeAction = X2Action_PlayNarrative(class'X2Action_PlayNarrative'.static.AddToVisualizationTree(ActionMetadata, VisualizeGameState.GetContext()));
        NarrativeAction.Moment = XComNarrativeMoment(DynamicLoadObject(EvacRequestedNarrativePathName, class'XComNarrativeMoment'));
        NarrativeAction.WaitForCompletion = false;
    }
}

// SpawnEvacZone()
// Countdown complete: time to spawn the evac zone.
function SpawnEvacZone()
{
    local XComGameState NewGameState;
    local X2EventManager EventManager;
    local Object ThisObj;

    EventManager = `XEVENTMGR;

    // Set up visualization of the new evac zone.
    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SpawnEvacZone");
    XComGameStateContext_ChangeContainer(NewGameState.GetContext()).BuildVisualizationFn = BuildVisualizationForEvacSpawn;

    // Place the evac zone on the map.
    class'XComGameState_EvacZone'.static.PlaceEvacZone(NewGameState, SpawnLocation, eTeam_XCom);

    // Register and trigger an event to occur after we've visualized this to clean ourselves up.
    ThisObj = self;
    EventManager.RegisterForEvent(ThisObj, 'SpawnEvacZoneComplete', OnSpawnEvacZoneComplete, ELD_OnStateSubmitted,, ThisObj);
    EventManager.TriggerEvent('SpawnEvacZoneComplete', ThisObj, ThisObj, NewGameState);

    `TACTICALRULES.SubmitGameState(NewGameState);
}

// BuildVisualizationForEvacSpawn(XComGameState VisualizeState)
// Visualize the evac spawn: turn off the flare we dropped as a countdown visualizer and visualize the evac zone dropping.
function BuildVisualizationForEvacSpawn(XComGameState VisualizeState)
{
	local VisualizationActionMetadata ActionMetadata;
	local VisualizationActionMetadata InitMetadata;
    local XComGameStateHistory History;
    local XComGameState_EvacZone EvacZone;
    local EvacZone_XComGameState_EvacSpawner EvacSpawnerState;
    local X2Action_PlayEffect EvacSpawnerEffectAction;
    local X2Action_PlayNarrative NarrativeAction;

    History = `XCOMHISTORY;

    // First, get rid of our old visualization from the delayed spawn.
    EvacSpawnerState = EvacZone_XComGameState_EvacSpawner(History.GetGameStateForObjectID(ObjectID));
	ActionMetadata.StateObject_OldState = EvacSpawnerState;
    ActionMetadata.StateObject_NewState = EvacSpawnerState;

    EvacSpawnerEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, VisualizeState.GetContext()));
    EvacSpawnerEffectAction.EffectName = FlareEffectPathName;
    EvacSpawnerEffectAction.EffectLocation = EvacSpawnerState.SpawnLocation;
    EvacSpawnerEffectAction.bStopEffect = true;
    EvacSpawnerEffectAction.bWaitForCompletion = false;
    EvacSpawnerEffectAction.bWaitForCameraCompletion = false;

    // Now add the new visualization for the evac zone placement.
    ActionMetadata = InitMetadata;

    foreach VisualizeState.IterateByClassType(class'XComGameState_EvacZone', EvacZone)
    {
        break;
    }
    `assert (EvacZone != none);

    ActionMetadata.StateObject_OldState = EvacZone;
    ActionMetadata.StateObject_NewState = EvacZone;
    ActionMetadata.VisualizeActor = EvacZone.GetVisualizer();
    class'X2Action_PlaceEvacZone'.static.AddToVisualizationTree(ActionMetadata, VisualizeState.GetContext());
    NarrativeAction = X2Action_PlayNarrative(class'X2Action_PlayNarrative'.static.AddToVisualizationTree(ActionMetadata, VisualizeState.GetContext()));
    NarrativeAction.Moment = XComNarrativeMoment(DynamicLoadObject(FirebrandArrivedNarrativePathName, class'XComNarrativeMoment'));
    NarrativeAction.WaitForCompletion = false;
}

// OnSpawnEvacZoneComplete(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
// Evac zone has spawned. We can now clean ourselves up as this state object is no longer needed.
function EventListenerReturn OnSpawnEvacZoneComplete(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
    local XComGameState NewGameState;
    local EvacZone_XComGameState_EvacSpawner NewSpawnerState;

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Spawn Evac Zone Complete");
    NewSpawnerState = EvacZone_XComGameState_EvacSpawner(NewGameState.ModifyStateObject(class'EvacZone_XComGameState_EvacSpawner', ObjectID));
    NewSpawnerState.ResetCountdown();
    NewGameState.AddStateObject(NewSpawnerState);
    `TACTICALRULES.SubmitGameState(NewGameState);

    return ELR_NoInterrupt;
}

// BuildVisualizationForFlareDestroyed(XComGameState VisualizeState)
function BuildVisualizationForFlareDestroyed(XComGameState VisualizeState)
{
    local X2Action_PlayEffect EvacSpawnerEffectAction;
	local VisualizationActionMetadata ActionMetadata;

	ActionMetadata.StateObject_OldState = self;
    ActionMetadata.StateObject_NewState = self;

    EvacSpawnerEffectAction = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, VisualizeState.GetContext()));
    EvacSpawnerEffectAction.EffectName = FlareEffectPathName;
    EvacSpawnerEffectAction.EffectLocation = SpawnLocation;
    EvacSpawnerEffectAction.bStopEffect = true;
    EvacSpawnerEffectAction.bWaitForCompletion = false;
    EvacSpawnerEffectAction.bWaitForCameraCompletion = false;
}

// OnEndTacticalPlay(XComGameState NewGameState)
function OnEndTacticalPlay(XComGameState NewGameState)
{
    local X2EventManager EventManager;
    local Object ThisObj;

    ThisObj = self;
    EventManager = `XEVENTMGR;

    EventManager.UnRegisterFromEvent(ThisObj, 'EvacSpawnerCreated');
    EventManager.UnRegisterFromEvent(ThisObj, 'SpawnEvacZoneComplete');
}

//InitiateEvacZoneDeployment(int InitialCountdown,const out Vector DeploymentLocation,optional XComGameState IncomingGameState,optional bool bSkipCreationNarrative)
// Entry point: create a delayed evac zone instance with the given countdown and position.
static function InitiateEvacZoneDeployment(
    int InitialCountdown,
    const out Vector DeploymentLocation,
    optional XComGameState IncomingGameState,
    optional bool bSkipCreationNarrative)
{
    local EvacZone_XComGameState_EvacSpawner NewEvacSpawnerState;
    local XComGameState NewGameState;
    local X2EventManager EventManager;
    local Object EvacObj;

    EventManager = `XEVENTMGR;

    if (IncomingGameState == none)
    {
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating XCom Evac Spawner");
    }
    else
    {
        NewGameState = IncomingGameState;
    }

    NewEvacSpawnerState = EvacZone_XComGameState_EvacSpawner(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'EvacZone_XComGameState_EvacSpawner', true));
    if (NewEvacSpawnerState != none)
    {
        NewEvacSpawnerState = EvacZone_XComGameState_EvacSpawner(NewGameState.ModifyStateObject(class'EvacZone_XComGameState_EvacSpawner', NewEvacSpawnerState.ObjectID));
    }
    else
    {
        NewEvacSpawnerState = EvacZone_XComGameState_EvacSpawner(NewGameState.CreateNewStateObject(class'EvacZone_XComGameState_EvacSpawner'));
    }

    // Clean up any existing evac zone.
    RemoveExistingEvacZone(NewGameState);

    NewEvacSpawnerState.InitEvac(InitialCountdown, DeploymentLocation);
    NewEvacSpawnerState.SkipCreationNarrative = bSkipCreationNarrative;

    NewGameState.AddStateObject(NewEvacSpawnerState);

    // Let others know we've requested an evac.
    EventManager.TriggerEvent('EvacRequested', NewEvacSpawnerState, NewEvacSpawnerState, NewGameState);

    // Register & immediately trigger a new event to react to the creation of this object. This should allow visualization to
    // occur in the desired order: e.g. we see the visualization of the place evac zone ability before the visualization of the state itself
    // (i.e. the flare).
    
    // NOTE: This event isn't intended for other parts of the code to listen to. See the 'EvacRequested' event below for that.
    EvacObj = NewEvacSpawnerState;
    EventManager.RegisterForEvent(EvacObj, 'EvacSpawnerCreated', OnEvacSpawnerCreated, ELD_OnStateSubmitted, , NewEvacSpawnerState);
    EventManager.TriggerEvent('EvacSpawnerCreated', NewEvacSpawnerState, NewEvacSpawnerState);

    if (IncomingGameState == none)
    {
        `TACTICALRULES.SubmitGameState(NewGameState);
    }
}

// RemoveExistingEvacZone(XComGameState NewGameState)
function static RemoveExistingEvacZone(XComGameState NewGameState)
{
    local XComGameState_EvacZone EvacZone;
    local X2Actor_EvacZone EvacZoneActor;

    EvacZone = class'XComGameState_EvacZone'.static.GetEvacZone();
    if (EvacZone == none)
        return;

    EvacZoneActor = X2Actor_EvacZone(EvacZone.GetVisualizer());
    if (EvacZoneActor == none)
        return;

    // We have an existing evac zone

    // Disable the evac ability
    class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('Evac', false, NewGameState);

    // Tell the visualizer to clean itself up.
    EvacZoneActor.Destroy();
    
    // Remove the evac zone state (even though we destroyed its visualizer, the state is still
    // there and will reappear if we reload the save).
    NewGameState.RemoveStateObject(EvacZone.ObjectID);

    // Stop the EvacZoneFlare environmental SFX (chopper blades/exhaust)
    //class'WorldInfo'.static.GetWorldInfo().StopAkSound('EvacZoneFlares');
}

// GetPendingEvacZone()
static function EvacZone_XComGameState_EvacSpawner GetPendingEvacZone()
{
    local EvacZone_XComGameState_EvacSpawner EvacState;
    local XComGameStateHistory History;

    History = `XCOMHistory;
    foreach History.IterateByClassType(class'EvacZone_XComGameState_EvacSpawner', EvacState)
    {
		if (EvacState.GetCountdown() > 0)
		{
			return EvacState;
		}
    }    
    return none;
}

/*
// Nothing to do here.
function SyncVisualizer(optional XComGameState GameState = none)
{

}

// AppendAdditionalSyncActions(out VisualizationTrack BuildTrack)
// Called when we load a saved game with an active delayed evac zone counter. Put the flare effect back up again, but don't
// focus the camera on it.
function AppendAdditionalSyncActions(out VisualizationTrack BuildTrack)
{
    local X2Action_PlayEffect PlayEffect;

    PlayEffect = X2Action_PlayEffect(class'X2Action_PlayEffect'.static.AddToVisualizationTrack(BuildTrack, GetParentGameState().GetContext()));

    PlayEffect.EffectName = FlareEffectPathName;

    PlayEffect.EffectLocation = SpawnLocation;
    PlayEffect.CenterCameraOnEffectDuration = 0;
    PlayEffect.bStopEffect = false;
}
*/