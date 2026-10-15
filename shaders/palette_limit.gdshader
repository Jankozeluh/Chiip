shader_type canvas_item;

// Retro color limit for the world image: fewer shades per color channel, with
// ordered (Bayer) dithering so the reduced shades blend instead of banding.
// Draws on a full-screen ColorRect inside the world's SubViewport, so the HUD
// isn't affected. Switched on and off by Main.palette_effect.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Shades per color channel (8-bit color has 256).
uniform float levels = 16.0;
// How much dithering mixes neighbouring shades (0 = hard bands).
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;

// 4 × 4 Bayer matrix: a fixed pattern of thresholds that repeats across the screen.
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
	float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 - 0.5;
	color += threshold * dither_strength / levels;
	COLOR = vec4(floor(color * levels + 0.5) / levels, 1.0);
}
