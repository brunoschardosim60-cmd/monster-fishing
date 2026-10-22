extends RefCounted
static var cache: Dictionary = {}
static func surface(kind: String, tint: Color = Color.WHITE, scale_value: float = 1.0, world_space: bool = true) -> StandardMaterial3D:
	var key := kind + tint.to_html() + str(scale_value) + str(world_space)
	if cache.has(key): return cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = load("res://assets/textures/%s_color.png" % kind)
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/%s_normal.png" % kind)
	mat.normal_scale = 0.65
	mat.roughness_texture = load("res://assets/textures/%s_rough.png" % kind)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world_space
	mat.uv1_scale = Vector3.ONE * scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = mat
	return mat
