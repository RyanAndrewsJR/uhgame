shader_type spatial;
// The hit flash (3D.md, UnitView): an additive overlay (material_overlay) on
// every mesh of a unit's model, so it works over any model's own materials.
// 0 adds nothing. The amount is per instance.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = flash_color.rgb * flash;
}
