//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWPodManager.uc
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: AI Pod management for LW Overhaul. Replaces the vanilla upthrottle/downthrottle code.
//---------------------------------------------------------------------------------------
class Pods_XComGameState_Manager extends XComGameState_BaseObject config(LWOTC_PodManager);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

// Specifies jobs to be added to a mission, and a set of constraints
// indicating which missions, when in the mission, and which pods should
// be eligible for it. 
struct PodJob
{
	var String FriendlyName;
	var int MinTurn;
	var int MaxTurn;
	var int MinSize;
	var int MaxSize;
	var int Priority;
	var int MinEngagedAI;
	var int MaxEngagedAI;
	var bool RequireGuardPods;
	var bool AllowGuardPods;
	var bool RequireYellowAlert;
	var bool AllowYellowAlert;
	var bool Unlimited;
	var float RandomChance;
	var Name LeaderAIJob;
	var Name EncounterID;
	var int Cooldown;
	var array<int> Difficulties;
	var array<String> IncludedMissionFamilies;
	var array<String> ExcludedMissionFamilies;

	var EAlertCause AlertCause;
	var String AlertTag;

	var array<Name> Jobs;

	// Private, written by the implementation
	var int ID;

	structdefaultproperties
	{
		MinTurn=-1
		MaxTurn=-1
		MinSize=-1
		MaxSize=-1
		MinEngagedAI=-1
		MaxEngagedAI=-1
		Cooldown=-1
		AlertCause=eAC_ThrottlingBeacon
		Priority=50
	}
};

struct JobCooldown
{
	var int Cooldown;
	var int ID;
};

// Job config values
var config array<PodJob> MissionJobs;

// Jobs that should be continued when yellow alert is entered
var config array<Name> JobsToMaintainAcrossAlert;

// Internal counter of the number of turns that have passed since
// xcom revealed.
var int TurnCount;

// The job system alert level: largest alert value any alien has had on this mission. Starts at 0 = green.
var int AlertLevel;

// A list of active jobs. This persists from turn to turn.
var array<StateObjectReference> ActiveJobs;

// A list of jobs that are on cooldown.
var array<JobCooldown> Cooldowns;

// Keep track of the last spot aliens have seen XCOM.
var Vector LastKnownXComPosition;
var int LastKnownXComPositionTurn;

static function Pods_XComGameState_Manager GetPodManager()
{
	local Pods_XComGameState_Manager PodMgr;

	foreach `XCOMHISTORY.IterateByClassType(class'Pods_XComGameState_Manager', PodMgr)
	{
		return PodMgr;
	}

	return none;
}

function XComGameState_AIPlayerData GetAIPlayerData()
{
	local XGAIPlayer AIPlayer;

	AIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
	return XComGameState_AIPlayerData(`XCOMHISTORY.GetGameStateForObjectID(AIPlayer.m_iDataID));
}

function OnBeginTacticalPlay(XComGameState NewGameState)
{
	local X2EventManager EventManager;
	local Object ThisObj;
	local XComGameState_Player PlayerState;

	super.OnBeginTacticalPlay(NewGameState);

	EventManager = `XEVENTMGR;
	ThisObj = self;
	PlayerState = `BATTLE.GetAIPlayerState();
	EventManager.RegisterForEvent(ThisObj, 'PlayerTurnBegun', OnAlienTurnBegin, ELD_OnStateSubmitted, , PlayerState);
	EventManager.RegisterForEvent(ThisObj, 'AbilityActivated', OnAbilityActivated, ELD_OnStateSubmitted);
}

