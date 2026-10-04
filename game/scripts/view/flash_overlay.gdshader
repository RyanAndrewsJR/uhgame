shader_type spatial;
// The hit flash (3D.md, UnitView): an additive overlay (material_overlay) on
// every mesh of a unit's model, so it works over any model's own materials.
// 0 adds nothing. The amount is per instance.
// ENEMIES_AI AI1: a second, tinted channel for a pose's rim (an enemy's tell):
// strongest at the silhouette's edge. UnitView zeroes it while the hit flash
// plays (the flash wins). Alpha 0 adds nothing.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 rim = vec4(0.0);

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = flash_color.rgb * flash + rim.rgb * rim.a * (0.3 + 0.7 * edge);
}
