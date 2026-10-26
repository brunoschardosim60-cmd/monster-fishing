extends SceneTree
## Turns the painted mesh dumps from color_imported.py into Godot meshes with LODs.
## godot --headless --script res://scripts/pipeline/bake_imported.gd -- /path/to/painted
func _init() -> void:
	var dir: String=OS.get_cmdline_user_args()[0]
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".bin"):continue
		var f:=FileAccess.open(dir+"/"+file,FileAccess.READ)
		var nv:=f.get_32();var ni:=f.get_32()
		var pos:=f.get_buffer(nv*12).to_float32_array();var nor:=f.get_buffer(nv*12).to_float32_array()
		var rgba:=f.get_buffer(nv*4);var idx:=f.get_buffer(ni*4).to_int32_array()
		var V:=PackedVector3Array();var N:=PackedVector3Array();var C:=PackedColorArray()
		V.resize(nv);N.resize(nv);C.resize(nv)
		for i: int in nv:
			V[i]=Vector3(pos[i*3],pos[i*3+1],pos[i*3+2]);N[i]=Vector3(nor[i*3],nor[i*3+1],nor[i*3+2])
			C[i]=Color8(rgba[i*4],rgba[i*4+1],rgba[i*4+2],rgba[i*4+3])
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=V;arrays[Mesh.ARRAY_NORMAL]=N;arrays[Mesh.ARRAY_COLOR]=C;arrays[Mesh.ARRAY_INDEX]=idx
		var im:=ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		im.generate_lods(25.,60.,[])
		var mesh:=im.get_mesh()
		var name:=file.get_basename()
		mesh.resource_name=name
		var out:="res://assets/models/imported/%s.res"%name
		ResourceSaver.save(mesh,out,ResourceSaver.FLAG_COMPRESS)
		print(out," v=",nv," t=",ni/3," lods=",mesh.surface_get_format(0))
	quit()
