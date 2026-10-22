const vec4 ISLANDS[7]=vec4[7](vec4(0,230,220,230),vec4(-140,105,95,115),vec4(150,110,100,130),vec4(-65,400,145,155),vec4(-690,-510,105,145),vec4(790,-640,180,220),vec4(20,-1340,230,190));
vec4 coast_data(vec2 p) {
	float nearest=10000.;float second=10000.;vec2 normal=vec2(0,-1);
	for(int i=0;i<7;i++){
		vec4 l=ISLANDS[i];vec2 q=(p-l.xy)/l.zw;
		float angle=atan(q.y,q.x);
		float edge=1.+sin(angle*3.+float(i)*1.7)*.055+cos(angle*7.)*.025;
		float dist=(length(q)-edge)*min(l.z,l.w);
		if(dist<nearest){if(i>=4){second=nearest;}nearest=dist;normal=normalize(q/l.zw+vec2(.000001));}
		else if(i>=4&&dist<second){second=dist;}
	}
	return vec4(nearest,normal,second);
}
