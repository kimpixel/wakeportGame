// Gemeinsame Teile der Feature-Shader (feature.gdshader, feature_rail.gdshader):
// Rauschen und die Verschmutzung vom Wasser aus.

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15; }

// Verschmutzung vom Wasser aus (wy = Höhe über dem Wasserspiegel, p = lokale Position, sd = Zufall je Teil):
//  * von ganz unten bis ca. 8 cm über dem Wasser sehr dreckig, braun bis gelblich, fleckig
//  * darüber ca. 30 cm ein heller, grau-fleckiger Verlauf, der nach oben ausläuft
// Auf schrägen Auffahrten wird das Band entsprechend lang (gleiche Höhe = weiter die Rampe hinauf).
vec3 water_dirt(vec3 col, float wy, vec3 p, float sd, float k, inout float rough) {
	vec3 q = vec3(p.x, 0.0, p.z);
	// Rand nicht gerade, sondern zufällig wellig: verzerrtes Rauschen (Wellenberge unterschiedlich breit und hoch),
	// dazu feine Zacken. Der graue Verlauf darüber hat einen eigenen, unabhängigen Rand.
	vec3 warp = vec3(noise(q * 0.9 + sd), 0.0, noise(q * 0.9 + sd + 7.3)) * 2.5;
	float amp = mix(0.4, 1.0, noise(q * 0.5 + sd * 0.3));          // mal ruhig, mal stark gewellt
	float wave = (fbm(q * 2.2 + warp + sd) - 0.5) * 0.14 * amp
		+ (noise(q * 6.5 + warp * 1.7 + sd * 1.3) - 0.5) * 0.05
		+ (noise(q * 18.0 + sd * 2.1) - 0.5) * 0.018;
	float h = wy + wave;
	// heller grauer Verlauf (bis ca. 38 cm), fleckig, dezent
	float hg = wy + (fbm(q * 1.4 + warp * 0.8 + sd + 3.1) - 0.5) * 0.2;
	float g = 1.0 - smoothstep(0.05, 0.38, hg);
	g = g * (0.5 + 0.5 * g);
	float blot = smoothstep(0.25, 0.7, fbm(p * 4.5 + sd * 1.7));
	float speck = smoothstep(0.5, 0.78, noise(p * 19.0 + sd));
	col = mix(col, col * vec3(0.72, 0.72, 0.69), clamp(g * (0.25 + blot * 0.5 + speck * 0.25), 0.0, 1.0) * k);
	// Dreckrand (bis ca. 8 cm): braun/gelblich, dunkle Krusten
	float d = 1.0 - smoothstep(0.055, 0.095, h);
	vec3 brown = vec3(0.34, 0.27, 0.14);
	vec3 yellow = vec3(0.6, 0.52, 0.27);
	vec3 dirt = mix(brown, yellow, smoothstep(0.3, 0.75, fbm(p * 6.0 + sd * 2.3)));
	dirt *= mix(0.7, 1.08, noise(p * 26.0 + sd));
	dirt = mix(dirt, vec3(0.2, 0.17, 0.1), smoothstep(0.65, 0.85, noise(p * 9.0 + sd * 0.7)) * 0.6);
	col = mix(col, dirt, d * mix(0.4, 0.49, noise(p * 3.0 + sd)) * k);
	rough = mix(rough, 0.92, max(d * 0.6, g * 0.3) * k);
	return col;
}
