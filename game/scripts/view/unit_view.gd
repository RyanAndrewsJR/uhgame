class_name UnitView
extends EntityView
## One unit's 3D look (3D.md, The generic view mechanism, UnitView). Shows:
## - the model: Unit.model_scene, or a placeholder capsule sized from
##   gameplay_radius and in the unit's model_color, with a nub showing its facing;
## - turning: smooth, toward the unit's facing (a Player's facing; an enemy's
##   walk, or the target it winds up at);
## - the base clips (idle, run, dash, hit, stun, death), named below;
## - the swing and cast clips named by the presentation hooks
##   (AttackSwing.swing_anim, Ability.cast_anim). They're positioned by the
##   swing's or cast's progress, so the strike lands on the hit at any speed;
## - the hit flash, the death (finishing after the unit is freed), the dash
##   afterimages (Dash afterimages, below) and the post-hit i-frame
##   blink;
## - placeholders without clips squash during a windup and stretch on the hit;
## - a blink (ABILITIES AB15): an afterimage where it started, a snap to where
##   it landed, a flash there.
## It never changes gameplay state.

const FLASH_SHADER := preload("res://scripts/view/flash_overlay.gdshader")

enum Phase { NONE, LEAD_BY_PROGRESS, LEAD_BY_TIME, FOLLOW, DASH }

@export_group("Turning")
## How fast the model turns to the unit's facing (exponential, per second; P0b).
@export var turn_rate: float = 20.0

@export_group("Base clips")
## The model's clips by role, as named in its AnimationPlayer (KayKit's names
## by default). A clip the model doesn't have is skipped.
@export var idle_clip: StringName = &"Idle"
@export var run_clip: StringName = &"Running_A"
@export var dash_clip: StringName = &"Dodge_Forward"
@export var hit_clip: StringName = &"Hit_A"
@export var stun_clip: StringName = &"Hit_B"
@export var death_clip: StringName = &"Death_A"
## The run clip plays at speed 1 at this speed (px/s; the Knight's 375 move
## speed is 120 px/s).
@export var run_speed_px: float = 120.0
## Blend time between base clips (s).
@export var base_blend: float = 0.12

@export_group("Swing and cast clips")
## Where a swing or cast clip starts, strikes and ends, as shares of its
## length. Start to strike plays up to the hit (a swing's windup, a cast's
## effect start), strike to end after it.
@export_range(0.0, 1.0) var action_start: float = 0.18
@export_range(0.0, 1.0) var action_strike: float = 0.42
@export_range(0.0, 1.0) var action_end: float = 0.85
## After a cast's effect starts, its clip's follow-through takes this long (s).
@export var cast_follow_through: float = 0.3
## A cast with no cast time strikes this long after it starts (s).
@export var instant_cast_lead: float = 0.08

@export_group("Airborne")
## A knock-up's apex over the ground (m; 3D.md, Airborne): view data, the sim
## never reads it.
@export var airborne_apex_m: float = 1.2
## The rise and fall over the knock-up's actual duration: 0 at both ends.
@export var airborne_curve: Curve = preload("res://data/curves/curve_airborne.tres")
## A leap's apex over the straight line from the ground at its start to the
## ground at its landing (m; LOOT L6, 3D.md, Leaps), on airborne_curve over
## the leap's time. High enough to clear a wall (the kit's are 2.2 m).
@export var leap_apex_m: float = 2.5

@export_group("Blink")
## A blink (ABILITIES AB15; 3D.md, 1e): how long the still afterimage it
## leaves where the model was takes to fade (s), in afterimage_color. 0 = none.
@export var blink_afterimage_fade: float = 0.25
## The model's flash where a blink arrives (the hit flash's overlay in this
## color). Alpha 0 = none.
@export var blink_flash_color: Color = Color(1, 1, 1, 1)

@export_group("Hit flash")
@export var flash_color: Color = Color(1, 1, 1, 1)
## How long the flash fades (s), and how bright it starts (0–1).
@export var flash_time: float = 0.12
@export_range(0.0, 1.0) var flash_strength: float = 0.8

@export_group("Poses")
## ENEMIES_AI AI1: an enemy's pose (its tell: Enemy.get_pose(), the look from
## its PoseSet) is blended in over this long (s): a capsule leans (+ toward
## its target), squashes and shows a rim; a model will play the pose's clip
## (the art pass).
@export var pose_blend_time: float = 0.08

