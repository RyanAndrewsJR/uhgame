extends Ability
## Korsavil v2 Q, Blade Singer (CHAMPIONS.md and ABILITIES.md, Korsavil v2;
## built in CHAMPIONS K4). Not to be confused with the old Q, Bladesinger
## (bladesinger.gd, unassigned since K3).
## Part 0, the dagger (UNIT): a chain projectile (Projectile.fire_chain()) at
## the target, then up to projectile_bounces more enemies, never one twice,
## each hit 30 + 25% AD (the ability's own numbers). It flies on its own: the
## cast ends as it's thrown, so he can swing and move meanwhile, and the
## recast window opens at once. When it's done:
## - it hit hits_for_recast enemies or more (hits that got through): it lodges
##   in the last enemy it hit (lodged_status: 10% slow), whose position the
##   sequence keeps (CastContext.sequence) for the recast;
## - fewer: no recast; the sequence ends (AbilityComponent.end_recast()) and
##   the cooldown starts.
## Part 1, the lunge (recast_targeting SELF: the press needs no enemy under the
## cursor; only once the dagger is lodged, can_cast_custom()): a dash to the
## lodged enemy where it stands at the effect (or where it fell), stopping at
## its edge, at most lunge_max; then 40 + 65% AD (lunge_base_damage,
## lunge_ad_ratio) on it if it's within lunge_hit_reach. The lodged dagger
## comes out (the status goes). The lunge is a dash, so a root refuses its
## press ("Rooted"); the throw doesn't move him and isn't refused.
## The 6-stack sweep is a REPLACE variant (K5).

## The lodged dagger on the last enemy hit (status_lodged_dagger).
@export var lodged_status: StatusEffect
## Enemies the dagger must hit (hits that got through) for the recast.
@export var hits_for_recast: int = 3
## The lunge: speed (LoL units a second) and longest reach (LoL units).
@export var lunge_speed: float = 3000.0
@export var lunge_max: float = 1175.0
## The lunge's hit (Ryan: 40 + 65% AD). Scoped params like any export.
@export var lunge_base_damage: float = 40.0
@export var lunge_ad_ratio: float = 0.65
## The lunge hits only if he ends within this of the lodged enemy (LoL units,
## edge to edge): it walked off past lunge_max, or a root stopped the dash.
@export var lunge_hit_reach: float = 150.0

var _fail_text: String = ""


func execute(caster: Unit, ctx: CastContext) -> void:
	if ctx.part == 0:
		_throw(caster, ctx)
	else:
		await _lunge(caster, ctx)


## Part 0: the dagger flies on its own (not awaited); _follow() settles the
## recast when it's done.
func _throw(caster: Unit, ctx: CastContext) -> void:
	ctx.sequence[&"hits"] = 0
	if not is_instance_valid(ctx.target) or not ctx.target.is_alive() or not ctx.target.is_targetable():
		_end_after_cast(caster, ctx)   # its target went during the cast time: no dagger, no recast
		return
	var dagger := Projectile.fire_chain(caster, self, ctx, caster.global_position, ctx.target)
	_follow(caster, ctx, dagger)


## Ends the sequence once this cast is over (end_recast() leaves a sequence
## alone while its part is being cast).
func _end_after_cast(caster: Unit, ctx: CastContext) -> void:
	await caster.get_tree().physics_frame
	if is_instance_valid(caster) and caster.abilities != null:
		caster.abilities.end_recast(ctx.slot)


## Counts the dagger's hits that get through; when it's done, lodges it (or
## ends the sequence), then keeps the lodged enemy's position in the sequence
## until the sequence ends, and takes the dagger out then.
func _follow(caster: Unit, ctx: CastContext, dagger: Projectile) -> void:
	var state := {&"done": false, &"last": null, &"counted": {}}
	var on_hit := func(target: Unit, hit: HitContext) -> void:
		state[&"last"] = target
		if not hit.blocked:
			var counted: Dictionary = state[&"counted"]
			counted[target.get_instance_id()] = true
			ctx.sequence[&"hits"] = counted.size()
	var on_done := func() -> void:
		state[&"done"] = true
	dagger.hit_resolved.connect(on_hit)
	dagger.finished.connect(on_done)
	var tree := caster.get_tree()
	while not state[&"done"] and is_instance_valid(dagger):
		await tree.physics_frame
	if not is_instance_valid(caster) or caster.abilities == null:
		return
	var last: Variant = state[&"last"]
	if int(ctx.sequence.get(&"hits", 0)) < hits_for_recast or not is_instance_valid(last):
		caster.abilities.end_recast(ctx.slot)
		return
	var lodged := last as Unit
	ctx.sequence[&"lodged"] = lodged
	ctx.sequence[&"lodged_at"] = lodged.global_position
	if lodged.is_alive() and lodged.status_component != null and lodged_status != null:
		lodged.status_component.apply_status(lodged_status, caster)
	# While the recast can still come: follow the lodged enemy (where it fell, if
	# it dies), then take the dagger out when the sequence ends unused.
	while is_instance_valid(caster) and caster.abilities != null and caster.abilities.get_recast_part(ctx.slot) == 1 \
			and not ctx.sequence.get(&"used", false):
		if is_instance_valid(lodged) and lodged.is_alive():
			ctx.sequence[&"lodged_at"] = lodged.global_position
		await tree.physics_frame
	_unlodge(lodged)


