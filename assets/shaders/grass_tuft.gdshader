shader_type spatial;
render_mode cull_disabled;
#include "res://assets/shaders/cloud_shadow_global.gdshaderinc"
uniform vec3 base_color=vec3(.08,.2,.06);
uniform vec3 tip_color=vec3(.4,.6,.2);
uniform float sway=.16;
varying float tip;
varying vec3 gp;
void vertex(){
	tip=UV.y;
	vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;gp=wp;
	float gust=sin(TIME*1.7+wp.x*.45+wp.z*.35)+.5*sin(TIME*3.1+wp.z*.9);
	VERTEX.x+=gust*sway*UV.y*UV.y;
	VERTEX.z+=gust*sway*.5*UV.y*UV.y;
}
void fragment(){
	ALBEDO=mix(base_color,tip_color,tip)*mix(1.,.58,cloud_shadow_g(gp.xz));
	ROUGHNESS=.95;
}
