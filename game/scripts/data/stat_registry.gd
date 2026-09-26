class_name StatRegistry
extends Resource
## Every stat a StatsComponent knows (res://data/stats/stat_registry.tres).
## To add a stat: a row in STATS.md, a field on UnitStats, and an entry here.

@export var definitions: Array[StatDefinition] = []

var _by_key: Dictionary = {}   # StringName -> StatDefinition
var _built: bool = false


func has_stat(key: StringName) -> bool:
	return _get_map().has(key)


## Null (with a push_error) for unknown keys.
func get_definition(key: StringName) -> StatDefinition:
	var def: StatDefinition = _get_map().get(key)
	if def == null:
		push_error("StatRegistry: unknown stat '%s'" % key)
	return def


func get_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for def in definitions:
		keys.append(def.key)
	return keys


func _get_map() -> Dictionary:
	if not _built:
		_built = true
		for def in definitions:
			if def == null:
				continue
			if _by_key.has(def.key):
				push_error("StatRegistry: duplicate stat '%s'" % def.key)
			_by_key[def.key] = def
	return _by_key
