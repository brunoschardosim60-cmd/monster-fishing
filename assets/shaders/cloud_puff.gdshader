shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft billboard puff for storm clouds and rain veils (storms.gd). `veil` turns it into an upright
// (Y-axis) billboard that fades at the sides and towards the sea, for rain hanging under the cloud.
uniform float intensity = 1.;
uniform bool veil = false;
// Daylight on the cloud (unshaded): ~.12 at night so storms do not glow grey in the dark.
uniform float light = 1.;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 x){vec2 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
	vec3 sc=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	if(veil){
		vec3 right=normalize(vec3(INV_VIEW_MATRIX[0].x,0.,INV_VIEW_MATRIX[0].z));
		MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*sc.x,0.),vec4(0.,sc.y,0.,0.),vec4(cross(right,vec3(0,1,0))*sc.z,0.),MODEL_MATRIX[3]);
	}else{
		MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*sc.x,INV_VIEW_MATRIX[1]*sc.y,INV_VIEW_MATRIX[2]*sc.z,MODEL_MATRIX[3]);
	}
	MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
	vec2 uv=UV-.5;
	float n=noise(UV*5.+COLOR.a*13.+TIME*.02)*.6+noise(UV*11.+COLOR.a*7.)*.4;
	float a;
	if(veil){
		// Rain hanging under the cloud: very soft sides, thinning gently towards the sea, falling in
		// slanted, uneven sheets rather than a solid column.
		float side=1.-smoothstep(.0,.5,abs(uv.x+(uv.y+.5)*.08));
		side*=side;
		float sheets=.55+.45*noise(vec2(UV.x*9.+UV.y*1.5,UV.y*1.2+TIME*.35));
		float streaks=.7+.3*noise(vec2(UV.x*60.+UV.y*6.,UV.y*3.+TIME*1.4));
		a=side*smoothstep(.5,.2,uv.y)*smoothstep(-.5,-.05,uv.y)*sheets*streaks;
		ALBEDO=vec3(.42,.47,.53)*light;
		ALPHA=a*intensity*.3;
	}else{
		float d=length(uv)*2.+(n-.5)*.45;
		a=1.-smoothstep(.45,1.,d);
		ALBEDO=COLOR.rgb*(.85+.3*n)*light;
		ALPHA=a*intensity*mix(.55,1.,COLOR.a);
	}
}