@export_group("Death")
## How long the view stays after the unit is freed: its death clip, or the
## placeholder's squash (s).
@export var death_linger: float = 1.6
@export var placeholder_death_time: float = 0.35

@export_group("Placeholder")
## The capsule's height for a unit with no model_scene (m). 0 = 2.4 x its
## gameplay radius. Its color is the unit's model_color.
@export var capsule_height_m: float = 0.0

@export_group("Dash afterimages")
## Still copies of the model a dash leaves behind (a unit with a
## DashComponent), the first at the start point. 0 = none. They were
## MovementVFXComponent's numbers until the cleanup's C2; the same values.
@export_range(0, 10) var afterimage_count: int = 4
## Seconds between them.
@export var afterimage_interval: float = 0.03
## Seconds for each to fade out.
@export var afterimage_fade_time: float = 0.15
## Their color; alpha = the starting opacity.
@export var afterimage_color: Color = Color(0.55, 0.85, 1.0, 0.5)

## The unit (set at setup; may be freed before this view, see EntityView.sim).
var unit: Unit
## The model's height (m), for what sits over its head (status VFX).
var model_height_m: float = 1.0
## How high a knock-up lifts the model this frame (m; P9).
var air_height_m: float = 0.0

var _air_from := 0.0          # the arc's start height (a refresh mid-air starts from where it is)
var _air_total := 0.0         # the knock-up's length (s); 0 = not airborne
var _air_elapsed := 0.0
var _air_elapsed_prev := 0.0
var _air_left_prev := 0.0
# A leap (LOOT L6): its clock, and the ground's height at its two ends.
var _leap_total := 0.0        # the leap's length (s); 0 = not leaping
var _leap_elapsed := 0.0
var _leap_elapsed_prev := 0.0
var _leap_from_m := 0.0
var _leap_to_m := 0.0
var _leap_to_px := Vector2.INF

var _model: Node3D            # turns to the facing (physics tick, interpolated)
var _anim: AnimationPlayer    # null for a placeholder
var _body: Node3D             # the placeholder's squash pivot
var _geos: Array[GeometryInstance3D] = []
var _yaw := 0.0
var _flash := 0.0
var _dead := false
var _death_t := 0.0
var _blink_t := 0.0
var _base := &""
# The swing or cast clip in play.
var _phase := Phase.NONE
var _clip := &""
var _is_cast := false
var _hit_share := 0.5         # a swing's windup / duration: where its strike lands
var _progress_prev := 0.0
var _progress_cur := 0.0
var _time_left := 0.0
var _time_total := 0.0
# Placeholder motion.
var _windup_left := 0.0
var _windup_total := 0.0
var _stretch := 0.0
var _bob := 0.0
var _face_px := Vector2.INF   # the target an enemy winds up at
# Dash afterimages.
var _ghosts_left := 0
var _ghost_timer := 0.0
var _ghost_pool: Array[Dictionary] = []   # a rigged model's: {"root", "anim", "material", "tween"}
var _ghost_next := 0
var _model_root: Node3D       # the model's own root (scaled), under _model
var _overlay: ShaderMaterial  # the flash overlay (hit flash, blink flash)
var _blink_snap := false      # a blink happened: snap and flash at the next sync
var _pose_lean := 0.0         # degrees, blended toward the pose's look (ENEMIES_AI AI1)
var _pose_squash := 1.0
var _pose_rim := Color(1, 1, 1, 0)
var _pose_pulse_t := 0.0
var _rim_shown := Color(1, 1, 1, 0)   # what the overlay's rim channel holds now


func _on_setup() -> void:
	unit = sim as Unit
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	if unit.model_scene != null:
		_build_model(unit.model_scene)
		_build_ghost_pool(unit.model_scene)
	else:
		_build_placeholder()
	var overlay := ShaderMaterial.new()
	overlay.shader = FLASH_SHADER
	overlay.set_shader_parameter(&"flash_color", flash_color)
	for geo: GeometryInstance3D in _geos:
		geo.material_overlay = overlay
	_overlay = overlay
	_connect_signals()
	var f := _facing()
	_yaw = atan2(f.x, f.y) if f != Vector2.ZERO else 0.0
	_model.rotation.y = _yaw
	_play_base(idle_clip)


