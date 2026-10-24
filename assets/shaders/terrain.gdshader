shader_type spatial;
#include "res://assets/shaders/archipelago_coast.gdshaderinc"
uniform float sea_time=0.;
uniform float wet_weather=0.;
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
vec3 saturate_color(vec3 c,float s){return mix(vec3(dot(c,vec3(.2126,.7152,.0722))),c,s);}
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
	float n=texture(noise_tex,wp.xz*.06).r;
	float grass=smoothstep(.35,.62,COLOR.g-COLOR.r+.48+n*.13);
	vec3 sand=texture(sand_color,wp.xz*.48).rgb;
	vec3 meadow=texture(meadow_tex,wp.xz*.16).rgb;
	vec3 floor_color=texture(floor_tex,wp.xz*.34).rgb;
	vec3 turf=mix(meadow*vec3(.85,1.,.82),floor_color,smoothstep(.43,.72,n)*.68);
	float detail=texture(noise_tex,wp.xz*2.6).r;
	turf*=mix(.82,1.12,detail);
	turf=saturate_color(turf*vec3(.84,1.07,.79),1.2);
	sand*=vec3(1.05,1.0,.9);
	float wash=.12+.1*sin(sea_time*1.15-wp.x*.12-wp.z*.14);
	float wet=max(wet_weather*.45,1.-smoothstep(wash,wash+.8,wp.y));
	ALBEDO=mix(sand,turf,grass)*mix(1.,.52,wet);
	NORMAL_MAP=texture(sand_normal,wp.xz*.48).rgb;
	NORMAL_MAP=mix(NORMAL_MAP,texture(ground_normal,wp.xz*.34).rgb,grass);
	vec3 weights=pow(abs(normalize(wn)),vec3(4.));
	weights/=max(.001,weights.x+weights.y+weights.z);
	vec3 stone=texture(rock_tex,wp.zy*.22).rgb*weights.x+texture(rock_tex,wp.xz*.22).rgb*weights.y+texture(rock_tex,wp.xy*.22).rgb*weights.z;
	float cliff=smoothstep(.07,.40,1.-normalize(wn).y)*smoothstep(1.6,3.,wp.y);
	stone=saturate_color(stone*.84,1.18);
	ALBEDO=mix(ALBEDO,stone*mix(vec3(.9,.94,.9),vec3(1.2,1.1,.94),n),cliff*mix(.78,1.,n));
	ALBEDO*=biome_tint;
	float frost=(1.-smoothstep(120.,200.,length(wp.xz-COLD_CENTER)))*smoothstep(12.,28.,wp.y)*smoothstep(.35,.8,wn.y);
	float regional_snow=biome_snow*smoothstep(10.,30.,wp.y)*smoothstep(.35,.82,wn.y);
	ALBEDO=mix(ALBEDO,vec3(.72,.82,.84),max(frost*.92,regional_snow*.94));
	float ash=biome_ash*smoothstep(4.,18.,wp.y)*(1.-cliff*.45);
	ALBEDO=mix(ALBEDO,vec3(.16,.15,.16),ash*.68);
	NORMAL_MAP=mix(NORMAL_MAP,texture(rock_normal,wp.xz*.3).rgb,cliff);
	NORMAL_MAP_DEPTH=.18;
	ROUGHNESS=mix(.98,.68,wet);
}
