shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 deep_color : source_color = vec3(0.025, 0.22, 0.28);
uniform vec3 coast_color : source_color = vec3(0.12, 0.52, 0.48);
uniform vec3 foam_color : source_color = vec3(0.63, 0.83, 0.76);
varying vec3 world_pos;

float wave(vec2 p, float t) {
	return sin(p.x * 0.19 + p.y * 0.11 + t * 0.75) * 0.12
		+ sin(p.y * 0.35 - p.x * 0.13 + t * 1.1) * 0.065;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(wp.xz, TIME);
	world_pos = wp;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;
	float a = p.x * 0.19 + p.y * 0.11 + t * 0.75;
	float b = p.y * 0.35 - p.x * 0.13 + t * 1.1;
	float dx = cos(a) * 0.0228 - cos(b) * 0.00845;
	float dz = cos(a) * 0.0132 + cos(b) * 0.02275;
	float detail = sin(p.x * 0.82 + p.y * 0.55 + t * 0.9) * 0.012;
	vec3 surface_normal = normalize(vec3(-dx - detail, 1.0, -dz + detail));
	NORMAL = normalize((VIEW_MATRIX * vec4(surface_normal, 0.0)).xyz);
	float radius = length(vec2(p.x / 29.0, (p.y - 18.0) / 32.0));
	float shallows = 1.0 - smoothstep(1.0, 1.6, radius);
	vec3 col = mix(deep_color, coast_color, shallows * 0.82);
	float band = sin(radius * 105.0 - t * 1.4 + sin(p.x * 0.44) * 0.65);
	float shore_foam = smoothstep(0.7, 0.97, band) * (1.0 - smoothstep(0.99, 1.12, radius)) * smoothstep(0.9, 0.98, radius) * (0.6 + 0.4 * sin(p.x * 0.6 + p.y * 0.4));
	float ripple = sin(p.x * 0.7 + p.y * 1.9 + t) * sin(p.y * 0.9 - t * 0.3);
	float glint = pow(max(0.0, ripple), 14.0) * 0.025;
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
	col = mix(col, vec3(0.44, 0.65, 0.65), fresnel * 0.35);
	ALBEDO = mix(col + glint, foam_color, shore_foam * 0.72);
	ROUGHNESS = 0.42 + shore_foam * 0.4;
	METALLIC = 0.05;
	SPECULAR = 0.4;
}
