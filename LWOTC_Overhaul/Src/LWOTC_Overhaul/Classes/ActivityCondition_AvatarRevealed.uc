//---------------------------------------------------------------------------------------
//  FILE:    ActivityCondition_AvatarRevealed
//  AUTHOR:  JohnnyLump / Pavonis Interactive
//	PURPOSE: Conditionals on whether Avatar project has been revealed to the player
//---------------------------------------------------------------------------------------
class ActivityCondition_AvatarRevealed extends ActivityCondition_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

simulated function bool MeetsCondition(ActivityCreation_LWOTC ActivityCreation, XComGameState NewGameState)
{
	`LWTrace ("ActivityCondition_AvatarRevealed" @ class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('S0_RevealAvatarProject'));
	
	if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('S0_RevealAvatarProject'))
		return true;

	return false;
}