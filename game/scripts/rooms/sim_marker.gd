@tool
class_name SimMarker
extends Marker3D
## Places a 2D sim scene in a room built in 3D (docs/3D.md, Rooms; 3D pivot
## P8): an enemy, an interactable, a hazard, a pickup or a perch. At load,
## RoomLayout.build_sim() instances `scene` in the sim room's Entities where
## this marker stands (Units.to_sim()), names it after the marker, and sets
## `properties` on it (e.g. passive: true for a training dummy). In the
## editor it shows the scene's look: a unit's model_scene, else a capsule as
## wide as its gameplay radius, tinted like its 2D body, with the marker's
## name over it. Nothing it shows is saved into the scene.

## The 2D sim scene to place.
@export var scene: PackedScene:
	set(value):
		scene = value
		_preview_dirty = true
## Set on the instance after it's made (property name -> value), e.g.
## {"passive": true, "modulate": Color(0.7, 0.75, 1)}.
@export var properties: Dictionary = {}:
	set(value):
		properties = value
		_preview_dirty = true

var _preview: Node3D
var _preview_dirty := true


## The sim node this marker places, at `position_px` (the marker's floor
## point in sim px), or null without a scene.
func make_sim_node(position_px: Vector2) -> Node:
	if scene == null:
		return null
	var node := scene.instantiate()
	node.name = name
	for key: Variant in properties:
		node.set(String(key), properties[key])
	if node is Node2D:
		(node as Node2D).position = position_px
	return node


# --- The editor's look ----------------------------------------------------------

func _enter_tree() -> void:
	_preview_dirty = true


func _exit_tree() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


func _process(_delta: float) -> void:
	# Editor only. (Godot turns processing on at ready for any script with
	# _process, so it's turned off here, not in _enter_tree.)
	if not Engine.is_editor_hint():
		set_process(false)
		return
	if _preview_dirty:
		_preview_dirty = false
		_rebuild_preview()


func _rebuild_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	if scene == null:
		return
	# A look at the sim scene without running it (its scripts aren't tools).
	var probe := scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var model: PackedScene = probe.get(&"model_scene") if &"model_scene" in probe else null
	var radius_m := 0.4
	var stats: Variant = probe.get(&"stats") if &"stats" in probe else null
	if stats is Resource and &"gameplay_radius" in stats:
		radius_m = Units.px_to_m(Units.to_px(float(stats.get(&"gameplay_radius"))))
	var tint: Variant = properties.get("modulate", properties.get(&"modulate", Color.WHITE))
	var color := _body_color(probe) * (tint as Color if tint is Color else Color.WHITE)
	probe.free()

	_preview = Node3D.new()
	_preview.name = "SimMarkerPreview"
	_preview.set_meta(RoomLayout.TOOL_META, true)
	var height := radius_m * 2.4
	if model:
		_preview.add_child(model.instantiate())
		height = 1.8
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = radius_m
		capsule.height = maxf(height, radius_m * 2.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		var body := MeshInstance3D.new()
		body.mesh = capsule
		body.material_override = material
		body.position = Vector3(0.0, capsule.height * 0.5, 0.0)
		_preview.add_child(body)
	var label := Label3D.new()
	label.text = String(name)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.008
	label.position = Vector3(0.0, height + 0.35, 0.0)
	_preview.add_child(label)
	add_child(_preview, false, Node.INTERNAL_MODE_BACK)


## The sim scene's 2D body color (its biggest polygon), as UnitView tints
## its capsule; grey without one.
static func _body_color(probe: Node) -> Color:
	var best: Polygon2D = null
	var best_area := 0.0
	for node in probe.find_children("*", "Polygon2D", true, false):
		var poly := node as Polygon2D
		if poly.polygon.is_empty():
			continue
		var r := Rect2(poly.polygon[0], Vector2.ZERO)
		for p in poly.polygon:
			r = r.expand(p)
		if r.get_area() > best_area:
			best = poly
			best_area = r.get_area()
	return best.color if best else Color(0.7, 0.7, 0.7)
