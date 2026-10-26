shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, blend_mix;
// Jellyfish from Bruno's marine pack. Mesh height 1 (bell on top at y > .15, tentacles below).
// The bell pulses, the tentacles trail and sway, the body is translucent with a glowing rim.
uniform vec3 tint : source_color = vec3(1.);
uniform float glow = .25;
instance uniform float phase = 0.;
varying float bell;
float pulse(){ return sin(TIME*2.1+phase); }
void vertex(){
	bell=smoothstep(.05,.3,VERTEX.y);
	float pl=pulse();
	VERTEX.xz*=1.+bell*pl*.1;
	VERTEX.y+=bell*pl*.025;
	float tail=smoothstep(.15,-.5,VERTEX.y);
	VERTEX.x+=sin(TIME*1.3+phase+VERTEX.y*7.)*tail*.07;
	VERTEX.z+=cos(TIME*1.1+phase*1.3+VERTEX.y*6.)*tail*.07;
	VERTEX.y+=tail*max(pl,0.)*.03;
}
void fragment(){
	if(!FRONT_FACING) NORMAL=-NORMAL;
	vec3 c=pow(COLOR.rgb,vec3(2.2))*tint;
	float rim=pow(1.-clamp(abs(dot(NORMAL,VIEW)),0.,1.),2.);
	ALBEDO=c;
	ROUGHNESS=.12; SPECULAR=.8;
	ALPHA=mix(.28,.72,rim)*mix(.75,1.,bell);
	EMISSION=c*(glow*(.4+rim*1.6));
	BACKLIGHT=c*.6;
}
