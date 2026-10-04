class_name PickupView
extends EntityView
## A pickup's 3D look (LOOT.md, View; LOOT L7), the Pickup's default view.
## Placeholders until the art pass (Ryan, 2026-10-03): a small gem (an
## octahedron) in its item's rarity color hovering over the ground, bobbing
## and turning slowly; from beam_from_rarity up (Legendary and Artifact) a
## light beam in that color too, drawn with PillarView's shader, while it lies
## there. The pop is an arc from where it dropped to its landing spot over the
## pickup's pop time, following the ground's height at both ends. Collected
## or taken: gone at once (the HUD line and the pickup sound say so).

const PILLAR_SHADER := preload("res://scripts/view/pillar.gdshader")

## The gem's size, tip to tip (m).
@export var gem_size_m: float = 0.25
## How high the gem's center hovers over the ground (m).
@export var gem_height_m: float = 0.35
## The bob: up and down by this much (m), this many times a second.
@export var bob_m: float = 0.05
@export var bob_hz: float = 0.6
## How fast the gem turns (degrees a second).
@export var turn_deg_per_s: float = 60.0
## How much brighter than its color the gem glows (emission energy).
@export var glow: float = 0.6
## The pop's arc: its top over the line between the two grounds (m).
@export var hop_apex_m: float = 0.6
## This rarity and above get the beam.
@export var beam_from_rarity: Item.Rarity = Item.Rarity.LEGENDARY
@export var beam_height_m: float = 1.25
@export var beam_foot_radius_m: float = 0.08
@export var beam_top_radius_m: float = 0.03
@export_range(0.0, 1.0) var beam_alpha: float = 0.55
## How much nearer the camera the beam is drawn (m; PillarView's pull). 0: it
## stands where it is.
@export var beam_pull_m: float = 0.0

## One gem mesh for every pickup (each has its own material).
static var _gem_mesh: ArrayMesh

## Turns and bobs every frame (not interpolated); the gem hangs under it.
var pivot: Node3D
var gem: MeshInstance3D
## null below beam_from_rarity.
var beam: MeshInstance3D

var _color := Color.WHITE
var _from_ground_m := 0.0
var _to_ground_m := 0.0
var _age := 0.0


## Its height (m): the ground under it once landed; during the hop, the line
## between the ground where it dropped and the ground where it lands, plus the
## arc.
func get_height_m() -> float:
	var t := _hop_progress()
	if t >= 1.0:
		return ground_height_m()
	return lerpf(_from_ground_m, _to_ground_m, t) + hop_apex_m * 4.0 * t * (1.0 - t)


## True while the beam shows (a landed pickup of beam_from_rarity or above).
func is_beam_shown() -> bool:
	return beam != null and beam.visible


## The gem's color (its rarity's).
func get_color() -> Color:
	return _color


func _on_setup() -> void:
	var pickup := sim as Pickup
	_color = pickup.get_color() if pickup != null else Color.WHITE
	if world_view != null and pickup != null:
		_from_ground_m = world_view.ground_height_m(pickup.get_hop_from())
		_to_ground_m = world_view.ground_height_m(pickup.global_position)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # animated every frame
	pivot.position.y = gem_height_m
	add_child(pivot)
	gem = MeshInstance3D.new()
	gem.name = "Gem"
	gem.mesh = _get_gem_mesh()
	gem.scale = Vector3.ONE * gem_size_m
	var material := StandardMaterial3D.new()
	material.albedo_color = _color
	material.emission_enabled = true
	material.emission = _color
	material.emission_energy_multiplier = glow
	material.roughness = 0.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	gem.material_override = material
	pivot.add_child(gem)
	if pickup != null and pickup.item != null and pickup.item.rarity >= beam_from_rarity:
		beam = _make_beam()
		beam.visible = pickup.is_landed()
		add_child(beam)


func _on_sync() -> void:
	if beam != null and not beam.visible and _hop_progress() >= 1.0:
		beam.visible = true


func _process(delta: float) -> void:
	_age += delta
	if pivot != null:
		pivot.position.y = gem_height_m + sin(_age * TAU * bob_hz) * bob_m
		pivot.rotation.y = _age * deg_to_rad(turn_deg_per_s)


## Where the view stands (px): along the hop from where it dropped to its
## landing spot (the sim already stands there), then the spot.
func _sim_position_px() -> Vector2:
	var pickup := sim as Pickup
	if pickup == null:
		return sim.global_position
	var t := pickup.get_hop_progress()
	return pickup.global_position if t >= 1.0 else pickup.get_hop_from().lerp(pickup.global_position, t)


func _hop_progress() -> float:
	if is_sim_gone() or not (sim is Pickup):
		return 1.0
	return (sim as Pickup).get_hop_progress()


func _make_beam() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = beam_height_m
	mesh.bottom_radius = beam_foot_radius_m
	mesh.top_radius = beam_top_radius_m
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = PILLAR_SHADER
	material.set_shader_parameter(&"pull_m", beam_pull_m)
	var node := MeshInstance3D.new()
	node.name = "Beam"
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = beam_height_m * 0.5   # the cylinder stands on the ground
	node.set_instance_shader_parameter(&"color", Color(_color, beam_alpha))
	return node


## An octahedron 1 m tip to tip (scaled by gem_size_m), flat-shaded.
static func _get_gem_mesh() -> ArrayMesh:
	if _gem_mesh != null:
		return _gem_mesh
	var top := Vector3(0.0, 0.5, 0.0)
	var bottom := Vector3(0.0, -0.5, 0.0)
	var ring := [Vector3(0.35, 0.0, 0.0), Vector3(0.0, 0.0, 0.35), Vector3(-0.35, 0.0, 0.0), Vector3(0.0, 0.0, -0.35)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		_add_face(st, top, a, b)
		_add_face(st, bottom, b, a)
	_gem_mesh = st.commit()
	return _gem_mesh


## One flat face, its normal pointing away from the gem's center (the
## material draws both sides, so the winding doesn't matter).
static func _add_face(st: SurfaceTool, p: Vector3, q: Vector3, r: Vector3) -> void:
	var normal := (q - p).cross(r - p).normalized()
	if normal.dot(p + q + r) < 0.0:
		normal = -normal
	for v in [p, q, r]:
		st.set_normal(normal)
		st.add_vertex(v)
