shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// The first-person muzzle flash (M11, D-155): an additive glow at the muzzle, drawn with the
// viewmodel's field of view and depth range so it stays on the gun's muzzle.

#include "res://shaders/viewmodel.gdshaderinc"

uniform sampler2D flash_texture : source_color, filter_nearest, repeat_disable;

void vertex() {
	POSITION = viewmodel_position(PROJECTION_MATRIX, MODELVIEW_MATRIX, VERTEX);
}

void fragment() {
	vec4 flash = texture(flash_texture, UV);
	ALBEDO = flash.rgb;
	ALPHA = flash.a;
}
