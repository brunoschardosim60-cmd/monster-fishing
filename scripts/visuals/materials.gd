extends RefCounted
## Materiais com aparência estilizada ("pintada"), sem mudar o tipo de retorno.
## As texturas fotográficas viram uma versão menor e de baixo contraste (feita uma
## vez e guardada em cache). A cor de tint passa a mandar no visual, e o detalhe da
## textura fica só como variação sutil, em vez de aparecer como foto esticada.
static var cache: Dictionary = {}
static var painted_cache: Dictionary = {}
## 0 = texturas originais, 1 = estilo pintado completo. Ajuste aqui para testar.
static var style_amount: float = 1.0
const PAINTED_SIZE := 384
const PAINTED_CONTRAST := 0.62
const PAINTED_BRIGHTNESS := 1.16
const PAINTED_SATURATION := 0.9

## Tint mais vivo: saturação e brilho levemente maiores, para as paletas não ficarem lavadas.
static func vivid(tint: Color) -> Color:
	if style_amount <= 0.: return tint
	var out := tint
	out.s = clampf(tint.s * (1. + .22 * style_amount) + .03 * style_amount, 0., 1.)
	out.v = clampf(tint.v * (1. + .07 * style_amount), 0., 1.)
	return out

## Versão "pintada" de uma textura: menor, menos contraste, cores um pouco mais suaves.
static func painted(path: String, keep_original: bool = false) -> Texture2D:
	var original: Texture2D = load(path)
	if style_amount <= 0. or keep_original or original == null: return original
	if painted_cache.has(path): return painted_cache[path]
	var result: Texture2D = original
	var img: Image = original.get_image()
	if img != null:
		if img.is_compressed() and img.decompress() != OK: img = null
	if img != null:
		var longest := maxi(img.get_width(), img.get_height())
		if longest > PAINTED_SIZE:
			var factor := float(PAINTED_SIZE) / float(longest)
			img.resize(maxi(8, int(img.get_width() * factor)), maxi(8, int(img.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		img.adjust_bcs(lerpf(1., PAINTED_BRIGHTNESS, style_amount), lerpf(1., PAINTED_CONTRAST, style_amount), lerpf(1., PAINTED_SATURATION, style_amount))
		img.generate_mipmaps()
		result = ImageTexture.create_from_image(img)
	painted_cache[path] = result
	return result

static func surface(kind: String, tint: Color = Color.WHITE, scale_value: float = 1.0, world_space: bool = true) -> StandardMaterial3D:
	var key := kind + tint.to_html() + str(scale_value) + str(world_space) + str(style_amount)
	if cache.has(key): return cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vivid(tint)
	var extension: String="png" if ResourceLoader.exists("res://assets/textures/%s_color.png"%kind) else "jpg"
	# Every surface, paving included, gets the same painted treatment (one style across the game).
	mat.albedo_texture = painted("res://assets/textures/%s_color.%s" % [kind,extension], false)
	var normal_path: String="res://assets/textures/%s_normal.%s" % [kind,extension]
	mat.normal_enabled = ResourceLoader.exists(normal_path)
	if mat.normal_enabled:mat.normal_texture = load(normal_path)
	mat.normal_scale = lerpf(.65, .38, style_amount)
	var rough_path: String="res://assets/textures/%s_rough.%s" % [kind,extension]
	if ResourceLoader.exists(rough_path):mat.roughness_texture = load(rough_path)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 1.0
	if style_amount > 0.:
		# Luz de borda curta dá o "pop" de objeto pintado sem virar cartoon.
		mat.rim_enabled = true
		mat.rim = .14 * style_amount
		mat.rim_tint = .45
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world_space
	mat.uv1_scale = Vector3.ONE * scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = mat
	return mat
