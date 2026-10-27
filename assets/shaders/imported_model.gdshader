shader_type spatial;
render_mode cull_disabled;
// Paint for the imported (untextured) ship and creature meshes. Every vertex carries its base colour in
// COLOR.rgb (sRGB) and a pattern id in COLOR.a (id/15). The pattern is drawn here in object space, in
// metres, so it stays crisp at any distance and needs no UVs:
//   0 plain · 1 steel hull (antifouling below the waterline, boot-top, plate seams, rust streaks)
//   2 containers (one colour per box, corrugation) · 3 superstructure (rows of windows, lit at night)
//   4 planks · 5 sailcloth · 6 painted deck · 7 rope / dark metal · 8 lamp glass · 9 wet skin
//   10 scales (serpent) · 11 weathered paint over wood · 12 galleon side (gun stripe)
instance uniform float model_scale = 1.;      // metres per mesh unit
instance uniform float night = 0.;            // 0 day … 1 night: windows and lamps light up
uniform float wear = .5;
// Creatures: the upper body sways and can lunge forward (-Z); weight grows with height in mesh units.
instance uniform float sway = 0.;
instance uniform float lunge = 0.;
uniform float sway_from = .3;
// Turtles: flippers (|x| beyond the shell) beat up and down; the front pair leads.
instance uniform float flap = 0.;
// Wrecks on the sea floor: algae, silt and rust over everything.
instance uniform float wreck = 0.;
instance uniform float flap_rate = 1.6;             // grime and rust
instance uniform vec3 hull_paint : source_color = vec3(.12,.2,.32);
instance uniform float seed = 0.;
varying vec3 p;      // object space, metres
varying vec3 n;      // object space normal
varying vec4 col;

float hash(vec3 q){ q=fract(q*vec3(.1031,.1030,.0973)+seed*.137); q+=dot(q,q.yxz+33.33); return fract((q.x+q.y)*q.z); }
float hash2(vec2 q){ return fract(sin(dot(q,vec2(127.1,311.7))+seed)*43758.5453); }
float vnoise(vec2 x){ vec2 i=floor(x),f=fract(x); f=f*f*(3.-2.*f);
	return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y); }
float fbm(vec2 x){ float a=.5,s=0.; for(int i=0;i<4;i++){ s+=a*vnoise(x); x*=2.03; a*=.5; } return s; }
vec3 srgb(vec3 c){ return pow(c,vec3(2.2)); }

void vertex(){
	p=VERTEX*model_scale; n=NORMAL; col=COLOR;
	if(sway>0. || lunge>0.){
		float w=smoothstep(sway_from,.95,VERTEX.y); w*=w;
		VERTEX.x+=sin(TIME*1.1+VERTEX.y*5.)*sway*w*.06;
		VERTEX.z+=cos(TIME*.8+VERTEX.y*3.)*sway*w*.03-lunge*w*.32;
		VERTEX.y-=lunge*w*.16;
	}
	if(flap>0.){
		float ax=abs(VERTEX.x);
		float w=smoothstep(.15,.34,ax);
		float front=step(VERTEX.z,-.02);
		float beat=sin(TIME*flap_rate+front*1.6+seed);
		VERTEX.y+=beat*w*(ax-.12)*flap*mix(.45,1.,front);
		VERTEX.z+=cos(TIME*flap_rate+front*1.6+seed)*w*(ax-.12)*flap*.35*front;
	}
}

