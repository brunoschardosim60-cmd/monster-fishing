shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft billboard droplet cloud for wind spray (wind_spray.gd). COLOR.a fades the puff over its life.
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 x){vec2 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
// Daylight on the spray (it is unshaded): ~.1 at night, so a storm at night does not fill the air with
// glowing white discs.
uniform float light=1.;
varying float seed;
void vertex(){
	vec3 sc=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	seed=fract(MODEL_MATRIX[3].x*.137+MODEL_MATRIX[3].z*.071);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*sc.x,INV_VIEW_MATRIX[1]*sc.y,INV_VIEW_MATRIX[2]*sc.z,MODEL_MATRIX[3]);
}
void fragment(){
	vec2 uv=UV-.5;
	float n=noise(UV*6.+seed*31.)*.55+noise(UV*17.+seed*13.)*.45;
	float d=length(uv)*2.+(n-.5)*.6;
	float a=(1.-smoothstep(.3,1.,d))*smoothstep(.25,.6,n+.2);
	ALBEDO=COLOR.rgb*vec3(light,light,min(1.,light*1.15));
	ALPHA=a*COLOR.a*.55*mix(.6,1.,light);
}
