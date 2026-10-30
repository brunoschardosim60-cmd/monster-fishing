shader_type spatial;
render_mode cull_disabled;
// The leviathan (tools/blender/leviathan.py): body along +Z from the skull (z 0) to the tail (z 90), head to -Z.
// A wave travels down the body, growing towards the tail; the head rises out of the water (raise), lunges
// forward and down on a strike (lunge) and the jaw swings open about its hinge (jaw, radians).
uniform bool is_jaw=false;
uniform bool glow=false;
uniform float body_length=90.;
uniform vec3 jaw_hinge=vec3(0.,-1.2,-1.);
// The head and neck: from z=head_start (fully raised) fading out by z=head_reach.
uniform float head_start=-4.;
uniform float head_reach=34.;
uniform float wave_amp=6.;
instance uniform float raise=0.;
instance uniform float lunge=0.;
instance uniform float jaw=0.;
instance uniform float swim_phase=0.;
varying float spot;
void vertex(){
	vec3 p=VERTEX;
	if(is_jaw){
		vec3 h=jaw_hinge;vec3 q=p-h;float a=jaw;
		p=h+vec3(q.x,q.y*cos(a)+q.z*sin(a),-q.y*sin(a)+q.z*cos(a));
	}
	float z=p.z;float back=clamp(z/body_length,0.,1.);
	float t=TIME*1.5+swim_phase;
	p.x+=sin(z*.085*90./body_length-t)*(1.2+wave_amp*back)*body_length/90.;
	p.y+=sin(z*.06-t*.7)*.9*back;
	float head=1.-smoothstep(head_start,head_reach,z);
	p.y+=head*head*(raise*8.+lunge*5.);
	p.z-=head*lunge*9.;
	VERTEX=p;
}
void fragment(){
	ALBEDO=COLOR.rgb;
	ROUGHNESS=.38;SPECULAR=.65;
	if(glow){EMISSION=COLOR.rgb*(2.2+1.2*sin(TIME*1.7));}
	// Wet sheen on the back.
	RIM=.25;RIM_TINT=.4;
}
