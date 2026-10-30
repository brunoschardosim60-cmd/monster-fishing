extends RefCounted
## Stylised townsfolk bodies (tools/blender/folk.py) skinned onto the humanoid rig of survivalist_rigged.glb.
## The GLB holds one rigid piece per bone, named after it, in the rig's rest space. Here they are merged
## into one skinned mesh: each vertex follows its bone, blended half-and-half with the parent bone near the
## joint so elbows, knees and shoulders bend smoothly. Cached per file: every NPC with the same body shares
## the mesh and skin.
const ARCHETYPES: Array[String]=["pescador","marujo","taberneiro","capitao","mercadora","pescadora","grumete","estivador"]
const BLEND: float=.09
static var _cache: Dictionary={}
static var _material: StandardMaterial3D

static func path_for(id: int) -> String:
	return "res://assets/characters/folk/%s_%d.glb"%[ARCHETYPES[id%ARCHETYPES.size()],1+(id/ARCHETYPES.size())%2]

## Adds the body under `skeleton` and returns it.
static func attach(skeleton: Skeleton3D,path: String) -> MeshInstance3D:
	var entry: Dictionary=_cache.get(path,{})
	if entry.is_empty():
		entry=_build(skeleton,path);_cache[path]=entry
	var mi:=MeshInstance3D.new();mi.name="CorpoFolk";mi.mesh=entry.mesh;mi.skin=entry.skin
	skeleton.add_child(mi);mi.skeleton=NodePath("..")
	return mi

static func _build(skeleton: Skeleton3D,path: String) -> Dictionary:
	if _material==null:
		_material=StandardMaterial3D.new();_material.vertex_color_use_as_albedo=true;_material.roughness=.85
	var scene: Node3D=load(path).instantiate()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	var skin:=Skin.new()
	for b: int in skeleton.get_bone_count():skin.add_named_bind(skeleton.get_bone_name(b),skeleton.get_bone_global_rest(b).affine_inverse())
	var base:=0
	for mi: MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		var bone: int=skeleton.find_bone(str(mi.name).get_slice("_",0))
		if bone<0:continue
		var parent: int=skeleton.get_bone_parent(bone)
		var head: Vector3=skeleton.get_bone_global_rest(bone).origin
		var xf:=_xform(mi,scene)
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array=mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for i: int in verts.size():
				var p: Vector3=xf*verts[i]
				var own: float=1.
				if parent>=0:own=.5+.5*clampf(p.distance_to(head)/BLEND,0.,1.)
				st.set_normal((xf.basis*normals[i]).normalized())
				st.set_color(colors[i] if i<colors.size() else Color.WHITE)
				st.set_bones(PackedInt32Array([bone,maxi(parent,0),0,0]));st.set_weights(PackedFloat32Array([own,1.-own,0.,0.]))
				st.add_vertex(p)
			if indices.is_empty():
				for i: int in verts.size():st.add_index(base+i)
			else:
				for i: int in indices:st.add_index(base+i)
			base+=verts.size()
	scene.free()
	st.set_material(_material)
	return {"mesh":st.commit(),"skin":skin}

static func _xform(node: Node3D,root: Node3D) -> Transform3D:
	var t:=Transform3D.IDENTITY;var n: Node=node
	while n!=null and n!=root:
		if n is Node3D:t=(n as Node3D).transform*t
		n=n.get_parent()
	return t
