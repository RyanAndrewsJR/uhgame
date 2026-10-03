// P0b feel spike (throwaway; branch spike/3d-p0b, never merged).
// Material (b): the shading is painted into the surface (rims, contact
// shadows, gradients) and real lights only add a soft ramp on top: the key
// light's shadow never goes black, torches warm what they reach.
shader_type spatial;
render_mode specular_disabled;

#include "res://scripts/spike/shaders/p0b_common.gdshaderinc"

uniform float wall_height = 1.2;
uniform float key_amount = 0.75;        // how much the key light adds
uniform float key_shadow_floor = 0.45;  // the key light left inside its shadow
uniform float point_amount = 0.7;       // torches
uniform float ao_strength = 1.0;        // vertex AO (floors next to walls)

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (!IN_SHADOW_PASS && faded_out(FRAGCOORD.xy, VIEWPORT_SIZE, VERTEX)) {
		discard;
	}
	Surf s = eval_surf(world_pos, world_normal, UV, wall_height);
	float ao = mix(1.0, COLOR.r, ao_strength);
	vec3 albedo = s.albedo * s.paint * ao;
	vec4 fd = floor_drawing(world_pos, world_normal);
	albedo = mix(albedo, fd.rgb, fd.a);
	ALBEDO = mix(albedo, vec3(1.0), flash);
	EMISSION = fd.rgb * fd.a * 0.9 + emission_color * emission_amount + vec3(flash) * 0.6;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = smoothstep(-0.05, 0.35, ndl) * ATTENUATION;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(key_shadow_floor, 1.0, lit) * key_amount;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * smoothstep(-0.25, 0.55, ndl) * point_amount;
	}
}
