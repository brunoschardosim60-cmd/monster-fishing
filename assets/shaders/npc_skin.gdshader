shader_type spatial;
// Recolours the shared survivalist atlas per NPC. The atlas is a scrambled patch map, so regions come from
// zone_tex (baked by scripts/pipeline/bake_skin_zone.gd): R = head/neck/hands, G = head only.
// Outside the zone: clothing is recoloured. Inside it: skin texels get skin_mul, the rest of the head gets hair_mul.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D zone_tex : filter_linear_mipmap, repeat_enable;
uniform float cloth_hue=0.;
uniform float cloth_sat_mul=1.;
uniform float cloth_sat_add=0.;
uniform float cloth_val_mul=1.;
uniform vec3 skin_mul=vec3(1.);
uniform vec3 hair_mul=vec3(1.);
vec3 rgb2hsv(vec3 c){
	vec4 K=vec4(0.,-1./3.,2./3.,-1.);
	vec4 p=mix(vec4(c.bg,K.wz),vec4(c.gb,K.xy),step(c.b,c.g));
	vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
	float d=q.x-min(q.w,q.y);
	return vec3(abs(q.z+(q.w-q.y)/(6.*d+1e-10)),d/(q.x+1e-10),q.x);
}
vec3 hsv2rgb(vec3 c){
	vec4 K=vec4(1.,2./3.,1./3.,3.);
	vec3 p=abs(fract(c.xxx+K.xyz)*6.-K.www);
	return c.z*mix(K.xxx,clamp(p-K.xxx,0.,1.),c.y);
}
void fragment(){
	vec3 base=pow(texture(albedo_tex,UV).rgb,vec3(1./2.2));
	vec2 zone=texture(zone_tex,UV).rg;
	vec3 hsv=rgb2hsv(base);
	float hd=min(hsv.x,1.-hsv.x);
	float warm=(1.-smoothstep(.10,.16,hd))*smoothstep(.06,.12,hsv.y);
	// Colour lifting fades out for very dark texels, so boots, belts and shadows stay dark.
	float gate=smoothstep(.16,.40,hsv.z);
	vec3 cloth=hsv2rgb(vec3(fract(hsv.x+cloth_hue),clamp(hsv.y*cloth_sat_mul+cloth_sat_add*(1.-hsv.y)*gate,0.,1.),clamp(hsv.z*mix(1.,cloth_val_mul,gate),0.,1.)));
	vec3 head_other=mix(base,clamp(base*hair_mul,0.,1.),zone.g);
	vec3 in_zone=mix(head_other,clamp(base*skin_mul,0.,1.),warm);
	vec3 result=mix(cloth,in_zone,zone.r);
	ALBEDO=pow(result,vec3(2.2));
	ROUGHNESS=.9;
	METALLIC=0.;
}
