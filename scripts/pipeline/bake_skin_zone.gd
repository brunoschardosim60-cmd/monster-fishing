extends SceneTree
## Bakes assets/characters/skin_zone_mask.png: a UV-space mask of the survivalist atlas.
## R = skin zone (head, neck, hands), G = head only (hair, beard). npc_skin.gdshader uses it so NPC clothing
## recolouring never touches faces or hands. Run: godot --headless --path . --script res://scripts/pipeline/bake_skin_zone.gd
const SIZE:=2048
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var a: Node3D=preload("res://scripts/player/imported_angler.gd").new()
	root.add_child(a);await process_frame
	var body: MeshInstance3D=a.model.find_children("*","MeshInstance3D",true,false)[0]
	var arrays:=body.mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var per_vertex:=bones.size()/uvs.size()
	var skin_bones:=[];var head_bones:=[]
	for i: int in a.skeleton.get_bone_count():
		var n: String=a.skeleton.get_bone_name(i)
		if n.begins_with("Head") or n.begins_with("Neck") or n.contains("Hand") or n.contains("Thumb") or n.contains("Index") or n.contains("Middle") or n.contains("Ring") or n.contains("Pinky"):skin_bones.append(i)
		if n.begins_with("Head"):head_bones.append(i)
	var skin_w:=PackedFloat32Array();var head_w:=PackedFloat32Array();skin_w.resize(uvs.size());head_w.resize(uvs.size())
	for v: int in uvs.size():
		for k: int in per_vertex:
			var b: int=bones[v*per_vertex+k]
			if b in skin_bones:skin_w[v]+=weights[v*per_vertex+k]
			if b in head_bones:head_w[v]+=weights[v*per_vertex+k]
	var img:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8)
	for t: int in range(0,indices.size(),3):
		var i0:=indices[t];var i1:=indices[t+1];var i2:=indices[t+2]
		var s:=(skin_w[i0]+skin_w[i1]+skin_w[i2])/3.;var h:=(head_w[i0]+head_w[i1]+head_w[i2])/3.
		if s<.55:continue
		var p0:=uvs[i0]*SIZE;var p1:=uvs[i1]*SIZE;var p2:=uvs[i2]*SIZE
		var lo:=Vector2(minf(p0.x,minf(p1.x,p2.x)),minf(p0.y,minf(p1.y,p2.y))).floor()-Vector2.ONE;var hi:=Vector2(maxf(p0.x,maxf(p1.x,p2.x)),maxf(p0.y,maxf(p1.y,p2.y))).ceil()+Vector2.ONE
		var den:=(p1.y-p2.y)*(p0.x-p2.x)+(p2.x-p1.x)*(p0.y-p2.y)
		var color:=Color(1.,1. if h>.5 else 0.,0.)
		for y: int in range(maxi(0,int(lo.y)),mini(SIZE-1,int(hi.y))+1):
			for x: int in range(maxi(0,int(lo.x)),mini(SIZE-1,int(hi.x))+1):
				var p:=Vector2(x+.5,y+.5)
				var l0:=.34;var l1:=.33;var l2:=.33
				if absf(den)>=.00001:
					l0=((p1.y-p2.y)*(p.x-p2.x)+(p2.x-p1.x)*(p.y-p2.y))/den;l1=((p2.y-p0.y)*(p.x-p2.x)+(p0.x-p2.x)*(p.y-p2.y))/den;l2=1.-l0-l1
				if l0>=-.35 and l1>=-.35 and l2>=-.35:img.set_pixel(x,y,color)
	img.save_png("res://assets/characters/skin_zone_mask.png")
	print("BAKED")
	quit(0)
