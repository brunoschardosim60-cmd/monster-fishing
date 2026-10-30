shader_type spatial;
render_mode cull_disabled;
// Sailcloth for the Blender-built ships (ship_models.gd): canvas panels sewn in vertical cloths with
// darker seams, a few patches and stains, light glowing through when the sun is behind, and a gentle
// flutter in the wind. The model has no UVs: panels are laid out in model space.
uniform vec3 cloth:source_color=vec3(.93,.89,.78);
uniform float panel=.75;          // width of one cloth (m)
uniform float flutter=1.;
varying vec3 mp;
varying vec3 mn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 x){vec2 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
	mp=VERTEX;mn=NORMAL;
	// Ripples run across the cloth, strongest away from the edges where it is lashed.
	float w=sin(VERTEX.z*1.6+TIME*3.1+VERTEX.x*.7)*.03+sin(VERTEX.z*3.7-TIME*4.3)*.012;
	VERTEX+=NORMAL*w*flutter;
}
void fragment(){
	// Across-sail coordinate: whichever horizontal axis the sail spans more of.
	// A square sail spans across the ship (x); a fore-and-aft sail spans along it (z).
	float across=abs(mn.z)>abs(mn.x)?mp.x:mp.z;
	float u=across/panel;
	float seam=1.-smoothstep(.0,.035,min(fract(u),1.-fract(u)));
	float row=floor(mp.y/1.6);
	float band=1.-smoothstep(.0,.025,abs(fract(mp.y/1.6)-.5)-.47);
	vec3 col=cloth*(.92+.1*noise(vec2(u*1.3,mp.y*.4)));
	// Patches: a few darker squares stitched on.
	vec2 cell=vec2(floor(u*.5),floor(mp.y/1.1));
	float patch=step(.86,hash(cell));
	vec2 fp=fract(vec2(u*.5,mp.y/1.1));
	float inside=step(.18,fp.x)*step(fp.x,.82)*step(.2,fp.y)*step(fp.y,.8);
	col=mix(col,cloth*vec3(.86,.82,.72),patch*inside*.6);
	// Weather stains towards the foot.
	col*=1.-.06*smoothstep(.5,1.,noise(mp.xz*.6+mp.y*.3));
	col*=1.-seam*.22-band*.12;
	ALBEDO=col;
	ROUGHNESS=.92;
	BACKLIGHT=vec3(.55,.5,.4);
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
