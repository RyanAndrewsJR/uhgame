class_name RemoveStatusesByTagGameplayEffect
extends GameplayEffect
## Removes every status on the target carrying any of `tags` (ABILITIES AB8).
## A cleanse is [&"cc"].

@export var tags: Array[StringName] = [&"cc"]


func apply(target: Unit, _source: Unit, _trigger_ctx: RefCounted) -> void:
	if is_instance_valid(target) and target.status_component != null:
		target.status_component.remove_statuses_with_tags(tags)
