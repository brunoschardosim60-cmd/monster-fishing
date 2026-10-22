shader_type sky;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction=vec3(.47,.34,-.81);
uniform vec3 moon_direction=vec3(-.47,-.34,.81);
uniform float cloud_cover=.32;
uniform float weather_time=0.;
uniform float lightning=0.;
float clouds(vec2 p) {
	return texture(cloud_noise,p).r*.6+texture(cloud_noise,p*2.13).r*.27+texture(cloud_noise,p*4.07).r*.13;
}
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void sky() {
	vec3 d=normalize(EYEDIR);
	float h=max(d.y,0.);
	vec3 col=mix(vec3(.28,.43,.51),vec3(.018,.075,.17),pow(h,.45));
	float day=smoothstep(-.16,.22,sun_direction.y);
	col=mix(mix(vec3(.014,.027,.055),vec3(.001,.004,.014),h),col,day);
	vec2 star_uv=vec2(atan(d.z,d.x)/6.283185+0.5,asin(d.y)/3.141593+0.5)*vec2(700.,350.);
	vec2 cell=floor(star_uv);float seed=hash21(cell);
	vec2 star_pos=vec2(hash21(cell+31.),hash21(cell+67.));
	float star=(1.-smoothstep(.025,.095,length(fract(star_uv)-star_pos)))*step(.975,seed);
	col+=mix(vec3(.6,.75,1.),vec3(1.,.77,.5),hash21(cell+3.))*star*(1.-day)*smoothstep(0.,.12,d.y)*(1.-cloud_cover)*(.6+.4*sin(weather_time*.7+seed*100.));
	float lunar=dot(d,normalize(moon_direction));
	float disc=smoothstep(.99965,.9998,lunar);
	float crater=clouds(d.xz*30.)*.45+.55;
	col+=vec3(.65,.78,.94)*(disc*crater*1.2+pow(max(lunar,0.),150.)*.018)*(1.-day)*(1.-cloud_cover*.9);
	float sun=max(dot(d,normalize(sun_direction)),0.);
	col+=vec3(1.,.48,.14)*pow(sun,10.)*.55*day;
	col+=vec3(1.,.87,.65)*smoothstep(.9996,.9999,sun)*9.*(1.-cloud_cover*.92);
	if(d.y>.015) {
		vec2 uv=d.xz/(d.y+.18)*.035+vec2(.21,.37)+weather_time*vec2(.00012,.00005);
		float c=clouds(uv);
		float density=smoothstep(mix(.5,.22,cloud_cover),mix(.67,.46,cloud_cover),c)*smoothstep(.015,.12,d.y);
		density=mix(density,1.,smoothstep(.65,1.,cloud_cover)*.92);
		density*=smoothstep(.015,.12,d.y);
		float edge=clouds(uv+sun_direction.xz*.008)-c;
		vec3 rim=mix(vec3(.75,.78,.76),vec3(1.,.63,.31),pow(sun,3.)*.8);
		vec3 cloud_col=mix(vec3(.10,.14,.19),rim,clamp(.45+edge*12.,0.,1.));
		cloud_col=mix(cloud_col,vec3(.08,.11,.15)*(1.+c*.4),smoothstep(.55,1.,cloud_cover));
		cloud_col=mix(cloud_col*vec3(.08,.13,.23),cloud_col,day);
		col=mix(col,cloud_col,density*.93);
	}
	if(d.y<0.) col=mix(col,vec3(.04,.12,.15),smoothstep(0.,.12,-d.y));
	col=mix(col,col*vec3(.25,.33,.43),cloud_cover*.78)+vec3(.65,.76,1.)*lightning*.5;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	COLOR=pow(max(col,vec3(0.)),vec3(1./2.2));
#else
	COLOR=col;
#endif
}