function OnEndTacticalPlay(XComGameState NewGameState)
{
	local X2EventManager EventManager;
	local Object ThisObj;

	super.OnEndTacticalPlay(NewGameState);

	EventManager = `XEVENTMGR;
	ThisObj = self;
	EventManager.UnRegisterFromEvent(ThisObj, 'PlayerTurnBegun');
	EventManager.UnRegisterFromEvent(ThisObj, 'AbilityActivated');
}

// If we have a 'RedAlert' or 'YellowAlert' ability activation set the alert flag in the pod manager: we're on.
function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComGameState_Ability Ability;
	local XComGameState NewGameState;
	local Pods_XComGameState_Manager NewPodManager;
	local Object ThisObj;

	Ability = XComGameState_Ability(EventData);
	if (Ability != none && 
			(Ability.GetMyTemplateName() == 'RedAlert' || Ability.GetMyTemplateName() == 'YellowAlert') &&
			GameState != none && 
			XComGameStateContext_Ability(GameState.GetContext()).ResultContext.InterruptionStep <= 0)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("PodManager: RedAlert");
		NewPodManager = Pods_XComGameState_Manager(NewGameState.CreateStateObject(class'Pods_XComGameState_Manager', ObjectID));
		NewGameState.AddStateObject(NewPodManager);
		NewPodManager.AlertLevel = (Ability.GetMyTemplateName() == 'RedAlert') ? `ALERT_LEVEL_RED : `ALERT_LEVEL_YELLOW;
		`TACTICALRULES.SubmitGameState(NewGameState);

		// If we're in alert level red we no longer care about activated abilities
		if (NewPodManager.AlertLevel == `ALERT_LEVEL_RED)
		{
			ThisObj = self;
			`XEVENTMGR.UnRegisterFromEvent(ThisObj, 'AbilityActivated');
		}
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnAlienTurnBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local XComGameState_Player XComPlayer;
	local XComGameState NewGameState;
	local Pods_XComGameState_Manager NewPodManager;

	// If we're still concealed, don't take any actions yet.
	XComPlayer = class'Utilities_LWOTC'.static.FindPlayer(eTeam_XCom);

	// If we're in green alert (from mission start) check if we should immediately bump it to yellow
	// because of the mission type.
	if (AlertLevel == `ALERT_LEVEL_GREEN && `TACTICALMISSIONMGR.ActiveMission.AliensAlerted)
	{
		AlertLevel = `ALERT_LEVEL_YELLOW;
	}

	// Don't activate pod mechanics until both we have an alert activation on a pod
	// and the squad isn't concealed.
	if (AlertLevel == `ALERT_LEVEL_GREEN || XComPlayer.bSquadIsConcealed)
	{
		return ELR_NoInterrupt;
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Updating Pod Jobs");
	NewPodManager = Pods_XComGameState_Manager(NewGameState.CreateStateObject(class'Pods_XComGameState_Manager', ObjectID));
	NewGameState.AddStateObject(NewPodManager);
	NewPodManager.Update(NewGameState);

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`TACTICALRULES.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

function RemoveActiveJob(int JobIdx)
{
	local JobCooldown CD;
	local Pods_XComGameState_Job Job;

	Job = Pods_XComGameState_Job(`XCOMHISTORY.GetGameStateForObjectID(ActiveJobs[JobIdx].ObjectID));
	ActiveJobs.Remove(JobIdx, 1);

	if (MissionJobs[Job.ID].Cooldown > 0)
	{
		CD.ID = Job.ID;
		CD.Cooldown = MissionJobs[Job.ID].Cooldown;
		Cooldowns.AddItem(CD);
	}
}

// Randomize the elements of UnassignedPods
function ShuffleUnassignedPods(array<StateObjectReference> UnassignedPods)
{
	local int i;
	local int other;
	local StateObjectReference tmp;

	// Walk backwards from the end of the list to the 2nd element
	for (i = UnassignedPods.Length - 1; i > 0; --i)
	{
		// Pick a random position from 0 to i and swap element i with
		// the one chosen.
		other = `SYNC_RAND(i);
		tmp = UnassignedPods[i];
		UnassignedPods[i] = UnassignedPods[other];
		UnassignedPods[other] = tmp;
	}
}

// Main update loop of the pod manager. Must be called on a new state of this object
// added to the passed in game state.
function Update(XComGameState NewGameState)
{
	local XComGameState_AIPlayerData AIPlayerData;
	local int i;
	local array<StateObjectReference> UnassignedPods;
	local Pods_XComGameState_Job ActiveJob;

	AIPlayerData = GetAIPlayerData();

	// Refresh the pod manager's knowledge of XCOM
	UpdateXComPosition();

	// Update our cooldown timers
	UpdateCooldowns();

	// Refresh our unassigned and active job lists.
	UpdateJobList(AIPlayerData, UnassignedPods);

	// Shuffle the unassigned pods so we don't always assign jobs in a
	// particular order.
	ShuffleUnassignedPods(UnassignedPods);

	// Run the job assignment logic
	AssignPodJobs(AIPlayerData, UnassignedPods, NewGameState);

	// Run the active jobs
	for (i = 0; i < ActiveJobs.Length; ++i)
	{
		ActiveJob = Pods_XComGameState_Job(NewGameState.CreateStateObject(class'Pods_XComGameState_Job', ActiveJobs[i].ObjectID));
		NewGameState.AddStateObject(ActiveJob);
		if (!ActiveJob.ProcessTurn(self, NewGameState))
		{
			RemoveActiveJob(i);
			--i;
		}
	}

	if (AlertLevel == `ALERT_LEVEL_RED)
		++TurnCount;
}

