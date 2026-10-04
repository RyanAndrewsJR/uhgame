class_name ResourceComponent
extends Node
## A unit's mana, energy or fury (STATS.md). Same shape as HealthComponent.
##
## With a StatsComponent (set_stats_component(), done by Unit) the max follows
## the max_resource stat and resource_regen restores per second. When the
## max goes up, current goes up by the same amount; when it goes down,
## current is clamped.
##
## The rhythm (CHAMPIONS.md, Resource rhythms; set from ChampionData): a pool
## can start empty, and can decay while its unit is out of combat. "In
## combat" = the unit dealt or took a hit that got through (Events.unit_hit;
## DoT ticks count) within the last decay_delay seconds of game time. Every
## default changes nothing.
##
## "Resource" in design text means mana/energy/fury; on Unit this node is
## `resource_pool`, so it isn't mixed up with Godot's Resource.

signal resource_changed(current: float, maximum: float)
## current reached 0 by spending (never by decay).
signal depleted

## NONE is only used by ChampionData: a champion with NONE has this node
## removed at load (CHAMPIONS.md), so a live ResourceComponent never has it.
enum ResourceType { MANA, ENERGY, FURY, NONE }

## The bar's color and the type's name. A champion's comes from its
## ChampionData; the type's rules are the fields below.
@export var resource_type: ResourceType = ResourceType.MANA
## Used until set_stats_component() is called.
@export var max_resource: float = 100.0
## Starts at 0 instead of full (fury), and a raised max doesn't add to current.
@export var starts_empty: bool = false
## Out of combat for decay_delay seconds, current drops by this much per
## second, down to 0. 0 = no decay. A pool uses regen or decay, not both.
@export var decay_per_second: float = 0.0
## Seconds after the last hit dealt or taken before decay starts.
@export var decay_delay: float = 0.0

var current: float

var _stats: StatsComponent = null
var _since_combat: float = INF   # seconds (game time) since the last hit dealt or taken
var _gain_on_max_raise: bool = true


func _ready() -> void:
	current = 0.0 if starts_empty else max_resource
	Events.unit_hit.connect(_on_events_unit_hit)


func setup(maximum: float) -> void:
	max_resource = maximum
	current = 0.0 if starts_empty else maximum
	resource_changed.emit(current, max_resource)


## Starts full (or empty, starts_empty) with the max_resource stat; later
## changes follow it.
func set_stats_component(stats: StatsComponent) -> void:
	_stats = stats
	setup(stats.get_stat(&"max_resource"))
	stats.stat_changed.connect(_on_stats_component_stat_changed)


# --- Queries --------------------------------------------------------------------

func can_afford(amount: float) -> bool:
	return current >= amount


func is_empty() -> bool:
	return current <= 0.0


## Seconds (game time) since the unit last dealt or took a hit that got
## through; INF before the first one.
func get_time_since_combat() -> float:
	return _since_combat


## A hit dealt or taken within decay_delay seconds.
func is_in_combat() -> bool:
	return _since_combat < decay_delay


# --- Commands -------------------------------------------------------------------

## Spends amount if there's enough; false (and nothing spent) otherwise.
func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_afford(amount):
		return false
	current -= amount
	resource_changed.emit(current, max_resource)
	if current <= 0.0:
		depleted.emit()
	return true


func restore(amount: float) -> void:
	if amount <= 0.0 or current >= max_resource:
		return
	current = minf(current + amount, max_resource)
	resource_changed.emit(current, max_resource)


## While `on` is false, a raised max doesn't add to current (LOOT.md,
## Equipping: EquipmentComponent turns it off around a live gear swap, so a
## swap never refills). On by default.
func set_gain_on_max_raise(on: bool) -> void:
	_gain_on_max_raise = on


## A raised max adds the difference to current (not for starts_empty, nor
## while set_gain_on_max_raise() turned it off); a lowered max clamps it.
func set_max_resource(maximum: float) -> void:
	var gained := maximum - max_resource
	max_resource = maximum
	if gained > 0.0 and not starts_empty and _gain_on_max_raise:
		current += gained
	current = clampf(current, 0.0, max_resource)
	resource_changed.emit(current, max_resource)


func _physics_process(delta: float) -> void:
	_since_combat += delta
	if _stats != null and current < max_resource:
		var regen := _stats.get_stat(&"resource_regen")
		if regen > 0.0:
			restore(regen * delta)
	if decay_per_second > 0.0 and current > 0.0 and _since_combat >= decay_delay:
		current = maxf(current - decay_per_second * delta, 0.0)
		resource_changed.emit(current, max_resource)


func _on_events_unit_hit(ctx: HitContext) -> void:
	if ctx.blocked:
		return
	var unit := get_parent()
	if ctx.source == unit or ctx.target == unit:
		_since_combat = 0.0


func _on_stats_component_stat_changed(key: StringName, _old_value: float, new_value: float) -> void:
	if key == &"max_resource":
		set_max_resource(new_value)
