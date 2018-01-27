//---------------------------------------------------------------------------------------
//  FILE:    X2LWActivityCreation_ProtectResearch.uc
//  AUTHOR:  JL / Pavonis Interactive
//	PURPOSE: This ensures conditions for creation, particularly how many PR activities 
//  are already out there, are checked only once per tick, to avoid spamming this activity
//---------------------------------------------------------------------------------------
class ActivityCreation_ProtectResearch extends ActivityCreation_LWOTC;

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

simulated function int GetNumActivitiesToCreate(XComGameState NewGameState)
{
	PrimaryRegions = FindValidRegions(NewGameState);

	NumActivitiesToCreate = PrimaryRegions.length;
	NumActivitiesToCreate = Min(NumActivitiesToCreate, 1);
	
	`LWTRACE ("Attempting to create ProtectResearch" @ NumActivitiesToCreate);

	return NumActivitiesToCreate;
}