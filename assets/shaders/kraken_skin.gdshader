shader_type spatial;
render_mode cull_disabled;
// Kraken skin: mottled wet red-brown hide with warts and a pale underside. With `tentacle` on, the straight tube mesh
// (along +Y, UV.y 0 base -> 1 tip) is bent in the vertex stage: the curl angle grows along the arm, waves travel to
// the tip, and `slam` whips the arm down. Suckers are painted on the inner (+Z) side.
uniform bool tentacle=false;
uniform float arm_length=14.;
uniform float curl=.16;        // base curvature (rad per metre)
uniform float wave=.08;        // travelling curvature wave
uniform float phase=0.;
uniform float slam=0.;         // 0..1
uniform vec3 hide_color:source_color=vec3(.14,.045,.05);
uniform vec3 mottle_color:source_color=vec3(.27,.075,.075);
uniform vec3 belly_color:source_color=vec3(.46,.25,.22);
uniform vec3 sucker_color:source_color=vec3(.86,.66,.58);
varying vec3 local_pos;
varying float inner;
varying float along;

float hash(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 x){vec3 i=floor(x);vec3 f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}

mat3 rot_x(float a){float c=cos(a);float s=sin(a);return mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c));}
mat3 rot_z(float a){float c=cos(a);float s=sin(a);return mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1));}
float bend_x(float s,float t){return (curl+wave*sin(t*1.3+phase-s*.45))*s+slam*(1.6*s/arm_length*s/arm_length*6.)-slam*.9;}
float bend_z(float s,float t){return .05*sin(t*.9+phase*1.7-s*.3)*s;}

void vertex(){
	local_pos=VERTEX;along=UV.y;inner=NORMAL.z;
	if(tentacle){
		float s=VERTEX.y;float t=TIME;
		// Integrate the bent centreline in 10 steps.
		vec3 c=vec3(0.);float ds=s/10.;
		for(int i=0;i<10;i++){float u=(float(i)+.5)*ds;c+=rot_z(bend_z(u,t))*rot_x(bend_x(u,t))*vec3(0,1,0)*ds;}
		mat3 r=rot_z(bend_z(s,t))*rot_x(bend_x(s,t));
		VERTEX=c+r*vec3(VERTEX.x,0.,VERTEX.z);
		NORMAL=r*NORMAL;TANGENT=r*TANGENT;BINORMAL=r*BINORMAL;
	}
}

void fragment(){
	vec3 p=local_pos;
	float m=noise(p*1.4)*.6+noise(p*4.1)*.4;
	vec3 col=mix(hide_color,mottle_color,smoothstep(.45,.75,m));
	// Warts: small raised spots darken at their rims.
	float warts=smoothstep(.72,.8,noise(p*6.5));
	col=mix(col,hide_color*.6,warts*.5);
	if(tentacle){
		// Pale inner side with two rows of suckers.
		float side=smoothstep(.15,.55,inner);
		col=mix(col,belly_color,side*.5);
		float row=fract(along*44.);float ring=length(vec2(row-.5,(abs(UV.x-.25)*12.)));
		float sucker=side*(1.-smoothstep(.28,.36,ring));
		float rim=side*smoothstep(.22,.3,ring)*(1.-smoothstep(.36,.44,ring));
		col=mix(col,sucker_color,sucker);col=mix(col,hide_color*.7,rim*.6);
	}else{
		col=mix(col,belly_color,smoothstep(1.4,.2,p.y)*.55);
	}
	if(!FRONT_FACING)NORMAL=-NORMAL;
	NORMAL=normalize(NORMAL+vec3(noise(p*9.)-.5,noise(p*9.+3.)-.5,0.)*.25*(1.-warts*.5));
	ALBEDO=col;ROUGHNESS=mix(.32,.55,m);SPECULAR=.55;
	RIM=.1;RIM_TINT=.2;
}
