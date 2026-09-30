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
## ability, with the same formula. Hit-scoped ones (&"hit:<tag>",
## &"target:<tag>", COMBAT C8) change a stat only for the hits they match:
## get_scoped_stat(&"damage_increase", scopes).
## An unknown key is never a silent 0: a modifier for an unknown stat, an
## unknown ability param or an unknown scope kind is rejected with a
## push_error (_is_valid()).

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


## An ability's param after scoped modifiers: base = ability.get_base_param()
## (its @export of that name, or a scaling term's ratio); modifiers with stat
## == param and a scope in ability.get_modifier_scopes(); the stat formula;
## never below 0.
## Cached per ability and param until a scoped modifier is added or removed.
func get_ability_param(ability: Ability, param: StringName) -> float:
	var key := "%d/%s" % [ability.get_instance_id(), param]
	if _param_cache.has(key):
		return _param_cache[key]
	# An @export param or a scaling term's ratio (ABILITIES AB2); anything
	# else is reported by the ability and counts 0.
	var base_value := ability.get_base_param(param)
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


## A stat for one hit (COMBAT C8): its normal value plus the modifiers
## scoped to any of `scopes` (&"hit:<tag>", &"target:<tag>";
## HitPipeline.get_hit_scopes()). Same formula and limits as get_stat().
## Not cached: without a matching scoped modifier it is just get_stat().
func get_scoped_stat(key: StringName, scopes: Array[StringName]) -> float:
	for mod in _modifiers:
		if mod.stat == key and mod.is_scoped() and scopes.has(mod.scope):
			return _calculate(key, scopes)
	return get_stat(key)


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


## Swaps these exact modifier instances (the ones still here) for new ones in
## one change, so stat_changed fires once per stat whose value moved (a
## StatScaling's refresh, CHAMPIONS CH2). new_mods may be empty (a removal).
func replace_modifiers(old_mods: Array[StatModifier], new_mods: Array[StatModifier]) -> void:
	var removed: Array[StatModifier] = []
	for mod in old_mods:
		if _modifiers.has(mod):
			removed.append(mod)
	var accepted: Array[StatModifier] = []
	for mod in new_mods:
		if _is_valid(mod):
			accepted.append(mod)
	if removed.is_empty() and accepted.is_empty():
		return
	var keys := _unscoped_keys(removed)
	for key in _unscoped_keys(accepted):
		if not keys.has(key):
			keys.append(key)
	var old := _snapshot(keys)
	var kept: Array[StatModifier] = []
	for mod in _modifiers:
		if not removed.has(mod):
			kept.append(mod)
	kept.append_array(accepted)
	_modifiers = kept
	if _has_scoped(removed) or _has_scoped(accepted):
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

## `scopes`: scoped modifiers that count too (get_scoped_stat()).
func _calculate(key: StringName, scopes: Array[StringName] = []) -> float:
	var def := registry.get_definition(key)
	var is_move_speed := key == &"move_speed"
	var flat := 0.0
	var percent_add := 0.0
	var percent_mult := 1.0
	var strongest_slow := 0.0
	for mod in _modifiers:
		if mod.stat != key or (mod.is_scoped() and not scopes.has(mod.scope)):
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
	if (not mod.is_scoped() or mod.is_hit_scoped()) and not registry.has_stat(mod.stat):
		push_error("StatsComponent: modifier for unknown stat '%s' (source '%s')" % [mod.stat, mod.source_id])
		return false
	if mod.is_scoped() and not mod.is_hit_scoped():
		# An ability param (STATS.md, Scoped modifiers): a typo would otherwise
		# match nothing and silently change nothing.
		if not (mod.scope.begins_with("ability:") or mod.scope.begins_with("tag:")):
			push_error("StatsComponent: modifier for '%s' has an unknown scope '%s' (source '%s')" % [mod.stat, mod.scope, mod.source_id])
			return false
		if not _is_known_ability_param(mod.stat, mod.scope):
			push_error("StatsComponent: modifier for unknown ability param '%s' (scope '%s', source '%s')" % [mod.stat, mod.scope, mod.source_id])
			return false
	return true


## An ability param a scoped modifier may change: a number @export on the
## Ability base class (cooldown, cast_range, base_damage...), or a param
## (a subclass @export such as radius, or a scaling term's param) of an
## ability the unit holds (its AbilityComponent's slots and active REPLACE
## variants) that `scope` reaches.
func _is_known_ability_param(param: StringName, scope: StringName) -> bool:
	if Ability.is_base_param(param):
		return true
	var abilities := get_parent().get_node_or_null(^"AbilityComponent") as AbilityComponent if get_parent() else null
	if abilities == null:
		return false
	for ability in abilities.get_all_abilities():
		if ability.get_modifier_scopes().has(scope) and ability.has_param(param):
			return true
	return false


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
