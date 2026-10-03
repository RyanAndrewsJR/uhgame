class_name FloorOverlay
extends SubViewport
## The floor drawings under the 3D view (docs/3D.md, Floor drawings; 3D pivot
## P7). Telegraphs, the player's ability indicators, the hover ring, swing
## arcs and rings are drawn by their own 2D nodes, exactly as in the 2D game.
## This viewport shares the sim's World2D and draws what's on canvas
## visibility layer 3 ("floor drawings") into a texture, in sim px; the
## floor's shader (floor_drawings.gdshader) lays that texture on the walkable
## ground straight down, so a drawing matches its sim shape exactly.
## It covers a window of floor around the camera, not the whole room, so its
## cost doesn't grow with the room: the floor the camera sees plus a margin,
## moved with the camera's focus, snapped to whole texels so drawings don't
## shimmer, and kept in the room (a room smaller than the window: the room).

## Canvas visibility layer 3, "floor drawings" (its bit). A 2D node with it
## draws on the 3D floor. Its ancestors are on layer 2 ("sim"), which this
## viewport draws too: only the room's root and its Entities are on layer 2,
## and they draw nothing themselves. The 2D game draws every layer, so the bit
## changes nothing there.
const DRAWING_VISIBILITY_BIT := 1 << 2
## After GameCamera3D (10) has moved this frame.
const PROCESS_PRIORITY := 25
## The texture's sides are rounded up to a multiple of this many texels.
const SIZE_STEP := 64

## Texels per sim px (2: 64 per meter). P0b drew the whole sandbox at this
## density inside a whole frame of 0.3–0.85 ms of GPU time.
@export var texels_per_px: float = 2.0
## Floor drawn past what the camera sees, on every side (m), so a shake or a
## lean never shows the window's edge.
@export var margin_m: float = 2.0

## The camera whose view the window covers.
var camera: GameCamera3D
## The room's floor in meters (x and z as a Rect2); the window stays inside.
## Empty: no bounds.
var bounds_m: Rect2 = Rect2()
## Where the window's top-left corner lies on the floor (m, x and z), on a
## whole texel.
var origin_m: Vector2 = Vector2.ZERO

## The floor materials (floor_drawings.gdshader) that show the drawings.
var _materials: Array[ShaderMaterial] = []
## The floor the camera sees around its focus, the margin included, relative
## to the focus (m, x and z), and the screen size it was measured at.
var _seen_m: Rect2 = Rect2()
var _seen_for: Vector2 = Vector2.ZERO
var _placed := false


func _init() -> void:
	name = "FloorOverlay"
	transparent_bg = true
	disable_3d = true
	canvas_cull_mask = WorldView.SIM_VISIBILITY_BIT | DRAWING_VISIBILITY_BIT
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	process_priority = PROCESS_PRIORITY
	size = Vector2i(SIZE_STEP, SIZE_STEP)


## WorldView calls this once, after setting `world_2d` (the sim's: its own
## viewport's) and adding it: the window follows `p_camera` and stays in
## `p_bounds_m`. The canvas transform can only be set once this viewport is in
## the tree (before, Godot errors with canvas_map.has).
func setup(p_camera: GameCamera3D, p_bounds_m: Rect2) -> void:
	camera = p_camera
	bounds_m = p_bounds_m
	update_window()


## Lays the drawings on a floor material (floor_drawings.gdshader).
func add_floor_material(material: ShaderMaterial) -> void:
	if material == null or _materials.has(material):
		return
	_materials.append(material)
	material.set_shader_parameter(&"drawings", get_texture())
	material.set_shader_parameter(&"drawings_size_m", get_size_m())
	material.set_shader_parameter(&"drawings_origin_m", origin_m)


func _process(_delta: float) -> void:
	update_window()


