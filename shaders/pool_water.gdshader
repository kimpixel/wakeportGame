shader_type spatial;
// Wasser im 6-Stair Pool: klares, leicht türkises Wasser über dem blauen Becken. Kleine Kräuselwellen
// nur in der Normale (die Höhe für die Physik ist flach, siehe Water.height_at), flach geschaut spiegelt es.
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.10, 0.42, 0.52);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Steigung (d/dx, d/dz) einer Welle a * sin(k · p + w t)
vec2 slope(vec2 p, vec2 k, float a, float w) {
	return a * k * cos(dot(k, p) + w * TIME);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 g = slope(p, vec2(2.1, 0.9), 0.012, 1.7)
		+ slope(p, vec2(-1.3, 2.6), 0.009, 2.3)
		+ slope(p, vec2(4.7, -3.1), 0.004, 3.1);
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = tint;
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	ALPHA = mix(0.45, 0.92, fres);
}
