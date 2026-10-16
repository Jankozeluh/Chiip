// The first-person viewmodel's own projection (M11, D-155): arms, gun and muzzle flash are drawn
// with their own field of view and squeezed into the nearest sliver of the depth buffer, so they
// never poke into a wall you stand against (Quake's depth-range hack, CS's viewmodel_fov) while
// still rendering in the world's own low-res viewport, with its lights and its palette effect.
//
// A viewmodel shader includes this and writes, in vertex():
//     POSITION = viewmodel_position(PROJECTION_MATRIX, MODELVIEW_MATRIX, VERTEX);
// Lighting still uses the real view-space position (VERTEX), so the gun is lit where it is.
// Viewmodel.clip_depth() in weapons/viewmodel.gd mirrors the depth formula; change both together.

// The viewmodel's vertical field of view in degrees: the camera's at CS's 90 (horizontal, 4:3),
// whatever the player's FOV setting or the scope's zoom (Viewmodel.FOV).
uniform float viewmodel_fov = 73.74;

// Nothing nearer than this (metres) is drawn.
const float VIEWMODEL_NEAR = 0.01;
// The share of the depth range the viewmodel uses, at the near end (Viewmodel.DEPTH_SHARE).
const float VIEWMODEL_DEPTH_SHARE = 0.02;

vec4 viewmodel_position(mat4 projection, mat4 modelview, vec3 vertex) {
	vec4 view = modelview * vec4(vertex, 1.0);
	vec4 clip = projection * view;
	// Scale x and y from the camera's field of view to the viewmodel's.
	clip.xy *= 1.0 / (tan(radians(viewmodel_fov) * 0.5) * abs(projection[1][1]));
	// Reverse Z: 1 at the near plane, CLIP_SPACE_FAR far away. The viewmodel's depth runs from 1
	// (at VIEWMODEL_NEAR) down to 1 - VIEWMODEL_DEPTH_SHARE of the range (infinitely far), so it
	// stays in order within itself and in front of everything the camera's near plane lets through.
	float distance = -view.z;
	float depth = 1.0 - VIEWMODEL_DEPTH_SHARE * (1.0 - CLIP_SPACE_FAR) * (1.0 - VIEWMODEL_NEAR / max(distance, 1e-4));
	clip.z = depth * clip.w;
	return clip;
}
