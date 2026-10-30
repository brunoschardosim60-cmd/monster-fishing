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
		// Flap-and-glide like a gull: a few seconds of wingbeats (~3 Hz), then a glide on slightly raised
		// wings. The wing turns about the shoulder; the hand bends further than the arm.
		float cycle=fract(TIME*.18+c.z*.37);
		float flapping=1.-smoothstep(.38,.48,cycle)+smoothstep(.95,1.,cycle);
		float beat=sin(TIME*18.8+c.z*7.);
		float th=mix(.12,beat*.75,flapping)*smoothstep(0.,.25,limb)*(1.+.45*limb);
		float az=abs(v.z);
		v.y+=az*sin(th);
		v.z=sign(v.z)*az*cos(th);
		// The body rises and dips a little with each beat.
		v.y-=beat*.03*flapping*c.w;
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
	// Flight paths wander: the circle breathes in and out and the height drifts, so a flock never
	// moves as one rigid ring.
	float rr=c.x*(fly>.5?(1.+.22*sin(a*1.3+c.z*2.)):1.);
	r+=vec3(cos(a),0.,sin(a))*rr;
	if(fly>.5)r.y+=sin(a*2.3+c.z)*3.+sin(TIME*.31+c.z*5.)*2.5;
	VERTEX=r;
	NORMAL=vec3(NORMAL.x*cs+NORMAL.z*sn,NORMAL.y,-NORMAL.x*sn+NORMAL.z*cs);
}
void fragment(){
	// Hand-built meshes may have inward winding; flip normals on back faces so lighting is correct from outside.
	if(!FRONT_FACING)NORMAL=-NORMAL;
	ALBEDO=COLOR.rgb;
	// A little self-light keeps the small animals and birds readable against the bright ground.
	EMISSION=COLOR.rgb*.22;
	ROUGHNESS=.85;
}
