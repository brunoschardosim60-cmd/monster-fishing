extends RefCounted
## Shared imported meshes. Wind is GPU-driven; no per-tree process callbacks.
const G=preload("res://scripts/world/geometry.gd")
const NAMES: Array[String]=["island_tree_01","island_tree_02","coconut_palm_0","coconut_palm_1","fern_02","coastal_cliff_02"]
static var cache: Dictionary={}
static func wind(time: float,strength: float,direction: Vector2) -> void:
	for entries: Array in cache.values():
		for part: Dictionary in entries:
			if part.material is ShaderMaterial:
				part.material.set_shader_parameter("wind_time",time)
				part.material.set_shader_parameter("wind_strength",strength)
				part.material.set_shader_parameter("wind_direction",direction)

static func parts(kind: int) -> Array[Dictionary]:
	if cache.has(kind):return cache[kind]
	var source: Node3D=load("res://assets/environment/nature/"+NAMES[kind]+".glb").instantiate()
	var raw: Array[Dictionary]=[];_collect(source,Transform3D.IDENTITY,raw)
	var bounds:=AABB();var first:=true
	for part: Dictionary in raw:
		var b: AABB=part.transform*part.mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
	var desired: float=[12.,10.,9.,11.,.7,12.][kind]
	var factor:=desired/maxf(bounds.size.y,.01)
	var shift:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	var result: Array[Dictionary]=[]
	for part: Dictionary in raw:
		var transform: Transform3D=part.transform
		transform.origin-=shift;transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),Vector3.ZERO)*transform
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.append_from(part.mesh,part.surface,transform)
		var material: Material=part.material
		var foliage:=kind<5 and (kind==4 or "leav" in str(material.resource_name).to_lower() or "frond" in str(material.resource_name).to_lower())
		if foliage and material is StandardMaterial3D:
			var wind:=ShaderMaterial.new();wind.shader=preload("res://assets/shaders/living_foliage.gdshader")
			wind.set_shader_parameter("albedo_tex",material.albedo_texture);wind.set_shader_parameter("tint",material.albedo_color)
			wind.set_shader_parameter("has_normal",material.normal_enabled);wind.set_shader_parameter("normal_tex",material.normal_texture)
			wind.set_shader_parameter("sway",.28 if kind in [2,3] else (.045 if kind==4 else .12));wind.set_shader_parameter("tree_height",desired)
			material=wind
		elif material is StandardMaterial3D:
			material=material.duplicate();material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=.9
		result.append({"mesh":st.commit(),"material":material,"foliage":foliage})
	source.free();cache[kind]=result;return result

static func _collect(node: Node,transform: Transform3D,out: Array[Dictionary]) -> void:
	if node is Node3D:transform=transform*node.transform
	if node is MeshInstance3D:
		for surface: int in node.mesh.get_surface_count():out.append({"mesh":node.mesh,"surface":surface,"material":node.get_active_material(surface),"transform":transform})
	for child: Node in node.get_children():_collect(child,transform,out)

static func plant(parent: Node3D,kind: int,at: Vector3,size: float=1.,angle: float=0.) -> Node3D:
	var node:=Node3D.new();node.name=NAMES[kind];parent.add_child(node);node.position=at;node.scale=Vector3.ONE*size;node.rotation.y=angle
	for part: Dictionary in parts(kind):
		var mesh:=G.mesh_node(node,part.mesh,part.material,Vector3.ZERO)
		mesh.visibility_range_end=260. if kind<4 else 1200.
	return node

static func grove(parent: Node3D,kind: int,transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():return
	var far_path: String="res://assets/environment/nature/"+NAMES[kind]+"_impostor.png"
	var has_far:=kind<4 and ResourceLoader.exists(far_path)
	for part: Dictionary in parts(kind):
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=part.mesh;mm.instance_count=transforms.size()
		for i: int in transforms.size():mm.set_instance_transform(i,transforms[i])
		var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=part.material
		node.visibility_range_end=125. if has_far else (110. if kind==4 else 1100.);node.visibility_range_end_margin=18.
		if part.foliage:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		if has_far:node.add_to_group("nature_near")
		if part.foliage:node.add_to_group("nature_foliage")
	if kind<4:
		var proxy:=SphereMesh.new();proxy.radius=3.8 if kind<2 else 2.7;proxy.height=6. if kind<2 else 2.;proxy.radial_segments=12;proxy.rings=6
		proxy.material=G.material(Color("384c36"))
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=proxy;mm.instance_count=transforms.size()
		for i: int in transforms.size():mm.set_instance_transform(i,transforms[i]*Transform3D(Basis.IDENTITY,Vector3(0,7.,0)))
		var shadow:=MultiMeshInstance3D.new();shadow.multimesh=mm;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;shadow.visibility_range_end=125.;parent.add_child(shadow);shadow.add_to_group("nature_shadow_proxy")
	if has_far:
		var quad:=QuadMesh.new();quad.size=Vector2(18,18);quad.center_offset=Vector3(0,8,0)
		var mat:=StandardMaterial3D.new();mat.albedo_texture=load(far_path);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.35;mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;mat.billboard_keep_scale=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1.
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=quad;mm.instance_count=transforms.size()
		for i: int in transforms.size():mm.set_instance_transform(i,transforms[i])
		var far:=MultiMeshInstance3D.new();far.multimesh=mm;far.material_override=mat;far.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;far.visibility_range_begin=125.;far.visibility_range_begin_margin=18.;far.visibility_range_end=2000.;parent.add_child(far);far.add_to_group("nature_far")
