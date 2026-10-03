extends Node3D
## P0b feel spike (throwaway; branch spike/3d-p0b, never merged).
## One unit's 3D look. It follows its sim unit on the physics tick (after the
## sim; physics interpolation smooths it), turns to the unit's facing
## (smoothly or in 8 steps), and plays animations from the unit's existing
## signals. It never changes gameplay state.
##   Player: KayKit's Knight (CC0). Moving -> run, swing_started -> an attack
##   timed so its strike lands on the hit, casts, the dash, death.
##   Enemies: a procedural slime with squash and stretch.

const Look := preload("res://scripts/spike/p0b_look.gd")
const KNIGHT_SCENE := preload("res://art/models/kaykit_knight/Knight.glb")
const TELEPORT_PX := 64.0
const TURN_RATE := 20.0
const HIDDEN_GEAR := ["1H_Sword_Offhand", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"]
## Swing clips by combo index (the last entry is the dash strike, index -1).
const SWING_CLIPS := [&"1H_Melee_Attack_Slice_Diagonal", &"1H_Melee_Attack_Slice_Horizontal", &"1H_Melee_Attack_Chop", &"1H_Melee_Attack_Stab"]
## Where a clip's anticipation starts and its strike lands, as fractions of
## its length (eyeballed; a pipeline test, not tuned art).
const CLIP_START := 0.18
const CLIP_STRIKE := 0.42
const CLIP_END := 0.85

var unit: Unit
var spike  # the P0b spike root (untyped: its toggles)
var look: Look
var is_player := false
var height_m := 1.0
var radius_m := 0.5

var _model: Node3D           # turns to the facing (physics tick)
var _knight: Node3D
var _anim: AnimationPlayer
var _knight_base_height := 1.0
var _blob: Node3D            # slimes: squash and stretch (frame time)
var _blob_mesh_height := 1.0
var _geos: Array = []        # for the hit flash
var _yaw := 0.0
var _last_px := Vector2.INF
var _flash := 0.0
var _dead := false
var _face_target: Vector2 = Vector2.INF
# Knight actions: a clip that holds over the base animation for a while.
var _action := &""
var _action_left := 0.0
var _after_strike_speed := 1.0
var _base := &""
# Slime motion.
var _hop := 0.0
var _windup_left := 0.0
var _windup_total := 0.0
var _stretch := 0.0
var _death_t := -1.0


func setup(p_unit: Unit, p_spike: Node, p_look: Look, knight_height: float) -> void:
	unit = p_unit
	spike = p_spike
	look = p_look
	is_player = unit is Player
	radius_m = unit.get_gameplay_radius_px() / 32.0
	name = "View_" + unit.name
	_model = Node3D.new()
	add_child(_model)
	if is_player:
		_build_knight(knight_height)
	else:
		_build_slime()
	unit.damaged.connect(_on_damaged)
	unit.died.connect(_on_died)
	unit.tree_exiting.connect(_on_unit_exiting)
	if is_player:
		var p := unit as Player
		p.attack.swing_started.connect(_on_swing_started)
		p.attack.swing_landed.connect(_on_swing_landed)
		p.attack.swing_cancelled.connect(_end_action)
		p.abilities.cast_started.connect(_on_cast_started)
		p.dash.dash_started.connect(_on_dash_started)
		p.dash.dash_ended.connect(_end_action)
	else:
		unit.attack.windup_started.connect(_on_windup_started)
		unit.attack.attack_landed.connect(_on_attack_landed)
		unit.attack.windup_cancelled.connect(func() -> void: _windup_left = 0.0)
		if unit.abilities:
			unit.abilities.cast_started.connect(_on_enemy_cast_started)
			unit.abilities.cast_finished.connect(func(_s: StringName, _a: Ability) -> void: _stretch = 1.0)
	_yaw = atan2(_facing().x, _facing().y) if _facing() != Vector2.ZERO else 0.0
	sync_tick()
	reset_physics_interpolation()


# --- Build ----------------------------------------------------------------------

func _build_knight(h: float) -> void:
	_knight = KNIGHT_SCENE.instantiate()
	_model.add_child(_knight)
	for gear: String in HIDDEN_GEAR:
		var n := _knight.find_child(gear, true, false)
		if n is Node3D:
			(n as Node3D).visible = false
	_anim = _knight.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: StringName in [&"Idle", &"Running_A", &"Walking_A"]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var pair: Array = []
	var box := AABB()
	var first := true
	var inv := _knight.global_transform.affine_inverse()
	for node in _knight.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if pair.is_empty():
			var mat := mi.get_active_material(0) as BaseMaterial3D
			pair = look.model_pair(mat.albedo_texture if mat else null)
		look.use(mi, pair)
		_geos.append(mi)
		if mi.name.begins_with("Knight_"):
			var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
	_knight_base_height = maxf(box.end.y, 0.1)
	set_knight_height(h)
	_play_base(&"Idle")


func set_knight_height(h: float) -> void:
	if _knight == null:
		return
	var s := h / _knight_base_height
	_knight.scale = Vector3.ONE * s
	height_m = h


func _build_slime() -> void:
	var color := _body_color()
	var r := radius_m * 0.85
	_blob = Node3D.new()
	_blob.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_model.add_child(_blob)
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 1.4
	mesh.radial_segments = 24
	mesh.rings = 12
	_blob_mesh_height = mesh.height
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = mesh.height * 0.5
	_blob.add_child(body)
	look.use(body, look.color_pair(&"slime", color))
	_geos.append(body)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.08, 0.05)
	eye_mat.roughness = 0.3
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = r * 0.13
		em.height = r * 0.3
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(side * r * 0.32, mesh.height * 0.62, r * 0.86)
		_blob.add_child(eye)
	height_m = mesh.height


