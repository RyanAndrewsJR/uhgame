class_name Hitbox
extends Area2D
## Deals damage to any Hurtbox it overlaps while active.
## Put it on the "attack" collision layer of whoever owns it.

@export var damage: float = 50.0
@export var knockback: float = 150.0
@export var starts_active: bool = true

var active: bool = true:
	set(value):
		active = value
		for child in get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", not value)


func _ready() -> void:
	monitoring = false
	monitorable = true
	active = starts_active


## Where knockback is pushed away from: the scene that owns this hitbox.
func get_source_position() -> Vector2:
	if owner is Node2D:
		return (owner as Node2D).global_position
	return global_position
