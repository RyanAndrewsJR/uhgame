class_name HealGameplayEffect
extends GameplayEffect
## Heals the target (green number, Unit.heal()).

@export var amount: float = 0.0
## Fraction of the target's max health added.
@export var max_health_ratio: float = 0.0


func apply(target: Unit, _source: Unit, _trigger_ctx: RefCounted) -> void:
	if not is_instance_valid(target):
		return
	target.heal(amount + max_health_ratio * target.health.max_health)
