class Override_TemplateMods_HackRewards extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateModifyHackRewardsTemplate());

    return Templates;
}

static function Override_TemplateMods_Template CreateModifyHackRewardsTemplate()
{
	local Override_TemplateMods_Template Template;

	`CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'ModifyHackRewards');
	Template.HackRewardTemplateModFn = ModifyHackRewards;
	return Template;
}

function ModifyHackRewards (X2HackRewardTemplate Template, int Difficulty)
{
    local X2HackRewardTemplate HackRewardTemplate;

	if (Template != none)
	{
		HackRewardTemplate = Template;
		if (HackRewardTemplate.DataName == 'PriorityData_T1' || HackRewardTemplate.DataName == 'PriorityData_T2')
		{
			HackRewardTemplate.ApplyHackRewardFn = none;
		}
		if (HackRewardTemplate.DataName == 'ResistanceBroadcast_T1')
		{
			HackRewardTemplate.ApplyHackRewardFn = class'HackReward_Templates'.static.ApplyResistanceBroadcast_LW_1;
		} 
		if (HackRewardTemplate.DataName == 'ResistanceBroadcast_T2')
		{
			HackRewardTemplate.ApplyHackRewardFn = class'HackReward_Templates'.static.ApplyResistanceBroadcast_LW_2;
		}
	}
}