func _connect_signals() -> void:
	unit.damaged.connect(_on_damaged)
	unit.died.connect(_on_died)
	unit.attack.swing_started.connect(_on_swing_started)
	unit.attack.swing_cancelled.connect(_end_action)
	unit.attack.windup_started.connect(_on_windup_started)
	unit.attack.attack_landed.connect(_on_attack_landed)
	unit.attack.windup_cancelled.connect(_on_windup_cancelled)
	unit.movement.blinked.connect(_on_blinked)
	if unit.abilities:
		unit.abilities.cast_started.connect(_on_cast_started)
		unit.abilities.cast_finished.connect(_on_cast_finished)
		unit.abilities.cast_cancelled.connect(_on_cast_cancelled)
	var dash := unit.get_node_or_null(^"DashComponent") as DashComponent
	if dash:
		dash.dash_started.connect(_on_dash_started.bind(dash))
		dash.dash_ended.connect(_on_dash_ended)


# --- Build ----------------------------------------------------------------------------

func _build_model(scene: PackedScene) -> void:
	var model := scene.instantiate() as Node3D
	_model.add_child(model)
	_model_root = model
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for clip: StringName in [idle_clip, run_clip, stun_clip]:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		_geos.append(node as GeometryInstance3D)
	model_height_m = _measure_height(model)


## The model's top above its feet (m): its visible meshes' bounds in the model's
## pose at load, in this view's space.
func _measure_height(model: Node3D) -> float:
	var top := 0.0
	var to_view := global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.skin != null:
			continue   # skinned meshes' boxes are their bind pose; the attached parts (helmet, weapon) show the pose
		top = maxf(top, ((to_view * mi.global_transform) * mi.get_aabb()).end.y)
	return top if top > 0.1 else 1.8


func _build_placeholder() -> void:
	var radius := Units.px_to_m(unit.get_gameplay_radius_px())
	var height := capsule_height_m if capsule_height_m > 0.0 else radius * 2.4
	height = maxf(height, radius * 2.0)
	var color := _body_color()
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	capsule.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "Capsule"
	mesh.mesh = capsule
	mesh.position.y = height * 0.5
	_body.add_child(mesh)
	# A nub at chest height pointing along the facing (+z: the model's front).
	var nub_mesh := BoxMesh.new()
	nub_mesh.size = Vector3(radius * 0.35, radius * 0.25, radius * 0.6)
	var nub_material := StandardMaterial3D.new()
	nub_material.albedo_color = color.darkened(0.45)
	nub_mesh.material = nub_material
	var nub := MeshInstance3D.new()
	nub.name = "Nub"
	nub.mesh = nub_mesh
	nub.position = Vector3(0.0, height * 0.62, radius * 0.95)
	_body.add_child(nub)
	_geos.append(mesh)
	_geos.append(nub)
	model_height_m = height


## The capsule's color: the unit's model_color times its tint (modulate, the
## sandbox dummies'). It was the 2D body's biggest polygon until the
## cleanup's C2.
func _body_color() -> Color:
	return unit.model_color * unit.modulate


# --- Sync (physics tick, after the sim) -----------------------------------------------

func _on_sync() -> void:
	if _dead:
		return
	var f := _facing()
	if f != Vector2.ZERO:
		_yaw = lerp_angle(_yaw, atan2(f.x, f.y), 1.0 - exp(-turn_rate * get_physics_process_delta_time()))
	_model.rotation.y = _yaw   # a glTF model faces +z: a sim facing (x, y) is the yaw atan2(x, y)
	_progress_prev = _progress_cur
	_progress_cur = _sim_progress()
	_sync_airborne()
	if _blink_snap:
		# AB15: the view stands where the blink landed now (sync() just set
		# it): no slide from the start, and the model flashes there.
		_blink_snap = false
		reset_physics_interpolation()
		if blink_flash_color.a > 0.0:
			_overlay.set_shader_parameter(&"flash_color", blink_flash_color)
			_flash = 1.0
			_set_flash(flash_strength)


