// The crew's surface (M6, D-053, D-073): uniforms and fragment() shared by crew.gdshader (the
// bodies) and crew_viewmodel.gdshader (the first-person arms, M11, D-155). See crew.gdshader.

// Palette colours. Team parts hold a grey here.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
// Red = team colour texels, green = glowing texels. Plain data, not a colour (no source_color).
uniform sampler2D mask_texture : filter_nearest_mipmap_anisotropic, repeat_disable;
// How strongly glowing texels are emitted.
uniform float glow_energy = 1.5;
// The colour of this character's team as the viewer sees it (Teams.color_for). Per instance.
instance uniform vec4 team_color : source_color = vec4(0.25, 0.4, 0.7, 1.0);

// Linear brightness of a team texel that shows the team colour unchanged.
// Must match TEAM_BASE in tools/modelgen/paint.py.
const float TEAM_BASE = 0.5;

void fragment() {
	vec3 albedo = texture(albedo_texture, UV).rgb;
	vec4 mask = texture(mask_texture, UV);
	vec3 team = team_color.rgb * (albedo.g / TEAM_BASE);
	ALBEDO = mix(albedo, team, mask.r);
	EMISSION = albedo * mask.g * glow_energy;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
	METALLIC = 0.0;
}
