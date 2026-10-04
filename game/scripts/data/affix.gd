class_name Affix
extends Resource
## One rolled stat line (LOOT.md, Stats): a StatModifier with a value range.
## An item's affix keeps a 0–1 roll; its value is the roll placed inside the
## rarity's band of [min_value, max_value], rounded to `step`. Files:
## res://data/affixes/affix_<name>.tres (the item pool, LootTable.affixes).
## COMPANIONS' quirks are Affixes too (their own lists, `slots` empty).
##
## Never `ability:`-scoped: that would make an item (or a quirk) one
## champion's. Plain stats, `hit:` / `target:` damage scopes and `tag:`
## ability-param scopes only.

const REGISTRY: StatRegistry = preload("res://data/stats/stat_registry.tres")

@export var id: StringName = &""
@export var stat: StringName = &""
@export var type: StatModifier.Type = StatModifier.Type.FLAT
## &"" = a normal stat; &"hit:<tag>" / &"target:<tag>" = a damage stat for
## some hits; &"tag:<tag>" = an Ability base param (cooldown...) of every
## ability with that tag. Never &"ability:<id>".
@export var scope: StringName = &""
## The value at roll 0 and at roll 1 of the full range (min may be above max:
## a cooldown reduction runs -0.04 -> -0.15).
@export var min_value: float = 0.0
@export var max_value: float = 1.0
## Rounding step of the value (1 for flat health or armor, 0.01 for percents);
## 0 = no rounding.
@export var step: float = 1.0
## The item slots it can roll on (the item pool needs at least one).
@export var slots: Array[Item.Slot] = []
@export var weight: float = 1.0
## Tooltip template: {value} = the signed number in the stat's format,
## {value%} = the signed percent ("{value%} damage with core abilities").
## Empty = "+<value> <stat name>" from the stat registry.
@export var text: String = ""


## The value for `roll` (0–1) inside the band [band_min, band_max] of the range.
func get_value(band_min: float, band_max: float, roll: float) -> float:
	var raw := lerpf(min_value, max_value, lerpf(band_min, band_max, clampf(roll, 0.0, 1.0)))
	return snappedf(raw, step) if step > 0.0 else raw


## The smallest and largest values `band` can give (before rounding).
func get_band_range(band_min: float, band_max: float) -> Vector2:
	var a := lerpf(min_value, max_value, band_min)
	var b := lerpf(min_value, max_value, band_max)
	return Vector2(minf(a, b), maxf(a, b))


func make_modifier(value: float, source_id: StringName) -> StatModifier:
	return StatModifier.create(stat, type, value, source_id, scope)


## The tooltip line for `value`.
func get_line(value: float) -> String:
	if text == "":
		return describe(stat, type, value)
	return text.replace("{value%}", format_percent(value)).replace("{value}", format_value(stat, type, value))


## "" when it can be used, else what's wrong. The item pool's own rules
## (slots, ids unique) are LootTable's.
func get_validation_error() -> String:
	if id == &"":
		return "an affix has no id"
	if step < 0.0:
		return "affix '%s': step below 0" % id
	return get_modifier_error(stat, scope, "affix '%s'" % id)


## "" when a modifier on `p_stat` with `p_scope` is one an item may carry
## without being one champion's (no `ability:` scope), else the reason.
## StatsComponent's own key check, minus the abilities a unit holds.
static func get_modifier_error(p_stat: StringName, p_scope: StringName, label: String) -> String:
	var s := String(p_scope)
	if s.begins_with("ability:"):
		return "%s: an ability: scope ('%s') would make it one champion's" % [label, p_scope]
	if s == "" or s.begins_with("hit:") or s.begins_with("target:"):
		if not REGISTRY.has_stat(p_stat):
			return "%s: unknown stat '%s'" % [label, p_stat]
		return ""
	if s.begins_with("tag:"):
		if not Ability.is_base_param(p_stat):
			return "%s: '%s' isn't a number param of every ability (scope '%s')" % [label, p_stat, p_scope]
		return ""
	return "%s: unknown scope kind '%s'" % [label, p_scope]


## "+40 Max Health", "+8% Attack Speed", "+10% more Attack Damage".
static func describe(p_stat: StringName, p_type: StatModifier.Type, value: float) -> String:
	var def: StatDefinition = REGISTRY.get_definition(p_stat) if REGISTRY.has_stat(p_stat) else null
	var stat_name := def.display_name if def != null else String(p_stat).capitalize()
	if p_type == StatModifier.Type.PERCENT_MULT:
		return "%s more %s" % [format_percent(value), stat_name]
	return "%s %s" % [format_value(p_stat, p_type, value), stat_name]


## The signed number in the stat's own format (a percent for PERCENT_ADD /
## PERCENT_MULT, which are fractions whatever the stat). A whole number shows
## without decimals ("+40", not "+40.0").
static func format_value(p_stat: StringName, p_type: StatModifier.Type, value: float) -> String:
	if p_type != StatModifier.Type.FLAT:
		return format_percent(value)
	var def: StatDefinition = REGISTRY.get_definition(p_stat) if REGISTRY.has_stat(p_stat) else null
	var magnitude := absf(value)
	var shown: String
	if def != null and def.format != StatDefinition.Format.NUMBER:
		shown = def.format_value(magnitude)
	elif is_equal_approx(magnitude, roundf(magnitude)):
		shown = str(roundi(magnitude))
	else:
		shown = str(snappedf(magnitude, 0.1))
	return ("-" if value < 0.0 else "+") + shown


## 0.08 -> "+8%", -0.1 -> "-10%".
static func format_percent(value: float) -> String:
	return "%s%d%%" % ["-" if value < 0.0 else "+", roundi(absf(value) * 100.0)]
