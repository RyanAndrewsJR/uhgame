extends RefCounted
## P0a spike (throwaway, never merged): a terrain patch in the sandbox.
## 1 m = 1 tile = 32 px. Sim (x, y) px -> view (x / 32, h, y / 32) m.
## A plateau (cells x 5..8, y 10..12, 1.5 m), a ramp up to it from the west
## (cells (3,11), (4,11)), stairs up to it from the south (cells x 6..7,
## y 13..14, 6 steps), a fence (layer 7) at cells x 2..4, y 14.

const PX := 32.0
const PLATEAU_H := 1.5
const WALL_H := 1.2
const FENCE_H := 0.5
const STEP_H := 0.25
const LEDGE_MIN_DROP := 0.3
const LEDGE_THICK_PX := 4.0
const LAYER_FENCE := 64      # collision layer 7
const LAYER_LEDGE := 1024    # collision layer 11

enum Kind { FLOOR, WALL, PLATEAU, RAMP_E, STAIRS_N }

var kinds: Dictionary = {}   # Vector2i -> Kind
var rect: Rect2i
var fence_rect_px := Rect2(64.0, 464.0 - 3.0, 96.0, 6.0)


func setup(tiles: TileMapLayer) -> void:
	rect = tiles.get_used_rect()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			var td := tiles.get_cell_tile_data(c)
			var solid := td != null and td.get_collision_polygons_count(0) > 0
			kinds[c] = Kind.WALL if solid else Kind.FLOOR
	for x in range(5, 9):
		for y in range(10, 13):
			kinds[Vector2i(x, y)] = Kind.PLATEAU
	kinds[Vector2i(3, 11)] = Kind.RAMP_E
	kinds[Vector2i(4, 11)] = Kind.RAMP_E
	for x in [6, 7]:
		for y in [13, 14]:
			kinds[Vector2i(x, y)] = Kind.STAIRS_N


func kind_at(c: Vector2i) -> int:
	return kinds.get(c, -1)


## The visible surface height of cell c at (x_m, z_m) (a point in or on the cell).
func h_vis_cell(c: Vector2i, x_m: float, z_m: float) -> float:
	match kind_at(c):
		Kind.WALL:
			return WALL_H
		Kind.PLATEAU:
			return PLATEAU_H
		Kind.RAMP_E:
			return clampf(PLATEAU_H * (x_m - 3.0) / 2.0, 0.0, PLATEAU_H)
		Kind.STAIRS_N:
			return clampf(STEP_H * ceilf((15.0 - z_m) * 3.0 - 0.0001), 0.0, PLATEAU_H)
		_:
			return 0.0


## The topmost surface at a map point (meters).
func h_top(x_m: float, z_m: float) -> float:
	return h_vis_cell(Vector2i(floori(x_m), floori(z_m)), x_m, z_m)


## The height a unit's model stands at (stairs are a smooth slope for models).
func h_model(sim: Vector2) -> float:
	var x_m := sim.x / PX
	var z_m := sim.y / PX
	var c := Vector2i(floori(x_m), floori(z_m))
	match kind_at(c):
		Kind.PLATEAU:
			return PLATEAU_H
		Kind.RAMP_E:
			return clampf(PLATEAU_H * (x_m - 3.0) / 2.0, 0.0, PLATEAU_H)
		Kind.STAIRS_N:
			return clampf(PLATEAU_H * (15.0 - z_m) / 2.0, 0.0, PLATEAU_H)
		_:
			return 0.0


func to_view(sim: Vector2, h: float) -> Vector3:
	return Vector3(sim.x / PX, h, sim.y / PX)


func to_sim(p: Vector3) -> Vector2:
	return Vector2(p.x * PX, p.z * PX)


# --- Sim footprint ----------------------------------------------------------------

## Ledge rects (sim px): every edge between two non-wall cells whose surfaces
## differ by more than LEDGE_MIN_DROP somewhere along it.
func ledge_rects_px() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Vector2i in kinds:
		if kind_at(c) == Kind.WALL:
			continue
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:   # each edge once
			var n: Vector2i = c + d
			if kind_at(n) == -1 or kind_at(n) == Kind.WALL:
				continue
			if _edge_max_drop(c, n, d) <= LEDGE_MIN_DROP:
				continue
			var t := LEDGE_THICK_PX
			if d == Vector2i.RIGHT:
				out.append(Rect2(float(n.x) * PX - t * 0.5, float(c.y) * PX - t * 0.5, t, PX + t))
			else:
				out.append(Rect2(float(c.x) * PX - t * 0.5, float(n.y) * PX - t * 0.5, PX + t, t))
	return out


func _edge_max_drop(c: Vector2i, n: Vector2i, d: Vector2i) -> float:
	var worst := 0.0
	for i in 6:
		var s := (float(i) + 0.5) / 6.0
		var a: Vector2
		var b: Vector2
		if d == Vector2i.RIGHT:
			var x := float(n.x)
			var z := float(c.y) + s
			a = Vector2(x - 0.001, z)
			b = Vector2(x + 0.001, z)
		else:
			var z2 := float(n.y)
			var x2 := float(c.x) + s
			a = Vector2(x2, z2 - 0.001)
			b = Vector2(x2, z2 + 0.001)
		worst = maxf(worst, absf(h_vis_cell(c, a.x, a.y) - h_vis_cell(n, b.x, b.y)))
	return worst


# --- View geometry -----------------------------------------------------------------

