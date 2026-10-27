shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Dark cloud deck of a storm cell (storms.gd): a unit cylinder scaled to the cell, churning slowly,
// thinning out at the rim. `intensity` fades the whole cell in and out.
instance uniform float intensity = 0.;
varying vec3 lp;
float hash(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 x){vec3 i=floor(x);vec3 f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){ lp=VERTEX; }
void fragment(){
	vec3 q=lp*vec3(5.,2.4,5.)+vec3(TIME*.02,0.,TIME*.013);
	float n=noise(q)*.55+noise(q*2.3)*.3+noise(q*5.1)*.15;
	float r=length(lp.xz);
	// Towering cumulonimbus: billowing bulges on the walls, an anvil spreading at the top, a black base.
	float rim=1.-smoothstep(.75,1.05,r-n*.2);
	float top=smoothstep(.2,.5,lp.y);
	float under=smoothstep(-.2,-.5,lp.y);
	float h=lp.y+.5;
	vec3 col=mix(vec3(.11,.12,.14),vec3(.42,.45,.5),smoothstep(.1,1.,h)*(.6+.4*n));
	col=mix(col,vec3(.05,.055,.065),under);
	ALBEDO=col;
	ALPHA=clamp(intensity*(.7+.3*n)*mix(1.,rim,top*.6),0.,.97);
}