void fragment(){
	if(!FRONT_FACING) NORMAL=-NORMAL;
	int id=int(round(col.a*15.));
	vec3 base=srgb(col.rgb);
	vec3 an=abs(n);
	float rough=.75; float metal=0.; vec3 emit=vec3(0.);
	float grime=fbm(p.xz*.35+p.y*.2);
	vec3 c=base;
	if(id==1){
		// Hull: paint above, antifouling red below the waterline, a dark boot-top band at the waterline.
		c=hull_paint;
		if(p.y<-.12) c=srgb(vec3(.52,.13,.09));
		else if(p.y<.45) c=srgb(vec3(.08,.08,.085));
		float seam=step(.94,fract(p.y/2.2))*.12+step(.985,fract((p.z+p.x)/6.))*.08;
		c*=1.-seam;
		float streak=smoothstep(.55,.9,vnoise(vec2((p.z+p.x)*1.7,p.y*.07)))*smoothstep(.3,3.,p.y);
		c=mix(c,srgb(vec3(.42,.2,.08)),streak*wear*.6);
		c*=.85+.3*grime;
		rough=.55; metal=.15;
	}else if(id==2){
		// Containers: 2.44 m wide, 2.6 m high, 6.1 m long boxes, each a colour of its own.
		vec3 cell=floor(vec3(p.x/2.44,p.y/2.6,p.z/6.1));
		float h=hash(cell);
		vec3 pal[8]=vec3[](vec3(.08,.27,.55),vec3(.62,.12,.1),vec3(.78,.42,.1),vec3(.15,.4,.25),vec3(.55,.55,.53),vec3(.85,.85,.82),vec3(.72,.6,.15),vec3(.35,.18,.12));
		c=srgb(pal[int(h*7.99)]);
		vec3 f=fract(vec3(p.x/2.44,p.y/2.6,p.z/6.1));
		float edge=0.;
		edge=max(edge,step(f.y,.04)+step(.97,f.y));
		edge=max(edge,(step(f.z,.015)+step(.985,f.z))*(1.-an.z));
		edge=max(edge,(step(f.x,.02)+step(.98,f.x))*an.z);
		float corr=.5+.5*sin((an.x>an.z? p.z: p.x)*24.);
		c*=(1.-edge*.45)*(.9+corr*.12)*(.82+.3*grime);
		rough=.6; metal=.2;
	}else if(id==3){
		// Superstructure: white decks with rows of windows on the walls.
		c=base*(.9+.15*grime);
		if(an.y<.35){
			vec2 w=vec2(an.x>an.z? p.z: p.x,p.y);
			vec2 cellw=vec2(1.7,2.8);vec2 f=fract(w/cellw);vec2 id2=floor(w/cellw);
			float win=step(.25,f.x)*step(f.x,.75)*step(.45,f.y)*step(f.y,.78);
			if(win>.5){
				c=srgb(vec3(.06,.09,.12));rough=.08;metal=.4;
				float lit=step(.35,hash(vec3(id2,3.)));
				emit=srgb(vec3(1.,.78,.45))*lit*night*1.6;
			}
		}
	}else if(id==4){
		// Planks: decks run fore and aft, hull planks run along the side.
		float along=an.y>.6? p.x: p.y;
		float w=an.y>.6? .22: .26;
		float row=floor(along/w);
		float joint=floor((p.z+hash2(vec2(row,1.))*7.)/4.5);
		float tone=hash2(vec2(row,joint));
		c=base*(.78+.38*tone)*(.85+.3*fbm(vec2(p.z*3.,along*12.)));
		c*=1.-step(.9,fract(along/w))*.45;
		rough=.85;
	}else if(id==5){
		// Sailcloth in vertical cloths, weathered towards the foot.
		float across=an.z>an.x? p.x: p.z;
		float seam=step(.93,fract(across/.9));
		c=base*(1.-seam*.12)*(.9+.12*vnoise(p.xy*.7+p.z));
		c=mix(c,c*.8,grime*.25*wear);
		rough=.92;
		BACKLIGHT=c*.55;
	}else if(id==6){
		c=base*(.82+.3*grime);
		float hatch=step(.97,fract(p.z/12.))+step(.985,fract(p.x/4.));
		c*=1.-min(hatch,1.)*.3;
		rough=.7; metal=.1;
	}else if(id==7){
		c=base*(.8+.3*grime); rough=.6; metal=.35;
	}else if(id==8){
		c=base; emit=base*(.15+night*2.2); rough=.1;
	}else if(id==9){
		c=base*(.88+.22*vnoise(p.xz*1.3+p.y*.9));
		rough=.32; metal=0.;
	}else if(id==10){
		// Serpent scales: rows of overlapping plates with darker edges, glossy and wet.
		vec2 q=vec2(dot(p,vec3(.71,0.,.71)),p.y)*1.4;
		q.x+=.5*floor(q.y);
		vec2 f=fract(q)-.5;
		float plate=1.-smoothstep(.25,.5,length(f*vec2(1.,1.4)));
		c=base*(.7+.45*plate)*(.85+.3*vnoise(p.xz*.2+p.y*.1));
		rough=.28;
	}else if(id==12){
		// Galleon side: dark planking, an ochre band along the gun deck, tarred bottom below the water.
		float y=p.y/model_scale;
		vec3 paint=base;
		if(y>.029 && y<.049) paint=srgb(vec3(.79,.6,.24));
		if(y<.0) paint=srgb(vec3(.24,.17,.12));
		float row=floor(p.y/.26);
		float joint=floor((p.z+hash2(vec2(row,1.))*7.)/4.5);
		c=paint*(.8+.32*hash2(vec2(row,joint)))*(1.-step(.9,fract(p.y/.26))*.4)*(.85+.3*grime);
		rough=.8;
	}else if(id==11){
		// Weathered paint over planks: flaking patches show the grey wood underneath.
		float along=an.y>.6? p.x: p.y;
		float row=floor(along/.2);
		float flake=smoothstep(.55,.62,fbm(p.xz*2.2+p.y*3.)+hash2(vec2(row,2.))*.15);
		vec3 paint=p.y<-.03? base: hull_paint;
		c=mix(paint,srgb(vec3(.42,.36,.28)),flake*wear);
		c*=(.85+.25*fbm(vec2(p.z*4.,along*14.)))*(1.-step(.92,fract(along/.2))*.35);
		rough=.88;
	}else{
		c=base*(.85+.3*grime);
	}
	if(wreck>0.){
		float algae=smoothstep(.35,.75,fbm(p.xz*.6+p.y*.3))*smoothstep(-.3,.7,n.y);
		c=mix(c*.45,srgb(vec3(.2,.27,.14)),algae*.8*wreck);
		c=mix(c,srgb(vec3(.33,.2,.1)),smoothstep(.6,.8,vnoise(p.xy*1.3))*.4*wreck);
		rough=.95;metal=0.;emit=vec3(0.);
	}
	ALBEDO=c; ROUGHNESS=rough; METALLIC=metal; EMISSION=emit;
}
