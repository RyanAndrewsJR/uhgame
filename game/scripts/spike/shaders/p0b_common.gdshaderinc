// P0b feel spike (throwaway; branch spike/3d-p0b, never merged).
// Shared by p0b_painted.gdshader and p0b_pbr.gdshader: procedural surface
// patterns in world space (no texture files), the floor drawings, the fade
// and the cut-out circle for tall things. A pattern returns its albedo, a
// height (for the PBR bump) and "paint" (shading painted into the surface,
// which only the painted material uses).

uniform int pattern = 0;   // 0 flagstones, 1 bricks, 2 rock, 3 grass, 4 roof, 5 plaster + timber, 6 wall cap, 7 plain, -1 texture (models)
uniform vec3 color_a : source_color = vec3(0.55, 0.52, 0.48);
uniform vec3 color_b : source_color = vec3(0.42, 0.40, 0.38);
uniform float pattern_scale = 1.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
instance uniform float flash = 0.0; // hit flash (models), per instance
uniform float emission_amount = 0.0;
uniform vec3 emission_color : source_color = vec3(1.0, 0.6, 0.25);

// Floor drawings: a SubViewport sharing the sim's World2D (P0a).
uniform sampler2D overlay : source_color, filter_linear, repeat_disable;
uniform bool use_overlay = false;
uniform vec2 room_origin_m = vec2(0.0);
uniform vec2 room_size_m = vec2(30.0, 20.0);

// Tall things between the camera and the player.
instance uniform float fade = 1.0;
uniform bool cut_on = false;
uniform vec2 cut_center_uv = vec2(0.5);
uniform float cut_radius = 0.16;    // fraction of the screen height
uniform float cut_depth = 0.0;      // the player's distance along the view axis

varying vec3 world_pos;
varying vec3 world_normal;

struct Surf {
	vec3 albedo;
	float height;
	float paint;
	float rough;
};

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 fc) {
	ivec2 p = ivec2(mod(fc, 4.0));
	return (BAYER[p.x + p.y * 4] + 0.5) / 16.0;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}

// Running-bond blocks of `size` (m). The painted rims: light on the top/left
// edge (the key light comes from the north-west, from the top left of the
// screen), dark on the bottom/right. `flip_v`: p.y grows downward on the
// screen (floors: z grows south) instead of upward (walls: y grows up).
Surf blocks(vec2 p, vec2 size, vec3 ca, vec3 cb, float grout_w, bool flip_v) {
	vec2 q = p / size;
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec2 e = min(f, 1.0 - f) * size;          // edge distance in meters
	float edge = min(e.x, e.y);
	float n = fbm(p * 2.5);
	float v = hash12(id + 0.37);
	vec3 col = mix(ca, cb, clamp(v * 0.75 + (n - 0.5) * 0.6, 0.0, 1.0));
	float rim = 0.06;
	float top = flip_v ? f.y * size.y : (1.0 - f.y) * size.y;      // distance to the upper edge
	float bottom = flip_v ? (1.0 - f.y) * size.y : f.y * size.y;
	float lit = max(1.0 - smoothstep(0.0, rim, f.x * size.x), 1.0 - smoothstep(0.0, rim, top));
	float dark = max(1.0 - smoothstep(0.0, rim, (1.0 - f.x) * size.x), 1.0 - smoothstep(0.0, rim, bottom));
	float grout = 1.0 - smoothstep(grout_w * 0.5, grout_w, edge);
	Surf s;
	s.albedo = mix(col, ca * 0.3, grout);
	s.height = smoothstep(0.0, rim * 1.5, edge) + (n - 0.5) * 0.3;
	s.paint = 1.0 + 0.22 * lit - 0.25 * dark + (n - 0.5) * 0.3 - grout * 0.15;
	s.rough = 0.7 + 0.25 * n;
	return s;
}

Surf rock(vec3 wp, vec3 wn, vec3 ca, vec3 cb) {
	vec2 p = abs(wn.x) > abs(wn.z) ? vec2(wp.z, wp.y) : vec2(wp.x, wp.y);
	float warp = fbm(vec2(p.x * 0.8, p.y * 0.3)) * 0.9;
	float band_f = p.y / 0.42 + warp;
	float band = floor(band_f);
	float bf = fract(band_f);
	float n = fbm(p * vec2(1.6, 3.5) + band * 3.1);
	vec3 col = mix(ca, cb, clamp(hash12(vec2(band, 2.0)) * 0.7 + (n - 0.5) * 0.7, 0.0, 1.0));
	float crack = 1.0 - smoothstep(0.0, 0.05, abs(fbm(vec2(p.x * 2.2, band)) - 0.5));
	Surf s;
	s.albedo = mix(col, ca * 0.3, crack * 0.8);
	s.height = smoothstep(0.0, 0.3, bf) * 0.7 + n * 0.3 - crack * 0.4;
	s.paint = 0.82 + 0.35 * smoothstep(0.7, 1.0, bf) - 0.25 * (1.0 - smoothstep(0.0, 0.25, bf)) + (n - 0.5) * 0.3 - crack * 0.2;
	s.rough = 0.85;
	return s;
}

Surf grass(vec2 p, vec3 ca, vec3 cb) {
	float n = fbm(p * 1.3);
	float fine = vnoise(p * 9.0);
	float blot = smoothstep(0.45, 0.7, fbm(p * 0.6 + 4.0));
	Surf s;
	s.albedo = mix(ca, cb, clamp((n - 0.25) * 1.6 + fine * 0.3, 0.0, 1.0));
	s.albedo = mix(s.albedo, s.albedo * vec3(1.15, 1.1, 0.75), blot * 0.6);
	s.height = n * 0.6 + fine * 0.4;
	s.paint = 0.9 + (n - 0.5) * 0.45 + (fine - 0.5) * 0.15;
	s.rough = 0.9;
	return s;
}

