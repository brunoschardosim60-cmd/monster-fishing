shader_type spatial;
render_mode cull_disabled;
// Scaled skin for turtle flippers, head and neck: dark polygonal scales with pale edges (Voronoi on local position).
uniform vec3 scale_color:source_color=vec3(.24,.22,.17);
uniform vec3 edge_color:source_color=vec3(.78,.74,.6);
uniform float scale_size=9.;
varying vec3 lp;
void vertex(){lp=VERTEX;}
vec2 h2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
void fragment(){
	vec2 p=(lp.xz+lp.y*.7)*scale_size;vec2 g=floor(p);vec2 f=fract(p);
	float d1=8.;float d2=8.;
	for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec2 o=vec2(float(x),float(y));vec2 c=o+h2(g+o)-f;float d=dot(c,c);
		if(d<d1){d2=d1;d1=d;}else if(d<d2){d2=d;}
	}
	float edge=1.-smoothstep(.0,.12,sqrt(d2)-sqrt(d1));
	ALBEDO=mix(scale_color,edge_color,edge*.75);ROUGHNESS=.55;
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
