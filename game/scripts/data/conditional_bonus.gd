class_name ConditionalBonus
extends Resource
## "Bonus if…" for an ability (ABILITIES.md, Conditions; AB12): param changes
## and statuses the ability gets only while its conditions pass, checked at
## the moment of the effect (cast-time params: the cast's target; hit-time:
## the unit hit). Inline in the ability's .tres (Ability.conditional_bonuses).

## All must pass (an empty list always passes).
@export var conditions: Array[Condition] = []
## Param changes: stat = the ability param (&"base_damage", &"radius",
## &"ad_ratio", a scaling term's param...), type FLAT / PERCENT_ADD /
## PERCENT_MULT with the StatModifier formula, applied after scoped modifiers
## and named-input scaling. scope and source_id are ignored.
@export var modifiers: Array[StatModifier] = []
## Applied to each unit the effect hits (through HitContext.statuses).
@export var target_statuses: Array[StatusEffect] = []
## Applied to the caster when the effect starts.
@export var self_statuses: Array[StatusEffect] = []
## The tooltip line ("+50% radius against stunned enemies").
@export var description: String = ""


func is_active(caster: Unit, target: Unit, cast: CastContext) -> bool:
	return Condition.all_met(conditions, caster, target, cast)
