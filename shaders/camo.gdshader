shader_type spatial;
render_mode cull_disabled;
// Camo-Stoff für die Bindungsschuhe: vier Farbflecken aus Rauschen (Modellkoordinaten).

// vier Tarnfarben (hell -> dunkel), je Board-Design einstellbar (BoardLibrary "camo")
uniform vec3 c1 : source_color = vec3(0.55, 0.55, 0.40);
uniform vec3 c2 : source_color = vec3(0.33, 0.37, 0.22);
uniform vec3 c3 : source_color = vec3(0.40, 0.28, 0.17);
uniform vec3 c4 : source_color = vec3(0.08, 0.09, 0.1);

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) { return noise(p) * 0.65 + noise(p * 2.3) * 0.35; }

void fragment() {
	vec3 p = lp * 26.0;
	vec3 col = c1;
	col = mix(col, c2, step(0.5, fbm(p)));
	col = mix(col, c3, step(0.6, fbm(p + vec3(5.2, 1.3, 7.7))));
	col = mix(col, c4, step(0.64, fbm(p * 1.2 + vec3(9.1, 3.3, 2.2))));
	ALBEDO = col;
	ROUGHNESS = 0.75;
}
