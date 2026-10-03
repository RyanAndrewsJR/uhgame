extends Node3D
## P0b feel spike (throwaway; branch spike/3d-p0b, never merged).
## The sandbox's look, built from its tile data: the floor, cutaway walls,
## three tall things standing on existing wall cells (a pillar, a plateau, a
## house; the sim is untouched) and four braziers. The floor is flat: P0b is
## about the look, P0a proved the terrain.

## Tall things on the sandbox's wall cells (cells; 1 cell = 1 m).
const Look := preload("res://scripts/spike/p0b_look.gd")

const PILLAR_CELL := Vector2i(9, 6)
const PLATEAU_RECT := Rect2i(19, 7, 2, 3)
const HOUSE_RECT := Rect2i(22, 7, 3, 3)
const BRAZIER_CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(16, 5), Vector2i(25, 10), Vector2i(23, 17)]
const PLATEAU_HEIGHT := 2.0
const HOUSE_WALL := 2.6
const HOUSE_RIDGE := 4.3
const PILLAR_HEIGHT := 3.9

var look: Look
var rect: Rect2i
## Tall things: {"root": Node3D, "aabb": AABB, "geos": Array, "fade": float}
var tall_things: Array = []
## Brazier lights: {"light": OmniLight3D, "flame": MeshInstance3D, "energy": float, "phase": float}
var torches: Array = []

var _walls: Dictionary = {}       # Vector2i -> true (sim wall cells)
var _tall_cells: Dictionary = {}  # Vector2i -> true (wall cells a tall thing stands on)
var _wall_sides: MeshInstance3D
var _wall_caps: MeshInstance3D
var _noise := FastNoiseLite.new()


func build(tiles: TileMapLayer, p_look: Look, wall_height: float) -> void:
	look = p_look
	rect = tiles.get_used_rect()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			var data := tiles.get_cell_tile_data(c)
			if data != null and data.get_collision_polygons_count(0) > 0:
				_walls[c] = true
	_noise.seed = 7
	_noise.frequency = 1.4
	_build_floor()
	if _all_walls(Rect2i(PILLAR_CELL, Vector2i.ONE)):
		_mark_tall(Rect2i(PILLAR_CELL, Vector2i.ONE))
		_build_pillar(Vector2(PILLAR_CELL) + Vector2(0.5, 0.5))
	if _all_walls(PLATEAU_RECT):
		_mark_tall(PLATEAU_RECT)
		_build_plateau(PLATEAU_RECT)
	if _all_walls(HOUSE_RECT):
		_mark_tall(HOUSE_RECT)
		_build_house(HOUSE_RECT)
	rebuild_walls(wall_height)
	for cell in BRAZIER_CELLS:
		if rect.has_point(cell) and not _walls.has(cell):
			_build_brazier(Vector3(cell.x + 0.5, 0.0, cell.y + 0.5))


func room_origin_m() -> Vector2:
	return Vector2(rect.position)


func room_size_m() -> Vector2:
	return Vector2(rect.size)


