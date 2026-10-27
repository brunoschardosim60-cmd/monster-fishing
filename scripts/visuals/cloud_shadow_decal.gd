extends Node3D
## Cloud shadows on everything that has no cloud term of its own (houses, boats, rocks, people, props).
## The cloud-shadow pattern (cloud_shadow.gdshaderinc) repeats every 1/.0014 m and drifts rigidly with
## the wind, so one period is baked into a texture (again whenever the cloud cover changes) and a 3×3
## grid of decals showing it rides along with the drift around the camera. Surfaces that already darken
## under clouds (terrain, ocean, foliage, grass, seabed) are moved to visual layer 20, which the decals skip.
## Decals need Forward+ / Mobile; in Compatibility this node does nothing.
const PERIOD: float=1./.0014
const OWN_SHADOW_LAYER: int=1<<19
const OWN_SHADOW: Array[String]=["terrain.gdshader","ocean.gdshader","living_foliage.gdshader","grass_tuft.gdshader","seabed.gdshader"]
var decals: Array[Decal]=[]
var mask: SubViewport
var mask_material: ShaderMaterial
var strength: float=0.
var cover: float=-1.
var velocity:=Vector2(.006,.0025)
var _baking: bool=false

func _ready() -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		set_process(false);return
	mask=SubViewport.new();mask.size=Vector2i(512,512);mask.transparent_bg=true;mask.disable_3d=true
	mask.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(mask)
	var rect:=ColorRect.new();rect.size=Vector2(512,512);mask.add_child(rect)
	mask_material=ShaderMaterial.new();mask_material.shader=preload("res://assets/shaders/cloud_shadow_mask.gdshader")
	mask_material.set_shader_parameter("noise_tex",load("res://assets/textures/cloud_noise.png"));rect.material=mask_material
	for i: int in 9:
		var d:=Decal.new();d.size=Vector3(PERIOD,800.,PERIOD);d.albedo_mix=1.;d.upper_fade=.05;d.lower_fade=.05;d.normal_fade=0.
		d.cull_mask=0xFFFFF & ~OWN_SHADOW_LAYER;d.visible=false;add_child(d);decals.append(d)
	get_tree().node_added.connect(_tag)
	_tag_all.call_deferred()

## strength 0..1, cover (cloud amount), drift (noise uv per second).
func set_params(value: float,cloud_cover: float,drift: Vector2) -> void:
	if mask==null:return
	strength=value;velocity=drift
	if absf(cloud_cover-cover)>.02 and not _baking:_bake(cloud_cover)

func _bake(cloud_cover: float) -> void:
	_baking=true;cover=cloud_cover
	mask_material.set_shader_parameter("cover",cloud_cover)
	mask.render_target_update_mode=SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture:=ImageTexture.create_from_image(mask.get_texture().get_image())
	for d: Decal in decals:d.texture_albedo=texture
	_baking=false

func _process(_delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null or decals.is_empty():return
	var on:=strength>.01 and decals[0].texture_albedo!=null
	# Shader TIME rolls over every hour; the decal grid follows the same clock.
	var t:=fmod(Time.get_ticks_msec()/1000.,3600.)
	var origin:=-velocity*t*PERIOD
	var c:=camera.global_position
	var base:=Vector2(origin.x+floorf((c.x-origin.x)/PERIOD)*PERIOD,origin.y+floorf((c.z-origin.y)/PERIOD)*PERIOD)
	for i: int in 9:
		var d:=decals[i]
		d.visible=on;d.modulate=Color(1,1,1,strength)
		var cell:=base+Vector2(float(i%3-1),float(i/3-1))*PERIOD
		d.global_position=Vector3(cell.x+PERIOD*.5,100.,cell.y+PERIOD*.5)

func _tag_all() -> void:
	for node: Node in get_tree().root.find_children("*","GeometryInstance3D",true,false):_tag(node)

func _tag(node: Node) -> void:
	if not node is GeometryInstance3D:return
	var g:=node as GeometryInstance3D
	var mat:=g.material_override as ShaderMaterial
	if mat==null and g is MeshInstance3D and (g as MeshInstance3D).mesh!=null and (g as MeshInstance3D).mesh.get_surface_count()>0:
		mat=(g as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	if mat==null and g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh!=null and (g as MultiMeshInstance3D).multimesh.mesh!=null:
		mat=(g as MultiMeshInstance3D).multimesh.mesh.surface_get_material(0) as ShaderMaterial
	if mat==null or mat.shader==null:return
	if mat.shader.resource_path.get_file() in OWN_SHADOW:g.layers=OWN_SHADOW_LAYER
