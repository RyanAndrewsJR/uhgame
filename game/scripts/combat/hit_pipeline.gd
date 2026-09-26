class_name HitPipeline
## The hit pipeline (COMBAT.md, Architecture). resolve() runs the attacker's
## stages, then hands the hit to the target's on_hit(), which runs the
## defender's stages:
##
##   base -> stat scaling (ratios) -> conditional damage (C8) -> crit (C8)
##   -> [target.on_hit] i-frames -> mitigation -> incoming_damage (C8)
##   -> shields (C10) -> health -> knockback, statuses, events, on-hit (C8)
##
## Stages marked with a build step aren't built yet and pass damage through
## unchanged.


## Runs the attacker's stages, then the target's on_hit(ctx). Returns ctx
## with its results filled in. A target without on_hit() gets nothing.
static func resolve(ctx: HitContext) -> HitContext:
	ctx.raw_damage = get_scaled_damage(ctx)
	ctx.add_tag(HitContext.get_damage_type_tag(ctx.damage_type))
	if is_instance_valid(ctx.target) and ctx.target.has_method(&"on_hit"):
		ctx.target.on_hit(ctx)
	else:
		ctx.blocked = true
	return ctx


## A hit from an ability: its damage numbers (after scoped modifiers), damage
## type, proc coefficient, the ability tag and the ability's own tags. Pass
## it to resolve().
static func from_ability(caster: Unit, ability: Ability, target: Node) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = caster
	ctx.target = target
	ctx.ability = ability
	ctx.base_damage = ability.get_param(caster, &"base_damage")   # after scoped modifiers
	ctx.ad_ratio = ability.get_param(caster, &"ad_ratio")
	ctx.damage_type = ability.damage_type
	ctx.proc_coefficient = ability.proc_coefficient
	ctx.add_tag(&"ability")
	for t in ability.tags:   # the ability's own tags (STATS step 6)
		ctx.add_tag(t)
	return ctx


## A basic attack swing's hit: ad_ratio x attack_damage, PHYSICAL, the
## swing's knockback (away from the attacker) and feel. Pass it to resolve().
static func basic_attack(source: Unit, target: Node, swing: AttackSwing) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = target
	ctx.ad_ratio = swing.ad_ratio
	ctx.damage_type = HitContext.DamageType.PHYSICAL
	ctx.proc_coefficient = swing.proc_coefficient
	ctx.knockback_px = swing.knockback_px
	ctx.knockback_duration = swing.knockback_duration
	ctx.knockback_from = source.global_position
	ctx.feel = swing.feel
	ctx.add_tag(&"basic_attack")
	return ctx


## Stages 1-2: base_damage plus the ratios of the source's stats. No source
## (the environment) = base_damage only.
static func get_scaled_damage(ctx: HitContext) -> float:
	var amount := ctx.base_damage
	if is_instance_valid(ctx.source) and ctx.source.stats_component != null:
		var stats := ctx.source.stats_component
		if ctx.ad_ratio != 0.0:
			amount += ctx.ad_ratio * stats.get_stat(&"attack_damage")
		if ctx.ap_ratio != 0.0:
			amount += ctx.ap_ratio * stats.get_stat(&"ability_power")
	return maxf(amount, 0.0)


## Damage multiplier for a resistance (armor or magic_resist):
## 100 / (100 + r). Negative resistance uses LoL's 2 - 100 / (100 - r)
## (proposed, COMBAT.md Open questions), so it never divides by zero.
static func get_mitigation_multiplier(resistance: float) -> float:
	if resistance >= 0.0:
		return 100.0 / (100.0 + resistance)
	return 2.0 - 100.0 / (100.0 - resistance)


## Damage after the target's armor or magic_resist. TRUE ignores both.
static func mitigate(amount: float, type: HitContext.DamageType, target_stats: StatsComponent) -> float:
	if target_stats == null:
		return amount
	match type:
		HitContext.DamageType.PHYSICAL:
			return amount * get_mitigation_multiplier(target_stats.get_stat(&"armor"))
		HitContext.DamageType.MAGIC:
			return amount * get_mitigation_multiplier(target_stats.get_stat(&"magic_resist"))
	return amount
