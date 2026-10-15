shader_type spatial;

// The look of a crew model (M6, D-053, D-073): palette-limited albedo texture, with the
// parts that wear the team's colour painted at runtime.
//
// The generator (tools/modelgen) paints every team texel as a neutral grey whose
// brightness is the baked shading, and writes a mask texture next to the albedo:
//   red   = team colour (take the grey, multiply it by the team colour)
//   green = glowing (also emitted, so it ignores the lights, like the Scout's goggles)
// A grey of linear TEAM_BASE therefore shows exactly the team colour, a darker grey a
// darker shade of it, a lighter grey a lighter one: the shading survives the recolouring.
//
// One ShaderMaterial is shared by every character of a class (CrewBody.material_for);
// the colour is an *instance* uniform, set per character from code with
// GeometryInstance3D.set_instance_shader_parameter(), so two soldiers of the same class
// can be blue and red while using the same material (and the same draw settings).

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
