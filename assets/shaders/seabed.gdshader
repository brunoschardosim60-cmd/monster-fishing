shader_type spatial;
#include "res://assets/shaders/ocean_common.gdshaderinc"
uniform sampler2D sand_tex: source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D noise_tex: filter_linear_mipmap,repeat_enable;
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
	ROUGHNESS=.93;
}
