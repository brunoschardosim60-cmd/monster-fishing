shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
#include "res://assets/shaders/ocean_common.gdshaderinc"
uniform float strength=0.;
uniform bool trail=false;
varying vec2 world_xz;
void vertex() {
	vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	world_xz=wp.xz;
	VERTEX.y+=sea_surface(wp.xz).y+.065;
}
void fragment() {
	float n=texture(foam_tex,UV*vec2(2.,5.)+vec2(0,-sea_time*.8)).r;
	if(trail){n=texture(foam_tex,world_xz*.65+sea_time*vec2(.02,.03)).r;}
	float edge=pow(max(0.,1.-abs(UV.x-.5)*2.),1.4);
	float tail=trail?COLOR.a:smoothstep(0.,.12,UV.y)*(1.-smoothstep(.22,1.,UV.y));
	ALBEDO=vec3(.73,.87,.85);
	ROUGHNESS=.87;
	ALPHA=edge*tail*smoothstep(.32,.62,n)*strength*.67;
}
