//---------------------------------------------------------------------------------------
//  FILE:    LWPodJobs_DefaultJobSet.uc
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: Templates for Pod Jobs
//---------------------------------------------------------------------------------------
class Pods_JobTemplate_DefaultJobSet extends X2StrategyElement config(LWOTC_PodManager);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config int GUARD_PATROL_DISTANCE;

delegate Pods_XComGameState_Job CreateInstanceFn(XComGameState NewGameState);
delegate Vector GetNewDestinationFn(Pods_XComGameState_Job Job, XComGameState NewGameState);

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

    Templates.AddItem(MakeSimpleJobTemplate('Guard', CreateGuardJob, GuardLocationCallback));
    Templates.AddItem(MakeSimpleJobTemplate('Defend', CreateDefendJob, GuardLocationCallback));
    Templates.AddItem(MakeSimpleJobTemplate('Intercept', CreateInterceptJob, InterceptLocationCallback));
    Templates.AddItem(MakeSimpleJobTemplate('Block', CreateBlockJob, BlockLocationCallback)); 
    Templates.AddItem(MakeSimpleJobTemplate('Flank', CreateFlankJob, none));
    return Templates;
}

static function Pods_JobTemplate MakeSimpleJobTemplate(name TemplateName, 
                                                        delegate<CreateInstanceFn> CreateFn,
                                                        delegate<GetNewDestinationFn> NewDestinationFn)
{
    local Pods_JobTemplate Template;
    `CREATE_X2TEMPLATE(class'Pods_JobTemplate', Template, TemplateName);
    Template.CreateInstance = CreateFn;
    Template.GetNewDestination = NewDestinationFn;
    return Template;
}

// Guard job: Move to the objective.
function Pods_XComGameState_Job CreateGuardJob(XComGameState NewGameState)
{
    local Pods_XComGameState_Job_MoveToLocation Job;
    local XComGameState_BattleData BattleData;
    local XComGameStateHistory History;

    History = `XCOMHISTORY;
    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

    Job = Pods_XComGameState_Job_MoveToLocation(NewGameState.CreateStateObject(class'Pods_XComGameState_Job_MoveToLocation'));
    NewGameState.AddStateObject(Job);
    Job.Location = BattleData.MapData.ObjectiveLocation;
    // This job never needs a location update
    return Job;
}

