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
//
// The surface itself is in crew_surface.gdshaderinc, shared with the first-person arms.

#include "res://characters/crew/crew_surface.gdshaderinc"