function UpdateXComPosition()
{
	local XGAIPlayer AIPlayer;
	local array<Vector> EnemyLocations;
	local int i;
	local Vector Midpoint;
	local XComGameState_Unit Unit;
	local XComGameState_AIUnitData AIUnitData;
	local XComGameStateHistory History;
	local TTile BestLocation;
	local int BestTurn;
	local int AIUnitDataID;

	History = `XCOMHISTORY;

	// First, try to find anyone with eyes on XCom. Use the current visible enemies,
	// rather than the absolute knowledge alerts.
	AIPlayer = XGAIPlayer(`BATTLE.GetAIPlayer());
	EnemyLocations = AIPlayer.GetAllVisibleEnemyLocations();
	if (EnemyLocations.Length > 0)
	{
		for (i = 0; i < EnemyLocations.Length; ++i)
		{
			Midpoint += EnemyLocations[i];
		}

		MidPoint /= EnemyLocations.Length;
		LastKnownXComPosition = Midpoint;
		LastKnownXComPositionTurn = class'Utilities_LWOTC'.static.FindPlayer(eTeam_Alien).PlayerTurnCount;
	}
	else
	{
		// Nobody has eyes on XCOM. Try looking for the freshest
		// suspicious alert.
		BestTurn = -1;
		foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
		{
			AIUnitDataID = Unit.GetAIUnitDataID();
			if (AIUnitDataID > 0 && !Unit.IsDead())
			{
				AIUnitData = XComGameState_AIUnitData(History.GetGameStateForObjectID(AIUnitDataID));
				for (i = 0; i < AIUnitData.GetAlertCount(); ++i)
				{
					// We only care about particular alerts for this purpose.
					if (IsInterestingCause(AIUnitData.GetAlertData(i).AlertCause) &&
							AIUnitData.GetAlertData(i).PlayerTurn > BestTurn &&
							AIUnitData.GetAlertData(i).PlayerTurn > LastKnownXComPositionTurn)
					{
						BestTurn = AIUnitData.GetAlertData(i).PlayerTurn;
						BestLocation = AIUnitData.GetAlertData(i).AlertLocation;
					}
				}
			}
		}

		if (BestTurn >= 0)
		{
			LastKnownXComPosition = `XWORLD.GetPositionFromTileCoordinates(BestLocation);
			LastKnownXComPositionTurn = BestTurn;
		}
	}
}

// Only some alert causes are interesting for the purposes of pod jobs. They are used to identify
// where XCOM is when they aren't visible, so we only want alert causes that point at or near
// where xcom is, not those that won't have as useful information (e.g. detected corpses or alerted
// allies).
function bool IsInterestingCause(EAlertCause Cause)
{
	switch (Cause)
	{
		case eAC_MapwideAlert_Hostile:
		case eAC_XCOMAchievedObjective:
		case eAC_AlertedByCommLink:
		case eAC_DetectedSound:
		case eAC_SeesExplosion:
			return true;
	}

	return false;
}

function UpdateCooldowns()
{
	local int i;

	for (i = 0; i < Cooldowns.Length; ++i)
	{
		if (--Cooldowns[i].Cooldown <= 0)
		{
			Cooldowns.Remove(i, 1);
			--i;
		}
	}
}

function UpdateJobList(XComGameState_AIPlayerData AIPlayerData, out array<StateObjectReference> UnassignedPods)
{
	local XComGameStateHistory History;
	local XComGameState_AIGroup Group;
	local array<int> LivingMembers;
	local int i;
	local Pods_XComGameState_Job Job;

	History = `XCOMHISTORY;

	UnassignedPods.Length = 0;
	for (i = 0; i < AIPlayerData.GroupList.Length; ++i)
	{
		Group = XComGameState_AIGroup(History.GetGameStateForObjectID(AIPlayerData.GroupList[i].ObjectID));
		LivingMembers.Length = 0;
		Group.GetLivingMembers(LivingMembers);

		if (LivingMembers.Length == 0)
			continue;

		// Add any pod that is not engaged and doesn't have a job
		if (!Group.IsEngaged() && !PodHasJob(Group))
		{
			UnassignedPods.AddItem(Group.GetReference());
		}
	}

	// Go over all our existing jobs. Any job on a pod that has since activated should be removed,
	// and pods that have entered yellow alert need to be re-examined to see if they can keep this
	// job when entering yellow.
	for (i = 0; i < ActiveJobs.Length; ++i)
	{
		Job = Pods_XComGameState_Job(History.GetGameStateForObjectID(ActiveJobs[i].ObjectID));
		Group = XComGameState_AIGroup(History.GetGameStateForObjectID(Job.GroupRef.ObjectID));
		LivingMembers.Length = 0;
		Group.GetLivingMembers(LivingMembers);

		if (Group.IsEngaged() || LivingMembers.Length == 0)
		{
			// The group has either activated or died. Remove this job.
			RemoveActiveJob(i);
			--i;
		}
		else if (GroupIsInYellowAlert(Group) && Job.AlertLevelOnJobAssignment == 0 && JobsToMaintainAcrossAlert.Find(Job.GetMyTemplateName()) < 0)
		{
			// If this group has entered yellow alert and this job shouldn't persist
			// across alert, remove it.
			RemoveActiveJob(i);
			--i;
		}
	}
}

function bool GroupIsInYellowAlert(XComGameState_AIGroup Group)
{
	local array<int> LivingMembers;
	local XComGameState_Unit Member;
	local XComGameStateHistory History;
	local int j;

	History = `XCOMHISTORY;
	Group.GetLivingMembers(LivingMembers);

	for (j = 0; j < LivingMembers.Length; ++j)
	{
		Member = XComGameState_Unit(History.GetGameStateForObjectID(LivingMembers[j]));
		if (Member.GetCurrentStat(eStat_AlertLevel) == 1)
		{
			return true;
		}
	}

	return false;
}

function int JobSorter(PodJob JobA, PodJob JobB)
{
	if (JobA.Priority < JobB.Priority)
		return 1;
	return JobA.Priority > JobB.Priority ? -1 : 0;
}

function bool PodJobIsValidForMission(PodJob Job)
{
	local string MissionFamily;
	local XComGameState_AIPlayerData AIPlayerData;

	MissionFamily = class'Utilities_LWOTC'.static.CurrentMissionFamily();
	AIPlayerData = GetAIPlayerData();

	if (Job.ExcludedMissionFamilies.Find(MissionFamily) != -1)
	{
		`LWTrace("Excluding job due to mission family exclusion");
		return false;
	}

	if (Job.Difficulties.Length > 0 && Job.Difficulties.Find(`CAMPAIGNDIFFICULTYSETTING) == -1)
	{
		`LWTrace("Excluding job due to difficulty");
		return false;
	}

	if (Job.IncludedMissionFamilies.Length > 0 && Job.IncludedMissionFamilies.Find(MissionFamily) == -1)
	{
		`LWTrace("Excluding job due to mission family inclusion");
		return false;
	}

	if (Job.MinTurn >= 0 && TurnCount < Job.MinTurn)
	{
		`LWTrace("Excluding job due to min turn count");
		return false;
	}

	if (Job.MaxTurn >= 0 && TurnCount > Job.MaxTurn)
	{
		`LWTrace("Excluding job due to max turn count");
		return false;
	}

	if (Job.MinEngagedAI >= 0 && AIPlayerData.StatsData.NumEngagedAI < Job.MinEngagedAI)
	{
		`LWTrace("Excluding job due to minimum engaged AI count");
		return false;
	}

	if (Job.MaxEngagedAI >= 0 && AIPlayerData.StatsData.NumEngagedAI > Job.MaxEngagedAI)
	{
		`LWTrace("Excluding job due to maximum engaged AI count");
		return false;
	}

	return true;
}

function bool PodJobIsValidForPod(PodJob Job, XComGameState_AIGroup Group)
{
	local array<int> Members;
	local XComGameState_Unit Unit;
	local XComGameStateHistory History;
	local int i;
	local float Roll;

	`LWTrace("Considering job " $ Job.FriendlyName $ " for pod " $ Group.EncounterID);

	Group.GetLivingMembers(Members);
	if (Job.MinSize >= 0 && Members.Length < Job.MinSize)
	{
		`LWTrace("Excluding job due to minimum member count");
		return false;
	}

	if (Job.MaxSize >= 0 && Members.Length > Job.MaxSize)
	{
		`LWTrace("Excluding job due to maximum member count");
		return false;
	}

	// Handle guard pod requirement/allowance.
	if (Job.RequireGuardPods)
	{
		if (Group.MyEncounterZoneWidth >= 10)
		{
			`LWTrace("Excluding job due to guard pod requirement");
			return false;
		}
	} 
	else if (!Job.AllowGuardPods)
	{
		if (Group.MyEncounterZoneWidth < 10)
		{
			`LWTrace("Excluding job due to non-guard pod requirement");
			return false;
		}
	}

	// Handle yellow alert requirement/allowance.
	if (Job.RequireYellowAlert)
	{
		if (!GroupIsInYellowAlert(Group))
		{
			`LWTrace("Excluding job due to yellow alert requirement");
			return false;
		}
	}
	else if (!Job.AllowYellowAlert)
	{
		if (GroupIsInYellowAlert(Group))
		{
			`LWTrace("Excluding job due to green alert requirement");
			return false;
		}
	}

	if (AlertLevel == `ALERT_LEVEL_GREEN && !GroupIsInYellowAlert(Group))
	{
		// If we're still in green alert, don't assign any green pods jobs.
		`LWTrace("Excluding job due to global alert level green");
		return false;
	}

	if (Job.EncounterID != '' && Job.EncounterID != Group.EncounterID)
	{
		`LWTrace("Excluding job due to encounter ID requirement");
		return false;
	}

	if (Job.RandomChance > 0)
	{
		Roll = `SYNC_FRAND();
		if (Roll > Job.RandomChance)
		{
			`LWTrace("Excluding job due to random chance failure: Rolled " $ Roll $ " of " $ Job.RandomChance );
			return false;
		}
	}

	History = `XCOMHISTORY;
	for (i = 0; i < Members.Length; ++i)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(Members[i]));
		if (Unit.IsTurret())
		{
			return false;
		}
	}

	return true;
}

function Pods_JobTemplate GetJobTemplate(Name JobName)
{
	local X2StrategyElementTemplateManager TemplateManager;
	local Pods_JobTemplate Template;

	TemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Template = Pods_JobTemplate(TemplateManager.FindStrategyElementTemplate(JobName));
	if (Template == none)
	{
		`Redscreen("Failed to locate job template for job " $ JobName);
	}

	return Template;
}

function AssignJob(Name JobName, int JobID, XComGameState_AIGroup Group, XComGameState NewGameState)
{
	local Pods_JobTemplate Template;
	local Pods_XComGameState_Job JobObj;
	local EAlertCause AlertCause;
	local int LeaderID;
	local XComGameState_AIPlayerData AIPlayerData;
	local KismetPostedJob KismetJob;
	local int ExistingIndex;

	// Pick a job from the job struct.
	Template = GetJobTemplate(JobName); 
	JobObj = Template.CreateInstance(NewGameState);
	AlertCause = MissionJobs[JobID].AlertCause >= 0 ? MissionJobs[JobID].AlertCause : eAC_ThrottlingBeacon;
	JobObj.InitJob(Template, Group, JobID, AlertCause, MissionJobs[JobID].AlertTag, NewGameState);
	ActiveJobs.AddItem(JobObj.GetReference());

	// If this job has a leader AI job, assign it
	if (MissionJobs[JobID].LeaderAIJob != '')
	{
		LeaderID = Group.m_arrMembers[0].ObjectID;
		AIPlayerData = GetAIPlayerData();
		AIPlayerData = XComGameState_AIPlayerData(NewGameState.GetGameStateForObjectID(AIPlayerData.ObjectID));
		if (AIPlayerData == none)
		{
			AIPlayerData = GetAIPlayerData();
			AIPlayerData = XComGameState_AIPlayerData(NewGameState.CreateStateObject(class'XComGameState_AIPlayerData', AIPlayerData.ObjectID));
			NewGameState.AddStateObject(AIPlayerData);
		}

		// Remove existing job.
		ExistingIndex = AIPlayerData.KismetJobs.Find('TargetID', LeaderID);
		while (ExistingIndex != INDEX_NONE)
		{
			AIPlayerData.KismetJobs.Remove(ExistingIndex, 1);
			ExistingIndex = AIPlayerData.KismetJobs.Find('TargetID', LeaderID);
		}
		KismetJob.JobName = MissionJobs[JobID].LeaderAIJob;
		KismetJob.PriorityValue = 0;
		KismetJob.TargetID = LeaderID;
		AIPlayerData.KismetJobs.AddItem(KismetJob);
		AIPlayerData.CreateNewAIUnitGameStateIfNeeded(LeaderID, NewGameState);

		`AIJOBMGR.bJobListDirty = true;
	}

	`LWTrace("Assigned job " $ JobObj.GetMyTemplateName() $ " to group " $ Group);
}

function GetFilteredJobListForMission(out array<PodJob> JobList)
{
	local int i;

	for (i = 0; i < MissionJobs.Length; ++i)
	{
		// Skip any job on cooldown.
		if (Cooldowns.Find('ID', i) != -1)
		{
			`LWTrace("Excluding job due to cooldown");
			continue;
		}

		if (PodJobIsValidForMission(MissionJobs[i]))
		{
			JobList.AddItem(MissionJobs[i]);
			// Record the original index in the config MissionJobs array in
			// each of the jobs in the filtered list.
			JobList[JobList.Length-1].ID = i;
		}
	}
}

