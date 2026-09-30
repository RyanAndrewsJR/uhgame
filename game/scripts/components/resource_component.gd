class_name ResourceComponent
extends Node
## A unit's mana, energy or fury (STATS.md). Same shape as HealthComponent.
##
## With a StatsComponent (set_stats_component(), done by Unit) the max follows
## the max_resource stat and resource_regen restores per second. When the
## max goes up, current goes up by the same amount; when it goes down,
## current is clamped.
##
## "Resource" in design text means mana/energy/fury; on Unit this node is
## `resource_pool`, so it isn't mixed up with Godot's Resource.

signal resource_changed(current: float, maximum: float)
## current reached 0 by spending.
signal depleted

## NONE is only used by ChampionData: a champion with NONE has this node
## removed at load (CHAMPIONS.md), so a live ResourceComponent never has it.
enum ResourceType { MANA, ENERGY, FURY, NONE }

## Only a label for now. A champion's comes from its ChampionData
## (CHAMPIONS.md); type rules (fury decay, energy caps) come with CH3.
@export var resource_type: ResourceType = ResourceType.MANA
## Used until set_stats_component() is called.
@export var max_resource: float = 100.0

var current: float

var _stats: StatsComponent = null


func _ready() -> void:
	current = max_resource


func setup(maximum: float) -> void:
	max_resource = maximum
	current = maximum
	resource_changed.emit(current, max_resource)


## Starts full with the max_resource stat; later changes follow it.
func set_stats_component(stats: StatsComponent) -> void:
	_stats = stats
	setup(stats.get_stat(&"max_resource"))
	stats.stat_changed.connect(_on_stats_component_stat_changed)


# --- Queries --------------------------------------------------------------------

func can_afford(amount: float) -> bool:
	return current >= amount


func is_empty() -> bool:
	return current <= 0.0


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


## A raised max adds the difference to current; a lowered max clamps it.
func set_max_resource(maximum: float) -> void:
	var gained := maximum - max_resource
	max_resource = maximum
	if gained > 0.0:
		current += gained
	current = clampf(current, 0.0, max_resource)
	resource_changed.emit(current, max_resource)


func _physics_process(delta: float) -> void:
	if _stats == null or current >= max_resource:
		return
	var regen := _stats.get_stat(&"resource_regen")
	if regen > 0.0:
		restore(regen * delta)


func _on_stats_component_stat_changed(key: StringName, _old_value: float, new_value: float) -> void:
	if key == &"max_resource":
		set_max_resource(new_value)
