@tool
class_name RoomLayout
extends Node3D
## A room built in 3D (docs/3D.md, Rooms; 3D pivot P8): a scene whose root is
## this Node3D and whose children are asset scenes (scenes/rooms/assets/)
## placed by hand on the 1 m grid. Under the 3D view the layout is the room's
## look. At load, build_sim() makes the flat 2D Room the game plays in:
##   - each asset's Footprint: a collider on its kind's layer (and a flat 2D
##     look, so the room also plays without the view);
##   - each SimMarker: its sim scene in Entities, where it stands;
##   - PlayerSpawn (a Marker3D child): the Room's PlayerSpawn;
##   - the layout's children that aren't Node3D (room scripts, such as the
##     sandbox's helpers): moved into the Room;
##   - the walkable ground's extent (or bounds_m): the Room's bounds and the
##     navigation bake's outline;
##   - depth: the Room's depth (LOOT L3).
## The groups: `walkable` on a mesh (walkable ground: the floor pick, later
## the height under each unit), `fades` on an asset's root (it fades while
## between the camera and the player), `decoration` on an asset's root (never
## in the sim). validate() lists what looks wrong; build_sim() warns once per
## problem.
## It's read before it's in the tree, so positions come from local transforms
## (transform_in()). The root stays at the origin.

## Marks a node a tool made (a footprint's or a marker's look): never part of
## the room.
const TOOL_META := &"room_tool"
## A footprint and its meshes may differ by this much (m) before validate()
## flags it (8 px).
const TOLERANCE_M := 0.25
## How closely validate() samples a footprint's area (m).
const SAMPLE_STEP_M := 0.1
## Faces this close to a slice's edge count as inside it (a box's bottom face
## on the floor).
const SLICE_EPSILON_M := 0.001
## How finely derive_ledges() samples the walkable ground (m).
const LEDGE_STEP_M := 0.25
## The walkable ground stepping down by more than this between two samples is
## a cliff (3D.md, Terrain and height 1b); a ramp or stairs is smooth.
const LEDGE_HEIGHT_M := 0.3
## A derived ledge's 2D look (the room played without the view) and its
## editor color (yellow, like a drawn LEDGE footprint).
const LEDGE_SIM_COLOR := Color(0.6, 0.55, 0.3)
const LEDGE_PREVIEW_COLOR := Color(1.0, 0.95, 0.2)

## Draws every footprint over the room in the editor, colored by kind (walls
## red, low obstacles orange, pits purple, ledges yellow).
@export var show_footprints: bool = true
## Draws the footprints over the room in play too.
@export var debug_draw: bool = false
## The room's floor in meters (x and z); empty: the walkable ground's extent.
@export var bounds_m: Rect2 = Rect2()
## As Room.nav_agent_radius: how far enemy paths stay from what blocks them
## (px).
@export var nav_agent_radius: float = 12.0
## As Room.depth (LOOT.md, Drops), copied onto the Room build_sim() makes.
## LOOT L3.
@export_range(1, 100, 1, "or_greater") var depth: int = 1

var _ledge_preview: MeshInstance3D
var _ledge_signature := INF
var _ledge_check_left := 0.0


# --- The derived ledges' drawing (editor; in play with debug_draw) ---------------------

func _process(delta: float) -> void:
	var wanted := show_footprints if Engine.is_editor_hint() else debug_draw
	if not Engine.is_editor_hint() and not wanted:
		set_process(false)   # in play the switch is read once
		return
	_ledge_check_left -= delta
	if _ledge_check_left > 0.0:
		return
	_ledge_check_left = 1.0
	if not wanted:
		if is_instance_valid(_ledge_preview):
			_ledge_preview.visible = false
		_ledge_signature = INF
		return
	# Recomputed only when the walkable ground moved (a cheap signature).
	var signature := 0.0
	var meshes := get_walkable_meshes()
	for i in meshes.size():
		var t := transform_in(meshes[i], self)
		signature += (i + 1) * (t.origin.x * 1.31 + t.origin.y * 7.17 + t.origin.z * 3.73 + t.basis.x.x + t.basis.z.x * 2.0 + t.basis.y.y * 5.0)
	if is_equal_approx(signature, _ledge_signature) and is_instance_valid(_ledge_preview):
		_ledge_preview.visible = true
		return
	_ledge_signature = signature
	if not is_instance_valid(_ledge_preview):
		_ledge_preview = MeshInstance3D.new()
		_ledge_preview.name = "LedgePreview"
		_ledge_preview.set_meta(TOOL_META, true)
		_ledge_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.no_depth_test = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.render_priority = 10
		_ledge_preview.material_override = material
		add_child(_ledge_preview, false, Node.INTERNAL_MODE_BACK)
	_ledge_preview.visible = true
	_ledge_preview.mesh = _ledges_mesh(derive_ledges())


