uniform float sea_time=0.;
uniform vec4 wave_data[8];
uniform vec2 wind_direction=vec2(.9,.43);
uniform float wind_strength=.32;
uniform float swell_energy=.4;
uniform float rain_strength=0.;
uniform vec2 ocean_center=vec2(0);
// Local sea features (storms.gd, whirlpools.gd): storm cells raise and sharpen the swell inside them;
// whirlpools sink a funnel into the surface with a spiral ripple. x, z, radius, strength (0 = off).
uniform vec4 storm_cell[4];
uniform vec4 whirl[4];
float storm_factor(vec2 p){
	float s=0.;
	for(int i=0;i<4;i++){vec4 c=storm_cell[i];if(c.w<=0.)continue;s=max(s,c.w*(1.-smoothstep(c.z*.55,c.z*1.25,length(p-c.xy))));}
	return s;
}
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
	// Short waves fade out past the fine grid; the long swells carry on over the mid ring towards the horizon.
	float reach=max(abs(p.x-ocean_center.x),abs(p.y-ocean_center.y));
	float lod=1.-smoothstep(185.,240.,reach);
	float lod_long=1.-smoothstep(880.,1150.,reach);
	// Far from land a storm builds much bigger swells.
	float open_sea=smoothstep(80.,350.,c.x)*smoothstep(.45,1.,swell_energy);
	vec3 result=vec3(0);
	// Rough seas sharpen the crests (stronger second harmonic): peaked waves with flat troughs.
	float storm=storm_factor(p);
	float sharp=.15+.3*smoothstep(.4,1.,swell_energy)+.2*storm;
	for(int i=0;i<8;i++) {
		vec4 w=wave_data[i]; float bend=dot(p,vec2(.019,.027))+float(i);
		float phase=dot(p,w.xy)-w.w+sin(bend)*.37;
		float a=w.z*mix(i<3?.32:.1,1.,exposed)*shore*(1.-channel*(i<3?.2:.65))*(i<3?lod_long*(1.+open_sea*1.2):lod*(1.+open_sea*.4))*(1.+storm*(i<3?1.5:.35));
		vec2 gradient=(w.xy+cos(bend)*vec2(.019,.027)*.37)*(cos(phase)+2.*sharp*cos(2.*phase))*a;
		result+=vec3(-gradient.x,(sin(phase)+sharp*sin(2.*phase))*a,-gradient.y);
	}
	for(int i=0;i<4;i++){
		vec4 wh=whirl[i];if(wh.w<=0.)continue;
		vec2 d=p-wh.xy;float dist=length(d);if(dist>=wh.z)continue;
		float t=1.-dist/wh.z;float depth=wh.w*min(wh.z*.16,13.);
		vec2 dir=d/max(dist,.01);
		float ang=atan(d.y,d.x);
		float ripple=sin(ang*3.+dist*.35-sea_time*3.)*.18*t*wh.w;
		result.y+=-depth*pow(t,2.5)+ripple;
		result.xz+=-dir*(depth*2.5*pow(t,1.5)/wh.z);
	}
	result.y+=(sin(c.x*.85-sea_time*1.15)*.12*(.3+swell_energy)*(1.-smoothstep(0.,9.,c.x))*smoothstep(-1.4,0.,c.x))*lod;
	result.y+=sin(p.y*1.8-sea_time*1.5)*.08*channel*shore*lod;
	result.z-=cos(p.y*1.8-sea_time*1.5)*.144*channel*shore*lod;
	return result;
}
