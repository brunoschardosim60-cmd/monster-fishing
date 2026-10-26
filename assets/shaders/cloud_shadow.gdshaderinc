// Moving cloud shadows on land and sea. The same cloud noise as the sky, laid over the world in metres
// and drifting with the wind. Strength peaks with broken cloud and fades under full overcast or at night.
uniform float cloud_shadow_strength=0.;
uniform float cloud_shadow_cover=.32;
uniform vec2 cloud_shadow_velocity=vec2(.006,.0025);
float cloud_shadow(sampler2D tex,vec2 xz){
	vec2 uv=xz*.0014+TIME*cloud_shadow_velocity;
	float c=texture(tex,uv).r*.58+texture(tex,uv*2.17+vec2(.31,.17)).r*.28+texture(tex,uv*4.6+vec2(.7,.2)).r*.14;
	float dense=smoothstep(mix(.62,.3,cloud_shadow_cover),mix(.74,.44,cloud_shadow_cover),c);
	return dense*cloud_shadow_strength;
}
