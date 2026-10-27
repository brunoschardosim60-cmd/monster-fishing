shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Curtain of rain hanging under a storm cell: fine slanted streaks falling fast, densest in the middle
// height, fading at the sea and at the cloud base. Seen from outside it greys the horizon.
instance uniform float intensity = 0.;
uniform float light = 1.;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 uv=vec2(UV.x*700.,UV.y*12.+TIME*2.6);
	float col_id=floor(uv.x);float h=hash(vec2(col_id,3.));
	float streak=smoothstep(.75,1.,fract(uv.y+h*7.))*step(.45,h);
	float veil=.18+.25*hash(vec2(floor(UV.x*60.),floor(UV.y*4.+TIME*.3)));
	float fade=smoothstep(0.,.25,UV.y)*smoothstep(1.,.75,UV.y);
	ALBEDO=vec3(.55,.6,.66)*light;
	// From outside the curtain reads as a grey veil hanging under the cloud.
	float far=smoothstep(150.,900.,length(VERTEX));
	// Soft silhouette: the curtain thins where it turns away from the eye, so it never shows a hard edge.
	float facing=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),.9);
	float ragged=.6+.4*hash(vec2(floor(UV.x*24.),3.));
	// The curtain is only for the near view inside the cell; the far wall dissolves instead of drawing
	// a hard-edged cylinder on the sea.
	float near=1.-smoothstep(120.,420.,length(VERTEX));
	ALPHA=clamp(intensity*fade*facing*ragged*(veil*.55+streak*.35)*near,0.,.6);
}
