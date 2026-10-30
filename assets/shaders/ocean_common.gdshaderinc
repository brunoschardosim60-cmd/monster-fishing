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
uniform float tide=0.;
float storm_factor(vec2 p){
	float s=0.;
	for(int i=0;i<4;i++){vec4 c=storm_cell[i];if(c.w<=0.)continue;s=max(s,c.w*(1.-smoothstep(c.z*.55,c.z*1.25,length(p-c.xy))));}
	return s;
}
// A storm stirs the sea well beyond its rain: a wide halo where the swell builds as it comes.
float storm_halo(vec2 p){
	float s=0.;
	for(int i=0;i<4;i++){vec4 c=storm_cell[i];if(c.w<=0.)continue;s=max(s,c.w*(1.-smoothstep(c.z*.9,c.z*2.6,length(p-c.xy))));}
	return s;
}
// Sea state varies over kilometres and drifts slowly: swell groups higher here, lower there, so the
// sea never repeats the same pattern block after block (wave_field.gd sea_groups mirrors this).
float sea_groups(vec2 p,int i){
	float fi=float(i);
	float s1=sin(p.x*.0031+p.y*.0017+sea_time*.011+fi*.6);
	float s2=sin(-p.x*.0019+p.y*.0043-sea_time*.007+fi*1.3);
	float s3=sin(p.x*.0057-p.y*.0023+sea_time*.013+fi*.4);
	return i<3?mix(.78,1.18,.5+.5*(s1*.5+s2*.35+s3*.15)):mix(.6,1.3,.5+.5*(s1*.5+s2*.35+s3*.15));
}
// Short waves fade out with distance from the camera before the grid gets too coarse to carry them,
// otherwise they alias into long streaks and lattices across the sea. Visual only: wave_field.gd keeps
// them everywhere, and near the camera (where anything floats in view) the two agree.
float sea_detail_fade(float reach,int i){
	if(i<3)return 1.;
	// The finest grid has 1 m cells: waves under ~4 m long cannot be carried by it at all (they alias
	// into moiré rings and zebra stripes). They live in the fragment's normal detail instead.
	if(i>=6)return 0.;
	float len=2.*3.14159265/length(wave_data[i].xy);
	return 1.-smoothstep(len*6.,len*14.,reach);
}
// Crest lines bend and wander so the same wave train never reads as a straight repeating stripe.
float sea_warp(vec2 p,vec4 w,int i){
	float fi=float(i);
	return sin(dot(p,vec2(-w.y,w.x))*.0105+fi*1.7)*1.3+sin(dot(p,vec2(.0047,-.0063))+fi*.9)*1.1+sin(dot(p,vec2(.021,-.017))+fi*2.3)*(i<3?.4:1.2);
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
	float halo=storm_halo(p);
	float sharp=.15+.25*smoothstep(.4,1.,swell_energy)+.12*storm;
	for(int i=0;i<8;i++) {
		vec4 w=wave_data[i]; float bend=dot(p,vec2(.019,.027))+float(i);
		float phase=dot(p,w.xy)-w.w+sin(bend)*.37+sea_warp(p,w,i);
		float a=w.z*mix(i<3?.32:.1,1.,exposed)*shore*(1.-channel*(i<3?.2:.65))*(i<3?lod_long*(1.+open_sea*.8):lod*(1.+open_sea*.4))*(1.+storm*(i<3?.9:.35))*sea_groups(p,i)*(1.+max(halo-storm,0.)*(i<3?.6:.3))*sea_detail_fade(reach,i);
		// The crest-sharpening harmonic has half the wavelength: only the long swell carries it, and only
		// where the grid is fine enough (it would alias on the coarse rings).
		float sh=i<3?sharp*lod:0.;
		vec2 gradient=(w.xy+cos(bend)*vec2(.019,.027)*.37)*(cos(phase)+2.*sh*cos(2.*phase))*a;
		result+=vec3(-gradient.x,(sin(phase)+sh*sin(2.*phase))*a,-gradient.y);
	}
	for(int i=0;i<4;i++){
		vec4 wh=whirl[i];if(wh.w<=0.)continue;
		vec2 d=p-wh.xy;float dist=length(d);if(dist>=wh.z)continue;
		vec2 dir=d/max(dist,.01);
		float ang=atan(d.y,d.x);
		float t=1.-dist/wh.z;
		// A real maelstrom: a broad bowl that steepens into a narrow throat tens of metres deep
		// (wave_field.gd whirl_offset mirrors this). Its own fine radial mesh draws it (whirlpools.gd).
		float bowl=min(wh.z*.08,7.)*wh.w;
		float core=wh.z*.075;float c2=core*core;
		float throat=min(wh.z*.42,40.)*wh.w;
		float f=c2/(c2+dist*dist)-c2/(c2+wh.z*wh.z);
		float ripple=sin(ang*3.+dist*.35-sea_time*3.)*.18*t*wh.w;
		result.y+=-bowl*t*t-throat*f+ripple;
		// Slope of that surface (outward), for the normals.
		float slope=bowl*2.*t/wh.z+throat*2.*c2*dist/((c2+dist*dist)*(c2+dist*dist));
		result.xz+=-dir*slope;
	}
	result.y+=tide;
	result.y+=(sin(c.x*.85-sea_time*1.15)*.12*(.3+swell_energy)*(1.-smoothstep(0.,9.,c.x))*smoothstep(-1.4,0.,c.x))*lod;
	// Swash: every few seconds a wave runs up the beach and drains back, quick up, slow down, never in
	// step along the whole shore. Reaches some metres inland on a gentle beach (wave_field.gd mirrors it).
	float swash_s=fract(sea_time/7.5+sin(p.x*.031)*.35+cos(p.y*.027)*.35-c.x*.012);
	float swash=smoothstep(0.,.18,swash_s)*(1.-smoothstep(.18,1.,swash_s));
	result.y+=swash*.5*(.35+swell_energy)*smoothstep(-9.,-1.,c.x)*(1.-smoothstep(2.,14.,c.x))*lod;
	result.y+=sin(p.y*1.8-sea_time*1.5)*.08*channel*shore*lod;
	result.z-=cos(p.y*1.8-sea_time*1.5)*.144*channel*shore*lod;
	return result;
}
