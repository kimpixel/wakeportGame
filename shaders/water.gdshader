shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Wasser ohne Szenentiefe (undurchsichtig, schnell). Code in water.gdshaderinc.
#include "res://shaders/water.gdshaderinc"