static func _ledges_mesh(ledges: Array[Dictionary]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for ledge in ledges:
		var r: Rect2 = ledge["rect"]
		var y: float = ledge["height"] + Footprint.PREVIEW_LIFT_M
		var a := Vector3(r.position.x, y, r.position.y)
		var b := Vector3(r.end.x, y, r.position.y)
		var c := Vector3(r.end.x, y, r.end.y)
		var d := Vector3(r.position.x, y, r.end.y)
		for v in [a, b, c, a, c, d]:
			verts.append(v)
			colors.append(Color(LEDGE_PREVIEW_COLOR, 0.6))
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- The sim (build_sim) -------------------------------------------------------

## Makes the 2D sim Room from this layout (see the class description). Warns
## once per validate() problem. The Room isn't in the tree yet: its _ready()
## bakes the navigation when Main adds it.
func build_sim() -> Room:
	for problem in validate():
		push_warning("RoomLayout %s: %s" % [name, problem])
	var room := Room.new()
	room.name = name
	room.nav_agent_radius = nav_agent_radius
	room.bounds_px = get_bounds_px()
	room.depth = depth

	var footprints := Node2D.new()
	footprints.name = "Footprints"
	footprints.add_to_group(&"navigation_source")
	room.add_child(footprints)
	for fp in get_footprints():
		var body := make_footprint_body(fp)
		if body:
			footprints.add_child(body)
	var ledges := make_ledge_body(derive_ledges())
	if ledges:
		footprints.add_child(ledges)

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	room.add_child(entities)
	for marker in get_sim_markers():
		var node := marker.make_sim_node(Units.to_sim(transform_in(marker, self).origin))
		if node:
			entities.add_child(node)

	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	var spawn_3d := get_node_or_null(^"PlayerSpawn") as Node3D
	if spawn_3d:
		spawn.position = Units.to_sim(transform_in(spawn_3d, self).origin)
	room.add_child(spawn)

	for child in get_children():
		if not (child is Node3D):
			remove_child(child)
			child.owner = null
			room.add_child(child)
	return room


## The 2D collider of a footprint: a StaticBody2D on its kind's layer
## (colliding with nothing itself), its outline in sim px, with a flat 2D look.
## null for an empty footprint.
func make_footprint_body(fp: Footprint) -> StaticBody2D:
	var outline := footprint_outline_m(fp)
	if outline.size() < 3:
		return null
	var points := PackedVector2Array()
	for p in outline:
		points.append(Vector2(Units.m_to_px(p.x), Units.m_to_px(p.y)))
	var body := StaticBody2D.new()
	body.name = "%s_%s" % [fp.get_parent().name, fp.name]
	body.collision_layer = fp.get_layer_bit()
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	var look := Polygon2D.new()
	look.polygon = points
	look.color = Footprint.SIM_COLORS[fp.kind]
	body.add_child(look)
	return body


## The derived ledges' collider (P9): one StaticBody2D "Ledges" on layer 11,
## a rectangle per run of ledge cells (in px), with a flat 2D look. null when
## the room has no cliffs.
func make_ledge_body(ledges: Array[Dictionary]) -> StaticBody2D:
	if ledges.is_empty():
		return null
	var body := StaticBody2D.new()
	body.name = "Ledges"
	body.collision_layer = 1 << 10
	body.collision_mask = 0
	for ledge in ledges:
		var r: Rect2 = ledge["rect"]
		var px := Rect2(Units.m_to_px(r.position.x), Units.m_to_px(r.position.y), Units.m_to_px(r.size.x), Units.m_to_px(r.size.y))
		var shape := RectangleShape2D.new()
		shape.size = px.size
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = px.get_center()
		body.add_child(col)
		var look := Polygon2D.new()
		look.polygon = PackedVector2Array([px.position, Vector2(px.end.x, px.position.y), px.end, Vector2(px.position.x, px.end.y)])
		look.color = LEDGE_SIM_COLOR
		body.add_child(look)
	return body


## The walkable ground's height on a grid of `step_m` cells over the room's
## bounds (the topmost walkable surface over each cell's center: one floor per
## map spot, 3D.md 1c): {"origin": Vector2 (m, x and z), "size": Vector2i,
## "step": float, "heights": PackedFloat32Array, -INF where there's no
## ground}. Rasterized from the walkable meshes' faces, so it needs no
## physics (a layout is read before it's in the tree).
func ground_grid(step_m: float = LEDGE_STEP_M) -> Dictionary:
	var bounds := get_bounds_m()
	var size := Vector2i(ceili(bounds.size.x / step_m - 0.001), ceili(bounds.size.y / step_m - 0.001))
	var heights := PackedFloat32Array()
	heights.resize(maxi(size.x * size.y, 0))
	heights.fill(-INF)
	for mesh in get_walkable_meshes():
		var xf := transform_in(mesh, self)
		var faces := mesh.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			var a := xf * faces[i]
			var b := xf * faces[i + 1]
			var c := xf * faces[i + 2]
			var a2 := Vector2(a.x, a.z)
			var v0 := Vector2(b.x, b.z) - a2
			var v1 := Vector2(c.x, c.z) - a2
			var den := v0.cross(v1)
			if absf(den) < 0.000001:
				continue   # a vertical face: no ground
			var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			var x0 := maxi(ceili((lo.x - bounds.position.x) / step_m - 0.5), 0)
			var x1 := mini(floori((hi.x - bounds.position.x) / step_m - 0.5), size.x - 1)
			var z0 := maxi(ceili((lo.y - bounds.position.y) / step_m - 0.5), 0)
			var z1 := mini(floori((hi.y - bounds.position.y) / step_m - 0.5), size.y - 1)
			for zi in range(z0, z1 + 1):
				for xi in range(x0, x1 + 1):
					var p := bounds.position + Vector2(xi + 0.5, zi + 0.5) * step_m
					var v2 := p - a2
					var l1 := v2.cross(v1) / den
					var l2 := v0.cross(v2) / den
					if l1 < -0.0001 or l2 < -0.0001 or l1 + l2 > 1.0001:
						continue
					var y := a.y + (b.y - a.y) * l1 + (c.y - a.y) * l2
					var index := zi * size.x + xi
					heights[index] = maxf(heights[index], y)
	return {"origin": bounds.position, "size": size, "step": step_m, "heights": heights}


## The ledges derived from the walkable ground (3D.md, Terrain and height
## 1b; P9): wherever the ground steps down by more than LEDGE_HEIGHT_M between
## two neighboring cells (no ramp or stairs between them), the top side's cell
## is a ledge cell. Each row's ledge cells merge into rectangles: [{"rect":
## Rect2 (m, x and z), "height": the top's height (m)}]. Where the ground just
## ends (the room's edge, a wall's gap) there's no ledge.
func derive_ledges() -> Array[Dictionary]:
	var grid := ground_grid()
	var size: Vector2i = grid["size"]
	var heights: PackedFloat32Array = grid["heights"]
	var step: float = grid["step"]
	var origin: Vector2 = grid["origin"]
	var out: Array[Dictionary] = []
	for zi in size.y:
		var run_start := -1
		var run_height := 0.0
		for xi in size.x + 1:
			var is_ledge := false
			var h := -INF
			if xi < size.x:
				h = heights[zi * size.x + xi]
				if h > -INF:
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n := Vector2i(xi, zi) + d
						if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
							continue
						var nh := heights[n.y * size.x + n.x]
						if nh > -INF and h - nh > LEDGE_HEIGHT_M:
							is_ledge = true
							break
			if is_ledge and run_start < 0:
				run_start = xi
				run_height = h
			elif is_ledge:
				run_height = maxf(run_height, h)
			elif run_start >= 0:
				out.append({"rect": Rect2(origin + Vector2(run_start, zi) * step, Vector2(xi - run_start, 1) * step), "height": run_height})
				run_start = -1
	return out


## The walkable ground's lowest and highest points (m): x min, y max.
func get_height_range_m() -> Vector2:
	var lo := INF
	var hi := -INF
	for mesh in get_walkable_meshes():
		var aabb: AABB = transform_in(mesh, self) * mesh.get_aabb()
		lo = minf(lo, aabb.position.y)
		hi = maxf(hi, aabb.end.y)
	return Vector2(lo, hi) if lo <= hi else Vector2.ZERO


## A footprint's outline in the layout's floor plane (m, x and z).
func footprint_outline_m(fp: Footprint) -> PackedVector2Array:
	var xf := transform_in(fp, self)
	var out := PackedVector2Array()
	for p in fp.get_outline_local():
		var v := xf * Vector3(p.x, 0.0, p.y)
		out.append(Vector2(v.x, v.z))
	return out


## The room's floor in meters (x and z): bounds_m, or the walkable ground's
## extent.
func get_bounds_m() -> Rect2:
	if bounds_m.has_area():
		return bounds_m
	var box := Rect2()
	var first := true
	for mesh in get_walkable_meshes():
		var aabb: AABB = transform_in(mesh, self) * mesh.get_aabb()
		var r := Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)
		box = r if first else box.merge(r)
		first = false
	return box


