class_name VFX
## Quick placeholder effects built from shapes and tweens. Everything here
## cleans itself up. Swap for real particles/sprites later.

## afterimage() sorts this far above the unit's feet (px), so y-sorting draws
## it just behind the unit (MovementVFXComponent uses the same offset).
const AFTERIMAGE_SORT_OFFSET := 0.02
## How much the 2D game squashes a floor circle north-south for its 3/4 look.
const FLOOR_SQUASH_2D := 0.55

## Floor circles drawn by 2D nodes (ring(), the hover ring) are squashed
## north-south by this: FLOOR_SQUASH_2D in the 2D game; 1 (true circles)
## while the 3D view shows the game, whose camera foreshortens the floor
## itself (WorldView sets it and puts it back; 3D.md, Floor drawings).
static var floor_squash: float = FLOOR_SQUASH_2D


## A presentation hook's scene (ABILITIES AB14: cast_vfx, impact_vfx,
## swing_vfx): instanced next to `anchor` (its parent, the room's Entities),
## at `pos` (world space) rotated to `angle` if its root is a Node2D; then
## setup(...setup_args) on the root if it has one. null scene or a freed
## anchor = nothing (returns null). VFX only: never gameplay state.
## A scene whose root is a Node3D (3D.md, P7) goes into the 3D view instead
## (WorldView.add_scene_at(): on the floor at `pos`, its +Z along `angle`);
## without a view (the 2D game, every test) it isn't spawned (returns null).
## A Node2D root on canvas visibility layer 3 is a floor drawing: it shows on
## the 3D floor too.
static func spawn_scene(scene: PackedScene, anchor: Node2D, pos: Vector2, angle: float, setup_args: Array = []) -> Node:
	if scene == null or not is_instance_valid(anchor) or anchor.get_parent() == null:
		return null
	var node := scene.instantiate()
	if node is Node3D:
		var view := WorldView.of(anchor)
		if view == null:
			node.free()
			return null
		view.add_scene_at(node as Node3D, pos, angle)
	else:
		anchor.get_parent().add_child(node)
		if node is Node2D:
			(node as Node2D).global_position = pos
			(node as Node2D).global_rotation = angle
			(node as Node2D).reset_physics_interpolation()
	if node.has_method(&"setup"):
		node.callv(&"setup", setup_args)
	return node


## Crescent slash sweeping across `half_arc` on either side of `angle`.
static func slash(parent: Node, origin: Vector2, angle: float, inner: float, outer: float,
		half_arc: float, color: Color = Color(1, 1, 1, 0.9), duration: float = 0.14, sweep_dir: float = 1.0) -> void:
	var poly := Polygon2D.new()
	poly.color = color
	poly.z_index = 20
	var pts := PackedVector2Array()
	var steps := 14
	var width := deg_to_rad(40.0)
	for i in steps + 1:
		pts.append(Vector2.from_angle(lerpf(-width, width, float(i) / steps)) * outer)
	for i in range(steps, -1, -1):
		pts.append(Vector2.from_angle(lerpf(-width, width, float(i) / steps)) * inner)
	poly.polygon = pts
	poly.position = origin
	poly.rotation = angle - (half_arc - width) * sweep_dir
	poly.visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # a floor drawing in 3D (3D.md)
	parent.add_child(poly)
	var tw := poly.create_tween()
	tw.tween_property(poly, "rotation", angle + (half_arc - width) * sweep_dir, duration)
	tw.parallel().tween_property(poly, "modulate:a", 0.0, duration * 1.6)
	tw.tween_callback(poly.queue_free)


## Expanding ring, squashed to lie on the floor (floor_squash).
static func ring(parent: Node, pos: Vector2, from_radius: float, to_radius: float,
		color: Color, duration: float = 0.3, width: float = 2.0) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.z_index = 19
	line.closed = true
	line.visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # a floor drawing in 3D (3D.md)
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a), sin(a) * floor_squash))
	line.points = pts
	line.position = pos
	line.scale = Vector2.ONE * from_radius
	line.width = width / maxf(from_radius, 0.01)
	parent.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "scale", Vector2.ONE * to_radius, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(line, "width", width / maxf(to_radius, 0.01), duration)
	tw.parallel().tween_property(line, "modulate:a", 0.0, duration)
	tw.tween_callback(line.queue_free)


## A fading copy of the unit's body shapes (dash trails). Like the F3 dash
## afterimages (MovementVFXComponent), it sorts just above the unit's feet in
## the y-sorted Entities, so it draws behind the unit and above the floor
## tiles (a negative z_index drew it under the TileMapLayer, unseen).
static func afterimage(unit: Unit, color: Color = Color(0.6, 0.8, 1.0, 0.5), duration: float = 0.25) -> void:
	var holder := Node2D.new()
	holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # a still image where it's placed
	holder.global_position = unit.global_position - Vector2(0.0, AFTERIMAGE_SORT_OFFSET)
	var ghost := Node2D.new()
	ghost.position = Vector2(0.0, AFTERIMAGE_SORT_OFFSET)
	ghost.scale = unit.body.scale
	holder.add_child(ghost)
	for child in unit.body.get_children():
		var src := child as Polygon2D
		if src == null:
			continue
		var p := Polygon2D.new()
		p.polygon = src.polygon
		p.position = src.position
		p.color = color
		ghost.add_child(p)
	unit.get_parent().add_child(holder)
	var tw := holder.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, duration)
	tw.tween_callback(holder.queue_free)


## Vertical light pillar / impact flash at a point.
static func impact(parent: Node, pos: Vector2, color: Color, height: float = 60.0, duration: float = 0.25) -> void:
	var poly := Polygon2D.new()
	poly.color = color
	poly.z_index = 21
	poly.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(-2, -height), Vector2(2, -height), Vector2(6, 0)])
	poly.position = pos
	parent.add_child(poly)
	var tw := poly.create_tween()
	tw.tween_property(poly, "scale", Vector2(0.2, 1.1), duration)
	tw.parallel().tween_property(poly, "modulate:a", 0.0, duration)
	tw.tween_callback(poly.queue_free)


## Pulsing ring under a unit that lasts while `is_active` returns true.
static func aura(unit: Unit, color: Color, is_active: Callable, max_time: float = 10.0) -> void:
	var node := Node2D.new()
	node.set_script(preload("res://scripts/vfx/aura.gd"))
	node.set("color", color)
	node.set("is_active", is_active)
	node.set("max_time", max_time)
	unit.add_child(node)
