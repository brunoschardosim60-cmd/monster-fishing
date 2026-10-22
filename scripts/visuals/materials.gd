extends RefCounted
static var cache: Dictionary = {}
static func surface(kind: String, tint: Color = Color.WHITE, scale_value: float = 1.0, world_space: bool = true) -> StandardMaterial3D:
	var key := kind + tint.to_html() + str(scale_value) + str(world_space)
	if cache.has(key): return cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	var extension: String="png" if ResourceLoader.exists("res://assets/textures/%s_color.png"%kind) else "jpg"
	mat.albedo_texture = load("res://assets/textures/%s_color.%s" % [kind,extension])
	var normal_path: String="res://assets/textures/%s_normal.%s" % [kind,extension]
	mat.normal_enabled = ResourceLoader.exists(normal_path)
	if mat.normal_enabled:mat.normal_texture = load(normal_path)
	mat.normal_scale = 0.65
	var rough_path: String="res://assets/textures/%s_rough.%s" % [kind,extension]
	if ResourceLoader.exists(rough_path):mat.roughness_texture = load(rough_path)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world_space
	mat.uv1_scale = Vector3.ONE * scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = mat
	return mat