## A blink (ABILITIES AB15; 3D.md, 1e): a still afterimage where the model is
## drawn now (the blink's start: the view hasn't followed yet), and at the next
## sync the view snaps to the landing, its ground height with it (onto a
## plateau at once, not rising at ground_speed_m_per_s), and the model flashes.
func _on_blinked(_from: Vector2, _to: Vector2) -> void:
	if _dead:
		return
	if blink_afterimage_fade > 0.0:
		_spawn_ghost(afterimage_color, blink_afterimage_fade)
	_blink_snap = true
	_ground_m = INF   # the next ground read snaps


## Where the view stands: the ground under the unit, except during a leap
## (LOOT L6): the straight line from the ground at its start (where the view
## stood) to the ground at its landing (a plateau's top, the floor below a
## cliff), by the leap's time. The arc over that line is the model's
## (_update_airborne()). The ground followed underneath is set to the line,
## so the view lands without a step.
func get_height_m() -> float:
	var ground := ground_height_m()
	var movement := unit.movement if is_instance_valid(unit) else null
	if movement == null or not movement.is_leaping() or world_view == null:
		if _leap_total > 0.0 and _leap_elapsed_prev < _leap_total:
			# The landing tick (the sim landed during it) and the one after:
			# the line's end and the arc's last stretch to 0 (drawn a tick
			# behind, interpolated), so the model touches down with the sim.
			_leap_elapsed_prev = _leap_elapsed
			_leap_elapsed = _leap_total
			_ground_m = _leap_to_m
			return _leap_to_m
		_leap_total = 0.0
		_leap_to_px = Vector2.INF
		return ground
	if _leap_total <= 0.0 or movement.get_leap_to() != _leap_to_px:
		# A new leap: from where the view stands now.
		_leap_from_m = position.y if _leap_total <= 0.0 else get_leap_base_m()
		_leap_to_px = movement.get_leap_to()
		_leap_to_m = world_view.ground_height_m(_leap_to_px)
		_leap_total = movement.get_leap_duration()
		_leap_elapsed = 0.0
		_leap_elapsed_prev = 0.0
	else:
		_leap_elapsed_prev = _leap_elapsed
	_leap_elapsed = clampf(_leap_total - movement.get_leap_time_left(), 0.0, _leap_total)
	var base := get_leap_base_m()
	_ground_m = base
	return base


## The leap's straight line at its current time (m): the start's ground to
## the landing's.
func get_leap_base_m() -> float:
	var t := clampf(_leap_elapsed / _leap_total, 0.0, 1.0) if _leap_total > 0.0 else 1.0
	return lerpf(_leap_from_m, _leap_to_m, t)


## The knock-up's clock from the sim (P9): the arc runs over the status's
## actual duration. A new knock-up, or one refreshed to a longer time mid-air,
## starts a new arc from the model's current height.
func _sync_airborne() -> void:
	var status := unit.status_component
	var left := status.get_time_left(&"airborne") if status and status.has_status(&"airborne") else 0.0
	if left > 0.0:
		if _air_total <= 0.0 or left > _air_left_prev + 0.0001:
			_air_from = air_height_m
			_air_total = left
			_air_elapsed = 0.0
			_air_elapsed_prev = 0.0
		else:
			_air_elapsed_prev = _air_elapsed
			_air_elapsed = _air_total - left
	else:
		_air_total = 0.0
	_air_left_prev = left


## A swing's or a cast's progress now (0 when nothing runs).
func _sim_progress() -> float:
	if _phase != Phase.LEAD_BY_PROGRESS:
		return 0.0
	if _is_cast:
		return unit.abilities.get_cast_progress() if unit.abilities and unit.abilities.casting else 1.0
	return unit.attack.get_swing_progress() if unit.attack.is_swinging() else 1.0


func _facing() -> Vector2:
	var facing: Variant = sim.get(&"facing")
	if facing is Vector2:
		return facing
	# An enemy whose brain runs faces its target, even while it strafes
	# around it (ENEMIES_AI AI1: Enemy.get_face_point()).
	if sim.has_method(&"get_face_point"):
		var point: Vector2 = sim.call(&"get_face_point")
		var to_point := point - sim.global_position if point != Vector2.INF else Vector2.ZERO
		if to_point.length() > 0.01:
			return to_point.normalized()
	if _face_px != Vector2.INF and (_windup_left > 0.0 or (unit.abilities and unit.abilities.casting)):
		return (_face_px - sim.global_position).normalized()
	var v := (sim as CharacterBody2D).velocity
	return v.normalized() if v.length() > 5.0 else Vector2.ZERO


