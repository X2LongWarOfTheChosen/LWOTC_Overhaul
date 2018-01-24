//---------------------------------------------------------------------------------------
//  FILE:    SeqAct_InitMissionTimer
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: Initialize the mission timer for a mission. This sets the turn value in the 
//           XComGameState_UITimer to the appropriate default value for the current mission
//           type, creating the state if necessary. Note: In LWS Overhaul mod the XComGameState_UITimer
//           is the official owner of the mission timer, not kismet (but retains the "Ui"
//           name to minimize diffs against the originals). LW mission kismet must fetch
//           the current timer value from the state rather than keeping a private timer
//           value in a kismet variable.
//--------------------------------------------------------------------------------------- 

class Infiltration_SeqAct_InitializeMissionTimer extends SequenceAction config(LWOTC_Infiltration);

struct TimerMap
{
    var String MissionFamily;
    var int Turns;
};

// The config mapping of mission families to initial turn counts
var config array<TimerMap> InitialTurnCounts;
var config array<int> TimerDifficultyMod;
var config int VERY_LARGE_MAP_BONUS;
var config int LARGE_MAP_BONUS;

// The number of turns to return to Kismet (optional)
var private int Turns;

defaultproperties
{
    ObjCategory="LWOverhaul"
    ObjName="Initialize Mission Timer"
    bConvertedForReplaySystem=true
    bAutoActivateOutputLinks=true

    VariableLinks.Empty
    VariableLinks(0)=(ExpectedType=class'SeqVar_Int',LinkDesc="Turns",PropertyName=Turns, bWriteable=true)
}

// Activated()
event Activated()
{
    local XComGameState_BattleData BattleData;
    local XComGameState_UITimer UiTimer;
    local XComGameState NewGameState;
    local String MissionFamily;

    BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    MissionFamily = BattleData.MapData.ActiveMission.MissionFamily;  
	Turns = GetInitialTimer(MissionFamily);

	if (Turns == -1)
	{
		Turns = 10;
	}

    UiTimer = XComGameState_UITimer(`XCOMHISTORY.GetSingleGameStateObjectForClass(class 'XComGameState_UITimer', true));
	NewGameState = class 'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Initialize Timer");
	if (UiTimer == none)
		UiTimer = XComGameState_UITimer(NewGameState.CreateStateObject(class 'XComGameState_UITimer'));
	else
		UiTimer = XComGameState_UITimer(NewGameState.CreateStateObject(class 'XComGameState_UITimer', UiTimer.ObjectID));

	UiTimer.TimerValue = Turns;
	
	NewGameState.AddStateObject(UiTimer);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

// GetInitialTimer(string MissionFamily)
static function int GetInitialTimer(string MissionFamily)
{
	local int i, TurnValue;
	local XComGameState_BattleData BattleData;
	local string teststr;

	i = default.InitialTurnCounts.Find('MissionFamily', MissionFamily);
	if (i >= 0)
    {
        // Add 1 to the initial mission count in the INI because this is typically invoked from the mission start sequence, and
        // the first thing the begin turn sequence does is decrement the mission count.
        TurnValue = default.InitialTurnCounts[i].Turns + 1;
    }
    else
    {
        //`redscreen("Failed to locate an initial mission count value for " $ MissionFamily);
        return -1;
    }
	TurnValue += default.TimerDifficultyMod[`CAMPAIGNDIFFICULTYSETTING];

    BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	
	if (BattleData != none)
	{
		TestStr = BattleData.MapData.PlotMapName;
		//`LOG ("Map For Timer:" @ TestStr);
		if (class'UIUtilities_LWOTC'.default.FixedExitMissions.Find (BattleData.MapData.ActiveMission.MissionName) != -1 && class'UIUtilities_LWOTC'.default.EvacTimerMissions.Find (BattleData.MapData.ActiveMission.MissionName) != -1)
		{
			if (instr(TestStr, "vlgObj") != -1) 
			{	
				TurnValue += default.VERY_LARGE_MAP_BONUS;
			}
			else
			{
				if (instr(TestStr, "LgObj") != -1) 
				{
					TurnValue += default.LARGE_MAP_BONUS;
				}
			}
		}
	}	
	return TurnValue;
}
