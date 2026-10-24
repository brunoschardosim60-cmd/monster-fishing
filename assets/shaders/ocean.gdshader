shader_type spatial;
// Screen refraction uses the transparent pass. Explicit depth writes prevent
// distant back faces from painting over the nearer wave surface.
render_mode cull_disabled, depth_draw_always;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
#include "res://assets/shaders/ocean_common.gdshaderinc"
uniform vec3 deep_color : source_color = vec3(0.02,0.33,0.40);
uniform vec3 shallow_color : source_color = vec3(0.07,0.58,0.55);
uniform float sea_glow = 0.0; // luz difusa da água; ocean_environment liga de dia e desliga à noite
varying vec3 world_pos;
varying vec3 wave_normal;
varying float crest;
void vertex() {
	vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 w=sea_surface(wp.xz);
	VERTEX.y+=w.y;
	world_pos=wp+vec3(0,w.y,0);
	wave_normal=normalize(vec3(w.x,1,w.z));
	crest=w.y;
}
void fragment() {
	vec2 p=world_pos.xz;
	vec4 coast=coast_data(p);
	float exposure=sea_exposure(p,coast);
	vec3 n1=texture(normal_tex,p*.055+sea_time*vec2(.017,.009)).xyz*2.-1.;
	vec3 n2=texture(normal_tex,p*.12+sea_time*vec2(-.011,.022)).xyz*2.-1.;
	float distance_fade=1.-smoothstep(70.,280.,length(VERTEX));
	vec3 detail=vec3((n1.x+n2.x),0,(n1.y+n2.y))*(.09+wind_strength*.23)*mix(.3,1.,distance_fade)*mix(.35,1.,exposure);
	vec2 cell=floor(p*3.); vec2 local=fract(p*3.)-.5;
	float random=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float age=fract(sea_time*1.3+random);
	float drop=sin((length(local)-age*.7)*60.)*exp(-abs(length(local)-age*.7)*28.)*(1.-age)*rain_strength;
	detail.xz+=normalize(local+vec2(.001))*drop*.045*distance_fade;
	vec3 wn=normalize(wave_normal+detail);
	NORMAL=normalize((VIEW_MATRIX*vec4(wn,0)).xyz);
	float depth=texture(depth_tex,SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc=vec3(SCREEN_UV,depth)*2.-1.;
#else
	vec3 ndc=vec3(SCREEN_UV*2.-1.,depth);
#endif
	vec4 scene=INV_PROJECTION_MATRIX*vec4(ndc,1.);
	float thickness=max(0.,-scene.z/scene.w+VERTEX.z);
	float bottom_depth=max(.1,.8+coast.x*.65);
	float shallow=exp(-min(thickness,bottom_depth)*.23);
	float foam_noise=texture(foam_tex,p*.18+sea_time*vec2(-.02,.04)).r;
	foam_noise=mix(foam_noise,texture(foam_tex,p*.85+sea_time*vec2(-.015,.025)).r,.3);
	float shore=(1.-smoothstep(.08,.85,thickness))*smoothstep(.35,.72,foam_noise)*(.45+.55*pow(.5+.5*sin(coast.x*.85-sea_time*1.15),2.));
	float breaker=pow(.5+.5*sin(coast.x*.85-sea_time*1.15),5.);
	float surf=(1.-smoothstep(.4,4.,abs(coast.x)))*breaker*smoothstep(.25,.64,foam_noise)*(.4+swell_energy);
	float whitecap=smoothstep(.3+swell_energy*.8,.65+swell_energy*1.05,crest)*smoothstep(.4,.67,foam_noise)*wind_strength*exposure;
	float foam=clamp(shore+surf+whitecap,0.,.96);
	float crest_scattering=smoothstep(-.15,.6,crest)*.20;
	vec3 col=mix(deep_color,shallow_color,shallow*.75+crest_scattering);
	float cold=1.-smoothstep(60.,300.,length(p-COLD_CENTER));
	col=mix(col,col*vec3(.55,.7,.85),cold*.75+rain_strength*.22);
	vec2 distortion=wn.xz*.018*min(thickness,2.);
	vec3 refract_color=textureLod(screen_tex,clamp(SCREEN_UV+distortion,vec2(.001),vec2(.999)),0.).rgb;
	col=mix(col,refract_color*vec3(.65,.94,.92),shallow*.32);
	ALBEDO=mix(col,vec3(.78,.85,.81),foam);
	EMISSION=col*sea_glow*(1.-foam);
	ROUGHNESS=mix(.11+wind_strength*.1+rain_strength*.08,.83,foam)+(.04*(1.-distance_fade));
	METALLIC=.12;
	SPECULAR=.65;
	if(!FRONT_FACING){ALBEDO=mix(vec3(.015,.12,.14),col,.3);NORMAL=-NORMAL;ROUGHNESS=.35;}
}