func get_bounds_px() -> Rect2:
	var m := get_bounds_m()
	return Rect2(Units.m_to_px(m.position.x), Units.m_to_px(m.position.y), Units.m_to_px(m.size.x), Units.m_to_px(m.size.y))


# --- The view's side ------------------------------------------------------------

## The walkable ground's floor pick (3D.md, The floor pick and aim): one
## view-only body on 3D physics layer 1 with every walkable mesh's faces, in
## the layout's space. WorldView adds it under the layout.
func build_floor_pick() -> StaticBody3D:
	var faces := PackedVector3Array()
	for mesh in get_walkable_meshes():
		var xf := transform_in(mesh, self)
		for v in mesh.mesh.get_faces():
			faces.append(xf * v)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "FloorPick"
	body.collision_layer = WorldView.FLOOR_LAYER
	body.collision_mask = 0
	body.add_child(col)
	return body


## The floor drawings' materials: each distinct ShaderMaterial using the
## floor's shader (floor_drawings.gdshader) on any mesh of the room (the
## walkable ground, and since P9 a stair's visible steps), for FloorOverlay.
func get_floor_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for mesh in get_meshes():
		var candidates: Array = [mesh.material_override]
		if mesh.mesh:
			for i in mesh.mesh.get_surface_count():
				candidates.append(mesh.get_surface_override_material(i))
				candidates.append(mesh.mesh.surface_get_material(i))
		for m: Variant in candidates:
			var shader_material := m as ShaderMaterial
			if shader_material and shader_material.shader == RoomView.FLOOR_SHADER and not out.has(shader_material):
				out.append(shader_material)
	return out


