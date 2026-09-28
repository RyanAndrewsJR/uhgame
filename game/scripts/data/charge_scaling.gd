class_name ChargeScaling
extends Resource
## One param of a CHARGE_UP ability that grows while the key is held
## (ABILITIES.md, Cast styles): from min_fraction of its value at a tap
## (charge 0) to its full value at full charge (1). The full value is the
## normal param after scoped modifiers, so items raise both ends. Lives
## inline in the ability's .tres (Ability.charge_scalings).

## The ability param, e.g. &"cast_range", &"base_damage", &"ad_ratio" or a
## scaling term's param.
@export var param: StringName = &""
## The share of the full value at charge 0 (0.4 = 40%).
@export_range(0.0, 1.0) var min_fraction: float = 0.5
## x = charge 0-1, y = progress from min to full 0-1. null = linear.
@export var curve: Curve
## The named 0-1 input it reads (ABILITIES AB12; CastContext.inputs):
## &"charge" (default: every AB6 charge-up is unchanged), &"self_missing_health",
## &"target_missing_health", &"target_distance", or one a script sets. With
## another input it's a named-input scaling ("stronger the more / less…"),
## read by Ability.get_effect_param(); get_charged_param() reads only charge.
@export var input: StringName = &"charge"


## The multiplier on the full value at `charge` (0-1; the input's value).
func get_multiplier(charge: float) -> float:
	var t := clampf(charge, 0.0, 1.0)
	if curve != null:
		t = clampf(curve.sample(t), 0.0, 1.0)
	return lerpf(min_fraction, 1.0, t)
