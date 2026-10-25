shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
// Scattered light in the air along the beam. UV.y is 1 at the lamp and 0 at the far end of the cone.
uniform vec3 tint=vec3(1.,.9,.68);
uniform float strength=1.;
void fragment(){
	float along=1.-UV.y;
	float edge=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),1.4);
	float fade=exp(-along*2.4)*smoothstep(0.,.012,along)*(1.-smoothstep(.55,1.,along));
	ALBEDO=tint;
	ALPHA=clamp(.38*strength*edge*fade,0.,1.);
}
