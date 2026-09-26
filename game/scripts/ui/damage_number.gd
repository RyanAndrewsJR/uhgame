extends Label
## Floating damage number that pops up, drifts and fades.

var color: Color = Color.WHITE
var big: bool = false


func _ready() -> void:
	z_index = 100
	add_theme_font_size_override("font_size", 13 if big else 10)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 3)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(40, 14)
	pivot_offset = size * 0.5
	position -= size * 0.5
	scale = Vector2(1.4, 1.4)
	var drift := Vector2(randf_range(-8, 8), -18)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(self, "position", position + drift, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
