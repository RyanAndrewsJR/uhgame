class_name PickupComponent
extends Area2D
## Collects pickups on proximity (LOOT.md, Pickups; LOOT L7): an Area2D on no
## layer masking layer 9 (pickup), a circle whose radius is the unit's
## pickup_radius stat (LoL units; the Knight's 200 u = 64 px), followed live.
## A landed pickup inside it is collected at once through Loot.collect(): no
## key, no prompt, no pause in movement (Hades' currency pickups). One that
## lands while already inside is reported by the physics server on the next
## step. A child of player.tscn.

## The circle never shrinks below this (px): a champion without a pickup
## radius still collects what it walks over.
const MIN_RADIUS_PX := 1.0

## Draws the collect circle on the floor (debug).
@export var debug_draw: bool = false

var unit: Unit
var _shape: CircleShape2D


func _ready() -> void:
	unit = get_parent() as Unit
	collision_layer = 0
	collision_mask = Pickup.PICKUP_LAYER
	monitorable = false
	monitoring = true
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	# Its own circle: the scene's sub-resource is shared by every Player.
	_shape = CircleShape2D.new()
	shape_node.shape = _shape
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if debug_draw:
		visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # a floor drawing in 3D
	# The unit sets its stats up in its own _ready(), after this one.
	if unit != null and not unit.is_node_ready():
		unit.ready.connect(_attach_stats, CONNECT_ONE_SHOT)
	else:
		_attach_stats()


## The collect circle's radius now (px).
func get_radius_px() -> float:
	return _shape.radius if _shape != null else 0.0


func _attach_stats() -> void:
	if unit != null and unit.stats_component != null:
		unit.stats_component.stat_changed.connect(_on_stat_changed)
	_update_radius()


func _update_radius() -> void:
	var units := unit.stats_component.get_stat(&"pickup_radius") if unit != null and unit.stats_component != null else 0.0
	_shape.radius = maxf(Units.to_px(units), MIN_RADIUS_PX)
	queue_redraw()


func _on_stat_changed(key: StringName, _old_value: float, _new_value: float) -> void:
	if key == &"pickup_radius":
		_update_radius()


## A dead unit collects nothing, nor an item it dropped until it has walked
## away from it (L7b, Pickup's hold).
func _on_area_entered(area: Area2D) -> void:
	if area is Pickup and unit != null and unit.is_alive() and not (area as Pickup).is_held_for(unit):
		Loot.collect(area as Pickup, unit)


## Leaving a pickup this unit dropped ends its hold: coming back takes it.
func _on_area_exited(area: Area2D) -> void:
	if area is Pickup and unit != null:
		(area as Pickup).release_hold(unit)


func _draw() -> void:
	if debug_draw and _shape != null:
		draw_arc(Vector2.ZERO, _shape.radius, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, 0.6), 1.0)
