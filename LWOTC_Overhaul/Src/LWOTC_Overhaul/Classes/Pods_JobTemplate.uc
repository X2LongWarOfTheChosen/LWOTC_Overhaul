//---------------------------------------------------------------------------------------
//  FILE:    LWPodJobTemplate.uc
//  AUTHOR:  tracktwo (Pavonis Interactive)
//  PURPOSE: Template class for managing pod jobs. Allows new jobs to be defined and added
//           to the system.
//---------------------------------------------------------------------------------------
class Pods_JobTemplate extends X2StrategyElementTemplate config(LWOTC_PodManager);

var delegate<CreateInstanceFn> CreateInstance;
var delegate<GetNewDestinationFn> GetNewDestination;

delegate Pods_XComGameState_Job CreateInstanceFn(XComGameState NewGameState);
delegate Vector GetNewDestinationFn(Pods_XComGameState_Job Job, XComGameState NewGameState);

