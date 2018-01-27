//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCooldown_Global.uc
//  AUTHOR:  Amineri / Pavonis Interactive
//	PURPOSE: Global cooldown mechanics for creation of alien activities
//---------------------------------------------------------------------------------------
class ActivityCooldown_Global extends ActivityCooldown_LWOTC;

simulated function ApplyCooldown(AlienActivity_XComGameState ActivityState, XComGameState NewGameState)
{
	local AlienActivity_XComGameState_Manager ActivityManager;
	local ActivityCooldownTimer Cooldown;

	foreach NewGameState.IterateByClassType(class'AlienActivity_XComGameState_Manager', ActivityManager)
	{
		break;
	}

	if(ActivityManager == none)
	{
		ActivityManager = class'AlienActivity_XComGameState_Manager'.static.GetAlienActivityManager();
		ActivityManager = AlienActivity_XComGameState_Manager(NewGameState.CreateStateObject(class'AlienActivity_XComGameState_Manager', ActivityManager.ObjectID));
		NewGameState.AddStateObject(ActivityManager);
	}
	Cooldown.ActivityName = ActivityState.GetMyTemplateName();
	Cooldown.CooldownDateTime = GetCooldownDateTime();

	ActivityManager.GlobalCooldowns.AddItem(Cooldown);
}