extends Control
## The player's mana / energy / fury bar (ABILITIES.md, HUD feedback): a thin
## bar just under the ability bar, colored by resource type, with the current
## amount. Flashes for flash_time when a cast fails for "not enough resource".
## Added by hud.gd's setup_resource() only for a player with a resource pool.

const WIDTH := 132.0   # the ability bar's width (4 slots of 30 + 3 gaps of 4)
const HEIGHT := 4.0
const TYPE_COLORS := {
	ResourceComponent.ResourceType.MANA: Color(0.35, 0.6, 1.0),
	ResourceComponent.ResourceType.ENERGY: Color(1.0, 0.85, 0.3),
	ResourceComponent.ResourceType.FURY: Color(0.95, 0.3, 0.25),
}

## Seconds the bar flashes on a "not enough resource" cast (ABILITIES.md, Numbers).
@export var flash_time: float = 0.2

var pool: ResourceComponent
var abilities: AbilityComponent

var _flash_left: float = 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = -HEIGHT - 2.0
	offset_bottom = -2.0
	if abilities != null:
		abilities.cast_failed.connect(_on_abilities_cast_failed)


func is_flashing() -> bool:
	return _flash_left > 0.0


func _on_abilities_cast_failed(_slot: StringName, reason: String) -> void:
	if reason == AbilityComponent.FAIL_NO_RESOURCE:
		_flash_left = flash_time


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if pool == null or not is_instance_valid(pool):
		return
	var fraction := clampf(pool.current / maxf(pool.max_resource, 0.001), 0.0, 1.0)
	var color: Color = TYPE_COLORS.get(pool.resource_type, Color(0.35, 0.6, 1.0))
	var back := Color(0.05, 0.05, 0.08, 0.85)
	if _flash_left > 0.0:
		# Blink: bright on the first and last thirds of the flash.
		var t := _flash_left / maxf(flash_time, 0.001)
		if t > 0.66 or t < 0.33:
			back = Color(1, 1, 1, 0.9)
	draw_rect(Rect2(Vector2.ZERO, size).grow(1), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), back)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fraction, size.y)), color)
	draw_string(_font, Vector2(size.x + 4, size.y + 1), "%d" % floori(pool.current),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(color, 0.95))
