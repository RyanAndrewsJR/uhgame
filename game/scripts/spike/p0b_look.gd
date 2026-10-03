extends RefCounted
## P0b feel spike (throwaway; branch spike/3d-p0b, never merged).
## Every surface's two materials, (a) fully lit PBR and (b) painted with a
## light ramp, keyed by a surface kind. Meshes register here and the material
## toggle swaps all of them at once.

const PAINTED_SHADER := preload("res://scripts/spike/shaders/p0b_painted.gdshader")
const PBR_SHADER := preload("res://scripts/spike/shaders/p0b_pbr.gdshader")

## Surface kinds: pattern (p0b_common.gdshaderinc), two colors, and PBR extras.
const KINDS := {
	&"floor": {"pattern": 0, "a": Color(0.58, 0.54, 0.49), "b": Color(0.45, 0.42, 0.39)},
	&"wall": {"pattern": 1, "a": Color(0.6, 0.55, 0.49), "b": Color(0.47, 0.43, 0.39)},
	&"cap": {"pattern": 6, "a": Color(0.13, 0.12, 0.11), "b": Color(0.2, 0.18, 0.17)},
	&"rock": {"pattern": 2, "a": Color(0.56, 0.5, 0.44), "b": Color(0.4, 0.37, 0.35)},
	&"grass": {"pattern": 3, "a": Color(0.5, 0.68, 0.3), "b": Color(0.2, 0.36, 0.15)},
	&"roof": {"pattern": 4, "a": Color(0.66, 0.3, 0.21), "b": Color(0.5, 0.23, 0.17)},
	&"plaster": {"pattern": 5, "a": Color(0.8, 0.74, 0.63), "b": Color(0.38, 0.25, 0.16), "wall_height": 2.6},
	&"pillar": {"pattern": 7, "a": Color(0.7, 0.67, 0.62), "b": Color(0.56, 0.53, 0.49)},
	&"metal": {"pattern": 7, "a": Color(0.2, 0.19, 0.19), "b": Color(0.3, 0.28, 0.27), "metallic": 0.7, "rough": 0.6},
	&"wood": {"pattern": 7, "a": Color(0.36, 0.24, 0.15), "b": Color(0.27, 0.18, 0.11)},
	&"window": {"pattern": 7, "a": Color(0.25, 0.18, 0.1), "b": Color(0.3, 0.2, 0.1), "emission": 1.6},
	&"slime": {"pattern": 7, "a": Color(0.35, 0.85, 0.4), "b": Color(0.3, 0.75, 0.35), "rough": 0.3},
}
## Kinds that belong to tall things: the fade and the cut-out circle apply.
const TALL_KINDS: Array[StringName] = [&"rock", &"grass", &"roof", &"plaster", &"pillar", &"window", &"wood"]

var painted: bool = true
## kind -> [painted ShaderMaterial, pbr ShaderMaterial]
var _materials: Dictionary = {}
## [GeometryInstance3D, [painted, pbr]] for everything registered.
var _users: Array = []


func _init() -> void:
	for kind: StringName in KINDS:
		_materials[kind] = [_make(PAINTED_SHADER, KINDS[kind]), _make(PBR_SHADER, KINDS[kind])]


func _make(shader: Shader, spec: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"pattern", spec["pattern"])
	m.set_shader_parameter(&"color_a", spec["a"])
	m.set_shader_parameter(&"color_b", spec["b"])
	if spec.has("wall_height"):
		m.set_shader_parameter(&"wall_height", spec["wall_height"])
	if spec.has("emission"):
		m.set_shader_parameter(&"emission_amount", spec["emission"])
	if shader == PBR_SHADER:
		m.set_shader_parameter(&"metallic", spec.get("metallic", 0.0))
		m.set_shader_parameter(&"roughness_scale", spec.get("rough", 1.0))
	return m


## The pair for a kind (painted, pbr).
func pair(kind: StringName) -> Array:
	return _materials[kind]


## A new pair for a model's own texture (pattern -1), lit like everything else.
func model_pair(albedo: Texture2D, tint: Color = Color.WHITE) -> Array:
	var out := []
	for shader: Shader in [PAINTED_SHADER, PBR_SHADER]:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"pattern", -1)
		m.set_shader_parameter(&"albedo_tex", albedo)
		m.set_shader_parameter(&"color_a", tint)
		m.set_shader_parameter(&"ao_strength", 0.0)
		if shader == PBR_SHADER:
			m.set_shader_parameter(&"bump", 0.0)
			m.set_shader_parameter(&"roughness_scale", 0.9)
		out.append(m)
	return out


## A new pair for a flat-colored thing (slimes): its own colors.
func color_pair(kind: StringName, color: Color) -> Array:
	var out := []
	for m: ShaderMaterial in _materials[kind]:
		var copy: ShaderMaterial = m.duplicate()
		copy.set_shader_parameter(&"color_a", color)
		copy.set_shader_parameter(&"color_b", color.darkened(0.12))
		copy.set_shader_parameter(&"ao_strength", 0.0)
		out.append(copy)
	return out


## Registers a mesh with a kind (or an explicit pair) and gives it the
## current material.
func use(geo: GeometryInstance3D, kind_or_pair: Variant) -> void:
	var p: Array = _materials[kind_or_pair] if kind_or_pair is StringName else kind_or_pair
	_users.append([geo, p])
	geo.material_override = p[0] if painted else p[1]


func set_painted(on: bool) -> void:
	painted = on
	var alive: Array = []
	for entry: Array in _users:
		if is_instance_valid(entry[0]):
			(entry[0] as GeometryInstance3D).material_override = entry[1][0] if painted else entry[1][1]
			alive.append(entry)
	_users = alive


## Sets a parameter on both materials of a kind.
func set_kind_param(kind: StringName, param: StringName, value: Variant) -> void:
	for m: ShaderMaterial in _materials[kind]:
		m.set_shader_parameter(param, value)


## Sets a parameter on every tall kind (the cut-out circle).
func set_tall_param(param: StringName, value: Variant) -> void:
	for kind in TALL_KINDS:
		set_kind_param(kind, param, value)
