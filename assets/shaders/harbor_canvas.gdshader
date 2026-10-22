shader_type spatial;
render_mode cull_disabled;
uniform sampler2D fabric_tex:source_color,filter_linear_mipmap_anisotropic;
uniform vec4 canvas_tint:source_color=vec4(.7,.6,.4,1.);
uniform float wind_strength=.3;
void vertex(){
	float free_edge=sin(UV.x*3.14159)*sin(UV.y*3.14159);
	VERTEX.y+=sin(TIME*1.7+VERTEX.x*2.+VERTEX.z)*(.025+wind_strength*.1)*free_edge;
}
void fragment(){
	ALBEDO=texture(fabric_tex,UV*3.).rgb*canvas_tint.rgb;
	ROUGHNESS=.9;
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
