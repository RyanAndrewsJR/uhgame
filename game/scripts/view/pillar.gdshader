shader_type spatial;
// VFX.impact()'s light pillar in the 3D view (pillar_view.gd; docs/3D.md, P7's
// 2D-only looks). It stands at a unit's feet, inside its model, and the 2D game
// drew it over the body. So every vertex is drawn `pull_m` nearer the camera
// along its own view ray: the same place on screen, only nearer, so the beam
// shows in front of the model it stands in while a wall in front still hides
// it. One material for every pillar; the color is per instance.
render_mode unshaded, cull_back, shadows_disabled, blend_mix, depth_draw_never;

uniform float pull_m = 0.8;
// The hit's color and the fade (GeometryInstance3D.set_instance_shader_parameter).
instance uniform vec4 color : source_color = vec4(1.0);

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_pos -= normalize(view_pos) * pull_m;
	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
