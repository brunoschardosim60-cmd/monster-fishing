shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled;
#include "res://assets/shaders/ocean_common.gdshaderinc"
uniform sampler2D foam_tex: filter_linear_mipmap,repeat_enable;
uniform float age=0.;
uniform float strength=1.;
void vertex(){vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.y=sea_surface(p.xz).y+.055;}
void fragment(){
	float r=length(UV-.5)*10.; float radius=.15+age*(.6+strength*.42);
	float ring=exp(-abs(r-radius)*15.)+exp(-abs(r-radius*.68)*24.)*.35;
	float noise=texture(foam_tex,UV*4.).r;
	ALBEDO=vec3(.64,.82,.81);ROUGHNESS=.75;
	ALPHA=clamp(ring*(1.-smoothstep(.3,3.5,age))*strength*noise,.0,.65);
}
