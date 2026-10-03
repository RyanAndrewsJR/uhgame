shader_type spatial;
// The fade (docs/3D.md, The room's look): an asset in the `fades` group fades
// while it stands between the camera and the player. Dithered with a 4x4
// ordered (Bayer) pattern, so the asset stays opaque (no sorting) and keeps
// its full shadow: the shadow pass skips the dither. One material for every
// instance; the amount is per instance. P3: a flat color, no materials work.

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// 1 = solid, 0 = gone (GeometryInstance3D.set_instance_shader_parameter).
instance uniform float fade : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	if (!IN_SHADOW_PASS && fade < 1.0) {
		ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
		if (fade < (BAYER[p.x + p.y * 4] + 0.5) / 16.0) {
			discard;
		}
	}
}
