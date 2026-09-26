class_name StatsComponent
extends Node
## A unit's live stats (STATS.md). UnitStats holds the base values; every
## change goes through a StatModifier tagged with a source_id, so
## remove_modifiers_from(source_id) takes back exactly what was added.
##
## final = (base + sum FLAT) x (1 + sum PERCENT_ADD) x product(1 + PERCENT_MULT)
## then clamped to the stat's min/max; integer stats round after the clamp.
## base = UnitStats field (or the registry default) + growth x (level - 1).
##
## move_speed (rules carried over from MovementComponent): negative
## PERCENT_ADD modifiers are slows and only the strongest one applies, as its
## own x (1 - slow) factor. The soft caps come last and use the thresholds on
## the unit's MovementComponent, so per-unit overrides (slimes) still apply.
##
## Values are cached. Adding or removing a modifier recalculates only the
## stats it touches and emits stat_changed for the ones whose value moved.
## Scoped modifiers change ability params instead of stats (STATS.md step 6):
## get_ability_param(ability, &"cooldown") applies the ones whose stat is
## the param and whose scope is &"ability:<id>" or &"tag:<tag>" of that
## ability, with the same formula.

signal stat_changed(key: StringName, old_value: float, new_value: float)

@export var registry: StatRegistry = preload("res://data/stats/stat_registry.tres")

var base_stats: UnitStats

var _level: int = 1
var _movement: MovementComponent
var _growth: Dictionary = {}                 # StringName -> growth per level
var _modifiers: Array[StatModifier] = []
var _cache: Dictionary = {}                  # StringName -> float
var _param_cache: Dictionary = {}            # "<ability instance id>/<param>" -> float


## movement: whose soft cap thresholds move_speed uses (none = no soft caps).
## growth: stat key -> amount added per level above 1 (ChampionData).
func setup(p_base_stats: UnitStats, movement: MovementComponent = null, growth: Dictionary = {}) -> void:
	base_stats = p_base_stats
	_movement = movement
	_growth = growth.duplicate()
	_cache.clear()


# --- Queries ------------------------------------------------------------------

## Final value of a stat, after modifiers, clamps and (move_speed) soft caps.
func get_stat(key: StringName) -> float:
	if not _cache.has(key):
		if registry.get_definition(key) == null:
			return 0.0   # get_definition() already pushed the error.
		_cache[key] = _calculate(key)
	return _cache[key]


## UnitStats value (or the registry default) plus level growth, before
## modifiers.
func get_base_value(key: StringName) -> float:
	var def := registry.get_definition(key)
	if def == null:
		return 0.0
	var base := def.default_value
	if base_stats != null:
		var field_value: Variant = base_stats.get(def.get_base_field())
		if field_value != null:
			base = float(field_value)
	return base + float(_growth.get(key, 0.0)) * (_level - 1)


## Every modifier added under source_id (scoped ones included).
func get_modifiers_from(source_id: StringName) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for mod in _modifiers:
		if mod.source_id == source_id:
			result.append(mod)
	return result


func get_level() -> int:
	return _level


## Seconds between basic attacks.
func get_attack_interval() -> float:
	return 1.0 / maxf(get_stat(&"attack_speed"), 0.001)


## An ability's param after scoped modifiers: base = the ability's own
## @export value (ability.get(param)); modifiers with stat == param and a
## scope in ability.get_modifier_scopes(); the stat formula; never below 0.
## Cached per ability and param until a scoped modifier is added or removed.
func get_ability_param(ability: Ability, param: StringName) -> float:
	var key := "%d/%s" % [ability.get_instance_id(), param]
	if _param_cache.has(key):
		return _param_cache[key]
	var base_value: Variant = ability.get(param)
	if not (base_value is float or base_value is int):
		push_error("StatsComponent: '%s' is not a number on ability '%s'" % [param, ability.id])
		return 0.0
	var scopes := ability.get_modifier_scopes()
	var flat := 0.0
	var percent_add := 0.0
	var percent_mult := 1.0
	for mod in _modifiers:
		if mod.stat != param or not mod.is_scoped() or not scopes.has(mod.scope):
			continue
		match mod.type:
			StatModifier.Type.FLAT:
				flat += mod.value
			StatModifier.Type.PERCENT_ADD:
				percent_add += mod.value
			StatModifier.Type.PERCENT_MULT:
				percent_mult *= 1.0 + mod.value
	var value := maxf((float(base_value) + flat) * (1.0 + percent_add) * percent_mult, 0.0)
	_param_cache[key] = value
	return value


