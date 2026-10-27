shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
// Cast net: a fine mesh of cord (polar grid) with a dark lead line around the rim; holes are see-through.
varying vec3 lp;
void vertex(){ lp=VERTEX; }
void fragment(){
	float r=length(lp.xz);float a=atan(lp.z,lp.x);
	float rings=abs(fract(r*6.)-.5);float spokes=abs(fract(a/6.2832*32.)-.5);
	float cord=max(smoothstep(.3,.45,rings),smoothstep(.3,.45,spokes));
	float rim=smoothstep(.9,.96,r);
	ALBEDO=mix(vec3(.82,.8,.72),vec3(.15,.15,.16),rim);
	ROUGHNESS=.9;
	ALPHA=max(cord*.85,rim)*(1.-smoothstep(.99,1.,r));
	ALPHA_SCISSOR_THRESHOLD=.4;
}
