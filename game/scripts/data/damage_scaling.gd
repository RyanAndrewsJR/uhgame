class_name DamageScaling
extends Resource
## One League-style damage ratio on an ability: ratio x a stat of the caster
## or of the target (ABILITIES.md, Damage scalings). Lives inline in the
## ability's .tres (Ability.scalings). ad_ratio and ap_ratio are the two
## built-in terms and don't use this.
##
## The ratio is an ability param named `param`, so scoped modifiers
## (items) can raise it: Ability.get_param(caster, param).

enum Of {
	CASTER_STAT,            ## The caster's `stat` (final value).
	CASTER_BONUS_STAT,      ## The caster's `stat` minus its base (League's "bonus").
	TARGET_MAX_HEALTH,      ## The target's max health.
	TARGET_MISSING_HEALTH,  ## The target's max minus current health.
	TARGET_CURRENT_HEALTH,  ## The target's current health.
}

## The param id of this term's ratio, e.g. &"target_missing_health_ratio".
## Must not match an @export on the ability (that would win).
@export var param: StringName = &""
## 0.2 = 20%.
@export var ratio: float = 0.0
@export var of: Of = Of.CASTER_STAT
## For CASTER_STAT / CASTER_BONUS_STAT: a registered stat (attack_damage,
## ability_power, max_health, armor, magic_resist...).
@export var stat: StringName = &""
## Tooltip text after the percent ("bonus AD", "of the target's missing
## health"). Empty = generated from `of` and `stat`.
@export var label: String = ""

const _STAT_LABELS := {
	&"attack_damage": "AD",
	&"ability_power": "AP",
	&"max_health": "max health",
	&"armor": "armor",
	&"magic_resist": "magic resist",
}


## True if the term reads the target (it's 0 without one, e.g. in a tooltip).
func is_target_term() -> bool:
	return of == Of.TARGET_MAX_HEALTH or of == Of.TARGET_MISSING_HEALTH or of == Of.TARGET_CURRENT_HEALTH


## The amount the ratio multiplies: the caster's stat (or bonus stat), or the
## target's health. 0 when the caster or target it needs is missing.
func get_amount(caster: Unit, target: Node) -> float:
	match of:
		Of.CASTER_STAT, Of.CASTER_BONUS_STAT:
			if not is_instance_valid(caster) or caster.stats_component == null:
				return 0.0
			var value := caster.stats_component.get_stat(stat)
			if of == Of.CASTER_BONUS_STAT:
				value -= caster.stats_component.get_base_value(stat)
			return maxf(value, 0.0)
	var unit := target as Unit
	if not is_instance_valid(unit) or unit.health == null:
		return 0.0
	match of:
		Of.TARGET_MAX_HEALTH:
			return unit.health.max_health
		Of.TARGET_MISSING_HEALTH:
			return maxf(unit.health.max_health - unit.health.current, 0.0)
	return unit.health.current


## The tooltip text after the percent: `label`, or one made from `of` / `stat`.
func get_label() -> String:
	if label != "":
		return label
	match of:
		Of.TARGET_MAX_HEALTH:
			return "of the target's max health"
		Of.TARGET_MISSING_HEALTH:
			return "of the target's missing health"
		Of.TARGET_CURRENT_HEALTH:
			return "of the target's current health"
	var stat_label: String = _STAT_LABELS.get(stat, String(stat).replace("_", " "))
	return ("bonus " + stat_label) if of == Of.CASTER_BONUS_STAT else stat_label
