shader_type spatial;
render_mode cull_disabled;
// Ray disc (UV = x / half span, z / half length; UV2.x = +1 top, -1 underside). Stingrays ripple their wing edges in a
// wave running front to back; mantas beat their wings up and down. Top: sandy with dark spots, or black with white
// shoulder patches for a manta; underside white.
uniform bool manta=false;
uniform float span=1.5;
uniform float beat=1.;
uniform float phase=0.;
uniform vec3 top_color:source_color=vec3(.42,.36,.26);
uniform vec3 spot_color:source_color=vec3(.2,.17,.12);
uniform vec3 under_color:source_color=vec3(.93,.92,.88);
varying vec2 disc;
varying float top;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){
	disc=UV;top=UV2.x;
	float x=abs(UV.x);
	if(manta){VERTEX.y+=sin(TIME*1.1*beat+phase)*pow(x,1.8)*span*.22;}
	else{VERTEX.y+=sin(TIME*3.2*beat+phase-UV.y*4.)*pow(x,2.2)*span*.07;}
}
void fragment(){
	vec3 col;
	if(top<0.){col=under_color;}
	else if(manta){
		col=top_color;
		float patch=smoothstep(.35,.2,length(vec2(abs(disc.x)-.32,disc.y+.35)*vec2(1.,1.6)));
		col=mix(col,vec3(.9,.9,.86),patch*.85);
	}else{
		vec2 g=floor(disc*vec2(7.,6.));vec2 f=fract(disc*vec2(7.,6.))-.5;
		float spot=smoothstep(.3,.18,length(f+(vec2(h(g),h(g+3.))-.5)*.5))*step(.45,h(g+7.));
		col=mix(top_color,spot_color,spot*.8);
	}
	ALBEDO=col;ROUGHNESS=.6;
	if(!FRONT_FACING)NORMAL=-NORMAL;
}
