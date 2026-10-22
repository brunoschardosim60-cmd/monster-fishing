shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform float sea_time=0.;
uniform float strength=0.;
float wave(vec2 p,vec2 direction,float wavelength,float amplitude,float speed) {
	return sin(dot(p,normalize(direction))*6.2831853/wavelength-sea_time*speed+sin(dot(p,vec2(.037,.029)))*1.7)*amplitude;
}
void vertex() {
	vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	float h=wave(wp.xz,vec2(1,.45),13.,.42,1.55);
	h+=wave(wp.xz,vec2(-.35,1),7.1,.22,1.9);
	h+=wave(wp.xz,vec2(.8,-.65),3.5,.095,2.4);
	h+=wave(wp.xz,vec2(-1.,-.2),5.3,.09,1.7);
	h+=wave(wp.xz,vec2(.15,1.),2.4,.045,2.7);
	VERTEX.y+=h*mix(.25,1.,smoothstep(13.,65.,length(wp.xz-vec2(0,-15))))+.055;
}
void fragment() {
	float n=texture(foam_tex,UV*vec2(2.,5.)+vec2(0,-sea_time*.8)).r;
	float edge=pow(max(0.,1.-abs(UV.x-.5)*2.),1.4);
	float tail=smoothstep(0.,.12,UV.y)*(1.-smoothstep(.22,1.,UV.y));
	ALBEDO=vec3(.73,.87,.85);
	ROUGHNESS=.87;
	ALPHA=edge*tail*smoothstep(.32,.63,n)*strength*.8;
}
