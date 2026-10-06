shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Luftbilder (DOP20, Hessen) – Nord oben, in UTM ausgerichtet.
uniform sampler2D dop_wide : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D dop_core : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 area_rect;   // dE0, dN0, dE1, dN1 relativ zum T2-Startmast
uniform vec4 core_rect;
uniform vec2 dir_u;       // T2-Richtung in (E, N)
uniform float brightness = 1.0;

varying vec2 v_rel;
varying float v_h;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_rel = vec2(-wp.z * dir_u.x + wp.x * dir_u.y, -wp.z * dir_u.y - wp.x * dir_u.x);
	v_h = wp.y;
}

vec2 rect_uv(vec4 r) {
	return vec2((v_rel.x - r.x) / (r.z - r.x), (r.w - v_rel.y) / (r.w - r.y));
}

void fragment() {
	vec2 uw = rect_uv(area_rect);
	vec3 col = texture(dop_wide, clamp(uw, vec2(0.001), vec2(0.999))).rgb;
	vec2 uc = rect_uv(core_rect);
	vec2 edge = min(uc, 1.0 - uc);
	float core_w = clamp(min(edge.x, edge.y) * 20.0, 0.0, 1.0);
	if (core_w > 0.0) {
		col = mix(col, texture(dop_core, uc).rgb, core_w);
	}
	// Uferstreifen: Wo das Luftbild noch Wasser zeigt, das Gelände aber schon Land ist,
	// würde türkise Textur auf der Böschung liegen – dort nassen Ufersand zeigen.
	float watery = smoothstep(1.15, 1.45, min(col.g, col.b) / max(col.r, 0.02))
		* smoothstep(0.25, 0.35, col.b) * step(col.g * 0.85, col.b);   // nur helles Türkis, kein Waldschatten
	col = mix(col, vec3(0.55, 0.5, 0.4), watery * (1.0 - smoothstep(1.5, 3.0, v_h)));
	// unter Wasser: heller Kies, wird vom Wasser ohnehin verdeckt
	col = mix(col, vec3(0.45, 0.5, 0.42), smoothstep(-0.05, -0.6, v_h));
	ALBEDO = col * brightness;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