// Shingles: p.x along the ridge, p.y down the slope (m).
Surf roof(vec2 p, vec3 ca, vec3 cb) {
	float row_h = 0.28;
	float row = floor(p.y / row_h);
	float x = p.x / 0.32 + mod(row, 2.0) * 0.5;
	float id = floor(x);
	float fx = fract(x);
	float fy = fract(p.y / row_h);
	float scallop = fy - 0.25 * sqrt(max(0.0, 1.0 - pow(fx * 2.0 - 1.0, 2.0)));
	float n = fbm(p * 3.0);
	vec3 col = mix(ca, cb, clamp(hash12(vec2(id, row)) * 0.7 + (n - 0.5) * 0.5, 0.0, 1.0));
	float edge = smoothstep(0.62, 0.78, scallop);
	Surf s;
	s.albedo = mix(col, ca * 0.35, edge * 0.85);
	s.height = 1.0 - fy - edge * 0.5;
	s.paint = 1.15 - fy * 0.35 - edge * 0.3 + (n - 0.5) * 0.25;
	s.rough = 0.75;
	return s;
}

// Plaster with a timber frame (posts every 1.5 m along the wall, beams at the
// bottom and top). `wall_top`: the wall's height (m).
Surf plaster(vec2 p, vec3 ca, vec3 cb, float wall_top) {
	float n = fbm(p * 1.8);
	vec3 col = mix(ca, ca * 0.86, n);
	float post = 1.0 - smoothstep(0.07, 0.09, abs(fract(p.x / 1.5 + 0.5) - 0.5) * 1.5);
	float beam = max(1.0 - smoothstep(0.1, 0.12, p.y), 1.0 - smoothstep(0.1, 0.12, abs(wall_top - 0.1 - p.y)));
	float timber = max(post, beam);
	float grain = vnoise(vec2(p.x * 2.0, p.y * 30.0));
	vec3 wood = mix(cb, cb * 0.7, grain);
	Surf s;
	s.albedo = mix(col, wood, timber);
	s.height = timber * 0.6 + n * 0.2;
	s.paint = 1.0 + (n - 0.5) * 0.25 + timber * (grain - 0.5) * 0.3 + 0.12 * smoothstep(0.0, wall_top, p.y);
	s.rough = mix(0.9, 0.6, timber);
	return s;
}

// The pattern at a world point. wall_h: walls' height, for their painted
// gradient.
Surf eval_surf(vec3 wp, vec3 wn, vec2 uv, float wall_h) {
	Surf s;
	vec3 an = abs(wn);
	bool up = an.y > 0.5;
	vec2 along = an.x > an.z ? vec2(wp.z, wp.y) : vec2(wp.x, wp.y);
	vec3 ca = color_a;
	vec3 cb = color_b;
	if (pattern == 0) {
		s = blocks(wp.xz * pattern_scale, vec2(0.5, 0.5), ca, cb, 0.035, true);
	} else if (pattern == 1) {
		if (up) {
			s = blocks(wp.xz, vec2(0.5, 0.5), ca, cb, 0.03, true);
		} else {
			s = blocks(along * pattern_scale, vec2(0.5, 0.25), ca, cb, 0.03, false);
			s.paint *= mix(0.62, 1.0, smoothstep(0.0, max(wall_h, 0.6), wp.y));   // painted contact shadow at the base
		}
	} else if (pattern == 2) {
		s = rock(wp, wn, ca, cb);
		s.paint *= mix(0.65, 1.0, smoothstep(0.0, 0.8, wp.y));
	} else if (pattern == 3) {
		s = grass(wp.xz, ca, cb);
	} else if (pattern == 4) {
		s = roof(uv, ca, cb);
	} else if (pattern == 5) {
		s = plaster(along, ca, cb, wall_h);
	} else if (pattern == 6) {
		float n = fbm(wp.xz * 3.0);
		s.albedo = mix(ca, cb, n);
		s.height = n;
		s.paint = 0.9 + (n - 0.5) * 0.3;
		s.rough = 0.9;
	} else if (pattern == 7) {
		float n = fbm((wp.xz + wp.y) * 4.0);
		s.albedo = mix(ca, cb, n);
		s.height = n;
		s.paint = 0.95 + (n - 0.5) * 0.2 + 0.1 * clamp(wn.y, 0.0, 1.0);
		s.rough = 0.6;
	} else {
		s.albedo = texture(albedo_tex, uv).rgb * ca;
		s.height = 0.0;
		s.paint = 1.0;
		s.rough = 0.7;
	}
	return s;
}

// True where a tall thing is faded away (dithered, so it stays opaque; the
// caller skips this in the shadow pass, so it keeps its shadow).
bool faded_out(vec2 fragcoord, vec2 viewport_size, vec3 vertex) {
	float keep = fade;
	if (cut_on && -vertex.z < cut_depth) {
		vec2 d = (fragcoord / viewport_size - cut_center_uv) * viewport_size / viewport_size.y;
		keep = min(keep, mix(0.15, 1.0, smoothstep(cut_radius * 0.7, cut_radius, length(d))));
	}
	return keep < 0.999 && keep < bayer4(fragcoord);
}

// Floor drawings on upward faces. The overlay is premultiplied (drawn over a
// transparent target), so it's un-premultiplied here.
vec4 floor_drawing(vec3 wp, vec3 wn) {
	if (!use_overlay) {
		return vec4(0.0);
	}
	vec2 uv = (wp.xz - room_origin_m) / room_size_m;
	vec4 ov = texture(overlay, uv);
	float a = ov.a * smoothstep(0.3, 0.6, wn.y);
	return vec4(ov.rgb / max(ov.a, 0.001), a);
}
