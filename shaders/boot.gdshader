shader_type spatial;
render_mode cull_disabled;
// Bindungsschuh: einfarbiges Material mit Knick am Knöchel (boot_flex.gdshaderinc).
#include "res://shaders/boot_flex.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float roughness = 0.7;
uniform float metallic = 0.0;

void vertex() {
	flex_vertex(VERTEX, NORMAL);
}

void fragment() {
	vec4 c = albedo * texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
