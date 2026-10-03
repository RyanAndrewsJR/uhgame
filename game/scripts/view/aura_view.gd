extends EntityView
## An aura's 3D look (3D.md, The generic view mechanism; the 2D one is
## aura.gd): a thin ring on the floor around the unit, in the aura's color,
## pulsing as the 2D ring does. It goes when the aura does.

## The ring's tube width (m), and how far it sits above the floor (m).
@export var ring_width_m: float = 0.07
@export var lift_m: float = 0.03

var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _radius_m := 0.5
var _color := Color(1, 0.8, 0.3)


func _on_setup() -> void:
	_radius_m = maxf(Units.px_to_m(float(sim.get(&"radius"))), 0.1)
	var c: Variant = sim.get(&"color")
	_color = c if c is Color else _color
	var torus := TorusMesh.new()   # lies flat around its y axis
	torus.inner_radius = _radius_m - ring_width_m * 0.5
	torus.outer_radius = _radius_m + ring_width_m * 0.5
	torus.rings = 48
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(_color, 0.7)
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = lift_m
	add_child(_ring)


func _process(_delta: float) -> void:
	if is_sim_gone():
		return
	var pulse := 0.5 + 0.5 * sin(float(sim.call(&"get_age")) * 10.0)
	_ring.scale = Vector3.ONE * (1.0 + pulse * Units.px_to_m(2.0) / _radius_m)
	_material.albedo_color.a = 0.5 + pulse * 0.4
