class_name Room
extends Node2D
## Base script for hand-built rooms.
##
## Required children:
##   Tiles        - TileMapLayer (walls need collision on physics layer 1)
##   Entities     - y-sorted Node2D; put enemies here
##   PlayerSpawn  - Marker2D
##
## Pathfinding is baked automatically from the wall collision when the room
## loads, so you can repaint walls freely without re-baking anything.
##
## A room built in 3D (RoomLayout.build_sim(), docs/3D.md, Rooms) has no
## Tiles: its walls, low obstacles and pits are StaticBody2Ds under a
## Footprints node (in the group navigation_source), and it gives its floor
## as bounds_px.

## What carves the navigation: walls (layer 1), pits (6), low obstacles (7)
## and ledges (11). A tile room has only walls.
const NAV_BLOCKING_LAYERS := 1 | (1 << 5) | (1 << 6) | (1 << 10)

## How far paths stay away from walls, in pixels. Should be a bit larger
## than the biggest unit's collision radius.
@export var nav_agent_radius: float = 12.0
## The room's floor in px, for a room without Tiles (a room built in 3D sets
## it from its walkable ground). A tile room's floor is its used tiles.
@export var bounds_px: Rect2 = Rect2()

@onready var tiles: TileMapLayer = get_node_or_null(^"Tiles") as TileMapLayer

var nav_region: NavigationRegion2D


func _ready() -> void:
	_bake_navigation()


## The room's floor in px: the used tiles' rectangle, or bounds_px without
## Tiles. The navigation bake's outline and the camera's bounds.
func get_bounds_px() -> Rect2:
	var t := tiles if tiles else get_node_or_null(^"Tiles") as TileMapLayer
	if t == null:
		return bounds_px
	var rect := t.get_used_rect()
	var ts := t.tile_set.tile_size
	var top_left := t.to_global(t.map_to_local(rect.position) - Vector2(ts) * 0.5)
	var bottom_right := t.to_global(t.map_to_local(rect.end) - Vector2(ts) * 0.5)
	return Rect2(top_left, bottom_right - top_left)


func _bake_navigation() -> void:
	var bounds := get_bounds_px()

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = nav_agent_radius
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = NAV_BLOCKING_LAYERS
	nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_poly.source_geometry_group_name = &"navigation_source"
	nav_poly.add_outline(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))

	if tiles:
		tiles.add_to_group(&"navigation_source")

	nav_region = NavigationRegion2D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
	nav_region.bake_navigation_polygon(false)