func _all_walls(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _walls.has(Vector2i(x, y)):
				return false
	return true


func _mark_tall(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_tall_cells[Vector2i(x, y)] = true


# --- Mesh helpers ---------------------------------------------------------------

## A quad a-b-c-d (a convex outline, either order); faces `n`. Godot's front
## faces wind clockwise, so the order is fixed here from the wanted normal.
static func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		colors: Array = [], uvs: Array = []) -> void:
	var pts := [a, b, c, d]
	var cols: Array = colors if colors.size() == 4 else [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	var tex: Array = uvs if uvs.size() == 4 else [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var order := [0, 1, 2, 0, 2, 3]
	if (b - a).cross(c - a).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(n)
		st.set_color(cols[i])
		st.set_uv(tex[i])
		st.add_vertex(pts[i])


static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var order := [a, b, c] if (b - a).cross(c - a).dot(n) <= 0.0 else [a, c, b]
	for p: Vector3 in order:
		st.set_normal(n)
		st.set_color(Color.WHITE)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(p)


func _mesh_instance(st: SurfaceTool, kind: StringName, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	parent.add_child(mi)
	look.use(mi, kind)
	return mi


func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# --- Floor and walls --------------------------------------------------------------

## Painted contact shadow: a floor corner darkens with each wall cell touching it.
func _corner_ao(x: int, z: int) -> Color:
	var count := 0
	for c in [Vector2i(x - 1, z - 1), Vector2i(x, z - 1), Vector2i(x - 1, z), Vector2i(x, z)]:
		if _walls.has(c):
			count += 1
	var ao := clampf(1.0 - 0.17 * count, 0.45, 1.0)
	return Color(ao, ao, ao)


func _build_floor() -> void:
	var st := _new_st()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			add_quad(st, Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1),
				Vector3.UP, [_corner_ao(x, y), _corner_ao(x + 1, y), _corner_ao(x + 1, y + 1), _corner_ao(x, y + 1)])
	var mi := _mesh_instance(st, &"floor")
	mi.name = "Floor"


## Walls at the cutaway height (the toggle rebuilds them). Tall things' cells
## are left to the tall things.
func rebuild_walls(h: float) -> void:
	if _wall_sides:
		_wall_sides.queue_free()
		_wall_caps.queue_free()
	var sides := _new_st()
	var caps := _new_st()
	for c: Vector2i in _walls:
		if _tall_cells.has(c):
			continue
		var x := float(c.x)
		var z := float(c.y)
		add_quad(caps, Vector3(x, h, z), Vector3(x + 1, h, z), Vector3(x + 1, h, z + 1), Vector3(x, h, z + 1), Vector3.UP)
		for dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nb := c + dir
			if _walls.has(nb) and not _tall_cells.has(nb):
				continue
			var n := Vector3(dir.x, 0, dir.y)
			var cx := x + 0.5 + dir.x * 0.5
			var cz := z + 0.5 + dir.y * 0.5
			var t := Vector3(-dir.y, 0, dir.x) * 0.5   # along the face
			var base := Vector3(cx, 0, cz)
			add_quad(sides, base - t, base + t, base + t + Vector3(0, h, 0), base - t + Vector3(0, h, 0), n)
	_wall_sides = _mesh_instance(sides, &"wall")
	_wall_caps = _mesh_instance(caps, &"cap")
	look.set_kind_param(&"wall", &"wall_height", h)


# --- Tall things ------------------------------------------------------------------

func _add_tall(root: Node3D) -> void:
	var geos: Array = []
	var box := AABB()
	var first := true
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		geos.append(geo)
		var b: AABB = geo.global_transform * geo.get_aabb()
		box = b if first else box.merge(b)
		first = false
	tall_things.append({"root": root, "aabb": box, "geos": geos, "fade": 1.0})


func _primitive(mesh: PrimitiveMesh, pos: Vector3, kind: StringName, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	look.use(mi, kind)
	return mi


func _build_pillar(center: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Pillar"
	add_child(root)
	root.position = Vector3(center.x, 0, center.y)
	var base := BoxMesh.new()
	base.size = Vector3(0.95, 0.35, 0.95)
	_primitive(base, Vector3(0, 0.175, 0), &"pillar", root)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.28
	shaft.bottom_radius = 0.32
	shaft.height = PILLAR_HEIGHT - 0.7
	shaft.radial_segments = 16
	_primitive(shaft, Vector3(0, 0.35 + shaft.height * 0.5, 0), &"pillar", root)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.95, 0.35, 0.95)
	_primitive(cap, Vector3(0, PILLAR_HEIGHT - 0.175, 0), &"pillar", root)
	_add_tall.call_deferred(root)


## A rock block with craggy sides (noise pushes them out, fading to nothing at
## the corners so the sides meet) and a grass top with a lip.
func _build_plateau(r: Rect2i) -> void:
	var root := Node3D.new()
	root.name = "Plateau"
	add_child(root)
	var x0 := float(r.position.x)
	var z0 := float(r.position.y)
	var x1 := float(r.end.x)
	var z1 := float(r.end.y)
	var h := PLATEAU_HEIGHT
	var st := _new_st()
	var sides := [
		[Vector3(x0, 0, z1), Vector3(1, 0, 0), x1 - x0, Vector3(0, 0, 1)],   # south
		[Vector3(x1, 0, z0), Vector3(-1, 0, 0), x1 - x0, Vector3(0, 0, -1)], # north
		[Vector3(x0, 0, z0), Vector3(0, 0, 1), z1 - z0, Vector3(-1, 0, 0)],  # west
		[Vector3(x1, 0, z1), Vector3(0, 0, -1), z1 - z0, Vector3(1, 0, 0)],  # east
	]
	for side: Array in sides:
		var start: Vector3 = side[0]
		var along: Vector3 = side[1]
		var length: float = side[2]
		var out: Vector3 = side[3]
		var nu := int(ceil(length / 0.2))
		var nv := 10
		var grid := []
		for j in nv + 1:
			var row := []
			var y := h * j / nv
			for i in nu + 1:
				var u := length * i / nu
				var p := start + along * u + Vector3(0, y, 0)
				var ends := smoothstep(0.0, 0.35, u) * smoothstep(0.0, 0.35, length - u)
				var d := (_noise.get_noise_2d(p.x + p.z, y * 1.3) * 0.5 + 0.5) * 0.16 * ends
				row.append(p + out * d)
			grid.append(row)
		for j in nv:
			for i in nu:
				add_quad(st, grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i], out)
	st.index()
	st.generate_normals()
	_mesh_instance(st, &"rock", root)
	# Grass top with a lip that hides the craggy top edge.
	var g := _new_st()
	var o := 0.16
	var top := h + 0.02
	add_quad(g, Vector3(x0 - o, top, z0 - o), Vector3(x1 + o, top, z0 - o), Vector3(x1 + o, top, z1 + o), Vector3(x0 - o, top, z1 + o), Vector3.UP)
	var lip := 0.14
	var corners := [Vector3(x0 - o, 0, z1 + o), Vector3(x1 + o, 0, z1 + o), Vector3(x1 + o, 0, z0 - o), Vector3(x0 - o, 0, z0 - o)]
	var normals := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		add_quad(g, a + Vector3(0, top, 0), b + Vector3(0, top, 0), b + Vector3(0, top - lip, 0), a + Vector3(0, top - lip, 0), normals[i])
	_mesh_instance(g, &"grass", root)
	_add_tall.call_deferred(root)


## A timber-framed house: plaster walls, a gable roof whose ridge runs east-
## west (the south slope faces the camera), a door and a lit window.
func _build_house(r: Rect2i) -> void:
	var root := Node3D.new()
	root.name = "House"
	add_child(root)
	var x0 := float(r.position.x)
	var z0 := float(r.position.y)
	var x1 := float(r.end.x)
	var z1 := float(r.end.y)
	var zm := (z0 + z1) * 0.5
	var hw := HOUSE_WALL
	var walls := _new_st()
	add_quad(walls, Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, hw, z1), Vector3(x0, hw, z1), Vector3(0, 0, 1))
	add_quad(walls, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, hw, z0), Vector3(x0, hw, z0), Vector3(0, 0, -1))
	add_quad(walls, Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x0, hw, z1), Vector3(x0, hw, z0), Vector3(-1, 0, 0))
	add_quad(walls, Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x1, hw, z1), Vector3(x1, hw, z0), Vector3(1, 0, 0))
	add_tri(walls, Vector3(x0, hw, z0), Vector3(x0, hw, z1), Vector3(x0, HOUSE_RIDGE, zm), Vector3(-1, 0, 0))
	add_tri(walls, Vector3(x1, hw, z0), Vector3(x1, hw, z1), Vector3(x1, HOUSE_RIDGE, zm), Vector3(1, 0, 0))
	_mesh_instance(walls, &"plaster", root)
	# Roof: two slopes with a 0.3 m overhang; UV = (along the ridge, down the slope).
	var o := 0.3
	var run := zm - z0
	var rise := HOUSE_RIDGE - hw
	var drop := rise / run * o
	var slope_len := sqrt((run + o) * (run + o) + (rise + drop) * (rise + drop))
	var roof := _new_st()
	for s: float in [1.0, -1.0]:
		var eave_z := zm + s * (run + o)
		var n := Vector3(0, run, s * rise).normalized()
		add_quad(roof, Vector3(x0 - o, HOUSE_RIDGE, zm), Vector3(x1 + o, HOUSE_RIDGE, zm),
			Vector3(x1 + o, hw - drop, eave_z), Vector3(x0 - o, hw - drop, eave_z), n, [],
			[Vector2(x0 - o, 0), Vector2(x1 + o, 0), Vector2(x1 + o, slope_len), Vector2(x0 - o, slope_len)])
	_mesh_instance(roof, &"roof", root)
	# Door and a lit window on the south face.
	var door := _new_st()
	var dx := x0 + (x1 - x0) * 0.5
	add_quad(door, Vector3(dx - 0.4, 0, z1 + 0.02), Vector3(dx + 0.4, 0, z1 + 0.02), Vector3(dx + 0.4, 1.7, z1 + 0.02), Vector3(dx - 0.4, 1.7, z1 + 0.02), Vector3(0, 0, 1))
	_mesh_instance(door, &"wood", root)
	var window := _new_st()
	var wx := x0 + 0.65
	add_quad(window, Vector3(wx - 0.3, 1.1, z1 + 0.02), Vector3(wx + 0.3, 1.1, z1 + 0.02), Vector3(wx + 0.3, 1.7, z1 + 0.02), Vector3(wx - 0.3, 1.7, z1 + 0.02), Vector3(0, 0, 1))
	_mesh_instance(window, &"window", root)
	_add_tall.call_deferred(root)