func _color(k: int) -> Color:
	match k:
		Kind.WALL:
			return Color(0.32, 0.33, 0.38)
		Kind.PLATEAU:
			return Color(0.55, 0.5, 0.4)
		Kind.RAMP_E:
			return Color(0.62, 0.55, 0.42)
		Kind.STAIRS_N:
			return Color(0.6, 0.52, 0.45)
		_:
			return Color(0.42, 0.44, 0.42)


## Adds a quad a-b-c-d (in order around it) whose front faces `n`. Godot's
## front faces are wound clockwise; each triangle is checked, so any order works.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_tri(st, a, b, c, n, col)
	_tri(st, a, c, d, n, col)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var order := [a, b, c] if (c - a).cross(b - a).dot(n) > 0.0 else [a, c, b]
	for v: Vector3 in order:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2i in kinds:
		var k := kind_at(c)
		var col := _color(k)
		var x0 := float(c.x)
		var z0 := float(c.y)
		var x1 := x0 + 1.0
		var z1 := z0 + 1.0
		# Top surface.
		match k:
			Kind.RAMP_E:
				var ha := h_vis_cell(c, x0, z0)
				var hb := h_vis_cell(c, x1, z0)
				_quad(st, Vector3(x0, ha, z0), Vector3(x1, hb, z0), Vector3(x1, hb, z1), Vector3(x0, ha, z1), Vector3(-(hb - ha), 1.0, 0.0).normalized(), col)
			Kind.STAIRS_N:
				for i in 3:
					var zs := z1 - float(i) / 3.0          # south edge of this tread
					var zn := z1 - float(i + 1) / 3.0      # north edge
					var h := h_vis_cell(c, x0 + 0.5, (zs + zn) * 0.5)
					_quad(st, Vector3(x0, h, zn), Vector3(x1, h, zn), Vector3(x1, h, zs), Vector3(x0, h, zs), Vector3.UP, col)
					if i > 0:   # riser at zs, from the tread south of it
						var hl := h_vis_cell(c, x0 + 0.5, zs + 0.01)
						_quad(st, Vector3(x0, hl, zs), Vector3(x1, hl, zs), Vector3(x1, h, zs), Vector3(x0, h, zs), Vector3.BACK, col.darkened(0.15))
			_:
				var h2 := h_vis_cell(c, x0 + 0.5, z0 + 0.5)
				_quad(st, Vector3(x0, h2, z0), Vector3(x1, h2, z0), Vector3(x1, h2, z1), Vector3(x0, h2, z1), Vector3.UP, col)
		# Sides toward lower neighbors (cliffs, wall faces, ramp and stair sides).
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			for i in 6:
				var s0 := float(i) / 6.0
				var s1 := float(i + 1) / 6.0
				var sm := (s0 + s1) * 0.5
				var p_in: Vector2
				var p_out: Vector2
				var e0: Vector2
				var e1: Vector2
				if d == Vector2i.LEFT or d == Vector2i.RIGHT:
					var ex := x0 if d == Vector2i.LEFT else x1
					p_in = Vector2(ex - float(d.x) * 0.001, z0 + sm)
					p_out = Vector2(ex + float(d.x) * 0.001, z0 + sm)
					e0 = Vector2(ex, z0 + s0)
					e1 = Vector2(ex, z0 + s1)
				else:
					var ez := z0 if d == Vector2i.UP else z1
					p_in = Vector2(x0 + sm, ez - float(d.y) * 0.001)
					p_out = Vector2(x0 + sm, ez + float(d.y) * 0.001)
					e0 = Vector2(x0 + s0, ez)
					e1 = Vector2(x0 + s1, ez)
				var top := h_vis_cell(c, p_in.x, p_in.y)
				var bottom := h_vis_cell(n, p_out.x, p_out.y) if kind_at(n) != -1 else 0.0
				if top > bottom + 0.001:
					var nn := Vector3(float(d.x), 0.0, float(d.y))
					_quad(st, Vector3(e0.x, bottom, e0.y), Vector3(e1.x, bottom, e1.y), Vector3(e1.x, top, e1.y), Vector3(e0.x, top, e0.y), nn, col.darkened(0.25))
	return st.commit()


func build_fence_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := fence_rect_px
	var a := Vector3(r.position.x / PX, 0.0, r.position.y / PX)
	var b := Vector3(r.end.x / PX, FENCE_H, r.end.y / PX)
	var col := Color(0.45, 0.3, 0.18)
	_quad(st, Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3.UP, col)
	_quad(st, Vector3(a.x, 0, b.z), Vector3(b.x, 0, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3.BACK, col.darkened(0.2))
	_quad(st, Vector3(a.x, 0, a.z), Vector3(b.x, 0, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z), Vector3.FORWARD, col.darkened(0.2))
	return st.commit()


## A HeightMapShape3D on the tile corners (1 m grid): each corner takes the
## highest surface of the cells around it. Origin = the room's center.
func build_heightmap() -> HeightMapShape3D:
	var w := rect.size.x + 1
	var d := rect.size.y + 1
	var data := PackedFloat32Array()
	data.resize(w * d)
	for j in d:
		for i in w:
			var x := float(rect.position.x + i)
			var z := float(rect.position.y + j)
			var best := 0.0
			for dc: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var c := Vector2i(rect.position.x + i, rect.position.y + j) + dc
				if kind_at(c) == -1:
					continue
				var px := x - 0.001 if dc.x < 0 else x + 0.001
				var pz := z - 0.001 if dc.y < 0 else z + 0.001
				best = maxf(best, h_vis_cell(c, px, pz))
			data[j * w + i] = best
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = data
	return shape


func room_center_m() -> Vector3:
	return Vector3(float(rect.position.x) + float(rect.size.x) * 0.5, 0.0, float(rect.position.y) + float(rect.size.y) * 0.5)