// Defend job: Move to the objective, but once you get there keep this job forever.
function Pods_XComGameState_Job CreateDefendJob(XComGameState NewGameState)
{
    local Pods_XComGameState_Job_MoveToLocation Job;
    local XComGameState_BattleData BattleData;
    local XComGameStateHistory History;

    History = `XCOMHISTORY;
    BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

    Job = Pods_XComGameState_Job_MoveToLocation(NewGameState.CreateStateObject(class'Pods_XComGameState_Job_MoveToLocation'));
    NewGameState.AddStateObject(Job);
    Job.Location = BattleData.MapData.ObjectiveLocation;
    Job.KeepJobAfterReachingDestination = true;
    return Job;
}

// Guard/Defend pods will patrol around a small 'encounter zone' near the objective. Just keeps them nearby but
// not completely stationary.
function Vector GuardLocationCallback(Pods_XComGameState_Job Job, XComGameState NewGameState)
{
	local Pods_XComGameState_Job_MoveToLocation MoveJob;
    local XComGameState_BattleData BattleData;
	local vector NewLocation;

    BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));

	MoveJob = Pods_XComGameState_Job_MoveToLocation(Job);
	if (MoveJob == none)
	{
		`redscreen("GuardLocationCallback called for non-movement job");
	}

	if (!MoveJob.HasReachedDestination())
	{
		// We haven't arrived  at our latest alert position yet. Keep going.
		return MoveJob.Location;
	}

	// Otherwise, choose a new location nearby (+/- GUARD_PATROL_DISTANCE tiles as a rectangle surrounding the objective)
	NewLocation = BattleData.MapData.ObjectiveLocation;
	switch(`SYNC_RAND(4))
	{
		case 0:
			// "NW" corner (-X, +Y)
			NewLocation.X -= default.GUARD_PATROL_DISTANCE;
			NewLocation.Y += default.GUARD_PATROL_DISTANCE;
			break;
		case 1:
			// "NE" corner (+X, +Y)
			NewLocation.X += default.GUARD_PATROL_DISTANCE;
			NewLocation.Y += default.GUARD_PATROL_DISTANCE;
			break;
		case 2:
			// "SW" corner (-X, -Y)
			NewLocation.X -= default.GUARD_PATROL_DISTANCE;
			NewLocation.Y -= default.GUARD_PATROL_DISTANCE;
			break;
		case 3:
			// "SE" corner (+X, -Y)
			NewLocation.X += default.GUARD_PATROL_DISTANCE;
			NewLocation.Y -= default.GUARD_PATROL_DISTANCE;
			break;
	}

	return NewLocation;
}

function Pods_XComGameState_Job CreateInterceptJob(XComGameState NewGameState)
{
    local Pods_XComGameState_Job_MoveToLocation Job;
    local Vector Location;
    local XGAIPlayer AIPlayer;

    AIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
    AIPlayer.GetSquadLocation(Location);

    Location = InterceptLocationCallback(none, NewGameState);

    Job = Pods_XComGameState_Job_MoveToLocation(NewGameState.CreateStateObject(class'Pods_XComGameState_Job_MoveToLocation'));
    NewGameState.AddStateObject(Job);
    Job.Location = Location;
    return Job;
}

function Vector InterceptLocationCallback(Pods_XComGameState_Job Job, XComGameState NewGameState)
{
    local Pods_XComGameState_Manager PodMgr, NewPodMgr;

    PodMgr = `PODMGR;
    NewPodMgr = Pods_XComGameState_Manager(NewGameState.GetGameStateForObjectID(PodMgr.ObjectID));
    if (NewPodMgr != none)
        PodMgr = NewPodMgr;

    // Intercept goes to xcom's last known position
    return PodMgr.GetLastKnownXComPosition();
}

function Pods_XComGameState_Job CreateBlockJob(XComGameState NewGameState)
{
    local Pods_XComGameState_Job_MoveToLocation Job;

    Job = Pods_XComGameState_Job_MoveToLocation(NewGameState.CreateStateObject(class'Pods_XComGameState_Job_MoveToLocation'));
    NewGameState.AddStateObject(Job);
    Job.Location = BlockLocationCallback(none, NewGameState);
    return Job;
}

function Vector BlockLocationCallback(Pods_XComGameState_Job Job, XComGameState NewGameState)
{
    local TwoVectors CurrentLineOfPlay;
    local Vector Location;
    local XGAIPlayer AIPlayer;
    local Pods_XComGameState_Manager PodMgr, NewPodMgr;

    PodMgr = `PODMGR;
    NewPodMgr = Pods_XComGameState_Manager(NewGameState.GetGameStateForObjectID(PodMgr.ObjectID));
    if (NewPodMgr != none)
        PodMgr = NewPodMgr;


    // "Block" XCOM: Set move to the middle of the current line of play, as per
    // vanilla upthrottling. The difference here is that the pod mgr doesn't 
    // necessarily have absolute knowledge of where XCOM is.
    AIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
    AIPlayer.m_kNav.UpdateCurrentLineOfPlay(CurrentLineOfPlay);
    Location = PodMgr.GetLastKnownXComPosition();
    Location = (Location + CurrentLineOfPlay.v2) * 0.5f;
    return Location;
}

function Pods_XComGameState_Job CreateFlankJob(XComGameState NewGameState)
{
    local Pods_XComGameState_Job_Flank Job;

    Job = Pods_XComGameState_Job_Flank(NewGameState.CreateStateObject(class'Pods_XComGameState_Job_Flank'));
    NewGameState.AddStateObject(Job);
    // Flank class handles location setup and update internally.
    return Job;
}

