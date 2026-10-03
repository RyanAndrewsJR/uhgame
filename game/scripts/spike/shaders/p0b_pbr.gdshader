// P0b feel spike (throwaway; branch spike/3d-p0b, never merged).
// Material (a): fully lit PBR. The same patterns as the painted material,
// but with nothing painted in: color, roughness and a bump from the
// pattern's height, and Godot's own lighting does the rest.
shader_type spatial;

#include "res://scripts/spike/shaders/p0b_common.gdshaderinc"

uniform float wall_height = 1.2;
uniform float bump = 0.012;
uniform float ao_strength = 1.0;
uniform float metallic = 0.0;
uniform float roughness_scale = 1.0;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (!IN_SHADOW_PASS && faded_out(FRAGCOORD.xy, VIEWPORT_SIZE, VERTEX)) {
		discard;
	}
	vec3 wn = normalize(world_normal);
	Surf s = eval_surf(world_pos, wn, UV, wall_height);
	if (pattern >= 0 && bump > 0.0) {
		// Bump from the pattern's height, in the surface's own plane.
		vec3 t = normalize(cross(wn, abs(wn.y) > 0.9 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0)));
		vec3 b = cross(wn, t);
		float e = 0.01;
		float hx = eval_surf(world_pos + t * e, wn, UV, wall_height).height;
		float hy = eval_surf(world_pos + b * e, wn, UV, wall_height).height;
		vec3 grad = ((hx - s.height) * t + (hy - s.height) * b) / e;
		vec3 n = normalize(wn - grad * bump);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
	vec3 albedo = s.albedo;
	vec4 fd = floor_drawing(world_pos, wn);
	albedo = mix(albedo, fd.rgb, fd.a);
	ALBEDO = mix(albedo, vec3(1.0), flash);
	EMISSION = fd.rgb * fd.a * 0.9 + emission_color * emission_amount + vec3(flash) * 0.6;
	ROUGHNESS = clamp(s.rough * roughness_scale, 0.04, 1.0);
	METALLIC = metallic;
	AO = mix(1.0, COLOR.r, ao_strength);
	AO_LIGHT_AFFECT = 0.3;
}
