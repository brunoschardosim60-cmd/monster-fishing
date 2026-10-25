shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
// Camera-facing flare at the lens. Its size grows with distance so a lighthouse stays a visible
// star from kilometres away, and `intensity` surges when the beam sweeps across the viewer.
uniform vec3 tint=vec3(1.,.9,.65);
uniform float intensity=.2;
uniform float size_per_meter=.045;
uniform float min_size=4.;
uniform float max_size=260.;
void vertex(){
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	float d=length(MODELVIEW_MATRIX[3].xyz);
	VERTEX.xy*=clamp(d*size_per_meter,min_size,max_size);
}
void fragment(){
	vec2 p=(UV-.5)*2.;
	float r2=dot(p,p);
	float core=exp(-r2*26.);
	float halo=exp(-r2*4.)*.5;
	float streak=exp(-abs(p.y)*38.)*exp(-abs(p.x)*2.4)*.7;
	ALBEDO=tint*(core*1.4+halo+streak)*intensity;
	ALPHA=1.;
}
