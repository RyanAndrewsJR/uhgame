class_name Hurtbox
extends Area2D
## Detects overlapping Hitboxes and reports hits, with invincibility frames.
## Checks every physics frame, so standing inside an enemy keeps hurting
## once the i-frames run out.

signal hurt(hitbox: Hitbox)

@export var invincibility_time: float = 0.2

var _invincible_timer: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	if not monitoring:
		return
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		return
	for area in get_overlapping_areas():
		var hitbox := area as Hitbox
		if hitbox and hitbox.active:
			_invincible_timer = invincibility_time
			hurt.emit(hitbox)
			return


func is_invincible() -> bool:
	return _invincible_timer > 0.0


func set_invincible(duration: float) -> void:
	_invincible_timer = maxf(_invincible_timer, duration)
