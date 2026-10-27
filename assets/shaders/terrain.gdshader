shader_type spatial;
#include "res://assets/shaders/archipelago_coast.gdshaderinc"
#include "res://assets/shaders/cloud_shadow.gdshaderinc"
uniform float sea_time=0.;
uniform float wet_weather=0.;
uniform float caustic_strength=1.;
uniform sampler2D sand_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 biome_tint=vec3(1.);
uniform float biome_snow=0.;
uniform float biome_ash=0.;
// Remote-island painting: ground/accent colours, how much of the turf is repainted, how rocky flat ground is.
uniform float biome_land=0.;
uniform float biome_paint=0.;
uniform float biome_rock=0.;
uniform vec3 biome_ground=vec3(.3,.5,.3);
uniform vec3 biome_accent=vec3(.4,.6,.3);
vec3 saturate_color(vec3 c,float s){return mix(vec3(dot(c,vec3(.2126,.7152,.0722))),c,s);}
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
	float n=texture(noise_tex,wp.xz*.06).r;
	float grass=smoothstep(.35,.62,COLOR.g-COLOR.r+.48+n*.13);
	grass=mix(grass,smoothstep(.15,.7,COLOR.a+n*.12-.06),biome_land);
	vec3 sand=texture(sand_color,wp.xz*.48).rgb;
	vec3 meadow=texture(meadow_tex,wp.xz*.16).rgb;
	vec3 floor_color=texture(floor_tex,wp.xz*.34).rgb;
	vec3 turf=mix(meadow*vec3(.85,1.,.82),floor_color,smoothstep(.43,.72,n)*.68);
	float detail=texture(noise_tex,wp.xz*2.6).r;
	turf*=mix(.82,1.12,detail);
	// Macro patches: ground and accent colours drift over hundreds of metres, higher ground shifts to the accent.
	float macro=texture(noise_tex,wp.xz*.011+vec2(.37,.11)).r;
	float macro2=texture(noise_tex,wp.xz*.035).r;
	float lum=dot(floor_color,vec3(.3333));
	vec3 painted=mix(biome_ground,biome_accent,smoothstep(.36,.66,macro)*.9+smoothstep(10.,34.,wp.y)*.3);
	painted*=(.5+.6*lum)*mix(.86,1.14,detail)*mix(.9,1.1,macro2);
	turf=saturate_color(turf*vec3(.84,1.07,.79),1.2);
	turf=mix(turf,painted,biome_paint);
	sand*=vec3(1.05,1.0,.9);
	float wash=.12+.1*sin(sea_time*1.15-wp.x*.12-wp.z*.14);
	float wet=max(wet_weather*.45,1.-smoothstep(wash,wash+.8,wp.y));
	ALBEDO=mix(sand,turf,grass)*mix(1.,.52,wet);
	// Below the waterline the ground is sea sand, not meadow.
	float submerged=1.-smoothstep(-1.4,-.3,wp.y);
	ALBEDO=mix(ALBEDO,sand*vec3(.84,.86,.76)*mix(.82,1.06,detail),submerged);
	grass*=1.-submerged;
	NORMAL_MAP=texture(sand_normal,wp.xz*.48).rgb;
	NORMAL_MAP=mix(NORMAL_MAP,texture(ground_normal,wp.xz*.34).rgb,grass);
	vec3 weights=pow(abs(normalize(wn)),vec3(4.));
	weights/=max(.001,weights.x+weights.y+weights.z);
	vec3 stone=texture(rock_tex,wp.zy*.22).rgb*weights.x+texture(rock_tex,wp.xz*.22).rgb*weights.y+texture(rock_tex,wp.xy*.22).rgb*weights.z;
	float cliff=smoothstep(.07,.40,1.-normalize(wn).y)*smoothstep(1.6,3.,wp.y);
	cliff=max(cliff,biome_rock*grass*smoothstep(.0,.9,macro2*1.3+n*.5-.35)*smoothstep(1.6,4.,wp.y));
	stone=saturate_color(stone*.84,1.18);
	ALBEDO=mix(ALBEDO,stone*mix(vec3(.9,.94,.9),vec3(1.2,1.1,.94),n),cliff*mix(.78,1.,n));
	ALBEDO*=biome_tint;
	float frost=(1.-smoothstep(120.,200.,length(wp.xz-COLD_CENTER)))*smoothstep(12.,28.,wp.y)*smoothstep(.35,.8,wn.y);
	float regional_snow=biome_snow*smoothstep(10.,30.,wp.y)*smoothstep(.35,.82,wn.y);
	ALBEDO=mix(ALBEDO,vec3(.72,.82,.84),max(frost*.92,regional_snow*.94));
	float ash=biome_ash*smoothstep(4.,18.,wp.y)*(1.-cliff*.45);
	ALBEDO=mix(ALBEDO,vec3(.16,.15,.16),ash*.68);
	// Deep under water the island ground meets the open seabed (seabed.gdshader): paint it the same sea
	// sand so the line where the two surfaces cross does not show as a pale ribbon.
	float seafloor=1.-smoothstep(-1.6,-.75,wp.y);
	vec3 seabed_sand=texture(sand_color,wp.xz*.35).rgb*mix(vec3(.38,.55,.43),vec3(.83,.82,.65),texture(noise_tex,wp.xz*.045).r);
	ALBEDO=mix(ALBEDO,seabed_sand,seafloor*(1.-cliff));
	NORMAL_MAP=mix(NORMAL_MAP,texture(rock_normal,wp.xz*.3).rgb,cliff);
	NORMAL_MAP_DEPTH=.18;
	// Caustics: two drifting noise layers; where they match, sunlight focuses into thin bright lines.
	float depth=max(0.,-wp.y);
	vec2 cuv=wp.xz*.3;
	float c1=texture(noise_tex,cuv+vec2(TIME*.031,TIME*.017)).r;
	float c2=texture(noise_tex,cuv*1.31+vec2(-TIME*.024,TIME*.029)).r;
	float caustic=pow(clamp(1.-abs(c1-c2)*3.2,0.,1.),6.)*smoothstep(.15,.9,depth)*exp(-depth*.09);
	ALBEDO*=1.+caustic*1.1*caustic_strength;
	// Water absorbs red first: deeper ground shifts towards blue-green.
	ALBEDO*=mix(vec3(1.),vec3(.52,.8,.84),smoothstep(0.,10.,depth));
	ALBEDO*=mix(1.,.58,cloud_shadow(noise_tex,wp.xz));
	ROUGHNESS=mix(.98,.68,wet);
}
