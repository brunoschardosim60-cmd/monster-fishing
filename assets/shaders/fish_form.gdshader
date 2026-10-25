shader_type spatial;
render_mode cull_disabled;
// Procedural fish (scripts/creatures/fish_forms.gd). Vertex colours carry the whole paint job.
// Tail wag: per-instance phase from MultiMesh custom data (schools) or TIME when `use_time` is on (single fish).
uniform float wag=.16;
uniform float tail_from=-.05;
uniform float tail_reach=.55;
uniform bool use_time=false;
uniform float time_speed=7.;
uniform float gloss=.28;
uniform float shimmer=.35;
void vertex(){
	float phase=(use_time?TIME*time_speed:INSTANCE_CUSTOM.x)+VERTEX.x*4.5;
	float tail=clamp((tail_from-VERTEX.x)/tail_reach,0.,1.);
	float body=clamp((VERTEX.x+.2)/.7,0.,1.);
	VERTEX.z+=sin(phase)*(tail*tail*wag+(1.-body)*.0)*.5+sin(phase)*tail*.0;
	// A slight sway of the whole body keeps big, slow fish alive.
	VERTEX.z+=sin(phase-1.2)*(1.-clamp(abs(VERTEX.x)*2.,0.,1.))*.012;
}
void fragment(){
	ALBEDO=COLOR.rgb;
	ROUGHNESS=gloss;METALLIC=.12;
	float rim=pow(1.-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),2.);
	EMISSION=COLOR.rgb*rim*shimmer*.25;
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
