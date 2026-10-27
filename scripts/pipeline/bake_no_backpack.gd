extends SceneTree
## The survivalist body mesh has a backpack modelled into it. This bakes a copy without it: the bag is
## pressed flat against the jacket and the straps, buckles and back pockets are dropped. The vertex and
## face lists come from assets/characters/no_backpack.json (made by scripts/pipeline/no_backpack.py).
## The optional backpack accessory (fisher_backpack.glb) is shown on top for characters that carry one.
## godot --headless --path . --script res://scripts/pipeline/bake_no_backpack.gd
const OUT: String="res://assets/characters/survivalist_body_nopack.res"
func _init() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/no_backpack.json"))
	var scene: Node3D=load("res://assets/characters/survivalist_rigged.glb").instantiate()
	var body: MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0]
	var mesh: Mesh=body.mesh
	var arrays: Array=mesh.surface_get_arrays(0)
	var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var moved: Array=data.moved;var zs: Array=data.z
	for k: int in moved.size():
		var i: int=int(moved[k]);verts[i]=Vector3(verts[i].x,verts[i].y,float(zs[k]))
	arrays[Mesh.ARRAY_VERTEX]=verts
	var drop: Dictionary={}
	for f in data.remove_faces:drop[int(f)]=true
	var idx: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var kept:=PackedInt32Array()
	for f: int in idx.size()/3:
		if not drop.has(f):kept.append(idx[f*3]);kept.append(idx[f*3+1]);kept.append(idx[f*3+2])
	arrays[Mesh.ARRAY_INDEX]=kept
	var out:=ArrayMesh.new()
	var flags: int=mesh.surface_get_format(0)&(Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	out.surface_set_material(0,mesh.surface_get_material(0))
	print("no backpack: ",idx.size()/3," -> ",kept.size()/3," faces · ",ResourceSaver.save(out,OUT,ResourceSaver.FLAG_COMPRESS))
	quit()
