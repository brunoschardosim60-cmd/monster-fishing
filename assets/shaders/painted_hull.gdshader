shader_type spatial;
render_mode cull_disabled;
// Painted wooden hull (vessel_models.gd): the vertex colour is the paint (antifouling, topsides, stripe,
// deck); on top of it the shader draws what makes a boat read as built rather than moulded: planks
// (strakes along the sides, deck planks fore-and-aft with caulked seams and butt joints), wood grain
// showing through worn paint, scuffed edges at the rail, a grime line at the waterline and weed below.
uniform float strake=.17;        // plank width on the sides (m)
uniform float deck_plank=.11;    // plank width on deck (m)
uniform float wear=.55;          // how worn the paint is (0 new … 1 old)
uniform vec3 wood_tint:source_color=vec3(.55,.38,.22);
// Livery (the boatyard's colours): vertex alpha 1 takes livery_hull, .5 takes livery_top, 0 stays as painted.
// White by default, so models without a livery look as modelled.
instance uniform vec3 livery_hull:source_color=vec3(1.);
instance uniform vec3 livery_top:source_color=vec3(1.);
varying vec3 mpos;
varying vec3 mnrm;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 x){vec2 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*noise(p);p*=2.03;a*=.5;}return v;}
void vertex(){mpos=VERTEX;mnrm=NORMAL;}
void fragment(){
	vec3 paint=COLOR.rgb;
	if(COLOR.a>.75)paint*=livery_hull;else if(COLOR.a>.25)paint*=livery_top;
	bool deck=abs(mnrm.y)>.75;
	// Plank coordinate across the planks (v) and along them (u).
	float v=deck?mpos.x/deck_plank:mpos.y/strake+abs(mpos.x)*.6;
	float u=mpos.z;
	float row=floor(v);
	float fv=fract(v);
	// Seams between planks, and staggered butt joints along each plank.
	float seam=1.-smoothstep(0.,.07,min(fv,1.-fv));
	float butt_at=fract(u/(deck?2.4:3.1)+hash(vec2(row,7.))*.9);
	float butt=1.-smoothstep(0.,.012,min(butt_at,1.-butt_at)*(deck?2.4:3.1));
	// Grain running along the plank, varying per plank.
	float grain=fbm(vec2(u*1.5,v*9.+row*3.1));
	float plank_shade=(hash(vec2(row,1.3))-.5)*.10;
	// Paint wears through at the rail and along the seams; more where the noise says so.
	float chip=smoothstep(.62,.8,fbm(mpos.xz*3.+mpos.yy*5.)+seam*.25)*wear;
	vec3 wood=wood_tint*(.75+grain*.5);
	vec3 col=paint*(1.+plank_shade)*(.92+grain*.16);
	if(!deck)col=mix(col,wood,chip*.8);
	else col=mix(col,col*vec3(.92,.88,.82),grain*.4);
	// Caulking: dark seams; on deck black pitch lines, on the sides fine shadow lines.
	col*=1.-seam*(deck?.55:.28)-butt*.25;
	// Grime and weed: a dirty band just above the waterline and green-brown below it.
	float wl=mpos.y;
	col=mix(col,col*vec3(.62,.6,.5),(1.-smoothstep(.0,.22,wl))*step(-.02,wl)*.6*(deck?0.:1.));
	col=mix(col,vec3(.18,.22,.12),smoothstep(.0,-.25,wl)*fbm(mpos.xz*2.)*.55*(deck?0.:1.));
	ALBEDO=col;
	ROUGHNESS=mix(.48,.85,chip+seam*.4)+(deck?.15:0.);
	SPECULAR=.35;
	NORMAL_MAP=vec3(.5+(grain-.5)*.15,.5-seam*.25,1.);
	NORMAL_MAP_DEPTH=.7;
}
