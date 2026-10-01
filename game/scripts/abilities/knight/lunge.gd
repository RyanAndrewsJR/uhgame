extends Ability
## Knight E - Lunge: dash toward the target spot, passing through units and
## damaging every enemy you cut through.
## Toolkit pieces (ABILITIES AB11): MovementComponent.dash() for the move,
## AbilityUtil.along_segment() + line of sight for who's on the path,
## hit_units() for the hits (one crit roll, the cast's context: a free cast's
## hits keep their chain depth), play_hit_feel() for the shake (hit_shake in
## the .tres). The afterimages and impact VFX are Lunge's own.
## FLAG augment &"lunge_stuns" (ABILITIES AB-M): every enemy it hits is also
## stunned (status_stun for flag_stun_duration, as a status of the hit).
## FLAG &"lunge_tackle" (TALENTS T3, Tackle): the dash stops at the first
## enemy in its path (picked at the start, in sight, its edge reached), hits
## only it and stuns it for flag_tackle_stun_duration (still Staggered). With
## nobody in the path it dashes its full length and hits nothing.

const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")

## Dash speed in LoL units per second.
@export var dash_speed: float = 1400.0
## Width of the damaging path in LoL units.
@export var hit_width: float = 80.0
## Speed profile of the lunge (MOVEMENT.md F2). null = constant speed.
## The distance and the hit path don't depend on it.
@export var dash_curve: Curve
## With &"lunge_stuns": the stun's length in seconds (a scoped param;
## tenacity still shortens it).
@export var flag_stun_duration: float = 0.5
## With &"lunge_tackle": the stun on the one enemy it stops at, seconds.
@export var flag_tackle_stun_duration: float = 0.75


func execute(caster: Unit, ctx: CastContext) -> void:
	var start := caster.global_position
	var offset := ctx.point - start
	var dist := offset.length()
	if dist < 1.0:
		return
	var tackled: Unit = null
	if ctx.has_flag(&"lunge_tackle"):
		tackled = _first_in_path(caster, start, ctx.point)
		if tackled != null:
			# Stop with the Knight's edge touching the enemy's.
			var along := (tackled.global_position - start).dot(offset / dist)
			dist = clampf(along - tackled.get_gameplay_radius_px() - caster.get_gameplay_radius_px(), 0.0, dist)
			offset = offset / offset.length() * dist
	var speed := Units.to_px(dash_speed)
	var duration := dist / speed
	if dist >= 1.0:
		caster.movement.dash(offset / dist * speed, duration, true, dash_curve)

	# Afterimage trail while dashing.
	var frame := 0
	while caster.movement.is_displaced():
		if frame % 2 == 0:
			VFX.afterimage(caster, Color(icon_color, 0.45))
		frame += 1
		await caster.get_tree().physics_frame
		if not is_instance_valid(caster):
			return

	var end := caster.global_position
	var targets: Array[Unit] = []
	if ctx.has_flag(&"lunge_tackle"):
		if is_instance_valid(tackled) and tackled.is_alive():
			targets.append(tackled)
	else:
		targets = _in_path(caster, start, end)
	# One stun, the longest of the stun flags (lunge_stuns from an item, Tackle's).
	var stun_time := 0.0
	if ctx.has_flag(&"lunge_stuns"):
		stun_time = get_effect_param(caster, &"flag_stun_duration", ctx)
	if ctx.has_flag(&"lunge_tackle"):
		stun_time = maxf(stun_time, get_effect_param(caster, &"flag_tackle_stun_duration", ctx))
	var statuses: Array[StatusEffect] = []
	if stun_time > 0.0:
		var stun: StatusEffect = STATUS_STUN.duplicate()
		stun.duration = stun_time
		statuses.append(stun)
	var hits := hit_units(caster, targets, ctx, statuses)
	for u in targets:
		if is_instance_valid(u):
			VFX.impact(u.get_parent(), u.global_position, Color(icon_color, 0.8), 36.0, 0.2)
	play_hit_feel(hits)


## Every enemy along the path start -> end, hit_width wide, in sight from the
## nearest point of the path (COMBAT C7).
func _in_path(caster: Unit, start: Vector2, end: Vector2) -> Array[Unit]:
	var targets := AbilityUtil.along_segment(caster, start, end, Units.to_px(hit_width) * 0.5)
	if not ignores_walls:
		targets = targets.filter(func(u: Unit) -> bool:
			var near := Geometry2D.get_closest_point_to_segment(u.global_position, start, end)
			return WorldQuery.has_line_of_sight(near, u.global_position))
	return targets


## Tackle: the enemy in the path whose nearest point is closest to the start.
func _first_in_path(caster: Unit, start: Vector2, end: Vector2) -> Unit:
	var first: Unit = null
	var best := INF
	var dir := (end - start).normalized()
	for u in _in_path(caster, start, end):
		var along := (u.global_position - start).dot(dir)
		if along < best:
			best = along
			first = u
	return first
