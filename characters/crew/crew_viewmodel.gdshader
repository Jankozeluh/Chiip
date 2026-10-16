shader_type spatial;

// The crew's look on the first-person arms (M11, D-155): the same surface as crew.gdshader, drawn
// with the viewmodel's own field of view and depth range (shaders/viewmodel.gdshaderinc).

#include "res://shaders/viewmodel.gdshaderinc"
#include "res://characters/crew/crew_surface.gdshaderinc"

void vertex() {
	POSITION = viewmodel_position(PROJECTION_MATRIX, MODELVIEW_MATRIX, VERTEX);
}
