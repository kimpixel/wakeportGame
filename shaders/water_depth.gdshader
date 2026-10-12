shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Wasser mit Szenentiefe: Durchsicht im Flachen.
// Wird nur benutzt, wenn die Option an ist (transparent gerendert, etwas teurer).
#define WATER_DEPTH
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
#include "res://shaders/water.gdshaderinc"
