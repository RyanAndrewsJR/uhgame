class_name Projectile
extends Node2D
## The shared projectile piece (ABILITIES.md, Projectiles; AB7). Fired by an
## ability with Projectile.fire(): it flies straight at projectile_speed for
## cast_range, stops at walls (unless the ability ignores_walls) and hits
## enemies of its caster's team through HitPipeline.from_ability(), each
## unit once, nearest first, projectile_pierce + 1 of them at most. Every
## projectile of one cast shares one crit roll.
##
## It keeps flying if its caster dies. While the caster exists its hits are
## normal (kill credit, crits, on-hit). Once the caster is freed they use the
## damage snapshotted at fire and have no source (no kill credit, no crit, no
## on-hit), like a DoT whose applier is gone.
##
## Visual: the 3D view's ProjectileView, a bolt in the ability's icon_color
## (its 2D bolt went in the 3D pivot's cleanup C3). debug_draw shows each
## frame's swept capsule, on the 3D floor.
##
## ARCHETYPES AR1b: a basic attack swing can fire one too (fire_swing(): an
## enemy's RANGED string, the Mage's volley). It has no ability: its speed,
## range, width and colour are the swing's, its hit is
## HitPipeline.basic_attack() (deflectable by the swing's mark, tagged
## `projectile`), it stops at walls and on the first unit it meets.

## Walls stop the projectile's core, a small circle (not its full width), so
## a wide projectile doesn't catch on corners it visibly clears.
const WALL_RADIUS_PX := 2.0
## Every projectile in flight is in this group (enemy perception reads it).
const GROUP := &"projectiles"

@export var debug_draw: bool = false
## Its 3D look (3D.md, The generic view mechanism; the projectile is in the
## group view_source). null = the default bolt, tinted by the ability's
## icon_color.
@export var view_scene: PackedScene

var caster: Unit
var ability: Ability
var cast: CastContext
var team: Unit.Team
var direction: Vector2 = Vector2.RIGHT
var speed_px: float = 0.0
var range_px: float = 0.0
var half_width_px: float = 0.0
var crit_roll: HitContext.CritRoll
## AR1b: the swing it was fired by (fire_swing()), else null (an ability's).
var swing: AttackSwing
## Its colour when it has no ability (ProjectileView): the swing's.
var tint: Color = Color(0.8, 0.8, 0.8)

var _travelled: float = 0.0
var _hits_left: int = 1
var _hit_ids: Dictionary = {}           # instance id -> true (each unit once)
var _snapshot_damage: float = 0.0       # the caster-side damage at fire
var _last_from: Vector2
var _last_to: Vector2


## Fires the ability's projectiles from `origin` along `direction`:
## projectile_count of them, projectile_spread_deg apart, centered on it.
## Params are read once, with Ability.get_effect_param() (the cast's charge
## and other named inputs, and its conditional bonuses for the cast's
## target; CONVENTIONS.md pattern 6). They're added next to the caster
## (the room's Entities). Returns them.
static func fire(p_caster: Unit, p_ability: Ability, p_cast: CastContext, origin: Vector2, p_direction: Vector2) -> Array[Projectile]:
	var out: Array[Projectile] = []
	var count := maxi(floori(p_ability.get_effect_param(p_caster, &"projectile_count", p_cast)), 1)
	var spread := deg_to_rad(p_ability.get_effect_param(p_caster, &"projectile_spread_deg", p_cast))
	var roll := HitContext.CritRoll.new()   # one crit roll per cast
	for i in count:
		var p := Projectile.new()
		p._setup(p_caster, p_ability, p_cast, origin, p_direction.rotated((i - (count - 1) * 0.5) * spread), roll)
		p_caster.get_parent().add_child(p)
		p.reset_physics_interpolation()
		out.append(p)
	return out


## AR1b: fires one shot of a basic attack swing (`p_swing`'s Ranged group)
## from `origin` along `direction`, next to the attacker (the room's
## Entities). Its hit is a basic attack hit; with its attacker freed, the
## damage snapshotted now, no source and no crit.
static func fire_swing(p_caster: Unit, p_swing: AttackSwing, origin: Vector2, p_direction: Vector2) -> Projectile:
	var p := Projectile.new()
	p.caster = p_caster
	p.swing = p_swing
	p.team = p_caster.team
	p.direction = p_direction.normalized() if p_direction.length() > 0.001 else Vector2.RIGHT
	p.speed_px = Units.to_px(p_swing.projectile_speed)
	p.range_px = Units.to_px(p_swing.projectile_range)
	p.half_width_px = Units.to_px(p_swing.projectile_width) * 0.5
	p.tint = p_swing.projectile_color
	p._hits_left = 1
	p._snapshot_damage = p_swing.ad_ratio * p_caster.stats_component.get_stat(&"attack_damage")
	p.crit_roll = HitContext.CritRoll.new()
	p.position = origin
	p._last_from = origin
	p._last_to = origin
	p_caster.get_parent().add_child(p)
	p.reset_physics_interpolation()
	return p


