shader_type spatial;
// Kunststoff-Features (Kicker, Boxen, Ledges, Pipes …) mit Gebrauchsspuren:
//  * leicht vergilbtes, fleckiges Weiß
//  * auf den Oberseiten Kratzer und Brettspuren längs der Fahrtrichtung (lokal Z),
//    in der Mitte (Fahrspur) dunkler abgerieben
//  * vom Wasser aus verdreckt: braun/gelblicher Rand, darüber grau-fleckiger Verlauf (water_dirt)
//  * hier und da dunkle Schlieren und Kratzer an den Wänden

uniform vec3 base_color : source_color = vec3(0.93, 0.94, 0.93);
uniform float wear = 1.0;            // Stärke der Spuren (0 = neu)
uniform float half_width = 1.0;      // halbe Breite des Teils (für die Fahrspur in der Mitte)
uniform float seed = 0.0;            // Zufall je Teil (0..20): Kratzer und Flecken sehen auf jedem Feature anders aus
uniform float wet_rough = 0.151;     // Rauheit des Wasserfilms (0 = Spiegel)
uniform float wet_dark = 0.052;      // so viel dunkler wird der nasse Kunststoff (dann dominiert die Spiegelung, wie ein nasser Boden)
uniform float wet_fresnel = 0.82;    // flach geschaut tritt das Weiß so weit zugunsten der Spiegelung zurück
uniform float wet_coat = 0.396;       // Stärke der Klarlack-Schicht (zweiter, glatter Glanz)

global uniform float feature_light;  // Dämmerung/Nacht: helles Weiß abdunkeln (Weather, project.godot [shader_globals])
varying vec3 lp;                     // lokale Position (Teil-Koordinaten)
varying vec3 wp;                     // Weltposition
varying vec3 ln;                     // lokale Normale

