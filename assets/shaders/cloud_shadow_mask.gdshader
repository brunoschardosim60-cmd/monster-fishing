shader_type canvas_item;
// One period (1/.0014 m) of the cloud-shadow pattern of cloud_shadow.gdshaderinc, for cloud_shadow_decal.gd.
// Black, alpha = shadow. The pattern repeats exactly, so tiles of it can follow the drifting clouds.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float cover = .32;
void fragment(){
	vec2 uv=UV;
	float c=texture(noise_tex,uv).r*.62+texture(noise_tex,uv*2.+vec2(.31,.17)).r*.38;
	c=(c-.5)*1.9+.5;
	float dense=smoothstep(mix(.62,.34,cover),mix(.72,.46,cover),c);
	COLOR=vec4(0.,0.,0.,dense*.42);
}
