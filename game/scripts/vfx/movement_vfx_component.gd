class_name MovementVFXComponent
extends Node2D
## Movement feedback for a Unit (docs/MOVEMENT.md, Feel pass F3).
## VFX only: never changes gameplay state.
##
## - Dash (DashComponent signals): the Body stretches along the dash, then
##   squashes when the dash ends; afterimages; a dust puff at the start.
## - Walking: a small bob whose rate follows the walking speed, and a dust
##   puff on a sharp reversal.
## - Any other displacement (knockback, Lunge): the Body stretches along
##   the push, scaled by the current speed.
##
## How the Body is deformed: only while the frame is drawn. The deformation
## is applied on RenderingServer.frame_pre_draw and undone on
## frame_post_draw, so game code that sets body.scale / body.position (the
## walk flip, the slime squash, death tweens) never sees it and nothing
## fights over the Body. While enabled, the Body's own physics interpolation
## is off so the deformation shows in full; the unit itself is still
## interpolated, so movement stays smooth (F1).
##
## Works on any Body: the deformation is a transform, and afterimages are
## copies of the Body (Polygon2D placeholders today, 8-direction sprites
## later). Put it last among the unit's children so it reads this physics
## frame's movement.

const AFTERIMAGE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, COLOR.a * tint.a);
}
"""
## Tiny y offsets (px) so y-sorting draws spawned effects behind the unit,
## and afterimages behind the dust.
const DUST_SORT_OFFSET := 0.01
const AFTERIMAGE_SORT_OFFSET := 0.02

## Off = no effects at all and the Body looks exactly as without this node.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_enabled()

## Point the Body stretches and squashes around, in the unit's space.
## (0, 0) = the feet, so the feet stay on the shadow.
@export var deform_pivot: Vector2 = Vector2.ZERO

@export_group("Dash")
## Body scale along × across the dash direction at the start of a dash.
@export var dash_stretch: Vector2 = Vector2(1.25, 0.8)
## Seconds the full stretch holds.
@export var dash_stretch_time: float = 0.06
## Seconds to ease back from the stretch.
@export var dash_stretch_return_time: float = 0.08
## Body scale along × across the dash direction when the dash ends.
@export var dash_squash: Vector2 = Vector2(0.9, 1.1)
## Seconds the full squash holds.
@export var dash_squash_time: float = 0.05
## Seconds to ease back from the squash.
@export var dash_squash_return_time: float = 0.08
## Afterimages per dash (the first one at the start point). 0 = none.
@export_range(0, 10) var afterimage_count: int = 4
## Seconds between afterimages.
@export var afterimage_interval: float = 0.03
## Seconds for an afterimage to fade out.
@export var afterimage_fade_time: float = 0.15
## Afterimage color. Alpha = starting opacity.
@export var afterimage_color: Color = Color(0.55, 0.85, 1.0, 0.5)
## true: afterimages are flat silhouettes in afterimage_color.
## false: tinted copies of the Body.
@export var afterimage_silhouette: bool = true
## Dust puff behind the unit when a dash starts.
@export var dash_dust: bool = true

@export_group("Walking")
## Bob height in px while walking. 0 = no bob from this node.
@export var walk_bob_px: float = 1.0
## Distance walked per bob, in px. The bob rate follows the walking speed.
@export var walk_bob_stride_px: float = 40.0
## true: this bob replaces the Body's own bob (player.gd's 2 px bob) while
## enabled. false: it's added on top.
@export var replace_existing_bob: bool = true
## Dust puff when the walking direction turns sharply.
@export var reversal_dust: bool = true
## A turn sharper than this (degrees) counts as a reversal.
@export_range(90.0, 180.0) var reversal_angle_deg: float = 135.0
## The old direction must have reached this speed (px/s).
@export var reversal_min_speed_px: float = 90.0
## A reversal still counts if the old direction was walked this recently
## (seconds), so letting go and pressing the other way counts too.
@export var reversal_memory_time: float = 0.1
## Minimum seconds between reversal puffs.
@export var reversal_cooldown: float = 0.15

@export_group("Displacement")
## Stretch along any displacement that isn't this unit's own dash
## (knockback, pulls, Lunge).
@export var displaced_stretch: bool = true
## Stretch per px/s of speed (0.0005: 400 px/s → 1.2). Across = 1 / along.
@export var displaced_stretch_per_speed: float = 0.0005
## Largest stretch along the push.
@export var displaced_stretch_max: float = 1.3

@export_group("Dust")
@export var dust_color: Color = Color(0.8, 0.74, 0.64, 0.75)
## Specks per puff.
@export_range(1, 16) var dust_count: int = 6
## Speck radius in px.
@export var dust_size_px: float = 2.5
## How far the specks fly, in px.
@export var dust_distance_px: float = 14.0
## Spread of the specks around their direction, in degrees.
@export var dust_spread_deg: float = 80.0
## Seconds a speck lives.
@export var dust_duration: float = 0.3
## Vertical squash of the dust's motion, so it stays on the floor in the
## 3/4 view.
@export var dust_y_scale: float = 0.5

static var _afterimage_shader: Shader

var unit: Unit
var body: Node2D
var movement: MovementComponent
## Optional: only units that dash have one.
var dash: DashComponent

var _hooked: bool = false
var _saved_interpolation_mode: Node.PhysicsInterpolationMode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
var _saved_body_transform: Transform2D = Transform2D.IDENTITY
var _body_changed: bool = false
var _rng := RandomNumberGenerator.new()   # own RNG: never shifts gameplay randomness

# Deformation this frame: scale along × across _deform_dir.
var _deform_dir: Vector2 = Vector2.RIGHT
var _deform_scale: Vector2 = Vector2.ONE

# Dash
var _dash_dir: Vector2 = Vector2.RIGHT
var _stretch_age: float = -1.0       # < 0 = not running
var _squash_age: float = -1.0
var _afterimages_spawned: int = 0
var _afterimage_clock: float = 0.0
var _last_physics_position: Vector2 = Vector2.ZERO

# Walking
var _walk_speed_px: float = 0.0
var _bob_phase: float = 0.0
var _bob_offset: float = 0.0
var _last_walk_dir: Vector2 = Vector2.ZERO
var _run_peak_speed_px: float = 0.0   # top speed in the current direction
var _since_walked: float = INF
var _reversal_cooldown_left: float = 0.0


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "MovementVFXComponent must be a child of a Unit")
	# Children are ready before their parent, so the Unit's @onready vars
	# aren't set yet. Fetch the siblings directly.
	body = unit.get_node("Body") as Node2D
	movement = unit.get_node("MovementComponent") as MovementComponent
	dash = unit.get_node_or_null("DashComponent") as DashComponent
	if dash:
		dash.dash_started.connect(_on_dash_component_dash_started)
		dash.dash_ended.connect(_on_dash_component_dash_ended)
	_rng.randomize()
	_last_physics_position = unit.global_position
	_apply_enabled()


func _enter_tree() -> void:
	# Re-entering the tree (e.g. the unit was moved to another parent).
	if is_node_ready():
		_apply_enabled()


func _exit_tree() -> void:
	_unhook()


# --- Toggle ---------------------------------------------------------------------

func _apply_enabled() -> void:
	set_process(enabled)
	set_physics_process(enabled)
	if enabled:
		_last_physics_position = unit.global_position
		_hook()
	else:
		_unhook()
		_reset_state()


func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	_saved_interpolation_mode = body.physics_interpolation_mode
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


func _unhook() -> void:
	if not _hooked:
		return
	_hooked = false
	_restore_body()
	RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
	if is_instance_valid(body):
		body.physics_interpolation_mode = _saved_interpolation_mode


func _reset_state() -> void:
	_deform_scale = Vector2.ONE
	_stretch_age = -1.0
	_squash_age = -1.0
	_afterimages_spawned = afterimage_count
	_bob_phase = 0.0
	_bob_offset = 0.0
	_last_walk_dir = Vector2.ZERO
	_since_walked = INF


# --- Dash -----------------------------------------------------------------------

func _on_dash_component_dash_started(direction: Vector2) -> void:
	if not enabled:
		return
	_dash_dir = direction
	_stretch_age = 0.0
	_squash_age = -1.0
	_afterimages_spawned = 0
	_afterimage_clock = 0.0
	# Emitted before the dash moves, so this is the start point.
	if afterimage_count > 0:
		_spawn_afterimage(unit.global_position)
	if dash_dust:
		_spawn_dust(unit.global_position, -direction)


func _on_dash_component_dash_ended() -> void:
	if not enabled:
		return
	_stretch_age = -1.0
	_squash_age = 0.0
	_afterimages_spawned = afterimage_count


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Where the unit was before this physics frame moved it. The screen shows
	# the unit between that point and now (physics interpolation), so an
	# afterimage placed here never shows up ahead of the unit.
	var frame_start_position := _last_physics_position
	_last_physics_position = unit.global_position
	if not unit.is_alive():
		return
	_reversal_cooldown_left -= delta

	# Afterimages every afterimage_interval while dashing.
	if dash and dash.is_dashing() and _afterimages_spawned < afterimage_count:
		_afterimage_clock += delta
		if _afterimage_clock >= afterimage_interval * _afterimages_spawned - 0.001:
			_spawn_afterimage(frame_start_position)

	# Walking (not while displaced).
	var dir := movement.get_move_direction()
	var walking := dir != Vector2.ZERO and not movement.is_displaced()
	_walk_speed_px = unit.velocity.length() if walking else 0.0
	if not walking:
		_since_walked += delta
		return
	var turned := _last_walk_dir != Vector2.ZERO and dir.dot(_last_walk_dir) < 0.999
	if turned:
		var sharp := dir.dot(_last_walk_dir) < cos(deg_to_rad(reversal_angle_deg)) - 0.001
		if reversal_dust and sharp and _since_walked <= reversal_memory_time \
				and _run_peak_speed_px >= reversal_min_speed_px and _reversal_cooldown_left <= 0.0:
			_spawn_dust(unit.global_position, -dir)
			_reversal_cooldown_left = reversal_cooldown
		_run_peak_speed_px = 0.0
	_run_peak_speed_px = maxf(_run_peak_speed_px, _walk_speed_px)
	_last_walk_dir = dir
	_since_walked = 0.0


func _process(delta: float) -> void:
	if not unit.is_alive():
		_deform_scale = Vector2.ONE
		return
	_update_bob(delta)
	_update_deform(delta)


func _update_bob(delta: float) -> void:
	if walk_bob_px <= 0.0:
		_bob_offset = 0.0
		return
	if _walk_speed_px > 0.0:
		_bob_phase += _walk_speed_px / maxf(walk_bob_stride_px, 1.0) * PI * delta
		_bob_offset = -absf(sin(_bob_phase)) * walk_bob_px
	else:
		_bob_phase = 0.0
		_bob_offset = move_toward(_bob_offset, 0.0, delta * 20.0)


## Dash stretch, then the end squash; otherwise a stretch from any other
## displacement, scaled by speed.
func _update_deform(delta: float) -> void:
	_deform_scale = Vector2.ONE
	if _squash_age >= 0.0:
		_squash_age += delta
		var k := _envelope(_squash_age, dash_squash_time, dash_squash_return_time)
		if k <= 0.0:
			_squash_age = -1.0
		else:
			_deform_dir = _dash_dir
			_deform_scale = Vector2.ONE.lerp(dash_squash, k)
		return
	if _stretch_age >= 0.0:
		_stretch_age += delta
		var k := _envelope(_stretch_age, dash_stretch_time, dash_stretch_return_time)
		if k <= 0.0:
			_stretch_age = -1.0
		else:
			_deform_dir = _dash_dir
			_deform_scale = Vector2.ONE.lerp(dash_stretch, k)
		return
	if not displaced_stretch or not movement.is_displaced():
		return
	if dash and dash.is_dashing():
		return   # The dash has its own stretch.
	var speed := unit.velocity.length()
	if speed < 1.0:
		return
	var along := minf(1.0 + speed * displaced_stretch_per_speed, maxf(displaced_stretch_max, 1.0))
	_deform_dir = unit.velocity / speed
	_deform_scale = Vector2(along, 1.0 / along)


## 1 while holding, then eases out to 0 over return_time. 0 = finished.
func _envelope(age: float, hold: float, return_time: float) -> float:
	if age < hold:
		return 1.0
	var u := (age - hold) / maxf(return_time, 0.001)
	if u >= 1.0:
		return 0.0
	return (1.0 - u) * (1.0 - u)


# --- Draw-time deformation ------------------------------------------------------

func _on_frame_pre_draw() -> void:
	_body_changed = false
	if not is_instance_valid(body) or not unit.is_alive():
		return
	var uses_bob := walk_bob_px > 0.0
	if not uses_bob and _deform_scale == Vector2.ONE:
		return
	_saved_body_transform = body.transform
	body.transform = _get_display_transform(_saved_body_transform)
	_body_changed = true


func _on_frame_post_draw() -> void:
	_restore_body()


func _restore_body() -> void:
	if _body_changed and is_instance_valid(body):
		body.transform = _saved_body_transform
	_body_changed = false


## The Body's transform as it should look this frame: the bob, then the
## stretch or squash around deform_pivot.
func _get_display_transform(base: Transform2D) -> Transform2D:
	var t := base
	if walk_bob_px > 0.0:
		if replace_existing_bob:
			t.origin.y = _bob_offset
		else:
			t.origin.y += _bob_offset
	if _deform_scale != Vector2.ONE:
		var angle := _deform_dir.angle()
		var deform := Transform2D(angle, Vector2.ZERO) \
			* Transform2D(0.0, _deform_scale, 0.0, Vector2.ZERO) \
			* Transform2D(-angle, Vector2.ZERO)
		t = Transform2D(0.0, deform_pivot) * deform * Transform2D(0.0, -deform_pivot) * t
	return t


# --- Spawned effects ------------------------------------------------------------

## A fading copy of the Body at `pos` (the Body as it looks this frame).
## The copy sits in a CanvasGroup, so it fades as one flat shape: the Body's
## overlapping parts (head over torso, eyes) don't show through each other.
func _spawn_afterimage(pos: Vector2) -> void:
	_afterimages_spawned += 1
	var parent := unit.get_parent() as Node2D
	if parent == null:
		return
	var holder := Node2D.new()
	holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Just above the feet, so y-sorting draws it behind the unit and its dust.
	holder.position = parent.to_local(pos) - Vector2(0.0, AFTERIMAGE_SORT_OFFSET)
	var group := CanvasGroup.new()
	group.position = Vector2(0.0, AFTERIMAGE_SORT_OFFSET)
	# self_modulate fades the finished shape; modulate would also fade each part.
	group.self_modulate = Color(1.0, 1.0, 1.0, afterimage_color.a)
	var copy := body.duplicate(0) as Node2D
	copy.process_mode = Node.PROCESS_MODE_DISABLED   # a still frame (sprites stop animating)
	copy.transform = _get_display_transform(body.transform)
	if afterimage_silhouette:
		var mat := ShaderMaterial.new()
		mat.shader = _get_afterimage_shader()
		mat.set_shader_parameter(&"tint", Color(afterimage_color, 1.0))
		copy.material = mat
		_use_parent_material(copy)
		copy.modulate = Color.WHITE
	else:
		copy.modulate = Color(afterimage_color, 1.0)
	group.add_child(copy)
	holder.add_child(group)
	parent.add_child(holder)
	var tween := holder.create_tween()
	tween.tween_property(group, "self_modulate:a", 0.0, afterimage_fade_time)
	tween.tween_callback(holder.queue_free)


func _use_parent_material(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).use_parent_material = true
		_use_parent_material(child)


static func _get_afterimage_shader() -> Shader:
	if _afterimage_shader == null:
		_afterimage_shader = Shader.new()
		_afterimage_shader.code = AFTERIMAGE_SHADER_CODE
	return _afterimage_shader


## A few specks of dust at `pos` flying toward `direction`, flattened onto
## the floor.
func _spawn_dust(pos: Vector2, direction: Vector2) -> void:
	var parent := unit.get_parent() as Node2D
	if parent == null or direction == Vector2.ZERO:
		return
	var puff := Node2D.new()
	puff.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Just above the feet, so y-sorting draws it behind the unit.
	puff.position = parent.to_local(pos) - Vector2(0.0, DUST_SORT_OFFSET)
	parent.add_child(puff)
	var base_angle := direction.angle()
	var spread := deg_to_rad(dust_spread_deg) * 0.5
	var tween := puff.create_tween().set_parallel(true)
	for i in dust_count:
		var speck := Polygon2D.new()
		speck.polygon = _circle(dust_size_px * _rng.randf_range(0.7, 1.2))
		speck.color = dust_color
		var way := Vector2.from_angle(base_angle + _rng.randf_range(-spread, spread))
		way.y *= dust_y_scale
		var start := way * dust_distance_px * 0.15 + Vector2(0.0, DUST_SORT_OFFSET)
		speck.position = start
		puff.add_child(speck)
		var life := dust_duration * _rng.randf_range(0.7, 1.0)
		var end := start + way * dust_distance_px * _rng.randf_range(0.6, 1.0)
		tween.tween_property(speck, "position", end, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(speck, "scale", Vector2.ONE * 0.3, life).set_ease(Tween.EASE_IN)
		tween.tween_property(speck, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(puff.queue_free)


static func _circle(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
