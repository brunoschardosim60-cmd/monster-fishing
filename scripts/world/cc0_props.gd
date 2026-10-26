extends RefCounted
## Places the CC0 Polygonal Mind models (assets/props/cc0, see LICENSE.md) at real-world sizes.
## Each model is normalised once: its bounds are measured, it is scaled to the requested height (or
## width) in metres and its base is set on the given point. Small props fade out with distance.
const ROOT: String="res://assets/props/cc0/%s.glb"
## Quaternius Stylized Nature MegaKit (CC0): pass "nature:Name".
const NATURE: String="res://assets/environment/quaternius_nature/%s.gltf"
static var _scenes: Dictionary={}
static var _bounds: Dictionary={}
static var _fixed: Dictionary={}

## The Polygonal Mind exports carry a toon "outline" shell, a logo decal and a high metallic/specular
## setup that reads as white in Godot. Fix once per model: hide the shell and the logo, and give the
## surfaces a painted, non-metallic response.
static func _fix_materials(instance: Node3D) -> void:
	for node: Node in instance.find_children("*","MeshInstance3D",true,false):
		var mesh:=(node as MeshInstance3D).mesh
		if mesh==null:continue
		for i: int in mesh.get_surface_count():
			var mat:=mesh.surface_get_material(i) as StandardMaterial3D
			if mat==null:continue
			if "logo" in mat.resource_name.to_lower():
				mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(1,1,1,0);mat.emission_enabled=false
			elif "outline" in mat.resource_name.to_lower():
				# The toon outline shell would cover the model in this renderer; drop it.
				mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(0,0,0,0);mat.albedo_texture=null
			else:
				mat.metallic=0.;mat.metallic_specular=.3;mat.roughness=maxf(mat.roughness,.75)

static func path_of(model: String) -> String:
	return NATURE%model.trim_prefix("nature:") if model.begins_with("nature:") else ROOT%model

static func exists(model: String) -> bool:
	return ResourceLoader.exists(path_of(model))

## size: metres along the measured axis; by_width measures the larger horizontal side instead of height.
static func spawn(parent: Node3D,model: String,at: Vector3,size: float,yaw: float=0.,by_width: bool=false,fade: float=160.) -> Node3D:
	var path:=path_of(model)
	if not ResourceLoader.exists(path):return null
	if not _scenes.has(path):_scenes[path]=load(path)
	var first_use:=not _fixed.has(path)
	var instance:=(_scenes[path] as PackedScene).instantiate() as Node3D
	var holder:=Node3D.new();holder.name="CC0_%s_%d"%[model.trim_prefix("nature:"),parent.get_child_count()];holder.position=at;holder.rotation.y=yaw
	parent.add_child(holder);holder.add_child(instance)
	if first_use:_fix_materials(instance);_fixed[path]=true
	# The exports keep their collision proxies and a logo decal as visible meshes: hide them.
	for node: Node in instance.find_children("*","MeshInstance3D",true,false):
		var lower:=String(node.name).to_lower()
		if "collider" in lower or lower=="logo":(node as MeshInstance3D).visible=false
	var box: AABB=_measure(path,instance)
	var span:=maxf(box.size.x,box.size.z) if by_width else box.size.y
	var factor:=size/maxf(span,.0001)
	instance.scale=Vector3.ONE*factor
	instance.position=-Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	for node: Node in instance.find_children("*","GeometryInstance3D",true,false):
		var g:=node as GeometryInstance3D
		g.visibility_range_end=fade;g.visibility_range_end_margin=fade*.15
		if size<1.2:g.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder

static func _measure(path: String,instance: Node3D) -> AABB:
	if _bounds.has(path):return _bounds[path]
	var first:=true;var box:=AABB()
	for node: Node in instance.find_children("*","MeshInstance3D",true,false):
		var mi:=node as MeshInstance3D
		if mi.mesh==null or not mi.visible:continue
		# Transform relative to the model root, so this also works before it enters the scene tree.
		var relative:=Transform3D.IDENTITY;var walker: Node=mi
		while walker!=instance and walker is Node3D:
			relative=(walker as Node3D).transform*relative;walker=walker.get_parent()
		var b:=relative*mi.get_aabb()
		box=b if first else box.merge(b);first=false
	_bounds[path]=box
	return box

## Solid box for a prop the player should not walk through.
static func solid(holder: Node3D,size: Vector3) -> void:
	if holder==null:return
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape3D.new();var b:=BoxShape3D.new();b.size=size;shape.shape=b;shape.position.y=size.y*.5
	body.add_child(shape);holder.add_child(body)
