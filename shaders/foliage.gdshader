shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

// Baumkronen (MultiMesh): Farbe je Baum aus der Instanzfarbe (sRGB), UV2.x = Verschattung im
// Kroneninneren. Zwei Materialien: dunkle, geschlossene Hülle und Blattkarten (cards) mit
// Blatt-/Nadeltextur, alpha-geschnitten. Leichter Wind.
uniform bool cards = false;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float brightness = 1.0;
uniform float wind = 0.06;           // Ausschlag oben in m

varying float v_ao;
varying float v_tone;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
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
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Wind: oben mehr als unten, je Baum eigene Phase; Blätter flattern zusätzlich
	float top = clamp(VERTEX.y + 0.5, 0.0, 1.5);
	float ph = dot(origin.xz, vec2(0.37, 0.21));
	vec3 sway = vec3(sin(TIME * 1.1 + ph), 0.0, cos(TIME * 0.83 + ph * 1.3)) * wind * top;
	if (cards) {
		sway += vec3(sin(TIME * 4.3 + wp.y * 3.0 + wp.x), sin(TIME * 3.1 + wp.z * 2.0), 0.0) * wind * 0.3;
	}
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz;
	v_ao = UV2.x;
	v_tone = hash3(floor(origin * 0.5) + 0.5);
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float shade = mix(0.3, 1.15, v_ao) * (0.9 + 0.2 * v_tone);
	if (cards) {
		vec4 t = texture(leaf_tex, UV);
		// Mipmaps machen das Alpha in der Ferne dünn: je gröber die Stufe, desto mehr anheben
		vec2 px = UV * vec2(textureSize(leaf_tex, 0));
		float lod = max(0.0, 0.5 * log2(max(dot(dFdx(px), dFdx(px)), dot(dFdy(px), dFdy(px)))));
		ALPHA = t.a * (1.0 + lod * 0.45);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		c *= t.rgb * 1.25 * shade;
		// Blattkarten: beide Seiten gleich beleuchtet (Normale zeigt vom Kronenmittelpunkt weg)
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
	} else {
		c *= shade * 0.85;
		if (!FRONT_FACING) {
			c *= 0.6;
		}
	}
	// etwas sattere Grüntöne (das bläuliche Himmelslicht macht sie sonst grau)
	c = max(mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 1.35), vec3(0.0));
	ALBEDO = c * brightness;
	ROUGHNESS = 0.9;
}