## The 2D body's main color (its biggest polygon) times the unit's tint.
func _body_color() -> Color:
	var best: Polygon2D = null
	var best_area := 0.0
	for node in unit.body.find_children("*", "Polygon2D", true, false):
		var poly := node as Polygon2D
		var r := Rect2()
		for i in poly.polygon.size():
			r = Rect2(poly.polygon[i], Vector2.ZERO) if i == 0 else r.expand(poly.polygon[i])
		if r.get_area() > best_area:
			best = poly
			best_area = r.get_area()
	var c := best.color if best else Color(0.4, 0.8, 0.4)
	return c * unit.modulate


# --- Sync (physics tick, after the sim) ---------------------------------------------

func sync_tick() -> void:
	if _dead or not is_instance_valid(unit) or not unit.is_inside_tree():
		return
	var p := unit.global_position
	global_position = Vector3(p.x / 32.0, 0.0, p.y / 32.0)
	if _last_px != Vector2.INF and p.distance_to(_last_px) > TELEPORT_PX:
		reset_physics_interpolation()
	_last_px = p
	var f := _facing()
	if f != Vector2.ZERO:
		var target := atan2(f.x, f.y)
		if spike.is_eight_directions():
			_yaw = snappedf(target, TAU / 8.0)
		else:
			_yaw = lerp_angle(_yaw, target, 1.0 - exp(-TURN_RATE * get_physics_process_delta_time()))
	_model.rotation.y = _yaw


func _facing() -> Vector2:
	if is_player:
		return (unit as Player).facing
	if _windup_left > 0.0 and _face_target != Vector2.INF:
		return (_face_target - unit.global_position).normalized()
	if unit.velocity.length() > 5.0:
		return unit.velocity.normalized()
	return Vector2.ZERO


# --- Frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 8.0, 0.0)
		for geo: GeometryInstance3D in _geos:
			geo.set_instance_shader_parameter(&"flash", _flash)
	if is_player:
		_update_knight(delta)
	else:
		_update_slime(delta)


func _update_knight(delta: float) -> void:
	if _dead or not is_instance_valid(unit):
		return
	if _action != &"":
		_action_left -= delta
		if _action_left <= 0.0:
			_end_action()
		return
	var p := unit as Player
	var speed := p.velocity.length()
	match p.state:
		Player.State.MOVE:
			_play_base(&"Running_A", maxf(speed / 120.0, 0.6))
		Player.State.STUNNED, Player.State.DISPLACED:
			_play_base(&"Hit_A", 0.6)
		_:
			_play_base(&"Idle")


func _play_base(clip: StringName, speed: float = 1.0) -> void:
	_anim.speed_scale = speed
	if _base == clip and _anim.current_animation == clip:
		return
	_base = clip
	_anim.play(clip, 0.12)


## A clip played from its anticipation so its strike lands after `to_strike`
## seconds, then its follow-through fills `after` seconds.
func _strike(clip: StringName, to_strike: float, after: float) -> void:
	if not _anim.has_animation(clip):
		return
	var length := _anim.get_animation(clip).length
	_action = clip
	_base = &""
	_anim.play(clip, 0.05)
	_anim.seek(length * CLIP_START, true)
	_anim.speed_scale = length * (CLIP_STRIKE - CLIP_START) / maxf(to_strike, 0.03)
	_after_strike_speed = length * (CLIP_END - CLIP_STRIKE) / maxf(after, 0.05)
	_action_left = to_strike + after


func _end_action() -> void:
	_action = &""
	_action_left = 0.0