# --- Frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta / maxf(flash_time, 0.001), 0.0)
		_set_flash(_flash * flash_strength)
	if _dead:
		_update_death(delta)
		return
	if is_sim_gone():
		return
	_update_airborne(delta)
	_update_blink(delta)
	_update_ghosts(delta)
	_update_pose(delta)
	if _anim:
		_update_clips(delta)
	else:
		_update_placeholder(delta)


## The arc this frame: the knock-up's time between the last two ticks
## (interpolated, so it doesn't step at 60 Hz on a faster screen). A knock-up
## that ends early (a death) lands quickly.
func _update_airborne(delta: float) -> void:
	if _leap_total > 0.0:
		# A leap (LOOT L6): the arc over its line, by its time between ticks.
		var leap_elapsed := lerpf(_leap_elapsed_prev, _leap_elapsed, Engine.get_physics_interpolation_fraction())
		var lt := clampf(leap_elapsed / _leap_total, 0.0, 1.0)
		air_height_m = leap_apex_m * (airborne_curve.sample(lt) if airborne_curve else 4.0 * lt * (1.0 - lt))
	elif _air_total > 0.0:
		var elapsed := lerpf(_air_elapsed_prev, _air_elapsed, Engine.get_physics_interpolation_fraction())
		var t := clampf(elapsed / _air_total, 0.0, 1.0)
		var arc := airborne_curve.sample(t) if airborne_curve else 4.0 * t * (1.0 - t)
		air_height_m = lerpf(_air_from, 0.0, t) + airborne_apex_m * arc
	else:
		air_height_m = move_toward(air_height_m, 0.0, delta * 8.0)
	_model.position.y = air_height_m


func _set_flash(amount: float) -> void:
	for geo: GeometryInstance3D in _geos:
		if is_instance_valid(geo):
			geo.set_instance_shader_parameter(&"flash", amount)


## The post-hit i-frames blink the model (Player.hit_iframes_blink_period; the 2D body blinked the same way until the cleanup's C3).
func _update_blink(delta: float) -> void:
	if unit.has_invulnerability(Unit.HIT_IFRAMES_ID):
		var period: float = sim.get(&"hit_iframes_blink_period") if sim.get(&"hit_iframes_blink_period") != null else 0.1
		_blink_t += delta
		_model.visible = fmod(_blink_t, period) < period * 0.6
	elif _blink_t > 0.0:
		_blink_t = 0.0
		_model.visible = true


func _update_clips(delta: float) -> void:
	match _phase:
		Phase.LEAD_BY_PROGRESS:
			var p := lerpf(_progress_prev, _progress_cur, Engine.get_physics_interpolation_fraction())
			if _is_cast:
				if _progress_cur >= 1.0:
					_start_follow(cast_follow_through)
					return
				_seek(lerpf(action_start, action_strike, p))
			else:
				if _progress_cur >= 1.0:
					_end_action()
					return
				_seek(action_clip_share(p, _hit_share, action_start, action_strike, action_end))
			return
		Phase.LEAD_BY_TIME:
			_time_left -= delta
			if _time_left <= 0.0:
				_start_follow(cast_follow_through)
				return
			_seek(lerpf(action_start, action_strike, 1.0 - _time_left / _time_total))
			return
		Phase.FOLLOW:
			_time_left = maxf(_time_left - delta, 0.0)
			# A leaping cast (LOOT L6) holds its clip's last frame until it lands.
			if _time_left <= 0.0 and not unit.movement.is_leaping():
				_end_action()
				return
			_seek(lerpf(action_strike, action_end, 1.0 - _time_left / _time_total))
			return
		Phase.DASH:
			return
	_update_base_clip()


