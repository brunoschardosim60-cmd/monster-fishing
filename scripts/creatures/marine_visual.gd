extends Node3D
@export_enum("mackerel","tuna","lanternfish","abyssal_guardian") var species: String="mackerel"
@export var face_forward: bool=true
static var scene_cache: Dictionary={}
static var material_cache: Dictionary={}
func _ready() -> void:
	var path: String="res://assets/%s/%s.glb"%["monsters" if species=="abyssal_guardian" else "fish",species]
	if not scene_cache.has(path):scene_cache[path]=load(path)
	var model: Node3D=scene_cache[path].instantiate();add_child(model)
	if face_forward:model.rotation.y=PI*.5
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface: int in mesh.mesh.get_surface_count():
			var source:=mesh.get_active_material(surface) as StandardMaterial3D
			if source==null:continue
			var is_fin:=str(mesh.name).begins_with("Fin ")
			var key: String=species+str(source.get_instance_id())+str(is_fin)
			if material_cache.has(key):mesh.set_surface_override_material(surface,material_cache[key].shader);continue
			var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/marine_skin.gdshader")
			mat.set_shader_parameter("guardian",species=="abyssal_guardian")
			mat.set_shader_parameter("fin_membrane",is_fin)
			mat.set_shader_parameter("tint",source.albedo_color);mat.set_shader_parameter("textured",source.albedo_texture!=null)
			if source.albedo_texture!=null:mat.set_shader_parameter("albedo_tex",source.albedo_texture)
			if source.emission_enabled:mat.set_shader_parameter("glow_color",source.emission)
			material_cache[key]={"source":source,"shader":mat}
			mesh.set_surface_override_material(surface,mat)
