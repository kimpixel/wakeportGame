shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// Wasser mit Szenentiefe: Schaumkränze an Features/Ufer und Durchsicht im Flachen.
// Wird nur benutzt, wenn eine der beiden Optionen an ist (transparent gerendert, etwas teurer).
#define WATER_DEPTH
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
#include "res://shaders/water.gdshaderinc"