# --- What's in it ---------------------------------------------------------------

func get_footprints() -> Array[Footprint]:
	var out: Array[Footprint] = []
	for n in find_children("*", "Node3D", true, false):
		if n is Footprint and not is_tool_visual(n, self):
			out.append(n as Footprint)
	return out


func get_sim_markers() -> Array[SimMarker]:
	var out: Array[SimMarker] = []
	for n in find_children("*", "Marker3D", true, false):
		if n is SimMarker and not is_tool_visual(n, self):
			out.append(n as SimMarker)
	return out


## Every mesh of the room (tools' drawings left out).
func get_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in find_children("*", "MeshInstance3D", true, false):
		if not is_tool_visual(n, self) and (n as MeshInstance3D).mesh != null:
			out.append(n as MeshInstance3D)
	return out


func get_walkable_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mesh in get_meshes():
		if in_group_up_to(mesh, &"walkable", self):
			out.append(mesh)
	return out


# --- The validator ---------------------------------------------------------------

## What looks wrong in this layout (3D.md, the validator), one line each:
##   - an unmarked solid mesh: not walkable, not decoration, and no footprint
##     on its asset (it looks solid, but units would walk through it);
##   - an empty footprint: fewer than 3 points or no area (or an empty polygon
##     with no meshes to derive it from);
##   - a footprint that doesn't match its asset's meshes: their lower outline
##     (the footprints' slice) more than TOLERANCE_M outside every footprint
##     of the asset (a solid thing you can walk into), or footprint area more
##     than TOLERANCE_M from all of them and not inside them (an invisible
##     wall, such as a hull over an archway; not checked for pits, which are
##     holes). Inside means within a closed mesh's cross-section at 10, 50 or
##     90% of the slice (the middle of a boulder).
## An asset scene placed many times is checked once.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for mesh in get_meshes():
		if in_group_up_to(mesh, &"walkable", self) or in_group_up_to(mesh, &"decoration", self):
			continue
		if not _has_footprint_up_to(mesh, self):
			problems.append("%s: a solid-looking mesh with no footprint that isn't walkable or decoration (units would walk through it)" % get_path_to(mesh))
	var assets := {}   # asset root -> its footprints
	for fp in get_footprints():
		var outline := fp.get_outline_local()
		if outline.size() < 3 or absf(polygon_area(outline)) < 0.0001:
			problems.append("%s: an empty footprint (fewer than 3 points or no area%s)" % [get_path_to(fp), "; nothing to derive it from" if fp.polygon.is_empty() else ""])
			continue
		var asset := fp.get_parent() as Node3D
		if asset == null or asset == self:
			continue
		if not assets.has(asset):
			assets[asset] = []
		assets[asset].append(fp)
	var checked := {}   # an asset scene's path -> its problems, as text with %s for the asset
	for asset: Node3D in assets:
		var key := asset.scene_file_path
		var found: Array[String] = []
		if key != "" and checked.has(key):
			found.assign(checked[key])
		else:
			found = check_asset(asset, assets[asset])
			if key != "":
				checked[key] = found
		for f in found:
			problems.append(f % get_path_to(asset))
	return problems


