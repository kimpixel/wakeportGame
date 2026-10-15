shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// Baumstämme (MultiMesh): Instanzfarbe = Rinde unten (sRGB), Alpha < 1 = Kiefer:
// nach oben hin die typische orange Spiegelrinde. Grobe Rindenstreifen per Rauschen.
uniform float brightness = 1.0;

varying float v_h;
varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Instanzfarbe ist sRGB; der Compatibility-Renderer (Web) liefert sie schon linear.
vec3 to_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return pow(c, vec3(2.2));
#endif
}

void vertex() {
	v_h = VERTEX.y + 0.5;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float pine = 1.0 - step(0.99, COLOR.a);
	vec3 orange = vec3(0.24, 0.12, 0.055);
	c = mix(c, orange, pine * smoothstep(0.45, 0.9, v_h) * 0.8);
	// Längsstreifen der Rinde (um den Stamm herum)
	float n = noise(vec2(UV.x * 18.0, v_world.y * 1.2));
	c *= mix(0.7, 1.1, n) * mix(0.75, 1.0, smoothstep(0.0, 0.25, v_h));
	ALBEDO = c * brightness;
	ROUGHNESS = 1.0;
}
