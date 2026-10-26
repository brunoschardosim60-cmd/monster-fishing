extends RefCounted
## Procedural traffic vessels. Each kind has its own hull proportions and topside, built in local space
## with the waterline at y=0, the bow towards -Z (traffic_vessel moves along -basis.z) and length L along Z.
const G=preload("res://scripts/world/geometry.gd")

static func build(kind: String,length_m: float) -> Node3D:
	var root:=Node3D.new();root.name="Casco_"+kind
	match kind:
		"canoa":_canoa(root,length_m)
		"bote":_bote(root,length_m)
		"pesqueiro":_pesqueiro(root,length_m)
		"rebocador":_rebocador(root,length_m)
		"apoio":_apoio(root,length_m)
		"cargueiro":_cargueiro(root,length_m)
		"petroleiro":_petroleiro(root,length_m)
		_:_bote(root,length_m)
	return root

static func _mat(color: String,rough: float=.7) -> StandardMaterial3D:
	return G.material(Color(color),rough)

## Lofted hull: sections along Z, each a 7-point profile (keel, bilge, chine, deck edges).
## Beam tapers to a point at the bow and a flat transom at the stern.
static func _hull(root: Node3D,length_m: float,beam: float,freeboard: float,draft: float,color: String) -> void:
	var mat:=_mat(color,.6);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var sections:=14
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array=[]
	for s: int in sections+1:
		var t:=float(s)/float(sections)
		var z:=lerpf(-length_m*.5,length_m*.5,t)
		var w:=beam*.5*pow(smoothstep(0.,.36,t),.55)*(1.-.12*smoothstep(.8,1.,t))
		var pts: Array[Vector3]=[Vector3(0.,-draft,z),Vector3(-w*.72,-draft*.45,z),Vector3(-w,0.,z),Vector3(-w*.96,freeboard,z),Vector3(w*.96,freeboard,z),Vector3(w,0.,z),Vector3(w*.72,-draft*.45,z)]
		rings.append(pts)
	for s: int in sections:
		for k: int in 7:
			var k2:=(k+1)%7
			var a: Vector3=rings[s][k];var b: Vector3=rings[s][k2];var c: Vector3=rings[s+1][k2];var d: Vector3=rings[s+1][k]
			st.add_vertex(a);st.add_vertex(b);st.add_vertex(c)
			st.add_vertex(a);st.add_vertex(c);st.add_vertex(d)
	var last: Array=rings[sections];var centre:=Vector3.ZERO
	for p: Vector3 in last:centre+=p
	centre/=7.
	for k: int in 7:
		st.add_vertex(centre);st.add_vertex(last[k]);st.add_vertex(last[(k+1)%7])
	st.generate_normals()
	var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=mat;root.add_child(node)

static func _canoa(root: Node3D,L: float) -> void:
	_hull(root,L,.95,.34,.14,"8a5a2b")
	var skin:=_mat("c98e5e");var shirt:=_mat("e06a3b");var wood:=_mat("d8b07a")
	G.sphere(root,Vector3(0,.98,L*.06),Vector3.ONE*.24,skin,10)
	G.box(root,Vector3(0,.62,L*.06),Vector3(.32,.5,.32),shirt)
	G.beam(root,Vector3(.5,.5,L*.12),Vector3(.95,.1,L*.22),.035,wood)
	G.box(root,Vector3(-.2,.42,-L*.18),Vector3(.5,.22,.5),_mat("c9a46a"))

static func _bote(root: Node3D,L: float) -> void:
	_hull(root,L,2.3,.85,.35,"2f6fb0")
	G.box(root,Vector3(0,1.4,L*.26),Vector3(1.7,1.1,1.8),_mat("f2f2ee"))
	G.box(root,Vector3(0,1.5,L*.26-.92),Vector3(1.3,.5,.05),_mat("24384a"))
	G.cylinder(root,Vector3(0,2.6,-L*.1),.035,2.6,_mat("8a8f96",.4))
	G.box(root,Vector3(.6,.9,-L*.18),Vector3(.6,.4,.6),_mat("e0b040"))

