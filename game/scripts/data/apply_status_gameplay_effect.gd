class_name ApplyStatusGameplayEffect
extends GameplayEffect
## Applies a status to the target, from the source (tenacity, stack rules as
## usual).

@export var status: StatusEffect
## Seconds; -1 = the status's own duration.
@export var duration: float = -1.0


func apply(target: Unit, source: Unit, _trigger_ctx: RefCounted) -> void:
	if status == null or not is_instance_valid(target) or target.status_component == null:
		return
	target.status_component.apply_status(status, source if is_instance_valid(source) else null, duration)