## Where a swing clip stands (a share of its length) at swing progress `p`:
## start to strike until the hit (`hit_share` of the swing: its windup over its
## duration), strike to end after, so the strike frame lands on the hit at any
## attack speed.
static func action_clip_share(p: float, hit_share: float, start: float, strike: float, end: float) -> float:
	if hit_share <= 0.0:
		return lerpf(strike, end, clampf(p, 0.0, 1.0))
	if p <= hit_share:
		return lerpf(start, strike, clampf(p / hit_share, 0.0, 1.0))
	return lerpf(strike, end, clampf((p - hit_share) / maxf(1.0 - hit_share, 0.0001), 0.0, 1.0))


func _seek(share: float) -> void:
	if _anim.assigned_animation != _clip:
		return
	_anim.seek(share * _anim.get_animation(_clip).length, true)


func _update_base_clip() -> void:
	var speed := 1.0
	var clip := idle_clip
	if unit.is_stunned() or (unit.movement.is_airborne() and not unit.movement.is_leaping()):   # knocked up: the stun pose (P9); a leap isn't (LOOT L6)
		clip = stun_clip
	elif unit.movement.is_displaced():
		clip = hit_clip
	elif (sim as CharacterBody2D).velocity.length() > 5.0:
		clip = run_clip
		speed = maxf((sim as CharacterBody2D).velocity.length() / maxf(run_speed_px, 1.0), 0.6)
	_play_base(clip, speed)


func _play_base(clip: StringName, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.speed_scale = speed
	if _base == clip and _anim.current_animation == clip:
		return
	_base = clip
	_anim.play(clip, base_blend)


# --- Swings and casts -------------------------------------------------------------------

func _start_action(clip: StringName, is_cast: bool) -> bool:
	if _anim == null or _dead or clip == &"" or not _anim.has_animation(clip):
		return false
	_clip = clip
	_is_cast = is_cast
	_base = &""
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.0, 0.0)   # speed 0: the view positions it
	_anim.seek(action_start * _anim.get_animation(clip).length, true)
	_progress_prev = 0.0
	_progress_cur = 0.0
	return true


func _start_follow(seconds: float) -> void:
	_phase = Phase.FOLLOW
	_time_total = maxf(seconds, 0.01)
	_time_left = _time_total


func _end_action() -> void:
	_phase = Phase.NONE
	_clip = &""
	if _anim:
		_update_base_clip()


func _on_swing_started(_index: int, _direction: Vector2, swing: AttackSwing) -> void:
	if not _start_action(swing.swing_anim, false):
		return
	_hit_share = clampf(swing.windup / swing.duration, 0.0, 1.0) if swing.duration > 0.0 else 0.0
	_phase = Phase.LEAD_BY_PROGRESS


func _on_cast_started(_slot: StringName, ability: Ability, ctx: CastContext) -> void:
	_face_px = ctx.point if ctx and ctx.point != Vector2.INF else Vector2.INF
	if _anim == null and ability.cast_time > 0.0:
		_windup_total = ability.cast_time
		_windup_left = _windup_total
	if not _start_action(ability.cast_anim, true):
		return
	if ability.cast_time > 0.0:
		_phase = Phase.LEAD_BY_PROGRESS
	else:
		_phase = Phase.LEAD_BY_TIME
		_time_total = maxf(instant_cast_lead, 0.01)
		_time_left = _time_total


func _on_cast_finished(_slot: StringName, _ability: Ability) -> void:
	if _anim == null:
		_windup_left = 0.0
		_stretch = 1.0


func _on_cast_cancelled(_slot: StringName, _ability: Ability) -> void:
	_windup_left = 0.0
	if _is_cast and _phase != Phase.NONE:
		_end_action()


func _on_dash_started(_direction: Vector2, dash: DashComponent) -> void:
	_start_ghosts()
	if _anim == null or _dead or not _anim.has_animation(dash_clip):
		return
	_phase = Phase.DASH
	_clip = dash_clip
	_base = &""
	_anim.play(dash_clip, 0.04)
	_anim.speed_scale = _anim.get_animation(dash_clip).length / maxf(dash.dash_duration, 0.05)


func _on_dash_ended() -> void:
	if _phase == Phase.DASH:
		_end_action()


# --- Placeholders: windup squash, hit stretch, walk bob ---------------------------------

func _on_windup_started(target: Unit, windup_time: float) -> void:
	_windup_total = maxf(windup_time, 0.05)
	_windup_left = _windup_total
	_face_px = target.global_position if is_instance_valid(target) else Vector2.INF


