class_name Telegraph
extends Node2D
## A floor warning for an enemy attack (COMBAT.md): the shape's outline shows
## where the hit lands, and its fill grows until the hit. VFX only: the
## ability's own query decides what gets hit.
##
## Drawn as a true circle (not squashed for the 3/4 view), so it matches the
## hit area exactly. Placed on the room's floor, under every unit. A line
## (ABILITIES AB13, VECTOR casts) is a band from its start whose fill grows
## along its length.
## A telegraph that belongs to a cast fills with the cast's progress
## (set_progress(), ABILITIES AB14); one without a cast uses its own clock.

## One consistent enemy-threat color (COMBAT.md, FREE which).
const THREAT_COLOR := Color(1.0, 0.35, 0.15)

var radius_px: float = 40.0
var duration: float = 0.75
var color: Color = THREAT_COLOR
## A line telegraph (line()): from this node's position to here, px. ZERO =
## a circle.
var line_vector: Vector2 = Vector2.ZERO
## A line telegraph's full width, px.
var width_px: float = 0.0

var _elapsed: float = 0.0
var _sound_handle: int = 0
var _finishing: bool = false
var _flash: float = 0.0
## ABILITIES AB14: set_progress() drives the fill (the cast's progress) and
## the telegraph's own clock is ignored from then on.
var _driven: bool = false
var _driven_before: float = 0.0   # the progress one physics tick ago
var _driven_now: float = 0.0      # the progress this physics tick


## A circle telegraph centered on `center` (world space) that fills over
## `duration` seconds. `anchor` is any node in the world (usually the
## caster): the telegraph goes on the room's floor next to it.
static func circle(anchor: Node2D, center: Vector2, radius: float, time: float, tint: Color = THREAT_COLOR) -> Telegraph:
	var t := Telegraph.new()
	t.radius_px = radius
	t.duration = maxf(time, 0.01)
	t.color = tint
	_add_to_floor(anchor, t)
	t.global_position = center
	return t


## A line telegraph from `start` to `end` (world space), `width` px wide,
## that fills from the start over `time` seconds (ABILITIES AB13). `anchor`
## as for circle().
static func line(anchor: Node2D, start: Vector2, end: Vector2, width: float, time: float, tint: Color = THREAT_COLOR) -> Telegraph:
	var t := Telegraph.new()
	t.line_vector = end - start
	t.width_px = width
	t.duration = maxf(time, 0.01)
	t.color = tint
	_add_to_floor(anchor, t)
	t.global_position = start
	return t


## Under the units: as a child of the room, just before its Entities node
## (like the click marker). Without a room, next to the anchor.
static func _add_to_floor(anchor: Node2D, t: Telegraph) -> void:
	var entities := anchor.get_parent()
	var room := entities.get_parent() if entities else null
	if room is Node2D and entities.name == &"Entities":
		room.add_child(t)
		room.move_child(t, entities.get_index())
	else:
		t.z_index = -1
		entities.add_child(t)


## Plays the cast's wind-up here (AUDIO.md). It stops when the telegraph
## finishes or is freed (a cancelled or interrupted cast). null = silent.
func play_sound(event: SoundEvent) -> void:
	Audio.stop(_sound_handle)
	_sound_handle = Audio.play_on(event, self)


## The hit happened: a short bright flash, then gone.
func finish() -> void:
	Audio.stop(_sound_handle)   # the hit sound takes over
	_sound_handle = 0
	_finishing = true
	_flash = 0.12
	queue_redraw()


## Fills the telegraph to `p` (0-1), the progress of the cast it belongs to
## (ABILITIES AB14; AbilityComponent calls it each physics tick of the cast
## time). From the first call the telegraph's own clock (`duration`) is
## ignored, so it stays in step with the cast whatever the cast speed. It's
## drawn between the last two ticks (physics interpolation), so it fills
## smoothly on any refresh rate.
func set_progress(p: float) -> void:
	p = clampf(p, 0.0, 1.0)
	if not _driven:
		_driven = true
		_driven_before = p
	else:
		_driven_before = _driven_now
	_driven_now = p
	queue_redraw()


## True once set_progress() drives it (it belongs to a cast).
func is_driven() -> bool:
	return _driven


## 0..1: how full the telegraph is: its cast's progress when driven
## (set_progress(); read during a physics frame it's the exact value, while
## drawing it's interpolated between the last two ticks), else its own clock.
func get_progress() -> float:
	if _driven:
		if Engine.is_in_physics_frame():
			return _driven_now
		return clampf(lerpf(_driven_before, _driven_now, Engine.get_physics_interpolation_fraction()), 0.0, 1.0)
	return clampf(_elapsed / duration, 0.0, 1.0)


func _process(delta: float) -> void:
	if _finishing:
		_flash -= delta
		if _flash <= 0.0:
			queue_free()
	elif not _driven:
		_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if line_vector != Vector2.ZERO:
		_draw_line_shape()
		return
	if _finishing:
		draw_circle(Vector2.ZERO, radius_px, Color(color, 0.6 * clampf(_flash / 0.12, 0.0, 1.0)))
		return
	draw_circle(Vector2.ZERO, radius_px, Color(color, 0.12))
	draw_circle(Vector2.ZERO, radius_px * get_progress(), Color(color, 0.35))
	draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 48, Color(color, 0.9), 1.0)


## The line: a band from the start, the fill growing along it.
func _draw_line_shape() -> void:
	if _finishing:
		draw_colored_polygon(_band(1.0), Color(color, 0.6 * clampf(_flash / 0.12, 0.0, 1.0)))
		return
	draw_colored_polygon(_band(1.0), Color(color, 0.12))
	if get_progress() > 0.0:
		draw_colored_polygon(_band(get_progress()), Color(color, 0.35))
	var outline := _band(1.0)
	outline.append(outline[0])
	draw_polyline(outline, Color(color, 0.9), 1.0)


## The band's corners from the start to `fraction` of its length (local).
func _band(fraction: float) -> PackedVector2Array:
	var side := line_vector.normalized().orthogonal() * width_px * 0.5
	var end := line_vector * fraction
	return PackedVector2Array([side, end + side, end - side, -side])
