shader_type spatial;
// Morgennebel über dem Wasser als ein Bild-Durchgang (Weather._build_mist): entlang jedes Blickstrahls wird die
// Nebelmenge exakt aufsummiert – Dichte über dem Wasser am größten, nach oben exponentiell dünner (Höhe `thick`).
// Früher waagrechte Schichten: die schnitten Wellen, Ufer und Features mit harten Kanten (Treppen).
// Der Strahl endet an der Szene (Tiefenpuffer) bzw. an der Wasseroberfläche (y = 0, das Wasser ist durchsichtig).
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float density = 0.0;      // Dichte direkt über dem Wasser (1/m)
uniform float thick = 2.5;        // m: so schnell wird der Nebel nach oben dünner
uniform vec3 mist_color : source_color = vec3(0.8, 0.8, 0.78);
uniform vec3 sun_color : source_color = vec3(1.0, 0.8, 0.5);
uniform vec3 sun_dir = vec3(0.0, 0.2, -1.0);
uniform float t = 0.0;

float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int k = 0; k < 4; k++) {
		v += a * n2(p);
		p = rot * p * 2.05 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Quad über das ganze Bild, direkt hinter der nahen Ebene
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	POSITION = vec4(VERTEX.xy * 2.0, -0.999, 1.0);
#else
	POSITION = vec4(VERTEX.xy * 2.0, 0.999, 1.0);
#endif
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vp.xyz /= vp.w;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz;
	vec3 dir = wp - cam;
	float len = min(length(dir), 3000.0);
	dir = normalize(dir);
	if (dir.y < -1e-4 && cam.y > 0.0) {
		len = min(len, -cam.y / dir.y);          // Wasseroberfläche
	}
	// Integral der Dichte density * exp(-y / thick) entlang des Strahls
	float k = dir.y / thick;
	float base = density * exp(-max(cam.y, 0.0) / thick);
	float amount = abs(k) > 1e-4 ? base * (1.0 - exp(-k * len)) / k : base * len;
	// fleckig: Dichte am Endpunkt bzw. in Fahrtrichtung, zieht langsam
	vec3 endp = cam + dir * min(len, 400.0);
	float n = fbm(endp.xz * 0.03 + vec2(t * 0.012, t * 0.005));
	amount *= 0.55 + 0.9 * n;
	float toward = max(dot(dir, normalize(sun_dir)), 0.0);
	float sun = pow(toward, 3.0) * 0.8 + pow(toward, 24.0);     // Gegenlicht: breit golden, nah an der Sonne grell
	ALBEDO = mix(mist_color, sun_color * 1.8, clamp(sun, 0.0, 1.0));
	ALPHA = clamp((1.0 - exp(-amount)) * (1.0 + 0.5 * sun), 0.0, 0.97);
}
