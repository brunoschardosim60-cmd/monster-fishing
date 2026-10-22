shader_type sky;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction=vec3(.47,.34,-.81);
float clouds(vec2 p) {
	return texture(cloud_noise,p).r*.6+texture(cloud_noise,p*2.13).r*.27+texture(cloud_noise,p*4.07).r*.13;
}
void sky() {
	vec3 d=normalize(EYEDIR);
	float h=max(d.y,0.);
	vec3 col=mix(vec3(.28,.43,.51),vec3(.018,.075,.17),pow(h,.45));
	float sun=max(dot(d,normalize(sun_direction)),0.);
	col+=vec3(1.,.48,.14)*pow(sun,10.)*.55;
	col+=vec3(1.,.87,.65)*smoothstep(.9996,.9999,sun)*9.;
	if(d.y>.015) {
		vec2 uv=d.xz/(d.y+.13)*.12+vec2(.21,.37);
		float c=clouds(uv);
		float density=smoothstep(.49,.67,c)*smoothstep(.015,.1,d.y);
		float edge=clouds(uv+sun_direction.xz*.008)-c;
		vec3 rim=mix(vec3(.75,.78,.76),vec3(1.,.63,.31),pow(sun,3.)*.8);
		vec3 cloud_col=mix(vec3(.09,.13,.18),rim,clamp(.4+edge*24.,0.,1.));
		col=mix(col,cloud_col,density*.93);
	}
	if(d.y<0.) col=mix(vec3(.29,.56,.65),vec3(.04,.12,.15),smoothstep(0.,.3,-d.y));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	COLOR=pow(max(col,vec3(0.)),vec3(1./2.2));
#else
	COLOR=col;
#endif
}
