class_name KnockbackGameplayEffect
extends GameplayEffect
## Pushes the target away from the source (dash-cancelable, like a hit's
## knockback; the stronger displacement wins). Nothing without a source.

@export var distance_px: float = 20.0
@export var duration: float = 0.12


func apply(target: Unit, source: Unit, _trigger_ctx: RefCounted) -> void:
	if not is_instance_valid(target) or not target.is_alive() or not is_instance_valid(source) or source == target:
		return
	var dir := (target.global_position - source.global_position).normalized()
	if dir == Vector2.ZERO:
		return
	var time := maxf(duration, 0.01)
	target.movement.displace(dir * distance_px / time, time, null, true)
