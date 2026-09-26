class_name HitPipeline
## The hit pipeline (COMBAT.md, Architecture). resolve() runs the attacker's
## stages, then hands the hit to the target's on_hit(), which runs the
## defender's stages:
##
##   base -> stat scaling (ratios) -> damage_increase -> crit
##   -> [target.on_hit] i-frames -> mitigation -> incoming_damage
##   -> shields (C10) -> health -> knockback, statuses (C9), events, on-hit
##
## Stages marked with a build step aren't built yet and pass damage through
## unchanged.

## Every crit roll uses it. Tests seed it for repeatable rolls.
static var crit_rng := RandomNumberGenerator.new()


## Runs the attacker's stages, then the target's on_hit(ctx). Returns ctx
## with its results filled in. A target without on_hit() gets nothing.
static func resolve(ctx: HitContext) -> HitContext:
	ctx.add_tag(HitContext.get_damage_type_tag(ctx.damage_type))   # before the scopes read it
	var scopes := get_hit_scopes(ctx)
	ctx.raw_damage = get_scaled_damage(ctx) * (1.0 + get_damage_increase(ctx, scopes))
	ctx.raw_damage = maxf(ctx.raw_damage, 0.0)
	roll_crit(ctx, scopes)
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


## The scopes a hit-scoped modifier can match on this hit (COMBAT C8):
## &"hit:<tag>" for each of its tags, &"target:<tag>" for each of the
## target's status tags (Unit.get_status_tags()).
static func get_hit_scopes(ctx: HitContext) -> Array[StringName]:
	var scopes: Array[StringName] = []
	for t in ctx.tags:
		scopes.append(StringName("hit:" + t))
	if is_instance_valid(ctx.target) and ctx.target.has_method(&"get_status_tags"):
		for t: StringName in ctx.target.get_status_tags():
			scopes.append(StringName("target:" + t))
	return scopes


## Stage 3: the source's damage_increase for this hit (its plain value plus
## the modifiers scoped to the hit's tags and the target's tags). 0.2 =
## +20%. No source = 0.
static func get_damage_increase(ctx: HitContext, scopes: Array[StringName]) -> float:
	if not is_instance_valid(ctx.source) or ctx.source.stats_component == null:
		return 0.0
	return ctx.source.stats_component.get_scoped_stat(&"damage_increase", scopes)


## Stage 4: rolls the source's crit_chance (scoped like damage_increase).
## A crit multiplies raw_damage by crit_damage (1.75 default), sets
## is_crit and adds the &"crit" tag. Hits with can_crit false (DoT ticks,
## procs, take_damage()) and hits without a source never crit.
static func roll_crit(ctx: HitContext, scopes: Array[StringName]) -> void:
	if not ctx.can_crit or not is_instance_valid(ctx.source) or ctx.source.stats_component == null:
		return
	var stats := ctx.source.stats_component
	var chance := stats.get_scoped_stat(&"crit_chance", scopes)
	if chance <= 0.0 or (chance < 1.0 and crit_rng.randf() >= chance):
		return
	ctx.is_crit = true
	ctx.add_tag(&"crit")
	ctx.raw_damage *= stats.get_scoped_stat(&"crit_damage", scopes)


## The source's on-hit effects for a hit that got through (COMBAT.md,
## Hits), called by the target's on_hit(). Only basic_attack and ability
## hits; never proc or dot hits (the loop guard). In order:
## - on_hit_damage x proc_coefficient: a MAGIC proc hit on the same target
##   (can't crit, no feel)
## - life_on_hit x proc_coefficient, plus life_steal x taken_damage on basic
##   attacks: heals the source (green number)
## - resource_on_hit x proc_coefficient: restores the source's resource
static func apply_on_hit(ctx: HitContext) -> void:
	if ctx.blocked or not is_instance_valid(ctx.source) or ctx.source.stats_component == null:
		return
	if ctx.has_tag(&"proc") or ctx.has_tag(&"dot"):
		return
	if not (ctx.has_tag(&"basic_attack") or ctx.has_tag(&"ability")):
		return
	var source := ctx.source
	var stats := source.stats_component
	var coefficient := ctx.proc_coefficient
	var extra := stats.get_stat(&"on_hit_damage") * coefficient
	if extra > 0.0 and is_instance_valid(ctx.target):
		resolve(make_proc(source, ctx.target, extra))
	if not source.is_alive():
		return
	var heal := stats.get_stat(&"life_on_hit") * coefficient
	if ctx.has_tag(&"basic_attack"):
		heal += stats.get_stat(&"life_steal") * ctx.taken_damage
	if heal > 0.0:
		source.heal(heal)
	var gain := stats.get_stat(&"resource_on_hit") * coefficient
	if gain > 0.0 and source.resource_pool != null:
		source.resource_pool.restore(gain)


## A proc hit (on-hit damage; later reaction damage): tagged &"proc" so it
## never triggers on-hit, can't crit, MAGIC (proposed, COMBAT.md), no feel.
static func make_proc(source: Unit, target: Node, amount: float) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = target
	ctx.base_damage = amount
	ctx.damage_type = HitContext.DamageType.MAGIC
	ctx.can_crit = false
	ctx.proc_coefficient = 0.0
	ctx.add_tag(&"proc")
	return ctx


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
