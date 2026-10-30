shader_type spatial;
// Screen refraction uses the transparent pass. Explicit depth writes prevent
// distant back faces from painting over the nearer wave surface.
render_mode cull_disabled, depth_draw_always, blend_mix;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
#include "res://assets/shaders/ocean_common.gdshaderinc"
#include "res://assets/shaders/cloud_shadow.gdshaderinc"
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.02,0.19,0.25);
uniform vec3 shallow_color : source_color = vec3(0.09,0.50,0.48);
uniform vec3 abyss_color : source_color = vec3(0.01,0.09,0.16);
uniform vec3 sky_horizon : source_color = vec3(0.62,0.76,0.86);
uniform vec3 sky_zenith : source_color = vec3(0.18,0.40,0.68);
uniform vec3 sun_dir = vec3(0.3,0.5,-0.8);
uniform vec3 sun_color : source_color = vec3(1.0,0.95,0.85);
uniform float sun_strength = 1.0;
uniform float sea_glow = 0.0; // luz difusa da água; ocean_environment liga de dia e desliga à noite
// The player's hull (wave_field.gd hull_*): the sea is cut out inside it, so the boat floats on the
// water instead of the water running through it; water that comes aboard is drawn by the boat itself.
uniform mat4 hull_inv=mat4(1.);
uniform vec4 hull_box=vec4(0.);
uniform float hull_pointed=0.;
uniform float hull_keel=-1.;
// Whirlpools have their own fine radial mesh (whirlpools.gd): on it funnel = (x, z, radius, 1); the
// regular grids (funnel.w = 0) leave the inside of every whirlpool to it, so the throat is never drawn
// with the coarse far cells.
instance uniform vec4 funnel=vec4(0.);
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
	if(funnel.w>0.){
		if(length(world_pos.xz-funnel.xy)>funnel.z*.9) discard;
	}else{
		for(int i=0;i<4;i++){
			vec4 wh=whirl[i];
			if(wh.w>.02 && length(world_pos.xz-wh.xy)<wh.z*.9) discard;
		}
	}
	if(hull_box.x>0.){
		vec3 hl=(hull_inv*vec4(world_pos,1.)).xyz;
		// Narrowing towards the bow so the cut follows the hull lines.
		float half_w=hull_box.x*mix(.25,1.,smoothstep(hull_box.y,hull_box.y+(hull_box.z-hull_box.y)*.35,hl.z));
		half_w*=mix(1.,mix(.12,1.,smoothstep(hull_box.z,hull_box.z-(hull_box.z-hull_box.y)*.35,hl.z))*mix(.5,1.,smoothstep(hull_box.y,hull_box.y+(hull_box.z-hull_box.y)*.35,hl.z)),hull_pointed);
		if(abs(hl.x)<half_w && hl.z>hull_box.y && hl.z<hull_box.z && hl.y<hull_box.w && hl.y>hull_keel) discard;
	}
	vec2 p=world_pos.xz;
	vec4 coast=coast_data(p);
	float exposure=sea_exposure(p,coast);
	vec3 n1=texture(normal_tex,p*.055+sea_time*vec2(.017,.009)).xyz*2.-1.;
	vec3 n2=texture(normal_tex,p*.12+sea_time*vec2(-.011,.022)).xyz*2.-1.;
	float distance_fade=1.-smoothstep(70.,280.,length(VERTEX));
	// A third, rotated layer at another scale so the ripple texture never lines up into a grid, and
	// wind gusts: patches where the ripples are rougher or almost flat (cat's paws), drifting downwind.
	vec2 pr=mat2(vec2(.8,-.6),vec2(.6,.8))*p;
	vec3 n3=texture(normal_tex,pr*.031+sea_time*vec2(.006,-.013)).xyz*2.-1.;
	float gust=smoothstep(.25,.75,texture(foam_tex,p*.0035-wind_direction*sea_time*.004).r);
	// Kept gentle: strong fine normals mirror the sky into zebra stripes and moiré rings.
	float fine=1.-smoothstep(.25,.9,length(fwidth(p)));
	vec3 detail=vec3((n1.x+n2.x*fine)*.8+n3.x*.3,0,(n1.y+n2.y*fine)*.8+n3.y*.3)*(.07+wind_strength*.13)*mix(.8,1.2,gust)*mix(.2,1.,distance_fade)*mix(.35,1.,exposure);
	vec2 cell=floor(p*3.); vec2 local=fract(p*3.)-.5;
	float random=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float age=fract(sea_time*1.3+random);
	float drop=sin((length(local)-age*.7)*60.)*exp(-abs(length(local)-age*.7)*28.)*(1.-age)*rain_strength;
	// Rain rings are ~10 cm across: once a pixel covers more than a few centimetres of sea they can no
	// longer be drawn and alias into big moiré rings over the whole storm, so they fade with the pixel size.
	float footprint=length(fwidth(p));
	drop*=1.-smoothstep(.012,.035,footprint);
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
	// Wind-driven streaks of old foam lying along the wind, and spray-white crests inside storm cells.
	float storm=storm_factor(p);
	vec2 along=normalize(wind_direction+vec2(1e-4));vec2 across=vec2(-along.y,along.x);
	float streak_noise=texture(foam_tex,vec2(dot(p,along)*.012,dot(p,across)*.09)+sea_time*vec2(.006,0.)).r;
	float streaks=smoothstep(.62,.8,streak_noise)*smoothstep(.45,.9,wind_strength+storm*.5)*exposure*.55;
	float crest_top=smoothstep(.55,1.,crest/max(.6,1.+swell_energy*2.2));
	float storm_caps=crest_top*smoothstep(.5,.75,foam_noise)*storm*.8+smoothstep(.62,.8,streak_noise)*storm*.35;
	float swirl=0.;float vortex=0.;
	for(int i=0;i<4;i++){
		vec4 wh=whirl[i];if(wh.w<=0.)continue;
		vec2 d=p-wh.xy;float dist=length(d);if(dist>=wh.z*1.1)continue;
		float t=clamp(1.-dist/wh.z,0.,1.);
		// Foam advected round the funnel: noise sampled in rotating polar coordinates, broken into streaks.
		float ang=atan(d.y,d.x)+sea_time*wh.w*(.4+1.6*t*t)+log(dist+1.)*1.6;
		// Angle in whole turns of the texture, so there is no seam where atan wraps round.
		vec2 polar=vec2(ang/6.2831853*4.,dist*.05);
		float churn=texture(foam_tex,polar*vec2(.5,1.)).r*.6+texture(foam_tex,polar*vec2(1.3,3.)+.3).r*.4;
		float arms=.5+.5*sin(ang*5.);
		swirl=max(swirl,smoothstep(.5,.85,churn*.7+arms*.45)*smoothstep(0.,.3,t)*(1.-smoothstep(.9,1.,t))*wh.w*.7);
		float core=wh.z*.075;
		vortex=max(vortex,max(t*t*.6,core*core/(core*core+dist*dist))*wh.w);
	}
	float foam=clamp(shore+surf+whitecap+streaks+storm_caps+swirl,0.,.96);
	// --- Colour model -------------------------------------------------------------------
	// Water body: turquoise only over shallow sand near the coast, deep teal-navy in open sea.
	float column=min(thickness,bottom_depth);
	float open_sea=smoothstep(18.,140.,coast.x);
	vec3 col=mix(deep_color,shallow_color,exp(-column*.16)*(1.-open_sea*.85));
	col=mix(col,abyss_color,open_sea*.75);
	col=mix(col,vec3(.004,.03,.05),vortex*.8);
	float cold=1.-smoothstep(60.,300.,length(p-COLD_CENTER));
	col=mix(col,col*vec3(.55,.7,.85),cold*.75+rain_strength*.22);
	vec2 distortion=wn.xz*.018*min(thickness,2.);
	vec3 refract_color=textureLod(screen_tex,clamp(SCREEN_UV+distortion,vec2(.001),vec2(.999)),0.).rgb;
	// Clear shallow water shows the seabed and the schools drawn before the surface.
	float view_dist=length(VERTEX);
	float clear=(1.-smoothstep(2.,12.,thickness))*(1.-smoothstep(35.,110.,view_dist))*(1.-open_sea);
	vec3 body=mix(col,refract_color*vec3(.62,.93,.9),clear*.7);
	// Fresnel reflection of the sky, plus the sun glitter path.
	vec3 v_world=normalize((INV_VIEW_MATRIX*vec4(VIEW,0.)).xyz);
	float ndv=clamp(dot(wn,v_world),0.,1.);
	float fresnel=.02+.98*pow(1.-ndv,5.);
	fresnel=mix(fresnel,1.,smoothstep(150.,900.,view_dist)*.35);
	vec3 r=reflect(-v_world,wn);
	vec3 sky=mix(sky_horizon,sky_zenith,pow(clamp(r.y,0.,1.),.5));
	float glint=pow(max(dot(r,normalize(sun_dir)),0.),mix(380.,900.,distance_fade))*sun_strength;
	// Light passing through wave crests between the viewer and the sun.
	float towards_sun=pow(max(dot(-v_world,normalize(vec3(sun_dir.x,0.,sun_dir.z))),0.),3.);
	vec3 sss=shallow_color*smoothstep(.05,.8,crest)*(.25+towards_sun*.9)*sun_strength*.35;
	vec3 surface=mix(body,sky,fresnel*(1.-foam));
	float shade=cloud_shadow(cloud_tex,p);
	glint*=1.-shade;sss*=1.-shade*.7;
	ALBEDO=mix(surface*(1.-fresnel*.6),vec3(.86,.9,.88),foam)*mix(1.,.72,shade)*(1.-vortex*.65);
	EMISSION=(sky*fresnel*.55+sss)*(1.-foam)+sun_color*glint*6.*(1.-foam)+col*sea_glow*(1.-foam);
	ROUGHNESS=mix(.06+wind_strength*.08+rain_strength*.1,.85,foam)+.05*(1.-distance_fade);
	METALLIC=0.;
	SPECULAR=.35;
	ALPHA=max(mix(.92,.32,clear),fresnel)*(1.-foam)+.95*foam;
	ALPHA=mix(ALPHA,1.,smoothstep(60.,160.,view_dist));
	if(!FRONT_FACING){ALBEDO=mix(vec3(.015,.12,.14),col,.3);EMISSION=vec3(0.);NORMAL=-NORMAL;ROUGHNESS=.35;ALPHA=.9;}
}
