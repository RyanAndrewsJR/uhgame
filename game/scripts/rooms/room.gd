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

## How far paths stay away from walls, in pixels. Should be a bit larger
## than the biggest unit's collision radius.
@export var nav_agent_radius: float = 12.0

@onready var tiles: TileMapLayer = $Tiles

var nav_region: NavigationRegion2D


func _ready() -> void:
	_bake_navigation()


func _bake_navigation() -> void:
	var rect := tiles.get_used_rect()
	var ts := tiles.tile_set.tile_size
	var top_left := tiles.to_global(tiles.map_to_local(rect.position) - Vector2(ts) * 0.5)
	var bottom_right := tiles.to_global(tiles.map_to_local(rect.end) - Vector2(ts) * 0.5)

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = nav_agent_radius
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = 1
	nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_poly.source_geometry_group_name = &"navigation_source"
	nav_poly.add_outline(PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y),
	]))

	tiles.add_to_group(&"navigation_source")

	nav_region = NavigationRegion2D.new()
	nav_region.name = "Navigation"
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
	nav_region.bake_navigation_polygon(false)
