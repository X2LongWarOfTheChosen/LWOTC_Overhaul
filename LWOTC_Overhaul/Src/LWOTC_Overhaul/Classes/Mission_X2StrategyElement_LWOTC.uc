class Mission_X2StrategyElement_LWOTC extends Object config(LWOTC_Missions);

var localized string m_strInsufficientRebels;

struct MissionSettings_LW
{
    var name MissionOrFamilyName;
    var name AlertType;
    var string MissionSound;
    var name EventTrigger;
    var EMissionUIType MissionUIType;
    var String OverworldMeshPath;
    var String MissionIconPath;
    var String MissionImagePath;
    var bool RestrictsLiaison;
};

var config array<MissionSettings_LW> MissionSettings;

var config int ALIEN_BASE_DOOM_REMOVAL;
var config int SUPER_EMERGENCY_GLOBAL_VIG;

var protected name RebelMissionsJob;

//---------------------------------------------------------------------------------------
//      Careful, these objects should NEVER be modified - only constructed by default.
//      They can be freely used by any activity template, but NEVER modified by them.
var private ActivityCondition_NumberActivities	SingleActivityInRegion, SingleActivityInWorld, TwoActivitiesInWorld;
var private ActivityCondition_RegionStatus		ContactedAlienRegion, AnyAlienRegion;
var private ActivityCondition_ResearchFacility	ResearchFacilityInRegion;
var private ActivityCondition_AlertVigilance	AlertGreaterThanVigilance, AlertAtLeastEqualtoVigilance;
var private ActivityCondition_RestrictedActivity  GeneralOpsCondition;
var private ActivityCondition_RestrictedActivity  RetalOpsCondition;
var private ActivityCondition_RestrictedActivity  LiberationCondition;

static function ActivityCondition_NumberActivities GetSingleActivityInRegion()
{
	return default.SingleActivityInRegion;
}

static function ActivityCondition_NumberActivities GetSingleActivityInWorld()
{
	return default.SingleActivityInWorld;
}

static function ActivityCondition_NumberActivities GetTwoActivitiesInWorld()
{
	return default.TwoActivitiesInWorld;
}

static function ActivityCondition_RegionStatus GetContactedAlienRegion()
{
	return default.ContactedAlienRegion;
}

static function ActivityCondition_RegionStatus GetAnyAlienRegion()
{
	return default.AnyAlienRegion;
}

static function ActivityCondition_ResearchFacility GetResearchFacilityInRegion()
{
	return default.ResearchFacilityInRegion;
}

static function ActivityCondition_AlertVigilance GetAlertGreaterThanVigilance()
{
	return default.AlertGreaterThanVigilance;
}

static function ActivityCondition_AlertVigilance GetAlertAtLeastEqualtoVigilance()
{
	return default.AlertAtLeastEqualtoVigilance;
}

static function ActivityCondition_RestrictedActivity GetGeneralOpsCondition()
{
	return default.GeneralOpsCondition;
}

static function ActivityCondition_RestrictedActivity GetRetalOpsCondition()
{
	return default.RetalOpsCondition;;
}

static function ActivityCondition_RestrictedActivity GetLiberationCondition()
{
	return default.LiberationCondition;
}

defaultProperties
{
	RebelMissionsJob="Intel"

	Begin Object Class=ActivityCondition_NumberActivities Name=DefaultSingleActivityInRegion
		MaxActivitiesInRegion=1
	End Object
	SingleActivityInRegion = DefaultSingleActivityInRegion;

	Begin Object Class=ActivityCondition_NumberActivities Name=DefaultSingleActivityInWorld
		MaxActivitiesInWorld=1
	End Object
	SingleActivityInWorld = DefaultSingleActivityInWorld;

	Begin Object Class=ActivityCondition_NumberActivities Name=DefaultTwoActivitiesInWorld
		MaxActivitiesInWorld=2
	End Object
	TwoActivitiesInWorld = DefaultTwoActivitiesInWorld;

	Begin Object Class=ActivityCondition_RegionStatus Name=DefaultContactedAlienRegion
		bAllowInLiberated=false
		bAllowInContacted=true
		bAllowInUncontacted=false
	End Object
	ContactedAlienRegion = DefaultContactedAlienRegion;

	Begin Object Class=ActivityCondition_RegionStatus Name=DefaultAnyAlienRegion
		bAllowInLiberated=false
		bAllowInContacted=true
		bAllowInUncontacted=true
	End Object
	AnyAlienRegion = DefaultAnyAlienRegion;

	Begin Object Class=ActivityCondition_AlertVigilance Name=DefaultAlertGreaterThanVigilance
		MinAlertVigilanceDiff = -1
	End Object
	AlertGreaterThanVigilance=DefaultAlertGreaterThanVigilance

	Begin Object Class=ActivityCondition_AlertVigilance Name=DefaultAlertAtLeastEqualtoVigilance
		MinAlertVigilanceDiff = 0
	End Object
	AlertAtLeastEqualtoVigilance=DefaultAlertAtLeastEqualtoVigilance

	Begin Object Class=ActivityCondition_RestrictedActivity Name=DefaultGeneralOpsCondition
		CategoryNames(0)="GeneralOps"
		MaxRestricted_Category=2
	End Object
	GeneralOpsCondition = DefaultGeneralOpsCondition;

	Begin Object Class=ActivityCondition_RestrictedActivity Name=DefaultRetalOpsCondition
		CategoryNames(0)="RetalOps"
		MaxRestricted_Category=1
	End Object
	RetalOpsCondition = DefaultRetalOpsCondition;

	Begin Object Class=ActivityCondition_RestrictedActivity Name=DefaultLiberationCondition
		CategoryNames(0)="LiberationSequence"
		MaxRestricted_Category=1
	End Object
	LiberationCondition = DefaultLiberationCondition;
}