## The footprint checks of one asset (its root and its footprints), in the
## asset's own space: each problem as text with %s for the asset's path.
static func check_asset(asset: Node3D, footprints: Array) -> Array[String]:
	var found: Array[String] = []
	var outlines: Array[PackedVector2Array] = []
	var y_min := INF
	var y_max := -INF
	var any_pit := false
	var all_pits := true
	for fp: Footprint in footprints:
		var xf := transform_in(fp, asset)
		var outline := PackedVector2Array()
		for p in fp.get_outline_local():
			var v := xf * Vector3(p.x, 0.0, p.y)
			outline.append(Vector2(v.x, v.z))
		outlines.append(outline)
		var slab := fp.get_slab_local()
		y_min = minf(y_min, xf.origin.y + slab.x)
		y_max = maxf(y_max, xf.origin.y + slab.y)
		any_pit = any_pit or fp.kind == Footprint.Kind.PIT
		all_pits = all_pits and fp.kind == Footprint.Kind.PIT
	var slices := solid_slices(asset, asset, y_min, y_max)
	# The meshes' lower outline outside every footprint.
	var worst_out := 0.0
	for s in slices:
		for i in s.size():
			var a := s[i]
			var b := s[(i + 1) % s.size()]
			var steps := maxi(1, ceili(a.distance_to(b) / SAMPLE_STEP_M))
			for k in steps:
				worst_out = maxf(worst_out, distance_outside(a.lerp(b, float(k) / steps), outlines))
	if worst_out > TOLERANCE_M:
		found.append("%%s: its meshes stick out of its footprint by %.2f m (a solid thing units can walk into)" % worst_out)
	# Footprint area far from every mesh (an invisible wall). Not for pits. A
	# point inside a closed mesh's cross-section (the middle of a boulder) is
	# inside the solid, not far from it.
	if not all_pits:
		var sections: Array[PackedVector2Array] = []
		for share in [0.1, 0.5, 0.9]:
			sections.append(cross_section(asset, asset, lerpf(y_min, y_max, share)))
		var worst_far := 0.0
		for outline in outlines:
			var box := Rect2(outline[0], Vector2.ZERO)
			for p in outline:
				box = box.expand(p)
			var x := box.position.x + SAMPLE_STEP_M * 0.5
			while x < box.end.x:
				var z := box.position.y + SAMPLE_STEP_M * 0.5
				while z < box.end.y:
					var p := Vector2(x, z)
					if Geometry2D.is_point_in_polygon(p, outline):
						var d := distance_to_slices(p, slices, worst_far)
						if d > worst_far:
							for section in sections:
								if inside_section(p, section):
									d = 0.0
									break
						worst_far = maxf(worst_far, d)
					z += SAMPLE_STEP_M
				x += SAMPLE_STEP_M
		if worst_far > TOLERANCE_M:
			found.append("%%s: its footprint covers floor %.2f m from any of its meshes (an invisible wall; a hull over an archway?)" % worst_far)
	return found


# --- Geometry helpers (also used by Footprint) ---------------------------------------

