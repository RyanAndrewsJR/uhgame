@tool
class_name Footprint
extends Node3D
## The flat outline a room asset occupies in the sim (docs/3D.md, Rooms; 3D
## pivot P8). It's a child of the asset's root, next to the asset's meshes. At
## load, RoomLayout.build_sim() makes one 2D collider from it on its kind's
## layer. In the editor it draws its outline over the room, colored by kind
## (RoomLayout.show_footprints); in play, only with RoomLayout.debug_draw.
## Surface tags (grappleable, destructible, bounce, wall_slam) come with
## WORLD_INTERACTION's SurfaceTags, which isn't built yet.

enum Kind { WALL, LOW_OBSTACLE, PIT, LEDGE }

## The collision layer number of each kind (WORLD_INTERACTION.md, Collision
## layers): walls 1, pits 6, low obstacles 7, ledges 11.
const LAYER_NUMBERS := {Kind.WALL: 1, Kind.LOW_OBSTACLE: 7, Kind.PIT: 6, Kind.LEDGE: 11}
## The editor's colors: walls red, low obstacles orange, pits purple, ledges
## yellow.
const PREVIEW_COLORS := {
	Kind.WALL: Color(1.0, 0.2, 0.2),
	Kind.LOW_OBSTACLE: Color(1.0, 0.6, 0.1),
	Kind.PIT: Color(0.7, 0.3, 1.0),
	Kind.LEDGE: Color(1.0, 0.95, 0.2),
}
## The 2D look of the sim's collider (the 2D game, a layout played without the
## view).
const SIM_COLORS := {
	Kind.WALL: Color(0.45, 0.42, 0.5),
	Kind.LOW_OBSTACLE: Color(0.55, 0.4, 0.25),
	Kind.PIT: Color(0.05, 0.04, 0.07),
	Kind.LEDGE: Color(0.6, 0.55, 0.3),
}
## How far over the footprint's plane the editor draws it (m).
const PREVIEW_LIFT_M := 0.03

## What the outline blocks. WALL (layer 1): walking, dashes, projectiles and
## sight. LOW_OBSTACLE (7): walking and knockback, not dashes or projectiles
## (a fence, rubble). PIT (6): a hole; enemies path around it, and its rules
## (blocking walking, falling) come with the pit step. LEDGE (11): a manual
## ledge (P9).
@export var kind: Kind = Kind.WALL:
	set(value):
		kind = value
		_dirty = true
## The outline in meters, in this node's own X/Z plane (a point (x, y) is
## local (x, 0, y)). Empty: derived as the convex hull of the asset's solid
## meshes from this node's height up to slice_height_m (a pit: down to it).
## Only for convex assets: a hull closes an archway's opening. Draw the
## outline of a concave asset, or use several footprints.
@export var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		_dirty = true
## The slice of the asset the derived outline and the validator look at: m
## above this node (a pit: below it).
@export var slice_height_m: float = 1.0:
	set(value):
		slice_height_m = value
		_dirty = true

var _preview: MeshInstance3D
var _dirty := true
var _check_left := 0.0
var _shown := false


## The outline in meters, in this node's X/Z plane: `polygon`, or the derived
## hull. Empty when there's nothing to derive it from.
func get_outline_local() -> PackedVector2Array:
	if not polygon.is_empty():
		return polygon
	var asset := get_parent() as Node3D
	if asset == null:
		return PackedVector2Array()
	var slab := get_slab_local()
	var points := PackedVector2Array()
	for s in RoomLayout.solid_slices(asset, self, slab.x, slab.y):
		points.append_array(s)
	if points.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	return hull if hull.size() >= 3 else PackedVector2Array()


## The heights (local y) the derived outline and the validator slice the
## asset between: x the bottom, y the top. A pit looks below its plane.
func get_slab_local() -> Vector2:
	return Vector2(-slice_height_m, 0.0) if kind == Kind.PIT else Vector2(0.0, slice_height_m)


## The collision layer number of this footprint's kind.
func get_layer_number() -> int:
	return LAYER_NUMBERS[kind]


## The layer as a collision bit.
func get_layer_bit() -> int:
	return 1 << (get_layer_number() - 1)


# --- The drawing (editor; in play with RoomLayout.debug_draw) -----------------------

func _enter_tree() -> void:
	_dirty = true
	_check_left = 0.0
	set_process(true)


func _exit_tree() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_shown = false


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.5
	var wanted := _should_show()
	if not Engine.is_editor_hint() and not wanted:
		set_process(false)   # in play the switch is read once
		return
	# In the editor a derived outline follows the asset's meshes, so it's redrawn
	# every half second; a drawn one only when it changes.
	if wanted != _shown or (wanted and (_dirty or polygon.is_empty())):
		_redraw(wanted)


func _should_show() -> bool:
	var layout := _layout()
	if Engine.is_editor_hint():
		return layout == null or layout.show_footprints
	return layout != null and layout.debug_draw


func _layout() -> RoomLayout:
	var n := get_parent()
	while n != null:
		if n is RoomLayout:
			return n as RoomLayout
		n = n.get_parent()
	return null


func _redraw(wanted: bool) -> void:
	_dirty = false
	_shown = wanted
	if not wanted:
		if is_instance_valid(_preview):
			_preview.visible = false
		return
	var outline := get_outline_local()
	if not is_instance_valid(_preview):
		_preview = MeshInstance3D.new()
		_preview.name = "FootprintPreview"
		_preview.set_meta(RoomLayout.TOOL_META, true)
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		material.no_depth_test = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.render_priority = 10
		_preview.material_override = material
		add_child(_preview, false, Node.INTERNAL_MODE_BACK)
	_preview.visible = true
	_preview.mesh = _outline_mesh(outline, PREVIEW_COLORS[kind])


static func _outline_mesh(outline: PackedVector2Array, color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if outline.size() < 3:
		return mesh
	var fill := PackedVector3Array()
	var fill_colors := PackedColorArray()
	for i in Geometry2D.triangulate_polygon(outline):
		fill.append(Vector3(outline[i].x, PREVIEW_LIFT_M, outline[i].y))
		fill_colors.append(Color(color, 0.3))
	if not fill.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = fill
		arrays[Mesh.ARRAY_COLOR] = fill_colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var lines := PackedVector3Array()
	var line_colors := PackedColorArray()
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		lines.append(Vector3(a.x, PREVIEW_LIFT_M, a.y))
		lines.append(Vector3(b.x, PREVIEW_LIFT_M, b.y))
		line_colors.append(color)
		line_colors.append(color)
	var line_arrays := []
	line_arrays.resize(Mesh.ARRAY_MAX)
	line_arrays[Mesh.ARRAY_VERTEX] = lines
	line_arrays[Mesh.ARRAY_COLOR] = line_colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
	return mesh
