shader_type spatial;
// Kelp ribbons: UV.y runs 0 at the holdfast to 1 at the tip; the tip sways with the current.
render_mode cull_disabled;
uniform float sway = 0.45;
uniform float speed = 0.7;
void vertex() {
	float t = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = w.x * 0.37 + w.z * 0.23;
	VERTEX.x += sin(TIME * speed + phase + t * 2.2) * sway * t * t;
	VERTEX.z += cos(TIME * speed * 0.8 + phase * 1.3 + t * 1.7) * sway * 0.6 * t * t;
}
void fragment() {
	ALBEDO = COLOR.rgb * mix(0.55, 1.0, UV.y);
	ROUGHNESS = 0.55;
	BACKLIGHT = COLOR.rgb * 0.6;
}
