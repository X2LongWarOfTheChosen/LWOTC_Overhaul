class Override_TemplateMods_UpdateQuestItems extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateUpdateQuestItemsTemplate());

    return Templates;
}

// Update QuestItemTemplates to include the new _LW MissionTypes
static function Override_TemplateMods_Template CreateUpdateQuestItemsTemplate()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'UpdateQuestItems');

    // We need to modify grenade items and ability templates
    Template.ItemTemplateModFn = UpdateQuestItemsTemplate;
    return Template;
}

function UpdateQuestItemsTemplate(X2ItemTemplate Template, int Difficulty)
{
	local X2QuestItemTemplate QuestItemTemplate;
	local array<string> MissionTypes;
	local string MissionType;

	QuestItemTemplate = X2QuestItemTemplate(Template);
	if(QuestItemTemplate == none)
		return;
	
	MissionTypes = QuestItemTemplate.MissionType;
	foreach MissionTypes(MissionType)
	{
		QuestItemTemplate.MissionType.AddItem(MissionType $ "_LW");
	}
	if (QuestItemTemplate.RewardType.Length > 0)
		QuestItemTemplate.RewardType.AddItem('Reward_None');

	if (QuestItemTemplate.DataName == 'FlightDevice')
	{
		QuestItemTemplate.MissionSource.AddItem('MissionSource_RecoverFlightDevice'); // this will prevent FlightDevice from being selected for Activity-based missions - fixes TTP 335
	}
}