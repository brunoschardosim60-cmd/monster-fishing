shader_type spatial;
render_mode cull_disabled;
// Whale / leviathan hide on the lathe body from big_animals.gd (length along +Y, tail at y=0, head at y=length;
// local +Z is the back after the body is rotated). Countershaded: dark back, pale belly with throat grooves,
// mottling and pale scars. The tail stock beats up and down. The leviathan adds rows of glowing spots.
uniform float body_length = 14.;
uniform float beat = .9;           // tail beats per second (radians * this)
uniform float beat_amp = .5;       // metres at the fluke
uniform vec3 back_color : source_color = vec3(.12,.16,.2);
uniform vec3 belly_color : source_color = vec3(.72,.76,.78);
uniform float glow = 0.;           // leviathan photophores
uniform vec3 glow_color : source_color = vec3(.45,.9,1.);
varying vec3 lp;
varying vec3 ln;
float hash(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 x){vec3 i=floor(x);vec3 f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){
	lp=VERTEX; ln=NORMAL;
	float s=VERTEX.y/body_length;            // 0 tail .. 1 head
	float w=pow(clamp(1.-s/.55,0.,1.),2.);
	VERTEX.z+=sin(TIME*beat-s*4.)*beat_amp*w;
}
void fragment(){
	float s=lp.y/body_length;
	float up=-normalize(ln).z;               // the lathe is turned so its -Z side is the back
	float m=noise(lp*.35)*.6+noise(lp*1.3)*.4;
	vec3 back=back_color*(.8+.4*m);
	vec3 belly=belly_color*(.88+.15*m);
	float line=smoothstep(-.35,-.05,up+.15*(m-.5));
	vec3 col=mix(belly,back,line);
	// Throat grooves under the front third.
	float grooves=(1.-line)*smoothstep(.62,.75,s)*smoothstep(.5,.0,abs(fract(atan(lp.x,-lp.z)*9.)-.5)*2.);
	col*=1.-grooves*.35;
	// Pale scars and barnacle patches on the back and head.
	float scar=smoothstep(.82,.86,noise(vec3(lp.x*4.,lp.y*.4,lp.z*4.)))*line;
	col=mix(col,vec3(.6,.62,.6),scar*.5);
	float barn=smoothstep(.78,.84,noise(lp*2.2))*smoothstep(.7,.95,s);
	col=mix(col,vec3(.55,.53,.48),barn*.7);
	vec3 emit=vec3(0.);
	if(glow>0.){
		float row=abs(fract(atan(lp.x,-lp.z)/6.2832*10.)-.5);
		float dot_=smoothstep(.12,.05,row)*smoothstep(.3,.15,abs(fract(lp.y*.45)-.5));
		emit=glow_color*dot_*glow*(.6+.4*sin(TIME*2.+lp.y));
	}
	if(!FRONT_FACING)NORMAL=-NORMAL;
	ALBEDO=col; ROUGHNESS=mix(.3,.5,m); SPECULAR=.5; EMISSION=emit;
}
