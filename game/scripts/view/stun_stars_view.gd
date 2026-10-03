extends EntityView
## The stun's 3D look (3D.md, The generic view mechanism; the 2D one is
## stun_stars.gd): three little stars circling over the unit's model. It
## follows the unit it sits on.

@export var star_count: int = 3
@export var star_radius_m: float = 0.07
@export var orbit_radius_m: float = 0.3
## Turns per second (radians).
@export var spin_speed: float = 6.0
## How far over the model's top the stars circle (m).
@export var above_head_m: float = 0.2
@export var color: Color = Color(1, 0.9, 0.3)

var _stars: Array[MeshInstance3D] = []
var _spin := 0.0


func _on_setup() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = star_radius_m
	mesh.height = star_radius_m * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	for i in star_count:
		var star := MeshInstance3D.new()
		star.mesh = mesh
		star.material_override = material
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(star)
		_stars.append(star)
	_place_stars()


func get_height_m() -> float:
	return world_view.unit_top_m(sim.get_parent()) + above_head_m   # P9: over the model where it stands (the ground, a knock-up)


func _sim_position_px() -> Vector2:
	var unit := sim.get_parent() as Node2D
	return unit.global_position if unit else sim.global_position


func _process(delta: float) -> void:
	_spin += delta * spin_speed
	_place_stars()


func _place_stars() -> void:
	for i in _stars.size():
		var a := _spin + i * TAU / _stars.size()
		_stars[i].position = Vector3(cos(a), 0.0, sin(a)) * orbit_radius_m
