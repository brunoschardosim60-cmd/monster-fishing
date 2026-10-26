extends SceneTree
## Dumps the meshes of imported models (merged, raw positions and triangles) for color_imported.py.
## Copy model_sources/*.fbx into a res:// folder first (Godot imports them), then:
## godot --headless --script res://scripts/pipeline/dump_imported.gd -- res://folder /out/raw
func _init():
	var args:=OS.get_cmdline_user_args()
	for p in ["sailing_ship.fbx","container_ship.fbx","cargo_ship.fbx","rowboat.fbx","marine_life.fbx","dragon.glb"]:
		if not ResourceLoader.exists(args[0]+"/"+p):continue
		var n:Node3D=load(args[0]+"/"+p).instantiate()
		root.add_child(n)
		var V:=PackedVector3Array(); var I:=PackedInt32Array(); var P:=PackedInt32Array()
		var part:=0
		for mi in n.find_children("*","MeshInstance3D",true,false):
			var xf:Transform3D=mi.global_transform
			for s in mi.mesh.get_surface_count():
				var a=mi.mesh.surface_get_arrays(s)
				var base:=V.size()
				for v in a[0]: V.append(xf*v); P.append(part)
				var idx=a[Mesh.ARRAY_INDEX]
				if idx==null:
					for k in a[0].size(): I.append(base+k)
				else:
					for k in idx: I.append(base+k)
			part+=1
		var f=FileAccess.open(args[1]+"/"+p.get_basename()+".bin",FileAccess.WRITE)
		f.store_32(V.size()); f.store_32(I.size())
		var fl:=PackedFloat32Array()
		for v in V: fl.append(v.x); fl.append(v.y); fl.append(v.z)
		f.store_buffer(fl.to_byte_array()); f.store_buffer(I.to_byte_array()); f.store_buffer(P.to_byte_array())
		f.close(); print(p," ",V.size()," ",I.size()/3)
		n.free()
	quit()
