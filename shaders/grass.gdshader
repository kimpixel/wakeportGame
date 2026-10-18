/* Gras (MultiMesh aus zwei gekreuzten Flächen), angepasst aus SimpleGrassTextured (grass.gdshaderinc).
Copyright (c) 2023 IcterusGames – MIT-Lizenz, siehe assets/grass/LICENSE_SimpleGrassTextured.txt

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.*/

// Änderungen: keine globalen Shader-Parameter und keine Interaktion mit der Spielfigur (Web), Wind aus
// Sinus-Überlagerung statt Windmuster-Textur, Instanzfarbe als Tönung, Normale nach oben (gleichmäßiges
// Licht wie „Normal grass“), in der Ferne (ab fade_begin) schrumpft das Gras weg statt hart zu verschwinden.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float brightness = 1.0;
global uniform float snow;          // Schneedecke 0..1 (Weather, project.godot [shader_globals])
uniform float wind_strength = 0.12;
uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float fade_begin = 55.0;
uniform float fade_end = 85.0;

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
	float lev = pow(clamp(VERTEX.y, 0.0, 1.0), 1.7);   // Halmspitzen bewegen sich, der Fuß nicht
	float rand = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.28;
	// Böen wandern über die Wiese, dazu leichtes Zittern je Büschel
	float gust = sin(dot(origin.xz, wind_direction) * 0.15 - TIME * 1.3) * 0.5 + 0.5;
	float sway = wind_strength * (0.4 + gust) + sin(TIME * 2.1 + rand) * wind_strength * 0.35;
	vec3 bend = vec3(wind_direction.x, 0.0, wind_direction.y) * sway * lev;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(bend, 0.0)).xyz;
	// in der Ferne kleiner werden lassen (kein hartes Aufploppen an der Sichtweite)
	float d = distance(origin, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	VERTEX *= smoothstep(fade_end, fade_begin, d);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 t = texture(texture_albedo, UV);
	ALBEDO = mix(t.rgb * to_linear(COLOR.rgb), vec3(0.85, 0.87, 0.9), snow * 0.8) * mix(0.55, 1.0, 1.0 - UV.y) * brightness;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
