class_name RestoreResourceGameplayEffect
extends GameplayEffect
## Restores the target's mana / energy / fury (ABILITIES AB8). Nothing for a
## unit without a resource pool.

@export var amount: float = 0.0
## Plus this fraction of the target's max resource (0.1 = 10%).
@export var max_resource_ratio: float = 0.0


func apply(target: Unit, _source: Unit, _trigger_ctx: RefCounted) -> void:
	if not is_instance_valid(target) or target.resource_pool == null:
		return
	target.resource_pool.restore(amount + max_resource_ratio * target.resource_pool.max_resource)
