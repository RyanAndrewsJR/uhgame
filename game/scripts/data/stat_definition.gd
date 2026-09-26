class_name StatDefinition
extends Resource
## One stat in the StatRegistry: its limits, rounding and how it's shown.
## Values are in LoL units (STATS.md, Stat list).

enum Format {
	NUMBER,      ## 64
	DECIMAL,     ## 0.70
	PERCENT,     ## 0.25 -> 25%
	PER_SECOND,  ## 1.5 -> 1.5/s
}

@export var key: StringName
@export var display_name: String = ""
## Base value when UnitStats has no field for this stat yet.
@export var default_value: float = 0.0

@export_group("Limits")
@export var has_min: bool = false
@export var min_value: float = 0.0
@export var has_max: bool = false
@export var max_value: float = 0.0
## Rounded after the clamp (dash_charges).
@export var is_integer: bool = false

@export_group("UnitStats fields")
## UnitStats field that holds the base. Empty = the same name as key.
## attack_speed reads base_attack_speed.
@export var base_field: StringName = &""
## UnitStats field that holds a per-unit max, used instead of max_value.
## attack_speed is capped by attack_speed_cap.
@export var max_field: StringName = &""

@export_group("Display")
@export var format: Format = Format.NUMBER


func get_base_field() -> StringName:
	return key if base_field == &"" else base_field


func format_value(value: float) -> String:
	match format:
		Format.DECIMAL:
			return "%.2f" % value
		Format.PERCENT:
			return "%d%%" % roundi(value * 100.0)
		Format.PER_SECOND:
			return "%.1f/s" % value
	if is_integer:
		return str(roundi(value))
	return str(snappedf(value, 0.1))
