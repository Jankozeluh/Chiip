shader_type spatial;

// A gun, knife or grenade in first person (M11, D-155): the look of its imported glTF material
// (palette texture, fully rough, no metal) drawn with the viewmodel's own field of view and depth
// range (shaders/viewmodel.gdshaderinc). Viewmodel.material_for() makes one per gun material.

#include "res://shaders/viewmodel.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);

void vertex() {
	POSITION = viewmodel_position(PROJECTION_MATRIX, MODELVIEW_MATRIX, VERTEX);
}

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
