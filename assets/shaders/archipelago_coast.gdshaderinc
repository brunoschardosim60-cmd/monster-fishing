const vec4 ISLANDS[8]=vec4[8](vec4(0,230,220,230),vec4(-140,105,95,115),vec4(150,110,100,130),vec4(-65,540,330,480),vec4(-690,-510,220,260),vec4(790,-640,250,320),vec4(20,-1340,330,300),vec4(-110,-18,30,29));
vec4 coast_data(vec2 p) {
	float nearest=10000.;float second=10000.;vec2 normal=vec2(0,-1);
	for(int i=0;i<8;i++){
		vec4 l=ISLANDS[i];vec2 q=(p-l.xy)/l.zw;
		float angle=atan(q.y,q.x);
		float edge=1.+sin(angle*3.+float(i)*1.7)*.055+cos(angle*7.)*.025;
		float dist=(length(q)-edge)*min(l.z,l.w);
		if(dist<nearest){if(i>=4&&i!=7){second=nearest;}nearest=dist;normal=normalize(q/l.zw+vec2(.000001));}
		else if(i>=4&&i!=7&&dist<second){second=dist;}
	}
	return vec4(nearest,normal,second);
}