## A cooldown after ability haste: base x 100 / (100 + haste).
func get_cooldown(base: float) -> float:
	return base * 100.0 / (100.0 + get_stat(&"ability_haste"))


# --- Commands -----------------------------------------------------------------

func add_modifier(mod: StatModifier) -> void:
	var one: Array[StatModifier] = [mod]
	add_modifiers(one)


func add_modifiers(mods: Array[StatModifier]) -> void:
	var accepted: Array[StatModifier] = []
	for mod in mods:
		if _is_valid(mod):
			accepted.append(mod)
	var keys := _unscoped_keys(accepted)
	var old := _snapshot(keys)
	_modifiers.append_array(accepted)
	if _has_scoped(accepted):
		_param_cache.clear()
	_apply_changes(old)


func remove_modifiers_from(source_id: StringName) -> void:
	var removed := get_modifiers_from(source_id)
	if removed.is_empty():
		return
	var old := _snapshot(_unscoped_keys(removed))
	var kept: Array[StatModifier] = []
	for mod in _modifiers:
		if mod.source_id != source_id:
			kept.append(mod)
	_modifiers = kept
	if _has_scoped(removed):
		_param_cache.clear()
	_apply_changes(old)


## Levels start at 1. Only stats with growth change.
func set_level(n: int) -> void:
	n = maxi(n, 1)
	if n == _level:
		return
	var keys: Array[StringName] = []
	for key: StringName in _growth.keys():
		keys.append(key)
	var old := _snapshot(keys)
	_level = n
	_apply_changes(old)


# --- Internals ----------------------------------------------------------------

func _calculate(key: StringName) -> float:
	var def := registry.get_definition(key)
	var is_move_speed := key == &"move_speed"
	var flat := 0.0
	var percent_add := 0.0
	var percent_mult := 1.0
	var strongest_slow := 0.0
	for mod in _modifiers:
		if mod.stat != key or mod.is_scoped():
			continue
		match mod.type:
			StatModifier.Type.FLAT:
				flat += mod.value
			StatModifier.Type.PERCENT_ADD:
				if is_move_speed and mod.value < 0.0:
					strongest_slow = maxf(strongest_slow, -mod.value)
				else:
					percent_add += mod.value
			StatModifier.Type.PERCENT_MULT:
				percent_mult *= 1.0 + mod.value

	var value := (get_base_value(key) + flat) * (1.0 + percent_add) * percent_mult
	if is_move_speed:
		value *= 1.0 - clampf(strongest_slow, 0.0, 0.99)
		if _movement != null:
			value = _movement.get_soft_capped_speed(value)

	if def.has_min:
		value = maxf(value, def.min_value)
	var max_from_field: Variant = null
	if def.max_field != &"" and base_stats != null:
		max_from_field = base_stats.get(def.max_field)
	if max_from_field != null:
		value = minf(value, float(max_from_field))
	elif def.has_max:
		value = minf(value, def.max_value)
	if def.is_integer:
		value = roundf(value)
	return value


func _is_valid(mod: StatModifier) -> bool:
	if mod == null:
		push_error("StatsComponent: tried to add a null StatModifier")
		return false
	if mod.source_id == &"":
		push_warning("StatsComponent: modifier for '%s' has no source_id, so it can't be removed" % mod.stat)
	if not mod.is_scoped() and not registry.has_stat(mod.stat):
		push_error("StatsComponent: modifier for unknown stat '%s' (source '%s')" % [mod.stat, mod.source_id])
		return false
	return true


func _has_scoped(mods: Array[StatModifier]) -> bool:
	for mod in mods:
		if mod.is_scoped():
			return true
	return false


func _unscoped_keys(mods: Array[StatModifier]) -> Array[StringName]:
	var keys: Array[StringName] = []
	for mod in mods:
		if not mod.is_scoped() and not keys.has(mod.stat):
			keys.append(mod.stat)
	return keys


## Current values of the given stats, taken before a change.
func _snapshot(keys: Array[StringName]) -> Dictionary:
	var old := {}
	for key in keys:
		old[key] = get_stat(key)
	return old


## Recalculates the snapshotted stats and emits stat_changed for the ones
## whose value moved.
func _apply_changes(old: Dictionary) -> void:
	for key in old.keys():
		_cache.erase(key)
	for key: StringName in old.keys():
		var old_value: float = old[key]
		var new_value := get_stat(key)
		if not is_equal_approx(new_value, old_value):
			stat_changed.emit(key, old_value, new_value)
