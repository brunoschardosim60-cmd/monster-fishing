shader_type spatial;
#include "res://assets/shaders/ocean_common.gdshaderinc"
uniform sampler2D sand_tex: source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D noise_tex: filter_linear_mipmap,repeat_enable;
uniform float caustic_strength=1.;
varying vec3 wp;
void vertex(){
	wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	VERTEX.y=-max(.85,.8+coast_data(wp.xz).x*.65);
	wp.y=VERTEX.y;
}
void fragment(){
	vec3 sand=texture(sand_tex,wp.xz*.35).rgb;
	float n=texture(noise_tex,wp.xz*.045).r;
	ALBEDO=sand*mix(vec3(.38,.55,.43),vec3(.83,.82,.65),n);
	float depth=max(0.,-wp.y);
	vec2 cuv=wp.xz*.3;
	float c1=texture(noise_tex,cuv+vec2(TIME*.031,TIME*.017)).r;
	float c2=texture(noise_tex,cuv*1.31+vec2(-TIME*.024,TIME*.029)).r;
	float caustic=pow(clamp(1.-abs(c1-c2)*3.2,0.,1.),6.)*exp(-depth*.09);
	ALBEDO*=1.+caustic*1.1*caustic_strength;
	// Water absorbs red first: deeper ground shifts towards blue-green.
	ALBEDO*=mix(vec3(1.),vec3(.52,.8,.84),smoothstep(0.,10.,depth));
	ROUGHNESS=.93;
}