## Part 1: the lunge to the lodged enemy, then its hit.
func _lunge(caster: Unit, ctx: CastContext) -> void:
	ctx.sequence[&"used"] = true
	var lodged: Unit = null
	var held: Variant = ctx.sequence.get(&"lodged")
	if is_instance_valid(held):
		lodged = held as Unit
	var alive := lodged != null and lodged.is_alive()
	var to: Vector2 = lodged.global_position if alive else ctx.sequence.get(&"lodged_at", caster.global_position)
	var start := caster.global_position
	var offset := to - start
	var dist := offset.length()
	if alive:   # stop at its edge, not inside it
		dist = maxf(dist - lodged.get_gameplay_radius_px() - caster.get_gameplay_radius_px(), 0.0)
	dist = minf(dist, Units.to_px(get_effect_param(caster, &"lunge_max", ctx)))
	if dist >= 1.0 and offset.length() > 0.001:
		var speed := Units.to_px(get_effect_param(caster, &"lunge_speed", ctx))
		caster.movement.dash(offset.normalized() * speed, dist / speed, true)
		while caster.movement.is_displaced():
			await caster.get_tree().physics_frame
			if not is_instance_valid(caster):
				return
	if lodged != null and lodged.is_alive() and lodged.is_targetable() \
			and caster.edge_distance_to(lodged) <= Units.to_px(get_effect_param(caster, &"lunge_hit_reach", ctx)):
		var hit := HitPipeline.from_ability(caster, self, lodged, ctx)
		hit.base_damage = get_effect_param(caster, &"lunge_base_damage", ctx, lodged)
		hit.ad_ratio = get_effect_param(caster, &"lunge_ad_ratio", ctx, lodged)
		hit.ap_ratio = 0.0
		HitPipeline.resolve(hit)
		if not hit.blocked and is_instance_valid(lodged):
			VFX.impact(lodged.get_parent(), lodged.global_position, Color(icon_color, 0.8), 36.0, 0.2)
		play_impact_vfx(caster, lodged, hit)
		var hits: Array[HitContext] = [hit]
		play_hit_feel(hits)
	_unlodge(lodged)


## Takes the dagger out of `lodged` (untyped: it may have been freed since).
func _unlodge(lodged: Variant) -> void:
	if not is_instance_valid(lodged) or lodged_status == null:
		return
	var unit := lodged as Unit
	if unit != null and unit.status_component != null:
		unit.status_component.remove_status(lodged_status.id)


## The recast needs the dagger lodged (it hit hits_for_recast enemies and is
## done flying), and the lunge is a dash: refused while he's rooted. The throw
## (part 0) has no check of its own.
func can_cast_custom(caster: Unit, ctx: CastContext) -> bool:
	if ctx == null or ctx.part == 0:
		return true
	if not ctx.sequence.has(&"lodged"):
		_fail_text = "Needs %d hits" % hits_for_recast
		return false
	if caster.movement != null and caster.movement.is_dash_blocked():
		_fail_text = AbilityComponent.ROOTED_FAIL_TEXT
		return false
	return true


func get_custom_fail_text() -> String:
	return _fail_text


## The throw lands on its target (a UNIT cast); the lunge on nobody but the
## lodged enemy, which an enemy can't dodge either.
func get_effect_area(caster: Unit, ctx: CastContext) -> Dictionary:
	if ctx == null or not is_instance_valid(caster) or ctx.part > 0:
		return {"kind": &"none"}
	return super.get_effect_area(caster, ctx)
