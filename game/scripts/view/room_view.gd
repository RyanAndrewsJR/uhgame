class_name RoomView
extends Node3D
## The look of a tile room under the 3D view (docs/3D.md, The room's look):
## 3D pivot P3, minimal scaffolding, not polished. Rooms built in 3D
## (RoomLayout, P8) are their own look; this one is generated from a tile
## room's Tiles: a flat floor (a quad per floor cell, in a checker so movement
## reads; `walkable`, with its trimesh for the floor pick since P5), a box per
## wall cell (each in the `fades` group), the environment, and the key light
## with its shadows. View only: the sim never reads it.
## P7: the floor's shader lays the floor drawings on it (FloorOverlay).

const FADE_SHADER := preload("res://scripts/view/fade_dither.gdshader")
const FLOOR_SHADER := preload("res://scripts/view/floor_drawings.gdshader")

## How tall the wall boxes are, in meters (Ryan's 2.2 m after P0b). In rooms
## built in 3D, walls are assets with their own heights (P8).
@export var wall_height_m: float = 2.2
@export var wall_color: Color = Color(0.46, 0.43, 0.50)
## Floor cells alternate between these two colors.
@export var floor_color_a: Color = Color(0.30, 0.29, 0.33)
@export var floor_color_b: Color = Color(0.35, 0.34, 0.38)

@export_group("Environment and light")
@export var background_color: Color = Color(0.035, 0.035, 0.045)
@export var ambient_color: Color = Color(0.5, 0.53, 0.62)
@export var ambient_energy: float = 0.6
## The way the key light shines. From the north-west and above, so shadows
## fall toward the bottom right of the screen.
@export var key_light_direction: Vector3 = Vector3(1.0, -1.7, 0.8)
@export var key_light_energy: float = 1.2
## Shadows are drawn up to this far from the camera, in meters (the default
## look sees floor up to about 40 m away).
@export var shadow_max_distance_m: float = 50.0

## Filled by build().
var walls: Array[MeshInstance3D] = []
var floor_mesh: MeshInstance3D
## The floor's material (floor_drawings.gdshader: its checker colors plus the
## floor drawings, P7).
var floor_material: ShaderMaterial
## The floor pick's body (P5): the floor mesh's trimesh on 3D layer 1.
var floor_body: StaticBody3D
var floor_cell_count: int = 0
var environment: WorldEnvironment
var key_light: DirectionalLight3D


func _init() -> void:
	name = "RoomView"


## Builds the look from a tile room's Tiles (in the tree). A wall is a cell
## whose tile has a collision polygon on the TileSet's physics layer 0 (the
## world layer); every other used cell is floor. Positions go through the
## Tiles' transform and Units.
func build(tiles: TileMapLayer) -> void:
	_build_environment()
	var tile := Vector2(tiles.tile_set.tile_size)
	var half := tile * 0.5
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(Units.px_to_m(tile.x), wall_height_m, Units.px_to_m(tile.y))
	var wall_material := ShaderMaterial.new()
	wall_material.shader = FADE_SHADER
	wall_material.set_shader_parameter(&"albedo", wall_color)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in tiles.get_used_cells():
		var data := tiles.get_cell_tile_data(cell)
		var center := tiles.map_to_local(cell)
		if data != null and data.get_collision_polygons_count(0) > 0:
			var wall := MeshInstance3D.new()
			wall.name = "Wall_%d_%d" % [cell.x, cell.y]
			wall.mesh = wall_mesh
			wall.material_override = wall_material
			wall.position = Units.to_view(tiles.to_global(center), wall_height_m * 0.5)
			wall.add_to_group(&"fades")
			add_child(wall)
			walls.append(wall)
		else:
			var color := floor_color_a if posmod(cell.x + cell.y, 2) == 0 else floor_color_b
			# North-west, north-east, south-east, south-west: clockwise seen
			# from above, which is a front face facing up.
			var corners: Array[Vector3] = [
				Units.to_view(tiles.to_global(center + Vector2(-half.x, -half.y))),
				Units.to_view(tiles.to_global(center + Vector2(half.x, -half.y))),
				Units.to_view(tiles.to_global(center + Vector2(half.x, half.y))),
				Units.to_view(tiles.to_global(center + Vector2(-half.x, half.y))),
			]
			_add_floor_quad(st, corners, color)
			floor_cell_count += 1

	if floor_cell_count > 0:
		# P3's plain StandardMaterial3D (vertex colors, roughness 0.95) became
		# this shader in P7: the same look, plus the floor drawings.
		floor_material = ShaderMaterial.new()
		floor_material.shader = FLOOR_SHADER
		floor_material.set_shader_parameter(&"roughness", 0.95)
		floor_mesh = MeshInstance3D.new()
		floor_mesh.name = "Floor"
		floor_mesh.mesh = st.commit()
		floor_mesh.material_override = floor_material
		floor_mesh.add_to_group(&"walkable")
		add_child(floor_mesh)
		_build_floor_pick()


## The walkable ground for the floor pick (P5): a view-only trimesh of the
## floor mesh on 3D physics layer 1 (WorldView.FLOOR_LAYER). Wall cells have
## no floor, so a ray through a wall box goes on to the floor behind it, or
## to the plane past the room (WorldView.floor_at_screen_px()).
func _build_floor_pick() -> void:
	var shape := floor_mesh.mesh.create_trimesh_shape()
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	floor_body = StaticBody3D.new()
	floor_body.name = "FloorPick"
	floor_body.collision_layer = WorldView.FLOOR_LAYER
	floor_body.collision_mask = 0
	floor_body.add_child(col)
	add_child(floor_body)


func _add_floor_quad(st: SurfaceTool, corners: Array[Vector3], color: Color) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_color(color)
		st.add_vertex(corners[i])


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	environment = WorldEnvironment.new()
	environment.name = "Environment"
	environment.environment = env
	add_child(environment)

	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = key_light_energy
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = shadow_max_distance_m
	key_light.basis = Basis.looking_at(key_light_direction.normalized())   # a light shines along its -z
	add_child(key_light)
