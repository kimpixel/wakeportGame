shader_type spatial;
// Kunststoff-Features (Kicker, Boxen, Ledges, Pipes …) mit Gebrauchsspuren:
//  * leicht vergilbtes, fleckiges Weiß
//  * auf den Oberseiten Kratzer und Brettspuren längs der Fahrtrichtung (lokal Z),
//    in der Mitte (Fahrspur) dunkler abgerieben
//  * an der Wasserlinie ein grünlich-brauner Algen- und Schmutzrand
//  * hier und da dunkle Schlieren und Kratzer an den Wänden

uniform vec3 base_color : source_color = vec3(0.93, 0.94, 0.93);
uniform float wear = 1.0;            // Stärke der Spuren (0 = neu)
uniform float half_width = 1.0;      // halbe Breite des Teils (für die Fahrspur in der Mitte)

varying vec3 lp;                     // lokale Position (Teil-Koordinaten)
varying vec3 wp;                     // Weltposition
varying vec3 ln;                     // lokale Normale

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15; }

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = base_color;
	float rough = 0.55;
	// Vergilbung und Flecken (großflächig)
	float stain = fbm(lp * 0.7 + 3.0);
	col = mix(col, col * vec3(0.95, 0.92, 0.82), smoothstep(0.45, 0.8, stain) * 0.7 * wear);
	float up = clamp(ln.y, 0.0, 1.0);
	if (up > 0.45) {
		// Fahrspur in der Mitte: dunkler abgerieben (Wachs, Gummi der Bindungen)
		float lane = 1.0 - smoothstep(0.0, max(half_width * 0.7, 0.25), abs(lp.x));
		float rub = fbm(vec3(lp.x * 6.0, lp.y, lp.z * 0.6));
		col *= 1.0 - wear * lane * smoothstep(0.3, 0.75, rub) * 0.3;
		// Kratzer: lange, feine Linien längs (lokal Z), quer sehr fein verteilt
		float sc = noise(vec3(lp.x * 140.0, lp.z * 0.9, 1.7));
		float sc2 = noise(vec3(lp.x * 260.0 + 7.0, lp.z * 1.6, 4.1));
		float scratch = smoothstep(0.86, 0.97, max(sc, sc2 * 0.98)) * smoothstep(0.3, 0.6, noise(lp * 1.3 + 9.0));
		col = mix(col, vec3(0.42, 0.42, 0.4), scratch * 0.55 * wear);
		rough = mix(rough, 0.85, scratch);
		// vereinzelte dunkle Schleifspuren (Kanten der Bretter)
		float streak = smoothstep(0.93, 0.99, noise(vec3(lp.x * 30.0, lp.z * 0.35, 5.0)));
		col = mix(col, vec3(0.2, 0.2, 0.2), streak * 0.4 * wear);
	} else {
		// Wände: senkrechte Schlieren und Kratzer
		float drip = noise(vec3(lp.x * 3.0 + lp.z * 3.0, lp.y * 0.8, 2.0));
		col = mix(col, col * vec3(0.8, 0.8, 0.76), smoothstep(0.6, 0.9, drip) * 0.6 * wear);
		float wsc = smoothstep(0.9, 0.98, noise(vec3((lp.x + lp.z) * 90.0, lp.y * 3.0, 3.0)));
		col = mix(col, vec3(0.45, 0.45, 0.43), wsc * 0.4 * wear);
	}
	// Algen- und Schmutzrand an der Wasserlinie
	float wl = smoothstep(0.22, -0.05, wp.y + (fbm(vec3(lp.x, 0.0, lp.z) * 2.0) - 0.5) * 0.12);
	vec3 algae = mix(vec3(0.42, 0.45, 0.28), vec3(0.32, 0.3, 0.22), noise(lp * 4.0));
	col = mix(col, algae, wl * 0.75 * wear);
	rough = mix(rough, 0.9, wl);
	ALBEDO = col;
	ROUGHNESS = rough;
}