#include "res://shaders/feature_common.gdshaderinc"

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = base_color;
	float rough = 0.03;                  // glatter Kunststoff, nass (siehe Wasserfilm unten)
	// Vergilbung und Flecken (großflächig)
	float sd = seed;
	float stain = fbm(lp * 0.7 + 3.0 + sd);
	col = mix(col, col * vec3(0.95, 0.92, 0.82), smoothstep(0.45, 0.8, stain) * 0.35 * wear);
	float up = clamp(ln.y, 0.0, 1.0);
	if (up > 0.45) {
		// je Teil eigener Charakter: Kratzer-Menge, -Stärke und -Richtung (Bretter fahren nie ganz gerade)
		float r1 = h3(vec3(sd, 1.0, 0.3));
		float r2 = h3(vec3(sd, 2.0, 0.7));
		float r3 = h3(vec3(sd, 3.0, 0.1));
		float r4 = h3(vec3(sd, 4.0, 0.9));
		// Fahrspur in der Mitte: dunkler abgerieben (Wachs, Gummi der Bindungen), Lage je Teil etwas versetzt
		float lane_x = lp.x - (r4 - 0.5) * half_width * 0.5;
		float lane = 1.0 - smoothstep(0.0, max(half_width * mix(0.5, 0.85, r3), 0.25), abs(lane_x));
		float rub = fbm(vec3(lp.x * 6.0, lp.y, lp.z * 0.6) + sd * 0.37);
		col *= 1.0 - wear * lane * smoothstep(0.3, 0.75, rub) * mix(0.09, 0.19, r2);
		// Kratzer: lange, feine Linien längs (lokal Z), drei Lagen mit eigenem leichten Winkel
		float a1 = (r1 - 0.5) * 0.1;
		float a2 = (r2 - 0.5) * 0.45;
		float a3 = (r3 - 0.5) * 0.9;
		vec2 q1 = vec2(lp.x * cos(a1) - lp.z * sin(a1), lp.x * sin(a1) + lp.z * cos(a1));
		vec2 q2 = vec2(lp.x * cos(a2) - lp.z * sin(a2), lp.x * sin(a2) + lp.z * cos(a2));
		vec2 q3 = vec2(lp.x * cos(a3) - lp.z * sin(a3), lp.x * sin(a3) + lp.z * cos(a3));
		float sc = noise(vec3(q1.x * 140.0, q1.y * 0.9, 1.7 + sd));
		float sc2 = noise(vec3(q2.x * 260.0 + 7.0, q2.y * 1.6, 4.1 + sd * 1.3));
		float sc3 = noise(vec3(q3.x * 190.0 + 3.0, q3.y * 2.4, 8.3 + sd * 0.7)) * smoothstep(0.4, 0.7, noise(lp * 2.2 + sd));
		float thr = mix(0.83, 0.9, r4);                      // wie dicht die Kratzer liegen
		float scratch = smoothstep(thr, thr + 0.11, max(max(sc, sc2 * 0.98), sc3 * 0.97))
			* smoothstep(0.25, 0.6, noise(lp * mix(0.9, 1.8, r1) + 9.0 + sd));
		col = mix(col, vec3(0.42, 0.42, 0.4), scratch * mix(0.4, 0.65, r3) * wear);
		rough = mix(rough, 0.95, scratch);
		// vereinzelte dunkle Schleifspuren (Kanten der Bretter)
		float streak = smoothstep(mix(0.91, 0.96, r2), 0.99, noise(vec3(q2.x * 30.0, q2.y * 0.35, 5.0 + sd)));
		col = mix(col, vec3(0.2, 0.2, 0.2), streak * 0.2 * wear);
	} else {
		// Wände: senkrechte Schlieren und Kratzer
		float drip = noise(vec3(lp.x * 3.0 + lp.z * 3.0, lp.y * 0.8, 2.0 + sd));
		col = mix(col, col * vec3(0.8, 0.8, 0.76), smoothstep(0.6, 0.9, drip) * 0.3 * wear);
		float wsc = smoothstep(0.9, 0.98, noise(vec3((lp.x + lp.z) * 90.0, lp.y * 3.0, 3.0 + sd)));
		col = mix(col, vec3(0.45, 0.45, 0.43), wsc * 0.4 * wear);
	}
	// Formschattierung unabhängig vom Licht: Auffahrten je nach Steilheit etwas dunkler als die flache
	// Oberseite, Wände deutlich dunkler (Seitenwände mehr als Stirnseiten). Sonst ist im Web
	// (Compatibility-Renderer: keine Umgebungsverdeckung, Schatten je nach Grafikstufe aus) alles Weiß auf Weiß
	// und die Kanten der Auffahrten verschwinden. Am Desktop schwächer, dort trägt das Licht mehr.
	vec3 n = normalize(ln);
	float tone_k = 1.0;
	if (CURRENT_RENDERER != RENDERER_COMPATIBILITY) {
		tone_k = 0.45;
	}
	float slope = 1.0 - smoothstep(0.8, 0.995, n.y);           // 0 flach … 1 ab ca. 37°
	float wall = 1.0 - smoothstep(0.2, 0.6, abs(n.y));         // senkrechte Flächen
	float tone = 1.0 - slope * 0.22 - wall * mix(0.1, 0.2, abs(n.x));
	col *= mix(1.0, tone, tone_k);
	// Verschmutzung vom Wasser aus (Seiten und besonders die Auffahrten)
	col = water_dirt(col, wp.y, lp, sd, wear, rough);
	// Nass glänzend wie Wasser: dünner Wasserfilm (Klarlack-Schicht, fast glatt) über dem Kunststoff.
	// Fresnel wie beim See: flach geschaut spiegelt die Fläche stark und das Weiß tritt zurück,
	// von oben sieht man den Kunststoff. Kratzer und Dreck sind matt (kein Film).
	float wet = clamp(1.0 - (rough - wet_rough) * 2.5, 0.0, 1.0);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	col *= 1.0 - wet * (wet_dark + (1.0 - wet_dark) * wet_fresnel * fres);
	ALBEDO = col * feature_light;
	ROUGHNESS = mix(rough, wet_rough, wet);
	SPECULAR = mix(0.5, 1.0, wet) * feature_light;      // nachts kein Glanzfleck vom Mond
	CLEARCOAT = wet * wet_coat * feature_light;
	CLEARCOAT_ROUGHNESS = 0.02;
}