## `node`'s transform relative to `root` (an ancestor, or the node itself),
## from local transforms only, so it works before the scene is in the tree.
static func transform_in(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## True if `node` or an ancestor below `root` is in `group`.
static func in_group_up_to(node: Node, group: StringName, root: Node) -> bool:
	var n := node
	while n != null and n != root:
		if n.is_in_group(group):
			return true
		n = n.get_parent()
	return false


## True for a node a tool made (TOOL_META on it or an ancestor below `root`).
static func is_tool_visual(node: Node, root: Node) -> bool:
	var n := node
	while n != null and n != root:
		if n.has_meta(TOOL_META):
			return true
		n = n.get_parent()
	return false


static func _has_footprint_up_to(node: Node, root: Node) -> bool:
	var n := node.get_parent()
	while n != null and n != root:
		for child in n.get_children():
			if child is Footprint:
				return true
		n = n.get_parent()
	return false


## The solid meshes of an asset (not walkable, decoration or a tool's
## drawing) cut to the heights y_min..y_max of `frame` (the asset's root or one
## of its footprints) and seen from above: each face's cut outline on the
## X/Z plane (a vertical face gives a thin sliver: its line on the floor).
static func solid_slices(asset: Node3D, frame: Node3D, y_min: float, y_max: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var faces := solid_faces(asset, frame)
	for i in range(0, faces.size() - 2, 3):
		var cut := clip_to_heights(PackedVector3Array([faces[i], faces[i + 1], faces[i + 2]]), y_min, y_max)
		if cut.size() < 2:
			continue
		var flat := PackedVector2Array()
		for v in cut:
			flat.append(Vector2(v.x, v.z))
		out.append(flat)
	return out


## Every face of an asset's solid meshes (not walkable, decoration or a
## tool's drawing), three points each, in `frame`'s space.
static func solid_faces(asset: Node3D, frame: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_frame := transform_in(frame, asset).affine_inverse()
	for n in asset.find_children("*", "MeshInstance3D", true, false):
		var mesh := n as MeshInstance3D
		if mesh.mesh == null or is_tool_visual(mesh, asset) \
				or in_group_up_to(mesh, &"walkable", asset.get_parent()) or in_group_up_to(mesh, &"decoration", asset.get_parent()):
			continue
		var xf := to_frame * transform_in(mesh, asset)
		for v in mesh.mesh.get_faces():
			out.append(xf * v)
	return out


## Where an asset's solid meshes cross the height `y` (in `frame`'s space):
## the cut's edges on the X/Z plane, two points each. A closed mesh gives
## closed loops: its cross-section.
static func cross_section(asset: Node3D, frame: Node3D, y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var faces := solid_faces(asset, frame)
	for i in range(0, faces.size() - 2, 3):
		var cut := PackedVector2Array()
		for k in 3:
			var a := faces[i + k]
			var b := faces[i + (k + 1) % 3]
			if (a.y - y) * (b.y - y) < 0.0:
				var r := a.lerp(b, (y - a.y) / (b.y - a.y))
				cut.append(Vector2(r.x, r.z))
		if cut.size() == 2:
			out.append_array(cut)
	return out


## True if `p` lies inside a cross-section: an odd number of its edges cross
## the ray from `p` toward +x.
static func inside_section(p: Vector2, section: PackedVector2Array) -> bool:
	var inside := false
	for i in range(0, section.size() - 1, 2):
		var a := section[i]
		var b := section[i + 1]
		if (a.y > p.y) != (b.y > p.y):
			var x := a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)
			if x > p.x:
				inside = not inside
	return inside


## A polygon (a face) cut to y_min <= y <= y_max (a little slack, so a face
## lying exactly on an edge counts).
static func clip_to_heights(poly: PackedVector3Array, y_min: float, y_max: float) -> PackedVector3Array:
	return _clip_y(_clip_y(poly, y_min - SLICE_EPSILON_M, true), y_max + SLICE_EPSILON_M, false)


static func _clip_y(poly: PackedVector3Array, y: float, keep_above: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var a_in := a.y >= y if keep_above else a.y <= y
		var b_in := b.y >= y if keep_above else b.y <= y
		if a_in:
			out.append(a)
		if a_in != b_in:
			out.append(a.lerp(b, (y - a.y) / (b.y - a.y)))
	return out


## How far `p` lies outside every polygon (0 if inside one).
static func distance_outside(p: Vector2, polygons: Array[PackedVector2Array]) -> float:
	var best := INF
	for poly in polygons:
		if Geometry2D.is_point_in_polygon(p, poly):
			return 0.0
		best = minf(best, distance_to_outline(p, poly))
	return best


## How far `p` lies from every slice (0 inside one). Stops early once it's
## within `enough` (the caller only needs to know if it's farther).
static func distance_to_slices(p: Vector2, slices: Array[PackedVector2Array], enough: float = 0.0) -> float:
	var best := INF
	for s in slices:
		if s.size() >= 3 and Geometry2D.is_point_in_polygon(p, s):
			return 0.0
		best = minf(best, distance_to_outline(p, s))
		if best <= enough:
			return best
	return best


static func distance_to_outline(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## A polygon's signed area (shoelace).
static func polygon_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
