shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Geschlossenes Kronendach des Waldes außerhalb des Datengebiets (bis zum Horizont).
uniform vec3 base_color : source_color = vec3(0.11, 0.2, 0.1);
uniform float brightness = 1.0;

varying float v_n;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float canopy(vec2 p) {
	return noise(p * 0.035) * 0.65 + noise(p * 0.009) * 0.35;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = canopy(wp.xz);
	const float A = 9.0;
	const float STEP = 6.0;
	VERTEX.y += n * A;
	NORMAL = normalize(vec3((n - canopy(wp.xz + vec2(STEP, 0.0))) * A, STEP, (n - canopy(wp.xz + vec2(0.0, STEP))) * A));
	v_n = n;
}

void fragment() {
	ALBEDO = base_color * (0.7 + 0.6 * v_n) * brightness;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
