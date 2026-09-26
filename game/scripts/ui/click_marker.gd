extends Node2D
## LoL-style move-click indicator: four arrows that snap inward and fade.

@export var color: Color = Color(0.35, 1.0, 0.45)
@export var lifetime: float = 0.35
@export var start_radius: float = 16.0
@export var end_radius: float = 4.0

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta / lifetime
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var ease_t := 1.0 - pow(1.0 - _t, 3.0)
	var r := lerpf(start_radius, end_radius, ease_t)
	var c := color
	c.a = 1.0 - _t * _t
	# Squash vertically so it reads as lying on the floor.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	for i in 4:
		var dir := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
		var tip := dir * r
		var side := dir.orthogonal() * 3.0
		var back := dir * (r + 5.0)
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), c)
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 16, Color(c, c.a * 0.5), 1.0)
