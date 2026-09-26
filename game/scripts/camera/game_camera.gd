extends Camera2D
## LoL-style camera.
##   Y          - toggle locked / unlocked
##   Hold Space - center on your character while held
##   Unlocked:  move the mouse to a screen edge, or use the arrow keys, to pan
## Also handles screen shake (GameFeel.shake()).
## Locked: leads toward the mouse by up to aim_lead px (see get_aim_lead()).

@export var target: Node2D
@export var locked: bool = true
@export var edge_pan_speed: float = 420.0
## Distance from the window edge (in screen pixels of the 640x360 view)
## that starts edge panning.
@export var edge_margin: float = 6.0
@export var shake_decay: float = 30.0
## How far (px) the locked camera leans toward the mouse at the screen edge.
## Scales with the mouse's distance from the screen center. 0 = off.
@export var aim_lead: float = 64.0

## Bounds the camera may show, set by Main from the room size.
var bounds: Rect2 = Rect2()

var _shake_amount: float = 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0


func shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)


func snap_to_target() -> void:
	if target:
		global_position = _clamp_to_bounds(target.global_position)
		reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle_lock"):
		locked = not locked


func _process(delta: float) -> void:
	# Real (unscaled) delta so hit-stop doesn't freeze camera panning.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)

	var centering := Input.is_action_pressed("camera_center")
	if target and (locked or centering):
		# Holding camera_center centers exactly; plain locked mode leads.
		var lead := get_aim_lead() if locked and not centering else Vector2.ZERO
		global_position = _clamp_to_bounds(target.global_position + lead)
	else:
		var pan := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		pan += _edge_pan_direction()
		if pan != Vector2.ZERO:
			global_position = _clamp_to_bounds(global_position + pan.limit_length(1.0) * edge_pan_speed * real_delta)

	if _shake_amount > 0.0:
		_shake_amount = move_toward(_shake_amount, 0.0, shake_decay * real_delta)
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amount
	else:
		offset = Vector2.ZERO


## Offset toward the mouse: the mouse's distance from the screen center as a
## fraction of half the screen (0..1), times aim_lead. Measured in screen
## space, so moving the camera doesn't feed back into the lead.
func get_aim_lead() -> Vector2:
	if aim_lead <= 0.0:
		return Vector2.ZERO
	var vp := get_viewport()
	var rect := vp.get_visible_rect()
	var from_center := (vp.get_mouse_position() - rect.get_center()) / (rect.size * 0.5)
	return from_center.limit_length(1.0) * aim_lead


func _edge_pan_direction() -> Vector2:
	var vp := get_viewport()
	if not vp.get_window().has_focus():
		return Vector2.ZERO
	var rect := vp.get_visible_rect()
	var m := vp.get_mouse_position()
	if not rect.grow(1.0).has_point(m):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if m.x <= rect.position.x + edge_margin:
		dir.x -= 1
	elif m.x >= rect.end.x - edge_margin:
		dir.x += 1
	if m.y <= rect.position.y + edge_margin:
		dir.y -= 1
	elif m.y >= rect.end.y - edge_margin:
		dir.y += 1
	return dir


func _clamp_to_bounds(p: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return p
	var half := get_viewport_rect().size * 0.5 / zoom
	var min_p := bounds.position + half
	var max_p := bounds.end - half
	# If the room is smaller than the screen on an axis, center on that axis.
	var x := bounds.get_center().x if min_p.x > max_p.x else clampf(p.x, min_p.x, max_p.x)
	var y := bounds.get_center().y if min_p.y > max_p.y else clampf(p.y, min_p.y, max_p.y)
	return Vector2(x, y)
