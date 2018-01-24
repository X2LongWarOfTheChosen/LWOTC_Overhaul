//--------------------------------------------------------------------------------------- 
//  FILE:    EvacZone_X2Condition_PlaceDelayedPermitted
//  AUTHOR:  Amineri (Pavonis Interactive)
//  PURPOSE: Disables the new PlaceDelayedEvacZone ability when the PlaceEvacZone ability
//           is globally disabled.
//---------------------------------------------------------------------------------------

class EvacZone_X2Condition_PlaceDelayedPermitted extends X2Condition;

event name CallMeetsCondition(XComGameState_BaseObject kTarget)
{
    local XComGameState_BattleData BattleData;

    BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
    if (BattleData.IsAbilityGloballyDisabled('PlaceEvacZone'))
    {
        return 'AA_AbilityUnavailable';
    }

    return 'AA_Success';
}
