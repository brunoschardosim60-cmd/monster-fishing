shader_type spatial;
render_mode cull_disabled;
// Birds and land animals move entirely on the GPU: every instance orbits/paces on a circle given by INSTANCE_CUSTOM
// (x radius, y angular speed, z phase, w scale), so hundreds of creatures cost no script time.
// Vertex alpha: 1 = rigid, lower = swinging limb or flapping wing (0 at the tip).
uniform float fly=0.;
uniform float bob=0.;
void vertex(){
	vec4 c=INSTANCE_CUSTOM;
	float a=c.z+TIME*c.y;
	vec3 v=VERTEX*c.w;
	float limb=1.-COLOR.a;
	if(fly>.5){
		v.y+=sin(TIME*9.+c.z*7.)*limb*.55*c.w;
	}else{
		float gait=TIME*(3.+c.y*40.)+c.z*3.;
		float s=sign(VERTEX.x*VERTEX.z+.0001);
		v.x+=sin(gait)*s*limb*.32*c.w;
		v.y+=max(0.,cos(gait)*s)*limb*.06*c.w;
		v.y+=abs(sin(gait))*bob*c.w;
	}
	float phi=-(a+1.5708);
	float cs=cos(phi);float sn=sin(phi);
	vec3 r=vec3(v.x*cs+v.z*sn,v.y,-v.x*sn+v.z*cs);
	if(fly>.5){r.z+=0.;float bank=-.25*sign(c.y);float cb=cos(bank);float sb=sin(bank);r=vec3(r.x,r.y*cb-r.z*sb,r.y*sb+r.z*cb);}
	r+=vec3(cos(a),0.,sin(a))*c.x;
	if(fly>.5)r.y+=sin(a*2.3+c.z)*3.;
	VERTEX=r;
	NORMAL=vec3(NORMAL.x*cs+NORMAL.z*sn,NORMAL.y,-NORMAL.x*sn+NORMAL.z*cs);
}
void fragment(){
	ALBEDO=pow(COLOR.rgb,vec3(2.2));
	ROUGHNESS=.85;
}
