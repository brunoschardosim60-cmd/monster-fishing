// Cloud shadows for shaders without their own cloud uniforms (foliage, grass): the same noise and drift
// as cloud_shadow.gdshaderinc, fed through global shader parameters by ocean_environment.gd.
global uniform float cloud_g_strength;
global uniform float cloud_g_cover;
global uniform vec2 cloud_g_velocity;
global uniform sampler2D cloud_g_noise : filter_linear_mipmap, repeat_enable;
float cloud_shadow_g(vec2 xz){
	vec2 uv=xz*.0014+TIME*cloud_g_velocity;
	float c=texture(cloud_g_noise,uv).r*.62+texture(cloud_g_noise,uv*2.+vec2(.31,.17)).r*.38;
	c=(c-.5)*1.9+.5;
	return smoothstep(mix(.62,.34,cloud_g_cover),mix(.72,.46,cloud_g_cover),c)*cloud_g_strength;
}