func _on_swing_started(index: int, _direction: Vector2, swing: AttackSwing) -> void:
	var p := unit as Player
	var speed := p.attack.get_swing_speed()
	var clip: StringName = SWING_CLIPS[3] if index < 0 else SWING_CLIPS[index % 3]
	_strike(clip, swing.windup / speed, maxf(swing.duration - swing.windup, 0.05) / speed)


func _on_swing_landed(_index: int, _targets: Array[Unit]) -> void:
	if _action != &"":
		_anim.speed_scale = _after_strike_speed


func _on_cast_started(_slot: StringName, ability: Ability, _ctx: CastContext) -> void:
	var id := String(ability.resource_path.get_file())
	var t := maxf(ability.cast_time, 0.08)
	if id.contains("lunge"):
		_strike(&"1H_Melee_Attack_Stab", 0.12, 0.25)
	elif id.contains("judgement"):
		_strike(&"1H_Melee_Attack_Chop", t, 0.3)
	elif id.contains("cleave"):
		_strike(&"1H_Melee_Attack_Slice_Horizontal", t, 0.25)
	elif id.contains("iron_resolve"):
		_strike(&"Block", 0.1, 0.35)
	else:
		_strike(&"Spellcast_Shoot", t, 0.3)


func _on_dash_started(_direction: Vector2) -> void:
	var dash := (unit as Player).dash
	_action = &"Dodge_Forward"
	_base = &""
	_anim.play(&"Dodge_Forward", 0.04)
	_anim.speed_scale = _anim.get_animation(&"Dodge_Forward").length / maxf(dash.dash_duration, 0.05)
	_action_left = dash.dash_duration + 0.05


func _on_damaged(_amount: float, _source: Unit) -> void:
	_flash = 1.0


func _on_died(_u: Unit) -> void:
	_dead = true
	if is_player:
		_anim.speed_scale = 1.0
		_anim.play(&"Death_A", 0.08)
	else:
		_death_t = 0.0


func _on_unit_exiting() -> void:
	_dead = true
	if not is_inside_tree():
		return
	get_tree().create_timer(1.6).timeout.connect(queue_free)


# --- Slimes -----------------------------------------------------------------------

func _on_windup_started(target: Unit, windup_time: float) -> void:
	_windup_total = maxf(windup_time, 0.05)
	_windup_left = _windup_total
	_face_target = target.global_position if is_instance_valid(target) else Vector2.INF


func _on_attack_landed(_target: Unit, _damage: float) -> void:
	_windup_left = 0.0
	_stretch = 1.0


func _on_enemy_cast_started(_slot: StringName, ability: Ability, ctx: CastContext) -> void:
	_windup_total = maxf(ability.cast_time, 0.1)
	_windup_left = _windup_total
	_face_target = ctx.point if ctx.point != Vector2.INF else Vector2.INF


func _update_slime(delta: float) -> void:
	if _blob == null:
		return
	if _death_t >= 0.0:
		_death_t += delta
		var k := clampf(_death_t / 0.35, 0.0, 1.0)
		_blob.scale = Vector3(1.0 + 0.6 * k, maxf(1.0 - 0.92 * k, 0.05), 1.0 + 0.6 * k)
		_blob.position.y = 0.0
		return
	var sq := Vector3.ONE
	var lift := 0.0
	var moving := is_instance_valid(unit) and unit.velocity.length() > 5.0
	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)
		var k := 1.0 - _windup_left / _windup_total
		sq = Vector3(1.0 + 0.18 * k, 1.0 - 0.25 * k, 1.0 + 0.18 * k)
	elif _stretch > 0.0:
		_stretch = maxf(_stretch - delta * 5.0, 0.0)
		sq = Vector3(1.0 - 0.12 * _stretch, 1.0 + 0.3 * _stretch, 1.0 - 0.12 * _stretch)
	elif moving:
		_hop += delta * 11.0
		var s := absf(sin(_hop))
		lift = s * 0.14
		sq = Vector3(1.0 + 0.08 * (1.0 - s), 1.0 - 0.1 * (1.0 - s) + 0.06 * s, 1.0 + 0.08 * (1.0 - s))
	else:
		_hop = 0.0
		var b := sin(Time.get_ticks_msec() * 0.004 + float(get_instance_id() % 97))
		sq = Vector3(1.0 + 0.025 * b, 1.0 - 0.035 * b, 1.0 + 0.025 * b)
	_blob.scale = _blob.scale.lerp(sq, 1.0 - exp(-30.0 * delta))
	_blob.position.y = lerpf(_blob.position.y, lift, 1.0 - exp(-30.0 * delta))
