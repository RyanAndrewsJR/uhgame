class_name HealthComponent
extends Node
## Tracks hit points for anything that can be damaged.
##
## With a StatsComponent (set_stats_component(), done by Unit) the max follows
## the max_health stat and health_regen heals per second (STATS.md). When the
## max goes up, current goes up by the same amount; when it goes down,
## current is clamped.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current: float

var _stats: StatsComponent = null
var _gain_on_max_raise: bool = true


func _ready() -> void:
	current = max_health


func setup(maximum: float) -> void:
	max_health = maximum
	current = maximum
	health_changed.emit(current, max_health)


## Starts at full health with the max_health stat; later changes follow it.
func set_stats_component(stats: StatsComponent) -> void:
	_stats = stats
	setup(stats.get_stat(&"max_health"))
	stats.stat_changed.connect(_on_stats_component_stat_changed)


## While `on` is false, a raised max doesn't add to current (LOOT.md,
## Equipping: EquipmentComponent turns it off around a live gear swap, so a
## swap never heals). On by default.
func set_gain_on_max_raise(on: bool) -> void:
	_gain_on_max_raise = on


## A raised max adds the difference to current (unless set_gain_on_max_raise()
## turned that off); a lowered max clamps it.
func set_max_health(maximum: float) -> void:
	var gained := maximum - max_health
	max_health = maximum
	if is_dead():
		health_changed.emit(current, max_health)
		return
	if gained > 0.0 and _gain_on_max_raise:
		current += gained
	current = minf(current, max_health)
	health_changed.emit(current, max_health)


func _physics_process(delta: float) -> void:
	if _stats == null or is_dead() or current >= max_health:
		return
	var regen := _stats.get_stat(&"health_regen")
	if regen > 0.0:
		heal(regen * delta)


func _on_stats_component_stat_changed(key: StringName, _old_value: float, new_value: float) -> void:
	if key == &"max_health":
		set_max_health(new_value)


func take_damage(amount: float) -> void:
	if is_dead():
		return
	current = maxf(current - amount, 0.0)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if is_dead():
		return
	current = minf(current + amount, max_health)
	health_changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0.0
