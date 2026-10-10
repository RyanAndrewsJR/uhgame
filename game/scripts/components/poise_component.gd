class_name PoiseComponent
extends Node
## A unit's poise meter (ARCHETYPES.md, Assassin; D1, D3, D8). A child of
## every enemy (slime.tscn, which every enemy scene inherits;
## Unit.poise_component), set up at spawn by Enemy._apply_enemy_data()
## (setup(): its archetype, its EnemyData.poise_max, its rank's rules).
## Since AR3a (2026-10-08) it runs for two kinds of unit:
## - an archetype with a meter (Archetype.poise_meter: the Assassin), always;
##   its size is its rank's (RankRules.poise_meter_max: regular 60, elite 100,
##   boss 160) unless its EnemyData.poise_max says otherwise (0 = none);
## - the PROTOTYPE's meters (Ryan, 2026-10-07: the elite slime's and the test
##   duelist's EnemyData.poise_max 100), only while poise_test_enabled is on
##   (off in shipped config; AR6 sets them to 0).
## Anything else (fodder, the other archetypes, the player until AR5) has
## none: every query reads 0 and nothing happens.
##
## - **It fills up to a break** (D1; Sekiro's posture): it starts at 0, and
##   take_poise_damage() raises it: a hit that gets through carrying
##   HitContext.poise_damage (Unit.on_hit() -> HitPipeline.apply_poise_damage()),
##   a deflect (DeflectComponent). After its rules' decay_delay with no poise
##   hit it decays toward 0 at decay_rate a second, × low_health_decay_scale
##   below low_health of its max health (PoiseRules).
## - At its maximum the unit is poise-broken: status_poise_broken (tags
##   poise_broken, debuff) for poise_break_time s (its rank's: regular 1.5,
##   elite 1.8, boss 1.4). Its blocks cut a cast or a windup at once and stop
##   moving, attacking, casting and dashing (StatusComponent, as for any
##   status); the unit takes break_damage_bonus more damage (×, an
##   incoming_damage PERCENT_MULT). It isn't tagged cc, so tenacity and
##   diminishing returns never touch it, and a cleanse doesn't end it. While
##   broken the meter reads full.
## - When it ends the meter is empty again, and for its rules' break_immunity
##   s poise damage does nothing (as during the break): no second break at once.
## - A hit still never flinches an enemy (ENEMIES_AI.md, Poise: no flinch):
##   the break is a separate, rare interrupt. This isn't the boss hook
##   (StatusComponent.poise, RankRules.poise), which stays off.

signal poise_changed(value: float, maximum: float)
signal poise_broken

## Values this close to the maximum or 0 are there (float residue).
const EPSILON := 0.0001
const STATUS_POISE_BROKEN: StatusEffect = preload("res://data/statuses/status_poise_broken.tres")
## The rules a meter reads when neither its export nor its archetype names one.
const DEFAULT_RULES: PoiseRules = preload("res://data/poise_rules/poise_rules_assassin.tres")

## PROTOTYPE flag, off in shipped config: the meters of units whose archetype
## has none (the elite slime's, the test duelist's) run only while it's on.
## The sandbox turns it on while it runs (SandboxDeflect, Shift+V); tests set
## it and put it back.
static var poise_test_enabled: bool = false

## The meter's size; 0 = none. Given at spawn (setup()).
@export var poise_max: float = 0.0
## Seconds the break lasts (tenacity doesn't shorten it). Given at spawn from
## its rank (RankRules.poise_break_time).
@export var poise_break_time: float = 1.8
## Its numbers (decay, the damage bonus, the immunity); null = its
## archetype's, else poise_rules_assassin.tres.
@export var rules: PoiseRules

@export_group("Presentation")
## Placeholders that never decide state. At the unit when it breaks
## (VFX.spawn_scene(): setup(unit)); null = nothing. (The status itself shows
## the stun stars while it lasts.)
@export var poise_break_vfx: PackedScene
## When it breaks (Audio). null = silent.
@export var poise_break_sound: SoundEvent

var unit: Unit
## Its unit's archetype (setup()); null = none.
var archetype: Archetype

var _poise: float = 0.0
var _decay_wait: float = 0.0
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


