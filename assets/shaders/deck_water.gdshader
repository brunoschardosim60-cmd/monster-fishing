shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, shadows_disabled;
// Water lying on deck (deck_wash.gd): a level sheet that sloshes with the hull; the deck hides it where
// the planks stand higher, so it only shows in the low side. Ripples run across it, foam gathers at the
// edges and streaks towards the scuppers.
uniform float amount=0.;      // 0 dry … 1 swamped
uniform float stir=0.;        // how hard it is moving (hull motion, water coming in)
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 x){vec2 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
varying vec2 local;
void vertex(){
	local=VERTEX.xz;
	// A low travelling slosh across the sheet.
	VERTEX.y+=sin(VERTEX.x*2.6+TIME*(2.2+stir*3.))*.012*(1.+stir*3.)+sin(VERTEX.z*1.7-TIME*1.6)*.008;
}
void fragment(){
	vec2 p=local*vec2(3.,2.);
	float t=TIME*(1.+stir*2.);
	float n1=noise(p*2.+vec2(t*.9,-t*.6));
	float n2=noise(p*5.3-vec2(t*1.4,t*.3));
	vec3 nrm=normalize(vec3((n1-.5)*.7+(n2-.5)*.35,1.,(n2-.5)*.7));
	NORMAL=normalize((VIEW_MATRIX*vec4(nrm,0.)).xyz);
	// Edges of the sheet (UV 0..1): foam where the water meets the bulwarks.
	vec2 e=min(UV,1.-UV);
	float edge=1.-smoothstep(0.,.08,min(e.x,e.y));
	float foam=clamp(edge*(.6+n2)+smoothstep(.6,.9,n1)*(.45+stir*.7)+smoothstep(.75,.95,n2)*.3,0.,1.);
	ALBEDO=mix(vec3(.2,.44,.48),vec3(.88,.93,.92),foam*.85);
	ROUGHNESS=mix(.04,.5,foam);
	SPECULAR=.9;
	METALLIC=.05;
	float fade=smoothstep(0.,.03,min(e.x,e.y));
	ALPHA=clamp((.55+amount*.35)*fade+foam*.35,0.,.95)*smoothstep(0.,.03,amount);
}
