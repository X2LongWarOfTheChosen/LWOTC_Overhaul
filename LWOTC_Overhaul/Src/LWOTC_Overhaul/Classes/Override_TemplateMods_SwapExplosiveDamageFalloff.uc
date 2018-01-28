class Override_TemplateMods_SwapExplosiveDamageFalloff extends X2StrategyElement config(LW_Overhaul);

`include(LWOTC_Overhaul\Src\LWOTC_Overhaul.uci)

struct DamageStep
{
	var float DistanceRatio;
	var float DamageRatio;
};

var config array<DamageStep> UnitDamageSteps;
var config array<DamageStep> EnvironmentDamageSteps;

var config array<name> ExplosiveFalloffAbility_Exclusions;
var config array<name> ExplosiveFalloffAbility_Inclusions;

static function array<X2DataTemplate> CreateTemplates()
{
    local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateSwapExplosiveDamageFalloff());

    return Templates;
}

// Replace the base game X2Effect_ApplyWeaponDamage with the new X2Effect_ApplyExplosiveFalloffWeaponDamage.
static function Override_TemplateMods_Template CreateSwapExplosiveDamageFalloff()
{
    local Override_TemplateMods_Template Template;

    `CREATE_X2TEMPLATE(class'Override_TemplateMods_Template', Template, 'SwapExplosiveDamageFalloff');

    // We need to modify grenade items and ability templates
    Template.ItemTemplateModFn = SwapExplosiveFalloffItem;
    Template.AbilityTemplateModFn = SwapExplosiveFalloffAbility;
    return Template;
}

function SwapExplosiveFalloffItem(X2ItemTemplate Template, int Difficulty)
{
	local X2GrenadeTemplate								GrenadeTemplate;
	local X2Effect_ApplyWeaponDamage					ThrownDamageEffect, LaunchedDamageEffect;
	local X2Effect_ApplyExplosiveFalloffWeaponDamage	FalloffDamageEffect;
	local X2Effect										GrenadeEffect;

	GrenadeTemplate = X2GrenadeTemplate(Template);
	if(GrenadeTemplate == none)
		return;
	foreach GrenadeTemplate.ThrownGrenadeEffects(GrenadeEffect)
	{
		ThrownDamageEffect = X2Effect_ApplyWeaponDamage(GrenadeEffect);
		if (ThrownDamageEffect != none)
		{
			break;
		}
	}
	foreach GrenadeTemplate.LaunchedGrenadeEffects(GrenadeEffect)
	{
		LaunchedDamageEffect = X2Effect_ApplyWeaponDamage(GrenadeEffect);
		if (LaunchedDamageEffect != none)
		{
			break;
		}
	}
	if (ThrownDamageEffect != none || LaunchedDamageEffect != none)
	{
		FalloffDamageEffect = new class'X2Effect_ApplyExplosiveFalloffWeaponDamage' (ThrownDamageEffect);

		//Falloff-specific settings
		FalloffDamageEffect.UnitDamageAbilityExclusions.AddItem('TandemWarheads'); // if has any of these abilities, skip any falloff
		FalloffDamageEffect.EnvironmentDamageAbilityExclusions.AddItem('CombatEngineer'); // if has any of these abilities, skip any falloff
		FalloffDamageEffect.UnitDamageSteps=default.UnitDamageSteps;
		FalloffDamageEffect.EnvironmentDamageSteps=default.EnvironmentDamageSteps;

		if (ThrownDamageEffect != none)
		{
			//`LOG("Swapping ThrownGrenade DamageEffect for item " $ Template.DataName $ ", Difficulty=" $ Difficulty);
			GrenadeTemplate.ThrownGrenadeEffects.RemoveItem(ThrownDamageEffect);
			GrenadeTemplate.ThrownGrenadeEffects.AddItem(FalloffDamageEffect);
		}
		if (LaunchedDamageEffect != none)
		{
			//`LOG("Swapping LaunchedGrenade DamageEffect for item " $ Template.DataName $ ", Difficulty=" $ Difficulty);
			GrenadeTemplate.LaunchedGrenadeEffects.RemoveItem(ThrownDamageEffect);
			GrenadeTemplate.LaunchedGrenadeEffects.AddItem(FalloffDamageEffect);
		}
	}
}


function SwapExplosiveFalloffAbility(X2AbilityTemplate Template, int Difficulty)
{
	local X2Effect_ApplyWeaponDamage					DamageEffect;
	local X2Effect_ApplyExplosiveFalloffWeaponDamage	FalloffDamageEffect;
	local X2Effect										MultiTargetEffect;

	//`LOG("Testing Ability " $ Template.DataName);

	foreach Template.AbilityMultiTargetEffects(MultiTargetEffect)
	{
		DamageEffect = X2Effect_ApplyWeaponDamage(MultiTargetEffect);
		if (DamageEffect != none)
		{
			break;
		}
	}
	if (DamageEffect != none && ValidExplosiveFalloffAbility(Template, DamageEffect))
	{
		FalloffDamageEffect = new class'X2Effect_ApplyExplosiveFalloffWeaponDamage' (DamageEffect);

		//Falloff-specific settings
		FalloffDamageEffect.UnitDamageAbilityExclusions.AddItem('TandemWarheads'); // if has any of these abilities, skip any falloff
		FalloffDamageEffect.EnvironmentDamageAbilityExclusions.AddItem('CombatEngineer'); // if has any of these abilities, skip any falloff
		FalloffDamageEffect.UnitDamageSteps=default.UnitDamageSteps;
		FalloffDamageEffect.EnvironmentDamageSteps=default.EnvironmentDamageSteps;

		//`LOG("Swapping AbilityMultiTargetEffects DamageEffect for item " $ Template.DataName);
		Template.AbilityMultiTargetEffects.RemoveItem(DamageEffect);
		Template.AbilityMultiTargetEffects.AddItem(FalloffDamageEffect);
	}
	else
	{
		//`LOG("Ability " $ Template.DataName $ " : Not Valid");
	}
}

function bool ValidExplosiveFalloffAbility(X2AbilityTemplate Template, X2Effect_ApplyWeaponDamage DamageEffect)
{
	//check specific exclusions
	if(default.ExplosiveFalloffAbility_Exclusions.Find(Template.DataName) != -1)
	{
		//`LOG("Ability " $ Template.DataName $ " : Explicitly Excluded");
		return false;
	}
	//exclude any psionic ability
	if(Template.AbilitySourceName == 'eAbilitySource_Psionic')
	{
		//`LOG("Ability " $ Template.DataName $ " : Excluded Because Psionic Source");
		return false;
	}
	//check for MultiTargetRadius
	if(Template.AbilityMultiTargetStyle.Class == class'X2AbilityMultiTarget_Radius')
	{
		if(DamageEffect.bExplosiveDamage)
			return true;
		//else
			//`LOG("Ability " $ Template.DataName $ " : Not bExplosiveDamage");

		if(DamageEffect.EffectDamageValue.DamageType == 'Explosion')
			return true;
		//else
			//`LOG("Ability " $ Template.DataName $ " : DamageType Not Explosion");

	}
	//check for specific inclusions
	if(default.ExplosiveFalloffAbility_Inclusions.Find(Template.DataName) != -1)
	{
		return true;
	}

	//`LOG("Ability " $ Template.DataName $ " : Excluded By Default");
	return false;
}