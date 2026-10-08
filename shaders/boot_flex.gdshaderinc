// Bindungsschuh knickt am Knöchel mit dem Schienbein (Wakeboard.flex): alles über dem Knöchel
// dreht um die Knöchelachse, die Sohle bleibt aufs Brett geschraubt. Werte je Schuh (Mesh-Raum).
instance uniform vec3 flex_pivot = vec3(0.0);
instance uniform vec3 flex_up = vec3(0.0, 1.0, 0.0);
instance uniform vec4 flex_rot = vec4(1.0, 0.0, 0.0, 0.0);   // Achse, Winkel

vec3 flex_turn(vec3 v, float a) {
	vec3 k = flex_rot.xyz;
	return v * cos(a) + cross(k, v) * sin(a) + k * dot(k, v) * (1.0 - cos(a));
}

void flex_vertex(inout vec3 vertex, inout vec3 normal) {
	if (flex_rot.w == 0.0) return;
	vec3 d = vertex - flex_pivot;
	// unterhalb des Knöchels steif, darüber voll mitgedreht (weicher Übergang am Gelenk)
	float a = flex_rot.w * smoothstep(-0.05, 0.06, dot(d, flex_up));
	vertex = flex_pivot + flex_turn(d, a);
	normal = flex_turn(normal, a);
}
