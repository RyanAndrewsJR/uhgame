extends EntityView
## Staggered's 3D look (3D.md, The generic view mechanism; the 2D one is
## staggered_mark.gd): a pale yellow ring, cracked in four places, over the
## unit's model, pulsing, so the player sees who a Cleave hits harder. It
## follows the unit it sits on.

@export var ring_radius_m: float = 0.28
@export var piece_thickness_m: float = 0.05
## How far over the model's top the ring floats (m).
@export var above_head_m: float = 0.3
@export var color: Color = Color(1.0, 0.92, 0.55, 0.9)

var _ring: Node3D
var _time := 0.0


func _on_setup() -> void:
	_ring = Node3D.new()
	_ring.name = "Ring"
	add_child(_ring)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	# Four arcs with gaps, as straight pieces: each covers a quarter turn less its gap.
	var gap := 0.5
	var arc := TAU / 4.0 - gap
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0 * ring_radius_m * sin(arc * 0.5), piece_thickness_m, piece_thickness_m)
	for i in 4:
		var mid := i * TAU / 4.0 + 0.25 + arc * 0.5
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.position = Vector3(cos(mid), 0.0, sin(mid)) * ring_radius_m * cos(arc * 0.5)
		piece.rotation.y = -mid + PI * 0.5
		_ring.add_child(piece)


func get_height_m() -> float:
	return world_view.unit_height_m(sim.get_parent()) + above_head_m


func _sim_position_px() -> Vector2:
	var unit := sim.get_parent() as Node2D
	return unit.global_position if unit else sim.global_position


func _process(delta: float) -> void:
	_time += delta
	_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(_time * 10.0))
