//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPodJob_MoveToLocation.uc
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: A pod job to move to a particular location on the map.
//---------------------------------------------------------------------------------------
class Pods_XComGameState_Job_MoveToLocation extends Pods_XComGameState_Job config(LWOTC_PodManager);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

var config const int DESTINATION_REACHED_SIZE_SQ;

// The target location
var Vector Location;

// Should we keep this job after we reach the destination?
var bool KeepJobAfterReachingDestination;

function InitJob(Pods_JobTemplate JobTemplate, XComGameState_AIGroup Group, int JobID, EAlertCause Cause, String Tag, XComGameState NewGameState)
{
    super.InitJob(JobTemplate, Group, JobID, Cause, Tag, NewGameState);

    Location = SetAlertAtLocation(Location, Group, NewGameState);
}

function bool ProcessTurn(Pods_XComGameState_Manager PodMgr, XComGameState NewGameState)
{
    local Vector NewDestination;
    local XComGameState_AIGroup Group;
    local Pods_JobTemplate Template;

    if (!ShouldContinueJob(NewGameState))
    {
        return false;
    }

    Template = GetMyTemplate();

    if (Template.GetNewDestination != none)
    {
        NewDestination = Template.GetNewDestination(self, NewGameState);

        if (Location != NewDestination)
        {
            Group = XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
            Location = SetAlertAtLocation(NewDestination, Group, NewGameState);
        }
    }

    return true;
}

function XComGameState_AIGroup GetGroup()
{
    return XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
}

function bool HasReachedDestination()
{
	local XComGameState_AIGroup Group;

	Group = GetGroup();
    return (VSizeSq(Group.GetGroupMidpoint() - Location) < DESTINATION_REACHED_SIZE_SQ);
}

function bool ShouldContinueJob(XComGameState NewGameState)
{
    // Have we reached our destination?
    if (HasReachedDestination())
    {
        // We're here!
        return KeepJobAfterReachingDestination;
    }

    // We haven't yet arrived. Use the standard mechanism to allow job timeouts if they can't get
    // to the destination, even if they would keep the job forever after getting there.
    if (!super.ShouldContinueJob(NewGameState))
    {
        return false;
    }

    return true;
}

function String GetDebugString()
{
    return Super.GetDebugString() $ " @ " $ Location;
}

function DrawDebugLabel(Canvas kCanvas)
{
    local XComGameState_AIGroup Group;
    local Vector CurrentGroupLocation;
    local Vector ScaleVector;
    local SimpleShapeManager ShapeManager;

    Group = XComGameState_AIGroup(`XCOMHISTORY.GetGameStateForObjectID(GroupRef.ObjectID));
    CurrentGroupLocation = Group.GetGroupMidpoint();
    
    ScaleVector = vect(64, 64, 64);
    ShapeManager = `SHAPEMGR;

    ShapeManager.DrawSphere(CurrentGroupLocation, ScaleVector, MakeLinearColor(0, 0.75, 0.75, 1));
    ShapeManager.DrawSphere(Location, ScaleVector, MakeLinearColor(0.75, 0, 0.75, 1));
    ShapeManager.DrawLine(CurrentGroupLocation, Location, 8, MakeLinearColor(0, 0.75, 0.75, 1));
}

