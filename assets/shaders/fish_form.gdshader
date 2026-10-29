shader_type spatial;
render_mode cull_disabled;
// Procedural fish (scripts/creatures/fish_forms.gd). Vertex colours carry the paint job (back, belly,
// pattern); the shader adds what reads at hand distance: overlapping scales, the lateral line, the gill
// cover, a silver-blue sheen that shifts with the view, and darker fin edges.
// Tail wag: per-instance phase from MultiMesh custom data (schools) or TIME when `use_time` is on (single fish).
uniform float wag=.16;
uniform float tail_from=-.05;
uniform float tail_reach=.55;
uniform bool use_time=false;
uniform float time_speed=7.;
uniform float gloss=.28;
uniform float shimmer=.35;
uniform float scale_size=.028;   // scale spacing in body lengths (0 = smooth skin: sharks, rays, sunfish)
varying vec3 body;
void vertex(){
	body=VERTEX;
	float phase=(use_time?TIME*time_speed:INSTANCE_CUSTOM.x)+VERTEX.x*4.5;
	float tail=clamp((tail_from-VERTEX.x)/tail_reach,0.,1.);
	VERTEX.z+=sin(phase)*tail*tail*wag*.5;
	// A slight sway of the whole body keeps big, slow fish alive.
	VERTEX.z+=sin(phase-1.2)*(1.-clamp(abs(VERTEX.x)*2.,0.,1.))*.012;
}
void fragment(){
	vec3 col=COLOR.rgb;
	vec3 p=body;
	// On the body proper (not the thin fins or the tail fan).
	float on_body=step(-.42,p.x)*step(p.x,.44)*smoothstep(.0,.008,abs(p.z));
	if(scale_size>0.){
		// Overlapping scales: rows of arcs opening towards the tail, offset every other row.
		vec2 g=vec2(p.x,p.y)/scale_size;
		float row=floor(g.y);
		vec2 c=vec2(fract(g.x+mod(row,2.)*.5),fract(g.y));
		float arc=length(vec2(c.x-.0,c.y-.5)*vec2(1.,1.2));
		float edge=smoothstep(.42,.5,arc)*(1.-smoothstep(.5,.62,arc));
		col*=1.-edge*.16*on_body*(1.-smoothstep(.2,.43,p.x));
	}
	// Lateral line: a fine dark line from the gill to the tail, following the back's curve.
	float lat=1.-smoothstep(.0,.006,abs(p.y-(.05-.06*p.x*p.x)));
	col=mix(col,col*.55,lat*on_body*step(-.4,p.x)*step(p.x,.3)*.7);
	// Gill cover: an arc behind the eye.
	float gill=1.-smoothstep(.0,.008,abs(length(vec2(p.x-.46,p.y*1.2))-.16));
	col=mix(col,col*.5,gill*on_body*step(p.x,.36)*.8);
	// Fins and tail: fine rays (radiating from the tail root on the tail fan, upright on the other fins)
	// and a darker edge.
	float fin=1.-on_body;
	float rays=p.x<-.42?sin(atan(p.y,p.x+.42)*70.):sin(p.x*190.);
	col*=1.-fin*(.12+smoothstep(.55,1.,rays)*.22);
	ALBEDO=col;
	ROUGHNESS=gloss;METALLIC=.12+on_body*.1;
	float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.);
	float rim=pow(1.-facing,2.);
	// Sheen: a cool blue-green tint that slides over the flank as the fish turns.
	vec3 sheen=mix(vec3(.55,.8,.95),vec3(.75,.95,.75),sin(p.x*18.+facing*6.)*.5+.5);
	EMISSION=(COLOR.rgb*rim*shimmer*.25+sheen*pow(facing,6.)*.06*on_body);
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
