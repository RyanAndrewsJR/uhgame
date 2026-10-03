extends EntityView
## A projectile's 3D look (3D.md, The generic view mechanism): the default
## bolt, tinted by its ability's icon_color, flying at chest height along its
## direction, with a short flash where it ends. A wide projectile (a wave such
## as Cleave Wave) is a flat slab across its path instead.

## How high the bolt flies (m; the 2D draws it 10 px above its line). It
## follows the terrain from P9.
@export var height_m: float = 0.9
@export var bolt_length_m: float = 0.6
## Wider than this (half width, m) and it's a slab.
@export var slab_from_half_width_m: float = 0.25
## The flash where it ends (s).
@export var impact_time: float = 0.15

var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func get_height_m() -> float:
	return height_m


func _on_setup() -> void:
	var ability: Variant = sim.get(&"ability")
	var color := (ability as Ability).icon_color if ability is Ability else Color(0.8, 0.8, 0.8)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = color
	_mesh = MeshInstance3D.new()
	_mesh.name = "Bolt"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half_width_m := Units.px_to_m(float(sim.get(&"half_width_px")))
	if half_width_m >= slab_from_half_width_m:
		var slab := BoxMesh.new()
		slab.size = Vector3(half_width_m * 2.0, 0.12, 0.3)
		_mesh.mesh = slab
	else:
		var bolt := CapsuleMesh.new()
		bolt.radius = maxf(half_width_m, 0.08)
		bolt.height = maxf(bolt_length_m, bolt.radius * 2.0)
		_mesh.mesh = bolt
		_mesh.rotation.x = PI * 0.5   # the capsule's axis along its flight (+z)
	_mesh.material_override = _material
	add_child(_mesh)


func _on_sync() -> void:
	var dir: Variant = sim.get(&"direction")
	if dir is Vector2 and dir != Vector2.ZERO:
		rotation.y = atan2(dir.x, dir.y)


func on_sim_exited() -> void:
	_sim_gone = true
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", _mesh.scale * 1.8, impact_time)
	tween.parallel().tween_property(_material, "albedo_color:a", 0.0, impact_time)
	tween.tween_callback(queue_free)
