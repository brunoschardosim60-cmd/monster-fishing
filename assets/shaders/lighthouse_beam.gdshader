shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled;
void fragment(){
	float edge=.25+.75*abs(dot(normalize(NORMAL),normalize(VIEW)));
	ALBEDO=vec3(1.,.85,.57);
	ALPHA=.22*pow(UV.y,1.7)*edge;
}
