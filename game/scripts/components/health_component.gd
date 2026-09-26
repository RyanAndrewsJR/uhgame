class_name HealthComponent
extends Node
## Tracks hit points for anything that can be damaged.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current: float


func _ready() -> void:
	current = max_health


func setup(maximum: float) -> void:
	max_health = maximum
	current = maximum
	health_changed.emit(current, max_health)


func take_damage(amount: float) -> void:
	if is_dead():
		return
	current = maxf(current - amount, 0.0)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if is_dead():
		return
	current = minf(current + amount, max_health)
	health_changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0.0
