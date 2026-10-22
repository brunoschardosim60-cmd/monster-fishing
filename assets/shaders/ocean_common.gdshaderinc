uniform float sea_time=0.;
uniform vec4 wave_data[8];
uniform vec2 wind_direction=vec2(.9,.43);
uniform float wind_strength=.32;
uniform float swell_energy=.4;
uniform float rain_strength=0.;
uniform vec2 ocean_center=vec2(0);
#include "res://assets/shaders/archipelago_coast.gdshaderinc"
float sea_exposure(vec2 p,vec4 c) {
	float lee=smoothstep(-.2,.65,dot(c.yz,wind_direction))*(1.-smoothstep(2.,38.,c.x));
	float port=1.-smoothstep(.35,1.5,length(vec2(p.x/16.,(p.y+17.)/21.)));
	float channel=1.-smoothstep(7.,32.,c.w);
	return clamp((1.-lee*.72-port*.72)*(1.-channel*.4),.16,1.);
}
vec3 sea_surface(vec2 p) {
	vec4 c=coast_data(p); float exposed=sea_exposure(p,c);
	float channel=1.-smoothstep(.25,1.,length((p-vec2(504,-626))/vec2(12,34)));
	float shore=smoothstep(-1.3,6.,c.x);
	float lod=1.-smoothstep(185.,240.,max(abs(p.x-ocean_center.x),abs(p.y-ocean_center.y)));
	vec3 result=vec3(0);
	for(int i=0;i<8;i++) {
		vec4 w=wave_data[i]; float bend=dot(p,vec2(.019,.027))+float(i);
		float phase=dot(p,w.xy)-w.w+sin(bend)*.37;
		float a=w.z*mix(i<3?.32:.1,1.,exposed)*shore*(1.-channel*(i<3?.2:.65));
		vec2 gradient=(w.xy+cos(bend)*vec2(.019,.027)*.37)*(cos(phase)+.3*cos(2.*phase))*a;
		result+=vec3(-gradient.x,(sin(phase)+.15*sin(2.*phase))*a,-gradient.y);
	}
	result.y+=sin(c.x*.85-sea_time*1.15)*.12*(.3+swell_energy)*(1.-smoothstep(0.,9.,c.x))*smoothstep(-1.4,0.,c.x);
	result.y+=sin(p.y*1.8-sea_time*1.5)*.08*channel*shore;
	result.z-=cos(p.y*1.8-sea_time*1.5)*.144*channel*shore;
	return result*lod;
}