function RemoveActiveJobsFromJobList(out array<PodJob> JobList)
{
	local Pods_XComGameState_Job Job;
	local XComGameStateHistory History;
	local int i, j;

	History = `XCOMHISTORY;
	for (i = 0; i < ActiveJobs.Length; ++i)
	{
		Job = Pods_XComGameState_Job(History.GetGameStateForObjectID(ActiveJobs[i].ObjectID));

		for (j = 0; j < JobList.Length; ++j)
		{
			if (Job.ID == JobList[j].ID)
			{
				// Unlimited jobs can stay
				if (!JobList[j].Unlimited)
					JobList.Remove(j, 1);
				break;
			}
		}
	}
}

function AssignPodJobs(XComGameState_AIPlayerData AIPlayerData, array<StateObjectReference> UnassignedPods, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local array<PodJob> JobList;
	local XComGameState_AIGroup Group;
	local int JobListIdx;
	local PodJob Job;

	History = `XCOMHISTORY;

	// Gather the list of jobs that meet the current battle criteria
	GetFilteredJobListForMission(JobList);

	// Build up a list of debug 

	// Remove all jobs that are currently active.
	RemoveActiveJobsFromJobList(JobList);

	// If we have no valid jobs to assign, we're done.
	if (JobList.Length == 0)
	{
		`LWTrace("No valid jobs for mission");
		return;
	}

	// Sort it by job priority so we can assign jobs just by walking this
	// list in order.
	JobList.Sort(JobSorter);

	// Walk the list, finding a pod for each job until we either
	// run out of jobs or pods.
	while (JobList.Length > 0 && UnassignedPods.Length > 0)
	{
		Group = XComGameState_AIGroup(History.GetGameStateForObjectID(UnassignedPods[0].ObjectID));
		UnassignedPods.Remove(0, 1);

		for (JobListIdx = 0; JobListIdx < JobList.Length; ++JobListIdx)
		{
			if (PodJobIsValidForPod(JobList[JobListIdx], Group))
			{
				Job = JobList[JobListIdx];

				// We have a valid job. Assign it
				AssignJob(Job.Jobs[`SYNC_RAND(Job.Jobs.Length)], Job.ID, Group, NewGameState);
				if (!Job.Unlimited)
				{
					JobList.Remove(JobListIdx, 1);
					--JobListIdx;
				}
				break;
			}
		}
	}
}

