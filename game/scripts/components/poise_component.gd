class_name PoiseComponent
extends Node
## PROTOTYPE (Ryan, 2026-10-07; tuning expected): an enemy's poise meter. A
## child of every enemy (slime.tscn, which every enemy scene inherits;
## Unit.poise_component). poise_max comes from its EnemyData at spawn
## (Enemy._apply_enemy_data(); 0 = no poise, the default: fodder, regulars
## and the player have none). Everything here sits behind poise_test_enabled,
## off in shipped config: then every poise_max acts as 0 and nothing happens.
##
## - Poise starts full and goes down by take_poise_damage(): a hit that gets
##   through carrying HitContext.poise_damage (Unit.on_hit() ->
##   HitPipeline.apply_poise_damage()), a deflect (DeflectComponent).
##   poise_regen_delay s after the last poise damage it fills back at
##   poise_regen_rate per second.
## - At 0 the unit is poise-broken: status_poise_broken (tags poise_broken,
##   debuff) for poise_break_time s. Its blocks cut a cast or a windup at once
##   and stop moving, attacking, casting and dashing (StatusComponent, as for
##   any status); the unit takes poise_break_damage_bonus more damage (×, an
##   incoming_damage PERCENT_MULT). It isn't tagged cc, so tenacity and
##   diminishing returns never touch it, and a cleanse doesn't end it.
## - When it ends poise is full again, and for poise_break_immunity s poise
##   damage does nothing (as during the break): no second break at once.
## - A hit still never flinches an enemy (ENEMIES_AI.md, Poise: no flinch):
##   the break is a separate, rare interrupt. This isn't the boss hook
##   (StatusComponent.poise, RankRules.poise), which stays off.

signal poise_changed(value: float, maximum: float)
signal poise_broken

## Values at or below this are 0 (float residue).
const EPSILON := 0.0001
const STATUS_POISE_BROKEN: StatusEffect = preload("res://data/statuses/status_poise_broken.tres")

## PROTOTYPE flag, off in shipped config. The sandbox turns it on while it
## runs (SandboxDeflect, Shift+V); tests set it and put it back.
static var poise_test_enabled: bool = false

## The meter's size; 0 = none. Enemy._apply_enemy_data() copies
## EnemyData.poise_max here at spawn.
@export var poise_max: float = 0.0
## Seconds after the last poise damage before it fills back.
@export var poise_regen_delay: float = 3.0
## Poise per second while it fills back.
@export var poise_regen_rate: float = 15.0
## Seconds the break lasts (tenacity doesn't shorten it).
@export var poise_break_time: float = 1.8
## Extra damage taken while broken: 0.5 = ×1.5.
@export var poise_break_damage_bonus: float = 0.5
## Seconds after a break during which poise damage does nothing.
@export var poise_break_immunity: float = 4.0

var unit: Unit

var _poise: float = 0.0
var _filled_for: float = -1.0   # the poise_max the meter was last filled for
var _regen_wait: float = 0.0
var _immune_left: float = 0.0
var _broken: bool = false
var _status_cache: Dictionary = {}   # damage bonus -> its status_poise_broken copy


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "PoiseComponent must be a child of a Unit")
	# Unit's @onready status_component is only set once the Unit itself is ready.
	if unit.is_node_ready():
		_on_unit_ready()
	else:
		unit.ready.connect(_on_unit_ready, CONNECT_ONE_SHOT)


func _on_unit_ready() -> void:
	if unit.status_component != null:
		unit.status_component.status_removed.connect(_on_status_removed)


# --- Queries --------------------------------------------------------------------

## The meter runs for this unit: the flag on, a poise_max above 0, alive.
func is_active() -> bool:
	return poise_test_enabled and poise_max > 0.0 and unit.is_alive()


## Poise now (0 when inactive).
func get_poise() -> float:
	if not is_active():
		return 0.0
	_fill_if_new()
	return _poise


## The meter's size now (0 when inactive: poise_max acts as 0).
func get_max_poise() -> float:
	return poise_max if is_active() else 0.0


## Poise-broken now (status_poise_broken on the unit).
func is_broken() -> bool:
	return _broken


## After a break: poise damage does nothing for a while.
func is_immune() -> bool:
	return _immune_left > 0.0


func get_immunity_left() -> float:
	return _immune_left


## Seconds before it starts filling back (0 = filling, or full).
func get_regen_wait() -> float:
	return _regen_wait


## Seconds the break has left (0 = not broken).
func get_break_left() -> float:
	if not _broken or unit.status_component == null:
		return 0.0
	return unit.status_component.get_time_left(STATUS_POISE_BROKEN.id)


# --- Commands -------------------------------------------------------------------

## Lowers poise by `amount` from `source` (null = none) and restarts the
## regen delay; at 0 the unit breaks. Nothing while inactive, broken or
## immune.
func take_poise_damage(amount: float, source: Unit = null) -> void:
	if amount <= 0.0 or not is_active() or _broken or _immune_left > 0.0:
		return
	_fill_if_new()
	_poise = maxf(_poise - amount, 0.0)
	_regen_wait = poise_regen_delay
	_emit_changed()
	if _poise <= EPSILON:
		_poise = 0.0
		_break(source)


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _immune_left > 0.0:
		_immune_left = maxf(_immune_left - delta, 0.0)
	if not is_active() or _broken:
		return
	_fill_if_new()
	if _regen_wait > 0.0:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		return
	if _poise < poise_max:
		_poise = minf(_poise + poise_regen_rate * delta, poise_max)
		_emit_changed()


## The meter fills when it first runs, and again when poise_max changes
## (spawn, the sandbox's panel).
func _fill_if_new() -> void:
	if _filled_for != poise_max:
		_filled_for = poise_max
		_poise = poise_max


func _break(source: Unit) -> void:
	var statuses := unit.status_component
	if statuses == null:
		return
	var status := _get_status()
	var from: Unit = source if is_instance_valid(source) else null
	_broken = true
	# An untargetable unit refuses statuses from others: then it breaks by itself.
	if not statuses.apply_status(status, from, poise_break_time) and not statuses.apply_status(status, null, poise_break_time):
		_broken = false
		_poise = poise_max
		_emit_changed()
		return
	poise_broken.emit()
	Events.poise_broken.emit(unit)


## status_poise_broken with the damage bonus now (a copy per value, so the
## sandbox can tune it live).
func _get_status() -> StatusEffect:
	var bonus := poise_break_damage_bonus
	if _status_cache.has(bonus):
		return _status_cache[bonus]
	var copy: StatusEffect = STATUS_POISE_BROKEN.duplicate()
	var mods: Array[StatModifier] = []
	if bonus != 0.0:
		mods.append(StatModifier.create(&"incoming_damage", StatModifier.Type.PERCENT_MULT, bonus, copy.get_source_id()))
	copy.modifiers = mods
	_status_cache[bonus] = copy
	return copy


func _on_status_removed(effect: StatusEffect) -> void:
	if effect.id != STATUS_POISE_BROKEN.id or not _broken:
		return
	_broken = false
	_poise = poise_max
	_filled_for = poise_max
	_regen_wait = 0.0
	_immune_left = poise_break_immunity
	_emit_changed()


func _emit_changed() -> void:
	poise_changed.emit(_poise, poise_max)
	Events.poise_changed.emit(unit, _poise, poise_max)
