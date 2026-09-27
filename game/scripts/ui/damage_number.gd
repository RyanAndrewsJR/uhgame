extends Label
## Floating number above a unit that pops in, rises and fades (COMBAT.md,
## Damage numbers). Unit sets it up from a hit (Unit._spawn_hit_number()).
## Look and motion come from `style` (DamageNumberStyle).

const DEFAULT_STYLE: DamageNumberStyle = preload("res://data/damage_number_styles/damage_number_style_default.tres")

enum Kind { DAMAGE, CRIT, DOT, HEAL, SHIELD }

var style: DamageNumberStyle = DEFAULT_STYLE
var kind: Kind = Kind.DAMAGE
var amount: float = 0.0
var color: Color = Color.WHITE
## 0 = worked out from the amount and kind.
var font_size: int = 0
## Kept from before C6: the old path (Unit._spawn_damage_number) sets these.
var big: bool = false

var _age: float = 0.0


func _ready() -> void:
	z_index = 100
	if font_size <= 0:
		font_size = _pick_font_size()
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color",
		style.crit_outline_color if kind == Kind.CRIT else style.outline_color)
	add_theme_constant_override("outline_size", style.outline_size)
	if kind == Kind.CRIT and style.crit_font:
		add_theme_font_override("font", style.crit_font)
	_update_text()
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(48, font_size + 4)
	pivot_offset = size * 0.5
	position -= size * 0.5
	scale = Vector2.ONE * style.pop_scale
	var drift := Vector2(randf_range(-style.spread_px, style.spread_px) * 0.5, -style.rise_px)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	tween.parallel().tween_property(self, "position", position + drift, style.lifetime) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "modulate:a", 0.0, style.lifetime * 0.5).set_delay(style.lifetime * 0.5)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta


## Seconds since it appeared (for merging DoT ticks).
func get_age() -> float:
	return _age


## A DoT tick on the same target: add it to this number.
func add_amount(extra: float) -> void:
	amount += extra
	_update_text()
	scale = Vector2.ONE * 1.15
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.08)


func _update_text() -> void:
	var shown := str(roundi(amount))
	match kind:
		Kind.CRIT:
			shown += style.crit_suffix
		Kind.HEAL:
			shown = "+" + shown
	text = shown


func _pick_font_size() -> int:
	match kind:
		Kind.DOT:
			return style.dot_font_size
		Kind.CRIT:
			return style.get_font_size(amount) + style.crit_size_bonus
	if big:
		return 13   # the old ability highlight (pre-C6 path)
	return style.get_font_size(amount)
