extends Node2D
## LoL-style health bar floating above a unit, with a tick every 100 HP and
## a lighter "recent damage" chunk that drains away after a hit.

@export var width: float = 36.0
@export var height: float = 4.0
@export var fill_color: Color = Color(0.85, 0.2, 0.2)
@export var hp_per_tick: float = 100.0

var _current: float = 1.0
var _maximum: float = 1.0
var _trail: float = 1.0


func _ready() -> void:
	z_index = 90
	var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.health_changed.connect(_on_health_changed)
		_maximum = health.max_health
		_current = health.current
		_trail = _current


func _on_health_changed(current: float, maximum: float) -> void:
	_current = current
	_maximum = maximum
	queue_redraw()


func _process(delta: float) -> void:
	if _trail > _current:
		_trail = move_toward(_trail, _current, _maximum * 0.6 * delta)
		queue_redraw()
	elif _trail < _current:
		_trail = _current


func _draw() -> void:
	var x := -width * 0.5
	var ratio := clampf(_current / _maximum, 0.0, 1.0)
	var trail_ratio := clampf(_trail / _maximum, 0.0, 1.0)
	draw_rect(Rect2(x - 1, -1, width + 2, height + 2), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(x, 0, width * trail_ratio, height), Color(1, 0.9, 0.6, 0.9))
	draw_rect(Rect2(x, 0, width * ratio, height), fill_color)
	if hp_per_tick > 0.0 and _maximum > hp_per_tick:
		var ticks := int(_maximum / hp_per_tick)
		for i in range(1, ticks + 1):
			var tx := x + width * (i * hp_per_tick / _maximum)
			if tx < x + width - 0.5:
				draw_line(Vector2(tx, 0), Vector2(tx, height * 0.6), Color(0, 0, 0, 0.7), 1.0)
