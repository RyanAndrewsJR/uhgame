class_name Perch
extends Area2D
## A perch (docs/3D.md, Terrain and height 2; 3D pivot P9): an area, usually
## a plateau's top, that gives `status` (status_elevated: the tag
## &"elevated") to every unit standing in it, and takes it away when the unit
## leaves. A melee hit can't reach an elevated unit from below
## (AbilityUtil.can_reach()); from another elevated unit it can. Standing in
## means the unit's feet (its position) are inside, so a unit pressed against
## the cliff below never counts. Placed in a room built in 3D with a
## SimMarker, its size from `size_m`.
## Each perch notes its answers (3D.md, No unanswerable enemy).

const STATUS_ELEVATED: StatusEffect = preload("res://data/statuses/status_elevated.tres")

## The perch's area, meters, centered on its position.
@export var size_m: Vector2 = Vector2(4.0, 4.0)
## What standing in it gives.
@export var status: StatusEffect = STATUS_ELEVATED
## How a unit can answer an enemy perched here (walk-up routes, ranged
## answers, a dead zone), for whoever builds the room.
@export_multiline var answers: String = ""

var _inside: Dictionary = {}   # Unit -> true (keys can be freed: read untyped)


func _ready() -> void:
	collision_layer = 0
	collision_mask = (1 << 1) | (1 << 2)   # the player's and the enemies' bodies
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Units.m_to_px(size_m.x), Units.m_to_px(size_m.y))
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


func _physics_process(_delta: float) -> void:
	var rect := get_rect_px()
	var still := {}
	for body in get_overlapping_bodies():
		var unit := body as Unit
		if unit == null or not unit.is_alive() or unit.status_component == null:
			continue
		if rect.has_point(unit.global_position):
			still[unit] = true
			if not _inside.has(unit):
				unit.status_component.apply_status(status)
	for unit: Variant in _inside.keys():
		if not still.has(unit) and is_instance_valid(unit) and (unit as Unit).status_component != null:
			(unit as Unit).status_component.remove_status(status.id)
	_inside = still


## The perch's area in world px.
func get_rect_px() -> Rect2:
	var size := Vector2(Units.m_to_px(size_m.x), Units.m_to_px(size_m.y))
	return Rect2(global_position - size * 0.5, size)