static func _pesqueiro(root: Node3D,L: float) -> void:
	_hull(root,L,4.0,1.5,.6,"c8553d")
	G.box(root,Vector3(0,2.9,L*.24),Vector3(2.6,1.9,2.6),_mat("eeeeee"))
	G.box(root,Vector3(0,4.1,L*.24),Vector3(2.9,.16,2.9),_mat("3a3a3a"))
	G.box(root,Vector3(0,3.0,L*.24-1.31),Vector3(2.2,.7,.06),_mat("24384a"))
	var steel:=_mat("9aa3a8",.4)
	G.beam(root,Vector3(-1.5,1.6,-L*.05),Vector3(0,5.8,-L*.05),.07,steel)
	G.beam(root,Vector3(1.5,1.6,-L*.05),Vector3(0,5.8,-L*.05),.07,steel)
	G.box(root,Vector3(1.0,1.9,-L*.2),Vector3(.8,.5,.8),_mat("e0b040"))
	G.box(root,Vector3(-1.0,1.9,-L*.3),Vector3(.8,.5,.8),_mat("4a8fd0"))

static func _rebocador(root: Node3D,L: float) -> void:
	_hull(root,L,7.0,2.4,1.0,"d9622b")
	G.box(root,Vector3(0,4.2,L*.12),Vector3(4.2,2.4,4.2),_mat("f4f4f4"))
	G.box(root,Vector3(0,4.6,L*.12-2.12),Vector3(3.8,.6,.1),_mat("1f2e3a"))
	G.cylinder(root,Vector3(0,6.0,L*.2),.65,2.6,_mat("1a1a1a"),.7,12)
	G.box(root,Vector3(0,7.35,L*.2),Vector3(1.4,.12,1.4),_mat("1a1a1a"))
	for side: float in [-1.,1.]:
		G.sphere(root,Vector3(side*3.6,1.4,-L*.1),Vector3.ONE*.6,_mat("ff7a1a"),10)

static func _apoio(root: Node3D,L: float) -> void:
	_hull(root,L,8.5,3.0,1.4,"36506e")
	G.box(root,Vector3(0,3.6,-L*.1),Vector3(6,1.0,L*.25),_mat("c0392b"))
	G.box(root,Vector3(0,6.0,L*.3),Vector3(5,3,5),_mat("f0f0f0"))
	G.box(root,Vector3(0,8.0,L*.3),Vector3(5.2,.8,5.2),_mat("2e4a63"))
	G.cylinder(root,Vector3(0,10.0,L*.05),.12,6,_mat("888888",.4))
	G.beam(root,Vector3(0,3.5,-L*.12),Vector3(0,11.0,-L*.24),.12,_mat("ffc400",.4))

static func _cargueiro(root: Node3D,L: float) -> void:
	_hull(root,L,11.5,4.5,2.0,"1f3d5c")
	G.box(root,Vector3(0,9.5,L*.36),Vector3(7.5,5,6),_mat("f2f2f2"))
	G.box(root,Vector3(0,12.5,L*.36),Vector3(7.8,.6,6.2),_mat("1d1d1d"))
	var colors: Array[String]=["d7263d","f0a202","2e86ab","3d9970"]
	for lane: int in 3:
		for row: int in 6:
			for level: int in 2:
				var z:=-L*.3+float(row)*6.4
				var x:=float(lane-1)*3.1
				G.box(root,Vector3(x,4.5+1.3+float(level)*2.6,z),Vector3(2.4,2.5,6.0),_mat(colors[(lane+row+level)%4],.5))

static func _petroleiro(root: Node3D,L: float) -> void:
	_hull(root,L,22.,9.0,3.0,"ececec")
	G.box(root,Vector3(0,16.0,L*.38),Vector3(10,8,9),_mat("f5f5f5"))
	G.box(root,Vector3(0,21.0,L*.38),Vector3(10.5,.8,9.5),_mat("333333"))
	for lane: float in [-6.5,0.,6.5]:
		for row: int in 7:
			var z:=-L*.42+float(row)*13.
			G.box(root,Vector3(lane,9.0+1.6,z),Vector3(4.5,3.2,12.),_mat("b8b8b8",.5))
	G.beam(root,Vector3(-3.,9.6,-L*.45),Vector3(-3.,9.6,L*.3),.22,_mat("a02020",.4))
	G.beam(root,Vector3(3.,9.6,-L*.45),Vector3(3.,9.6,L*.3),.22,_mat("a02020",.4))
