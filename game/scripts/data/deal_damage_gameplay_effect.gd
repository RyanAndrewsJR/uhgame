class_name DealDamageGameplayEffect
extends GameplayEffect
## A proc hit on the target (HitPipeline.make_proc()): always tagged &"proc",
## can't crit, proc coefficient 0, so it never triggers on-hit or HIT rules.

@export var base_damage: float = 0.0
## Fraction of the source's attack_damage added.
@export var ad_ratio: float = 0.0
@export var damage_type: HitContext.DamageType = HitContext.DamageType.MAGIC
## Extra hit tags (e.g. &"shatter"), for damage_increase scopes.
@export var tags: Array[StringName] = []


func apply(target: Unit, source: Unit, _trigger_ctx: RefCounted) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	var ctx := HitPipeline.make_proc(source if is_instance_valid(source) else null, target, base_damage)
	ctx.ad_ratio = ad_ratio
	ctx.damage_type = damage_type
	for t in tags:
		ctx.add_tag(t)
	HitPipeline.resolve(ctx)
