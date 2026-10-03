extends Node3D
## VFX.impact()'s light pillar in the 3D view (3D.md, P7's 2D-only looks; the
## 2D one is a Polygon2D, hidden with the sim there): a tapered beam standing
## on the ground where it's placed (WorldView.add_scene_at()). It narrows,
## stretches and fades as the 2D one does, then frees itself. setup() starts
## it. Drawn by pillar.gdshader: pulled toward the camera, so it shows in front
## of the unit it stands in, as the 2D one drew over the body.

const PILLAR_SHADER := preload("res://scripts/view/pillar.gdshader")

## The beam's radius at its foot and at its top (m). The 2D pillar is 12 px
## wide at its foot and 4 px at its top.
@export var foot_radius_m: float = 0.1875
@export var top_radius_m: float = 0.0625
## Its size when it's gone, as the 2D tween: 20% as wide, 10% taller.
@export var end_width_scale: float = 0.2
@export var end_height_scale: float = 1.1
## Multiplies the height the caller asks for.
@export var height_scale: float = 1.0
@export var radial_segments: int = 12
## How much nearer the camera it's drawn (m): more than the widest unit's
## radius (the elite slime's 0.75 m), so it shows in front of that unit.
@export var pull_m: float = 0.8

## One material and one beam for every pillar (the color is an instance
## uniform; the height and width are the pivot's scale). Made by the first,
## from its exports: setting them again would rebuild the mesh at every hit.
static var _material: ShaderMaterial
static var _mesh: CylinderMesh

## Scaled to the beam's height and width (its origin at the beam's foot).
var pivot: Node3D
var beam: MeshInstance3D
var _color := Color.WHITE


## `height_m` tall, in `color` (its alpha too), gone after `duration` s.
func setup(color: Color, height_m: float, duration: float) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = PILLAR_SHADER
		_material.set_shader_parameter(&"pull_m", pull_m)
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.height = 1.0
		_mesh.bottom_radius = foot_radius_m
		_mesh.top_radius = top_radius_m
		_mesh.radial_segments = radial_segments
		_mesh.rings = 1
		_mesh.cap_top = false
		_mesh.cap_bottom = false
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # animated every frame
	var height := maxf(height_m * height_scale, 0.01)
	pivot.scale = Vector3(1.0, height, 1.0)
	add_child(pivot)
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = _mesh
	beam.material_override = _material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 0.5   # the unit-high cylinder stands on the pivot
	pivot.add_child(beam)
	_color = color
	_set_alpha(color.a)
	var tw := create_tween()
	tw.tween_property(pivot, "scale", Vector3(end_width_scale, height * end_height_scale, end_width_scale), duration)
	tw.parallel().tween_method(_set_alpha, color.a, 0.0, duration)
	tw.tween_callback(queue_free)


## The beam's color now (its alpha fades to 0).
func get_color() -> Color:
	return beam.get_instance_shader_parameter(&"color") if beam else _color


func _set_alpha(alpha: float) -> void:
	beam.set_instance_shader_parameter(&"color", Color(_color, alpha))
