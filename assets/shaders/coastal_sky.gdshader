shader_type sky;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction=vec3(.47,.34,-.81);
uniform vec3 moon_direction=vec3(-.47,-.34,.81);
uniform float cloud_cover=.32;
uniform float weather_time=0.;
uniform float lightning=0.;
float clouds(vec2 p) {
	return texture(cloud_noise,p).r*.52+texture(cloud_noise,p*2.13).r*.24+texture(cloud_noise,p*4.07).r*.13+texture(cloud_noise,p*8.1).r*.07+texture(cloud_noise,p*16.3).r*.04;
}
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void sky() {
	vec3 d=normalize(EYEDIR);
	float h=max(d.y,0.);
	vec3 col=mix(vec3(.45,.62,.75),vec3(.025,.13,.36),pow(h,.42));
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
		// Integrate a shallow cloud layer; shifted samples give soft, lit volume.
		float transmission=1.;vec3 scattered=vec3(0.);
		vec3 warm=mix(vec3(1.12,1.16,1.13),vec3(1.45,.87,.43),pow(sun,4.)*(1.-smoothstep(.1,.6,sun_direction.y)));
		for(int i=0;i<6;i++){
			float layer=(float(i)+.5)/6.;
			vec2 uv=d.xz/(d.y+.12)*(.052+layer*.005)+vec2(.21,.37)+weather_time*vec2(.00012,.00005);
			float c=clouds(uv);
			float profile=sin(layer*3.141593)*.075;
			float density=smoothstep(mix(.64,.27,cloud_cover)-profile,mix(.76,.43,cloud_cover),c);
			density=mix(density,.85,smoothstep(.65,1.,cloud_cover));
			float lighting=clamp(.58+(clouds(uv+sun_direction.xz*.009)-c)*14.+layer*.15,0.,1.);
			vec3 cloud_col=mix(vec3(.18,.24,.30),warm,lighting);
			cloud_col=mix(cloud_col,vec3(.10,.14,.19)*(1.+lighting*.7),smoothstep(.55,1.,cloud_cover));
			cloud_col*=mix(vec3(.07,.11,.20),vec3(1.),day);
			float opacity=(1.-exp(-density*.8))*smoothstep(.015,.14,d.y);
			scattered+=transmission*opacity*cloud_col;transmission*=1.-opacity;
		}
		col=col*transmission+scattered;
	}
	if(d.y<0.) col=mix(col,vec3(.04,.12,.15),smoothstep(0.,.12,-d.y));
	col=mix(col,col*vec3(.25,.33,.43),cloud_cover*.78)+vec3(.65,.76,1.)*lightning*.5;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	COLOR=pow(max(col,vec3(0.)),vec3(1./2.2));
#else
	COLOR=col;
#endif
}