func _on_attack_landed(_target: Unit, _damage: float) -> void:
	_windup_left = 0.0
	_stretch = 1.0


func _on_windup_cancelled() -> void:
	_windup_left = 0.0


func _update_placeholder(delta: float) -> void:
	if _body == null:
		return
	var squash := Vector3.ONE
	var lift := 0.0
	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)
		var windup_k := 1.0 - _windup_left / _windup_total
		squash = Vector3(1.0 + 0.15 * windup_k, 1.0 - 0.2 * windup_k, 1.0 + 0.15 * windup_k)
	elif _stretch > 0.0:
		_stretch = maxf(_stretch - delta * 5.0, 0.0)
		squash = Vector3(1.0 - 0.1 * _stretch, 1.0 + 0.25 * _stretch, 1.0 - 0.1 * _stretch)
	elif (sim as CharacterBody2D).velocity.length() > 5.0:
		_bob += delta * 11.0
		lift = absf(sin(_bob)) * 0.06
	else:
		_bob = 0.0
	# The pose's squash on top (ENEMIES_AI AI1): height down, width up.
	var pose_width := 1.0 + (1.0 - _pose_squash) * 0.5
	squash *= Vector3(pose_width, _pose_squash, pose_width)
	var k := 1.0 - exp(-30.0 * delta)
	_body.scale = _body.scale.lerp(squash, k)
	_body.position.y = lerpf(_body.position.y, lift, k)
	# The pose's lean about the capsule's base: + tilts its top toward its
	# front (+z), which faces its target while its brain runs.
	_body.rotation.x = deg_to_rad(_pose_lean)


# --- Poses (ENEMIES_AI AI1) --------------------------------------------------------------

## The look of the pose the sim shows now (Enemy.get_pose() in its
## PoseSet), or null: no pose, or a unit without poses (the Player).
func _target_pose_look() -> PoseLook:
	if not sim.has_method(&"get_pose"):
		return null
	var pose: StringName = sim.call(&"get_pose")
	if pose == &"":
		return null
	var pose_set := sim.call(&"get_pose_set") as PoseSet
	return pose_set.get_look(pose) if pose_set != null else null


## Blends toward the pose's look (pose_blend_time), and shows its rim on the
## overlay's second channel, pulsing at its rate; the hit flash wins while it
## plays. The lean and the squash are applied by _update_placeholder() (a
## model's clip comes with the art pass).
func _update_pose(delta: float) -> void:
	var look := _target_pose_look()
	var k := 1.0 - exp(-3.0 * delta / maxf(pose_blend_time, 0.001))
	_pose_lean = lerpf(_pose_lean, look.lean_deg if look else 0.0, k)
	_pose_squash = lerpf(_pose_squash, look.squash if look else 1.0, k)
	_pose_rim = _pose_rim.lerp(look.rim_color if look else Color(_pose_rim, 0.0), k)
	_pose_pulse_t += delta
	var alpha := _pose_rim.a
	var pulse_hz := look.pulse_hz if look else 0.0
	if pulse_hz > 0.0:
		alpha *= 0.55 + 0.45 * sin(_pose_pulse_t * TAU * pulse_hz)
	if _flash > 0.0:
		alpha = 0.0
	_set_rim(Color(_pose_rim.r, _pose_rim.g, _pose_rim.b, alpha if alpha > 0.004 else 0.0))


func _set_rim(rim: Color) -> void:
	if rim.is_equal_approx(_rim_shown):
		return
	_rim_shown = rim
	for geo: GeometryInstance3D in _geos:
		if is_instance_valid(geo):
			geo.set_instance_shader_parameter(&"rim", rim)


## The pose's blended look now (view_test): {lean_deg, squash, rim}.
func get_pose_look_now() -> Dictionary:
	return {"lean_deg": _pose_lean, "squash": _pose_squash, "rim": _rim_shown}


# --- Hit, death ----------------------------------------------------------------------------

func _on_damaged(_amount: float, _source: Unit) -> void:
	_overlay.set_shader_parameter(&"flash_color", flash_color)   # a blink may have tinted it
	_flash = 1.0
	_set_flash(flash_strength)


