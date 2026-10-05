extends Ability
## The enemy ability library (ENEMIES_AI AI3d, Kits): a dash strike, the
## Charge (a gap-closer) and the Flurry (through its target). Through its cast
## time a band fills from the caster toward where its target stood and
## overshoot_px past it, up to length_px, cut short at a wall or a ledge (the
## telegraph); then it dashes along it (ghosted: through units, sliding on
## walls) and hits every champion its band touches, once each. Leaving the
## band answers it; a root stops it (it moves its caster: tagged `dash`).

## The longest dash, px.
@export var length_px: float = 192.0
## How far past the aimed point it goes, px (through its target).
@export var overshoot_px: float = 32.0
## The band's full width, px.
@export var width_px: float = 38.0
## How long the dash itself takes, s.
@export var dash_time: float = 0.3
## Enemy attack hitboxes are this much smaller than they look (COMBAT.md).
@export_range(0.0, 0.2) var enemy_hit_forgiveness: float = 0.10
@export var telegraph_color: Color = Telegraph.THREAT_COLOR

## The sweep that cuts the band at a wall or a ledge (the projectile's).
const WALL_SWEEP_RADIUS_PX := 2.0


func on_cast_started(caster: Unit, ctx: CastContext) -> void:
	ctx.point = get_dash_end(caster.global_position, ctx.point)   # where the dash will really end
	ctx.telegraph = Telegraph.line(caster, caster.global_position, ctx.point, width_px, cast_time, telegraph_color)


func execute(caster: Unit, ctx: CastContext) -> void:
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.finish()
	var from := caster.global_position
	var offset := ctx.point - from
	if offset.length() < 1.0:
		return
	var time := maxf(dash_time, 0.01)
	caster.movement.dash(offset / time, time)
	var half_width := width_px * 0.5 * (1.0 - enemy_hit_forgiveness)
	var already := {}   # instance id -> true: each champion is hit once
	var crit_roll := HitContext.CritRoll.new()   # one crit roll per cast
	var no_statuses: Array[StatusEffect] = []
	var hits: Array[HitContext] = []
	var last := from
	while true:
		await caster.get_tree().physics_frame
		if not is_instance_valid(caster) or not caster.is_alive():
			return
		var now := caster.global_position
		var fresh: Array[Unit] = []
		for u in filter_by_walls(now, AbilityUtil.along_segment(caster, last, now, half_width)):
			if not already.has(u.get_instance_id()):
				already[u.get_instance_id()] = true
				fresh.append(u)
		if not fresh.is_empty():
			hits.append_array(hit_units(caster, fresh, ctx, no_statuses, 1.0, crit_roll))
		last = now
		if not caster.movement.is_displaced():
			break
	play_hit_feel(hits)


## Where a dash from `from` aimed at `aim` ends: overshoot_px past the aim,
## at most length_px from `from`, short of the first wall or ledge on the way.
func get_dash_end(from: Vector2, aim: Vector2) -> Vector2:
	var offset := aim - from
	var dir := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
	var end := from + dir * minf(offset.length() + overshoot_px, length_px)
	var wall := WorldQuery.shape_sweep(from, end, WALL_SWEEP_RADIUS_PX, MovementComponent.GHOST_KEEP_MASK)
	return wall.position if not wall.is_empty() else end


## The band from where it stands to where the dash ends.
func get_effect_area(caster: Unit, ctx: CastContext) -> Dictionary:
	if ctx == null or not is_instance_valid(caster):
		return {"kind": &"none"}
	return {"kind": &"segment", "from": caster.global_position, "to": ctx.point, "half_width": width_px * 0.5}


## The aiming indicator (unused by enemies; kept for a player version).
func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var end := canvas.to_local(get_dash_end(caster.global_position, aim))
	var side := end.normalized().orthogonal() * width_px * 0.5
	canvas.draw_polyline(PackedVector2Array([side, end + side, end - side, -side, side]), Color(telegraph_color, 0.8), 1.0)