// Remove any eAC_ThrottlingBeacon alerts from all members of this group.
function RemoveThrottlingBeacon(XComGameState_AIGroup Group, XComGameState NewGameState)
{
	local XComGameStateHistory History;
	local XComGameState_AIUnitData AIUnitData;
	local int AIUnitDataID;
	local XComGameState_Unit Unit;
	local array<int> LivingMembers;
	local int UnitIdx;
	local int AlertIdx;

	History = `XCOMHISTORY;
	Group.GetLivingMembers(LivingMembers);
	for (UnitIdx = 0; UnitIdx < LivingMembers.Length; ++UnitIdx)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(LivingMembers[UnitIdx]));
		AIUnitDataID = Unit.GetAIUnitDataID();
		if (AIUnitDataID > 0)
		{
			AIUnitData = XComGameState_AIUnitData(NewGameState.GetGameStateForObjectID(AIUnitDataID));
			if (AIUnitData == none)
			{
				AIUnitData = XComGameState_AIUnitData(NewGameState.CreateStateObject(class'XComGameState_AIUnitData', 
							AIUnitDataID));
				NewGameState.AddStateObject(AIUnitData);
			}
			for (AlertIdx = AIUnitData.GetAlertCount() - 1; AlertIdx >= 0; --AlertIdx)
			{
				if (AIUnitData.GetAlertData(AlertIdx).AlertCause == eAC_ThrottlingBeacon)
				{
					AIUnitData.RemoveAlertDataAtIndex(AlertIdx);
				}
			}
		}
	}
}

function Pods_XComGameState_Job FindPodJobForPod(XComGameState_AIGroup Group)
{
	local int i;
	local Pods_XComGameState_Job Job;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for (i = 0; i < ActiveJobs.Length; ++i)
	{
		Job = Pods_XComGameState_Job(History.GetGameStateForObjectID(ActiveJobs[i].ObjectID));
		if (Job != none && Job.GroupRef == Group.GetReference())
		{
			return Job;
		}
	}

	return none;
}

function Vector GetLastKnownXComPosition()
{
	return LastKnownXComPosition;
}

function bool PodHasJob(XComGameState_AIGroup Group)
{
	if (FindPodJobForPod(Group) != none)
		return true;

	return false;		
}

/// DEBUGGING

function DrawDebugLabel(Canvas kCanvas)
{
	local String DebugString;
	local XComGameStateHistory History;
	local XComGameState_AIGroup Group;
	local XComGameState_AIPlayerData AIPlayerData;
	local array<int> LivingMembers;
	local Pods_XComGameState_Job Job;
	local int i;
	local String JobName;
	local SimpleShapeManager ShapeManager;

	DebugString $= "========= LW Pod Jobs ==========\n";
	DebugString $= "================================\n";

	History = `XCOMHISTORY;
	AIPlayerData = GetAIPlayerData();
	ShapeManager = `SHAPEMGR;

	for (i = 0; i < AIPlayerData.GroupList.Length; ++i)
	{
		Group = XComGameState_AIGroup(History.GetGameStateForObjectID(AIPlayerData.GroupList[i].ObjectID));
		LivingMembers.Length = 0;
		Group.GetLivingMembers(LivingMembers);
		if (LivingMembers.Length == 0)
			continue;

		Job = FindPodJobForPod(Group);

		if (Job != none)
		{
			JobName = Job.GetDebugString();
			// Let the job draw interesting stuff.
			Job.DrawDebugLabel(kCanvas);
		}
		else if (Group.IsEngaged())
		{
			JobName = "(Engaged)";
		}
		else if (GroupIsInYellowAlert(Group))
		{
			JobName= "(Yellow Alert)";
		}
		else
		{
			JobName = "(No Job)";
		}

		DebugString $= string(Group.EncounterID);
		DebugString $= " [" $ Group.ObjectID $ "]: " $ JobName $ "\n";
	}

	if (Cooldowns.Length > 0)
	{
		DebugString $= "\n======= LW Job Cooldowns =======\n";
		DebugString $=   "================================\n";
		for (i = 0; i < Cooldowns.Length; ++i)
		{
			if (MissionJobs[Cooldowns[i].ID].FriendlyName != "")
			{
				DebugString $= MissionJobs[Cooldowns[i].ID].FriendlyName;
			}
			else
			{
				DebugString $= "Job #" $ Cooldowns[i].ID;
			}
			DebugString $= ": ";
			DebugString $= Cooldowns[i].Cooldown $ "\n";
		}
	}


	kCanvas.SetPos(10, 650);
	kCanvas.SetDrawColor(0, 0, 0, 125);
	kCanvas.DrawRect(400, 500);

	kCanvas.SetPos(15, 665);
	kCanvas.SetDrawColor(0, 255, 0);
	kCanvas.DrawText(DebugString);

	// Draw the last known xcom position
	ShapeManager.DrawSphere(LastKnownXComPosition, vect(64, 64, 64), MakeLinearColor(0.8, 0.8, 0.8, 1));
}

defaultproperties
{
	LastKnownXComPositionTurn=-1
}

