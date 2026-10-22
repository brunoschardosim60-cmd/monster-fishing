shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color,filter_linear_mipmap_anisotropic;
uniform bool textured=false;
uniform vec4 tint : source_color=vec4(1.);
uniform vec3 glow_color : source_color=vec3(0.);
uniform bool guardian=false;
uniform bool fin_membrane=false;
uniform float swim_speed=1.;
uniform float swim_phase=0.;
uniform float swim_amount=1.;
uniform bool controlled=false;
void vertex(){
	float tail=clamp((.3-VERTEX.x)/1.1,0.,1.);
	if(guardian){
		float wing=clamp(abs(VERTEX.z)/9.,0.,1.);
		VERTEX.y+=sin(TIME*.85-abs(VERTEX.z)*.3)*wing*wing*1.1;
		VERTEX.z+=sin(TIME*.65+VERTEX.x*.45)*clamp(-VERTEX.x-2.,0.,9.)*.12;
	}else{
		float phase=(controlled?swim_phase:TIME*6.*swim_speed)+VERTEX.x*5.;
		float amplitude=tail*tail*.075*swim_amount;
		float slope=cos(phase)*5.*amplitude-sin(phase)*tail*.13636*swim_amount;
		VERTEX.z+=sin(phase)*amplitude;
		NORMAL=normalize(vec3(NORMAL.x-slope*NORMAL.z,NORMAL.y,NORMAL.z));
	}
}
void fragment(){
	ALBEDO=tint.rgb*(textured?texture(albedo_tex,UV).rgb:vec3(1.));
	ROUGHNESS=.28;METALLIC=guardian?.08:.22;EMISSION=glow_color*1.5;
	if(fin_membrane){
		float ray=pow(.5+.5*cos(UV.x*113.1),12.);
		ALBEDO=mix(vec3(.06,.085,.09),vec3(.29,.31,.26),ray*.65+UV.y*.25);
		ROUGHNESS=.42;METALLIC=.15;
	}
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
