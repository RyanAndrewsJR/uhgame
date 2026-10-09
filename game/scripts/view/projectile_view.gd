extends EntityView
## A projectile's 3D look (3D.md, The generic view mechanism): the default
## bolt, tinted by its ability's icon_color (a swing's shot, ARCHETYPES AR1b: its
## projectile_color), flying at chest height along its
## direction, with a short flash where it ends. A wide projectile (a wave such
## as Cleave Wave) is a flat slab across its path instead.

## How high the bolt flies over the ground (m; the 2D draws it 10 px above its
## line). Since P9 it starts that high over the ground where it's fired and
## eases toward that height over the ground under it (a share per tick,
## ground_follow), never closer to the ground than min_clearance_m: a shot
## from a plateau glides down instead of dropping at the cliff.
@export var height_m: float = 0.9
@export_range(0.0, 1.0, 0.01) var ground_follow: float = 0.15
@export var min_clearance_m: float = 0.15
@export var bolt_length_m: float = 0.6
## Wider than this (half width, m) and it's a slab.
@export var slab_from_half_width_m: float = 0.25
## The flash where it ends (s).
@export var impact_time: float = 0.15

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _flight_m := INF


func get_height_m() -> float:
	var ground := world_view.ground_height_m(_sim_position_px()) if world_view else 0.0
	var want := ground + height_m
	_flight_m = want if _flight_m == INF else lerpf(_flight_m, want, ground_follow)
	return maxf(_flight_m, ground + min_clearance_m)


func _on_setup() -> void:
	var ability: Variant = sim.get(&"ability")
	var tint: Variant = sim.get(&"tint")   # ARCHETYPES AR1b: a swing's shot has no ability
	var color := (ability as Ability).icon_color if ability is Ability else (tint as Color if tint is Color else Color(0.8, 0.8, 0.8))
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
