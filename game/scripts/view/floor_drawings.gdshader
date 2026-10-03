shader_type spatial;
// The walkable ground with the floor drawings on it (docs/3D.md, Floor
// drawings; 3D pivot P7): the floor's own color (its vertex colors, as the
// plain floor material had them) with FloorOverlay's texture laid over it
// straight down, by each surface point's x/z. So a drawing follows slopes and
// matches the sim's shape exactly: the overlay is drawn in sim px.
// The overlay is premultiplied (2D drawn over a transparent target) and in
// sRGB. The drawings are unlit (added as emission over the floor, which they
// cover by their alpha), so a telegraph reads the same in a shadow.

uniform float roughness : hint_range(0.0, 1.0) = 0.95;
// FloorOverlay's texture; without one, nothing is drawn.
uniform sampler2D drawings : hint_default_transparent, filter_linear, repeat_disable;
// The overlay's window on the floor, in meters (x, z): where its texture's
// top-left corner lies, and how much floor it covers.
uniform vec2 drawings_origin_m = vec2(0.0);
uniform vec2 drawings_size_m = vec2(1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec2 uv = (world_xz - drawings_origin_m) / drawings_size_m;
	vec4 drawn = vec4(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		drawn = texture(drawings, uv);
	}
	vec3 color = drawn.a > 0.0001 ? srgb_to_linear(clamp(drawn.rgb / drawn.a, 0.0, 1.0)) : vec3(0.0);
	ALBEDO = COLOR.rgb * (1.0 - drawn.a);
	EMISSION = color * drawn.a;
	ROUGHNESS = roughness;
}