## At spawn (Enemy._apply_enemy_data()): `archetype_` (null = none), the
## size its data asks for (`size`: EnemyData.poise_max; −1 = its rank's when
## its archetype has a meter, else none; 0 = none) and its rank's rules
## (`rank`: the size and the break time; null = none). The meter starts empty.
func setup(archetype_: Archetype, size: float, rank: RankRules) -> void:
	archetype = archetype_
	if size < 0.0:
		size = rank.poise_meter_max if has_archetype_meter() and rank != null else 0.0
	poise_max = size
	if rank != null and rank.poise_break_time > 0.0:
		poise_break_time = rank.poise_break_time
	_poise = 0.0
	_decay_wait = 0.0


# --- Queries --------------------------------------------------------------------

## Its archetype gives it a meter (no flag needed).
func has_archetype_meter() -> bool:
	return archetype != null and archetype.poise_meter


## The meter runs for this unit: a poise_max above 0, alive, and its
## archetype has a meter or the prototype's flag is on.
func is_active() -> bool:
	return poise_max > 0.0 and unit.is_alive() and (has_archetype_meter() or poise_test_enabled)


## Its numbers: the export, else its archetype's, else poise_rules_assassin.tres.
func get_rules() -> PoiseRules:
	if rules != null:
		return rules
	if archetype != null and archetype.poise_rules != null:
		return archetype.poise_rules
	return DEFAULT_RULES


## Poise now: 0 (empty) up to get_max_poise(); full while broken; 0 when
## inactive.
func get_poise() -> float:
	if not is_active():
		return 0.0
	return minf(_poise, poise_max)


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


## Seconds before it starts to decay (0 = decaying, or empty).
func get_decay_wait() -> float:
	return _decay_wait


## Poise a second it loses while it decays now: its rules' decay_rate, ×
## low_health_decay_scale below low_health of its max health.
func get_decay_rate() -> float:
	var r := get_rules()
	var rate := r.decay_rate
	var health := unit.health
	if health != null and health.max_health > 0.0 and health.current / health.max_health < r.low_health:
		rate *= r.low_health_decay_scale
	return rate


## Seconds the break has left (0 = not broken).
func get_break_left() -> float:
	if not _broken or unit.status_component == null:
		return 0.0
	return unit.status_component.get_time_left(STATUS_POISE_BROKEN.id)


# --- Commands -------------------------------------------------------------------

## Raises poise by `amount` from `source` (null = none) and restarts the decay
## delay; at the maximum the unit breaks. Nothing while inactive, broken or
## immune.
func take_poise_damage(amount: float, source: Unit = null) -> void:
	if amount <= 0.0 or not is_active() or _broken or _immune_left > 0.0:
		return
	_poise = minf(minf(_poise, poise_max) + amount, poise_max)
	_decay_wait = get_rules().decay_delay
	_emit_changed()
	if _poise >= poise_max - EPSILON:
		_poise = poise_max
		_break(source)


## Lowers poise by `amount` (its own successful deflect: ARCHETYPES AR3b,
## PoiseRules.own_deflect_drain), not below 0; the decay delay runs on.
## Nothing while inactive or broken.
func drain_poise(amount: float) -> void:
	if amount <= 0.0 or not is_active() or _broken:
		return
	var before := minf(_poise, poise_max)
	_poise = maxf(before - amount, 0.0)
	if _poise != before:
		_emit_changed()


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _immune_left > 0.0:
		_immune_left = maxf(_immune_left - delta, 0.0)
	if _broken:
		return
	if not is_active():
		_poise = 0.0   # switched off (the flag, a size of 0): it starts empty when back
		_decay_wait = 0.0
		return
	if _decay_wait > 0.0:
		_decay_wait = maxf(_decay_wait - delta, 0.0)
		return
	if _poise > 0.0:
		_poise = maxf(minf(_poise, poise_max) - get_decay_rate() * delta, 0.0)
		if _poise <= EPSILON:
			_poise = 0.0
		_emit_changed()


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
		_poise = 0.0
		_emit_changed()
		return
	poise_broken.emit()
	Events.poise_broken.emit(unit)
	Audio.play_on(poise_break_sound, unit)
	VFX.spawn_scene(poise_break_vfx, unit, unit.global_position, 0.0, [unit])


## status_poise_broken with the damage bonus now (a copy per value, so the
## sandbox can tune it live).
func _get_status() -> StatusEffect:
	var bonus := get_rules().break_damage_bonus
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
	_poise = 0.0
	_decay_wait = 0.0
	_immune_left = get_rules().break_immunity
	_emit_changed()


func _emit_changed() -> void:
	poise_changed.emit(_poise, poise_max)
	Events.poise_changed.emit(unit, _poise, poise_max)