func _setup(p_caster: Unit, p_ability: Ability, p_cast: CastContext, origin: Vector2, p_direction: Vector2, roll: HitContext.CritRoll) -> void:
	caster = p_caster
	ability = p_ability
	cast = p_cast
	team = p_caster.team
	direction = p_direction.normalized() if p_direction.length() > 0.001 else Vector2.RIGHT
	speed_px = Units.to_px(p_ability.get_effect_param(p_caster, &"projectile_speed", p_cast))
	range_px = Units.to_px(p_ability.get_effect_param(p_caster, &"cast_range", p_cast))
	half_width_px = Units.to_px(p_ability.get_effect_param(p_caster, &"projectile_width", p_cast)) * 0.5
	_hits_left = maxi(floori(p_ability.get_effect_param(p_caster, &"projectile_pierce", p_cast)), 0) + 1
	_snapshot_damage = p_ability.get_damage_against(p_caster, null, p_cast.charge)   # target terms come at the hit
	for e in p_cast.empowers:   # the cast's empowers, for hits after the caster is freed (AB10)
		_snapshot_damage += e.empower_base_damage + e.empower_ad_ratio * p_caster.stats_component.get_stat(&"attack_damage")
	crit_roll = roll
	position = origin
	_last_from = origin
	_last_to = origin


func _ready() -> void:
	add_to_group(&"view_source")   # its 3D look (3D.md); nothing happens without a WorldView
	add_to_group(GROUP)   # what enemies see in flight (ENEMIES_AI AI3)
	if debug_draw:
		visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # the debug sweep shows on the 3D floor (cleanup C2)


## How far it can still fly (px).
func get_range_left() -> float:
	return maxf(range_px - _travelled, 0.0)


## The scene of its 3D view (view_scene, or the default bolt). Loaded only when
## a WorldView asks.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/projectile_view.tscn")


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * minf(speed_px * delta, range_px - _travelled)
	var done := false
	if ability == null or not ability.ignores_walls:
		var wall := WorldQuery.shape_sweep(from, to, WALL_RADIUS_PX)
		if not wall.is_empty():
			to = wall.position
			done = true
	var targets := AbilityUtil.along_segment_of_team(get_tree(), team, from, to, half_width_px)
	targets.sort_custom(func(a: Unit, b: Unit) -> bool:
		return (a.global_position - from).dot(direction) < (b.global_position - from).dot(direction))
	for u in targets:
		if _hit_ids.has(u.get_instance_id()):
			continue
		_hit_ids[u.get_instance_id()] = true
		_hit(u)
		_hits_left -= 1
		if _hits_left <= 0:
			done = true
			break
	_last_from = from
	_last_to = to
	_travelled += from.distance_to(to)
	global_position = to
	if debug_draw:
		queue_redraw()
	if done or _travelled >= range_px - 0.001:
		queue_free()


## One hit: the normal ability hit while the caster exists; after it's freed,
## the snapshot with no source. A swing's shot: _hit_swing().
func _hit(target: Unit) -> void:
	if swing != null:
		_hit_swing(target)
		return
	var hit: HitContext
	if is_instance_valid(caster):
		hit = HitPipeline.from_ability(caster, ability, target, cast)
		hit.crit_roll = crit_roll
	else:
		hit = HitContext.new()
		hit.target = target
		hit.ability = ability
		hit.base_damage = _snapshot_damage + ability.get_scaling_damage(null, target, cast.charge)
		hit.damage_type = ability.damage_type
		hit.can_crit = false
		hit.proc_coefficient = ability.proc_coefficient
		hit.hit_sound = ability.hit_sound
		hit.chain_depth = cast.chain_depth
		hit.add_tag(&"ability")
		for t in ability.tags:
			hit.add_tag(t)
		if not cast.empowers.is_empty():   # the bonus is in the snapshot (AB10)
			for e in cast.empowers:
				for s in e.empower_statuses:
					if s is StatusEffect:
						hit.statuses.append(s)
			hit.add_tag(&"empowered")
	HitPipeline.resolve(hit)
	if not hit.blocked:
		VFX.impact(target.get_parent(), target.global_position, Color(ability.icon_color, 0.8), 24.0, 0.15)
		var source: Unit = caster if is_instance_valid(caster) else null
		ability.play_impact_vfx(source, target, hit)   # AB14: nothing while impact_vfx is empty


## AR1b: a swing's shot hits as a basic attack (the swing's ratio, knockback
## and feel; deflectable by its mark; tagged `projectile`); after its
## attacker is freed, the snapshot with no source and no crit. A deflected
## shot is absorbed (it stops here, blocked).
func _hit_swing(target: Unit) -> void:
	var hit: HitContext
	if is_instance_valid(caster):
		hit = HitPipeline.basic_attack(caster, target, swing)
		hit.crit_roll = crit_roll
	else:
		hit = HitContext.new()
		hit.target = target
		hit.base_damage = _snapshot_damage
		hit.damage_type = HitContext.DamageType.PHYSICAL
		hit.can_crit = false
		hit.proc_coefficient = swing.proc_coefficient
		hit.hit_sound = swing.hit_sound
		hit.add_tag(&"basic_attack")
	hit.deflectable = swing.deflectable
	hit.add_tag(&"projectile")
	HitPipeline.resolve(hit)
	if not hit.blocked:
		VFX.impact(target.get_parent(), target.global_position, Color(tint, 0.8), 24.0, 0.15)
		VFX.spawn_scene(swing.impact_vfx, target, target.global_position, direction.angle(), [caster if is_instance_valid(caster) else null, hit])


func _draw() -> void:
	if debug_draw:
		var a := to_local(_last_from)
		var b := to_local(_last_to)
		draw_line(a, b, Color(1, 1, 0, 0.6), half_width_px * 2.0)
		draw_circle(b, WALL_RADIUS_PX, Color(1, 0, 0, 0.8))
