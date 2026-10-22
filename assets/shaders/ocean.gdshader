shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float sea_time = 0.;
uniform vec3 deep_color : source_color = vec3(0.015,0.25,0.27);
uniform vec3 shallow_color : source_color = vec3(0.03,0.40,0.39);
varying vec3 world_pos;
varying vec3 wave_normal;
varying float crest;
float coast_factor(vec2 p) {
	return mix(0.25,1.0,smoothstep(13.0,65.0,length(p-vec2(0,-15))));
}
vec3 swell(vec2 p, vec2 direction, float length_wave, float amplitude, float speed, float t) {
	float k = 6.2831853 / length_wave;
	float bend=dot(p,vec2(.037,.029));
	float phase = dot(p,direction)*k-t*speed+sin(bend)*1.7;
	vec2 gradient=direction*k+cos(bend)*vec2(.037,.029)*1.7;
	return vec3(-gradient.x*amplitude*cos(phase),amplitude*sin(phase),-gradient.y*amplitude*cos(phase));
}
void vertex() {
	vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 w=swell(wp.xz,normalize(vec2(1,.45)),13.,.42,1.55,sea_time);
	w+=swell(wp.xz,normalize(vec2(-.35,1)),7.1,.22,1.9,sea_time);
	w+=swell(wp.xz,normalize(vec2(.8,-.65)),3.5,.095,2.4,sea_time);
	w+=swell(wp.xz,normalize(vec2(-1.,-.2)),5.3,.09,1.7,sea_time);
	w+=swell(wp.xz,normalize(vec2(.15,1.)),2.4,.045,2.7,sea_time);
	float f=coast_factor(wp.xz);
	float lod=1.-smoothstep(185.,240.,max(abs(wp.x),abs(wp.z)));
	VERTEX.y+=w.y*f*lod;
	world_pos=wp+vec3(0,w.y*f*lod,0);
	wave_normal=normalize(vec3(w.x*f,1,w.z*f));
	crest=w.y*f;
}
void fragment() {
	vec2 p=world_pos.xz;
	vec3 n1=texture(normal_tex,p*.055+sea_time*vec2(.017,.009)).xyz*2.-1.;
	vec3 n2=texture(normal_tex,p*.12+sea_time*vec2(-.011,.022)).xyz*2.-1.;
	float distance_fade=1.-smoothstep(70.,280.,length(VERTEX));
	vec3 detail=vec3((n1.x+n2.x)*.2,0,(n1.y+n2.y)*.2)*mix(.3,1.,distance_fade);
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
	float shallow=exp(-thickness*.23);
	float foam_noise=texture(foam_tex,p*.18+sea_time*vec2(-.02,.04)).r;
	foam_noise=mix(foam_noise,texture(foam_tex,p*.85+sea_time*vec2(-.015,.025)).r,.3);
	float shore=(1.-smoothstep(.08,.85,thickness))*smoothstep(.24,.68,foam_noise);
	float whitecap=smoothstep(.22,.52,crest)*smoothstep(.34,.63,foam_noise)*.9;
	float foam=clamp(shore+whitecap,0.,1.);
	float crest_scattering=smoothstep(-.15,.6,crest)*.20;
	vec3 col=mix(deep_color,shallow_color,shallow*.75+crest_scattering);
	vec2 distortion=wn.xz*.018*min(thickness,2.);
	vec3 refract_color=textureLod(screen_tex,clamp(SCREEN_UV+distortion,vec2(.001),vec2(.999)),0.).rgb;
	col=mix(col,refract_color*vec3(.65,.94,.92),shallow*.32);
	ALBEDO=mix(col,vec3(.78,.85,.81),foam);
	ROUGHNESS=mix(.16,.83,foam)+(.04*(1.-distance_fade));
	METALLIC=.12;
	SPECULAR=.65;
}
