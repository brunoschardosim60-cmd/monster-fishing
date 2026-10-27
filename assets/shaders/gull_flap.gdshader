shader_type spatial;
render_mode cull_disabled;
// Gulls over a school: transforms come from the script; here only the wings move.
// INSTANCE_CUSTOM: r = wing beat (0 glide .. 1 full flap), g = phase, b = folded (1 = wings swept back in a plunge).
// Vertex alpha marks the wing (1 body, 0 tip).
void vertex(){
	vec4 c=INSTANCE_CUSTOM;
	float limb=1.-COLOR.a;
	VERTEX.y+=sin(TIME*10.+c.g)*limb*.6*c.r+sin(TIME*1.7+c.g)*limb*.05;
	VERTEX.z*=mix(1.,.28,c.b*limb);
	VERTEX.x-=c.b*limb*.35;
}
void fragment(){
	if(!FRONT_FACING)NORMAL=-NORMAL;
	ALBEDO=COLOR.rgb;
	EMISSION=COLOR.rgb*.45;
	ROUGHNESS=.85;
}