## Moves the window with the camera's focus (each frame, after the camera
## moved): the floor it sees plus the margin, kept in the room, snapped to
## whole texels. The texture is resized only when the screen's shape changes.
func update_window() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var screen := camera.get_viewport().get_visible_rect().size
	if screen != _seen_for:
		_seen_for = screen
		_seen_m = seen_floor_around_focus_m(camera).grow(margin_m)
		var want := window_size_texels(_seen_m.size, get_texels_per_m(), bounds_m)
		if size != want:
			size = want
		for material in _materials:
			material.set_shader_parameter(&"drawings_size_m", get_size_m())
	var focus := camera.get_focus()
	var size_m := get_size_m()
	# The texture's rounding up spreads evenly on both sides of what's seen.
	var want_m := Vector2(focus.x, focus.z) + _seen_m.position - (size_m - _seen_m.size) * 0.5
	var origin := window_origin_m(want_m, size_m, bounds_m, get_texels_per_m())
	if origin == origin_m and _placed:
		return
	origin_m = origin
	_placed = true
	canvas_transform = window_canvas_transform(origin_m, texels_per_px)
	for material in _materials:
		material.set_shader_parameter(&"drawings_origin_m", origin_m)


func get_texels_per_m() -> float:
	return texels_per_px * Units.PX_PER_METER


## How much floor the window covers (m, x and z).
func get_size_m() -> Vector2:
	return Vector2(size) / get_texels_per_m()


## The floor `p_camera` sees at its focus height, relative to its focus (m,
## x and z): the box around the points where the rays through the screen's
## four corners meet the floor, the shake set aside. Every look we use sees
## floor at the screen's top edge (the default: still 35° down there).
## P9: at the lowest walkable height in view instead (a floor 1 m lower is
## seen 1.4 m farther at the top edge).
static func seen_floor_around_focus_m(p_camera: GameCamera3D) -> Rect2:
	var screen := p_camera.get_viewport().get_visible_rect()
	var center := screen.get_center()
	var corners: Array[Vector2] = [screen.position, Vector2(screen.end.x, screen.position.y),
		screen.end, Vector2(screen.position.x, screen.end.y)]
	var box := Rect2()
	for i in corners.size():
		var d := p_camera.screen_to_floor(corners[i] - center)
		var p := Vector2(d.x, d.z)
		box = Rect2(p, Vector2.ZERO) if i == 0 else box.expand(p)
	return box


## The texture's size (texels) for a window `seen_size_m` across: rounded up
## to SIZE_STEP texels, and no bigger than the room (`p_bounds_m`; empty: no
## limit).
static func window_size_texels(seen_size_m: Vector2, p_texels_per_m: float, p_bounds_m: Rect2) -> Vector2i:
	var want := (seen_size_m * p_texels_per_m / SIZE_STEP).ceil() * SIZE_STEP
	if p_bounds_m.has_area():
		want = want.min((p_bounds_m.size * p_texels_per_m - Vector2(0.001, 0.001)).ceil())
	return Vector2i(want)


## Where the window's top-left corner goes (m, x and z): `want_m`, kept so the
## window stays in the room (on an axis where the room is smaller than the
## window: the room's edge), on a whole texel.
static func window_origin_m(want_m: Vector2, size_m: Vector2, p_bounds_m: Rect2, p_texels_per_m: float) -> Vector2:
	var o := want_m
	if p_bounds_m.has_area():
		o.x = p_bounds_m.position.x if size_m.x >= p_bounds_m.size.x else clampf(o.x, p_bounds_m.position.x, p_bounds_m.end.x - size_m.x)
		o.y = p_bounds_m.position.y if size_m.y >= p_bounds_m.size.y else clampf(o.y, p_bounds_m.position.y, p_bounds_m.end.y - size_m.y)
	return (o * p_texels_per_m).round() / p_texels_per_m


## The canvas transform that draws the sim (px) into the window: the sim
## point at the window's corner lands on texel (0, 0), `p_texels_per_px`
## texels per px. The floor's shader reads the same texel at that point's
## x/z: uv = (x/z - origin_m) / size_m.
static func window_canvas_transform(p_origin_m: Vector2, p_texels_per_px: float) -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * p_texels_per_px, 0.0, -Units.m_to_px(1.0) * p_origin_m * p_texels_per_px)