# --- Braziers ---------------------------------------------------------------------

func _build_brazier(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Brazier"
	add_child(root)
	root.position = pos
	var stand := CylinderMesh.new()
	stand.top_radius = 0.05
	stand.bottom_radius = 0.09
	stand.height = 0.85
	stand.radial_segments = 8
	_primitive(stand, Vector3(0, 0.425, 0), &"metal", root)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.26
	bowl.bottom_radius = 0.12
	bowl.height = 0.2
	bowl.radial_segments = 12
	_primitive(bowl, Vector3(0, 0.95, 0), &"metal", root)
	var flame := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.42
	sphere.radial_segments = 10
	sphere.rings = 6
	flame.mesh = sphere
	flame.position = Vector3(0, 1.18, 0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.62, 0.22)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.55, 0.18)
	fm.emission_energy_multiplier = 3.0
	flame.material_override = fm
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.45, 0)
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 2.2
	light.omni_range = 6.5
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.shadow_bias = 0.05
	root.add_child(light)
	torches.append({"light": light, "flame": flame, "energy": light.light_energy, "phase": randf() * 100.0})


## Flicker (view only).
func update_torches(time: float, on: bool) -> void:
	for t: Dictionary in torches:
		var light: OmniLight3D = t["light"]
		var flame: MeshInstance3D = t["flame"]
		light.visible = on
		flame.visible = on
		if not on:
			continue
		var p: float = t["phase"] + time
		var f := 0.85 + 0.1 * sin(p * 9.1) + 0.06 * sin(p * 23.7 + 1.3) + 0.04 * sin(p * 41.0)
		light.light_energy = t["energy"] * f
		flame.scale = Vector3(1.0, 0.85 + 0.25 * f, 1.0)