func _on_died(_unit: Unit) -> void:
	_dead = true
	_death_t = 0.0
	_phase = Phase.NONE
	_model.visible = true
	_set_rim(Color(1, 1, 1, 0))   # a pose's rim goes with the death
	if _body:
		_body.rotation.x = 0.0
	if _anim and _anim.has_animation(death_clip):
		_anim.speed_scale = 1.0
		_anim.play(death_clip, 0.08)


func _update_death(delta: float) -> void:
	_death_t += delta
	if _body:
		var k := clampf(_death_t / maxf(placeholder_death_time, 0.01), 0.0, 1.0)
		_body.scale = Vector3(1.0 + 0.5 * k, maxf(1.0 - 0.9 * k, 0.05), 1.0 + 0.5 * k)
		_body.position.y = 0.0
		_model.visible = k < 1.0


## The unit was freed: a dead unit's view finishes its death first.
func on_sim_exited() -> void:
	_sim_gone = true
	if _dead and is_inside_tree():
		get_tree().create_timer(death_linger).timeout.connect(queue_free)
	else:
		queue_free()


# --- Dash afterimages ------------------------------------------------------------------------

func _start_ghosts() -> void:
	_ghosts_left = afterimage_count
	_ghost_timer = 0.0


func _update_ghosts(delta: float) -> void:
	if _ghosts_left <= 0:
		return
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = afterimage_interval
	_ghosts_left -= 1
	_spawn_ghost(afterimage_color, afterimage_fade_time)


## A still copy of the model where it's drawn now, fading out. A rigged model
## uses its pool (copies made at load, posed with the model's clip at its
## current time): baking a skinned mesh's pose each time cost up to 40 ms
## (P6). A placeholder copies its meshes.
func _spawn_ghost(color: Color, fade_time: float) -> void:
	var to_drawn := get_global_transform_interpolated() * global_transform.affine_inverse()
	if not _ghost_pool.is_empty():
		_show_pooled_ghost(to_drawn, color, fade_time)
		return
	if _anim != null:
		return   # a rigged model without a pool: no afterimages
	var material := _ghost_material(color)
	var ghost := Node3D.new()
	ghost.name = "Ghost"
	ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	world_view.add_child(ghost)
	for geo: GeometryInstance3D in _geos:
		var mi := geo as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		ghost.add_child(copy)
		copy.global_transform = to_drawn * mi.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, maxf(fade_time, 0.01))
	tween.tween_callback(ghost.queue_free)


func _ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material


## A rigged model's afterimages: afterimage_count copies of it, made once,
## hidden, under the WorldView (they stay where they were left).
func _build_ghost_pool(scene: PackedScene) -> void:
	if afterimage_count <= 0 or _anim == null:
		return
	for i in afterimage_count:
		var root := scene.instantiate() as Node3D
		root.name = "Ghost_%s_%d" % [sim.name, i]
		root.visible = false
		root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		world_view.add_child(root)
		var material := _ghost_material(Color.WHITE)
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost_pool.append({"root": root, "anim": root.find_child("AnimationPlayer", true, false), "material": material, "tween": null})


func _show_pooled_ghost(to_drawn: Transform3D, color: Color, fade_time: float) -> void:
	var g: Dictionary = _ghost_pool[_ghost_next]
	_ghost_next = (_ghost_next + 1) % _ghost_pool.size()
	var root: Node3D = g["root"]
	if not is_instance_valid(root):
		return
	var anim := g["anim"] as AnimationPlayer
	if anim and _anim.assigned_animation != &"":
		anim.play(_anim.assigned_animation, 0.0, 0.0)   # speed 0: it holds the pose
		anim.seek(_anim.current_animation_position if _anim.is_playing() else 0.0, true)
	root.global_transform = to_drawn * _model_root.global_transform
	var material: StandardMaterial3D = g["material"]
	material.albedo_color = color
	root.visible = true
	if g["tween"] is Tween and (g["tween"] as Tween).is_valid():
		(g["tween"] as Tween).kill()
	var tween := root.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, maxf(fade_time, 0.01))
	tween.tween_callback(root.hide)
	g["tween"] = tween


func _exit_tree() -> void:
	for g: Dictionary in _ghost_pool:
		if is_instance_valid(g["root"]):
			(g["root"] as Node).queue_free()
	_ghost_pool.clear()
