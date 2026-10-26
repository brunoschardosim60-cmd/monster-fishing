extends RefCounted
## Procedural vessels. Every kind has its own hull form and topside; colours, flags, cargo and details
## vary per ship from a seed. Built in local space with the waterline at y=0, bow towards -Z (traffic
## moves along -basis.z) and length along Z. Models are visual only: the vessel owns its collision.
##
## The returned root carries metadata used by traffic_vessel.gd and the crew:
##   deck (float) deck height · helm (Vector3) · walk ([Vector3, Vector3]) deck walkway · rails (Array of
##   [Vector3 position, float facing]) · seats (Array of [Vector3, float]) · sails (Array[Node3D]) ·
##   flag (Node3D) · oars (Array[Node3D]) · windows (StandardMaterial3D) · crew (int suggested size)
const G=preload("res://scripts/world/geometry.gd")
const KINDS: Array[String]=["canoa","bote_remo","bote","pesqueiro","veleiro","escuna","rebocador","apoio","cargueiro","petroleiro","gigante"]
const FLAGS: Array=[[Color("009c3b"),Color("ffdf00"),Color("002776")],[Color("d52b1e"),Color("ffffff"),Color("d52b1e")],[Color("0055a4"),Color("ffffff"),Color("ef4135")],
	[Color("000000"),Color("dd0000"),Color("ffce00")],[Color("ffffff"),Color("0038a8"),Color("ffffff")],[Color("006847"),Color("ffffff"),Color("ce1126")],[Color("c60b1e"),Color("ffc400"),Color("c60b1e")]]

static func build(kind: String,length_m: float,seed_value: int=1) -> Node3D:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var root:=Node3D.new();root.name="Casco_"+kind
	root.set_meta("rails",[]);root.set_meta("seats",[]);root.set_meta("sails",[]);root.set_meta("oars",[])
	var windows:=StandardMaterial3D.new();windows.albedo_color=Color("1d2b36");windows.roughness=.15;windows.metallic=.3
	windows.emission_enabled=true;windows.emission=Color("ffcf86");windows.emission_energy_multiplier=0.
	root.set_meta("windows",windows)
	match kind:
		"canoa":_canoa(root,length_m,rng)
		"bote_remo":_bote_remo(root,length_m,rng)
		"bote":_bote(root,length_m,rng)
		"pesqueiro":_pesqueiro(root,length_m,rng)
		"veleiro":_veleiro(root,length_m,rng)
		"escuna":_escuna(root,length_m,rng)
		"rebocador":_rebocador(root,length_m,rng)
		"apoio":_apoio(root,length_m,rng)
		"cargueiro":_cargueiro(root,length_m,rng,3,2)
		"gigante":_cargueiro(root,length_m,rng,9,4)
		"petroleiro":_petroleiro(root,length_m,rng)
		_:_bote(root,length_m,rng)
	# Small parts fade out with distance; hulls and superstructures stay visible to the horizon.
	var detail_range:=clampf(length_m*14.,160.,1100.)
	for node: Node in root.find_children("*","GeometryInstance3D",true,false):
		if node.has_meta("detail"):(node as GeometryInstance3D).visibility_range_end=detail_range
	return root

## Beam (width) of each hull form, used for collision and wave sampling.
static func beam_of(kind: String,L: float) -> float:
	match kind:
		"canoa":return .95
		"bote_remo":return 1.65
		"bote":return 2.4
		"pesqueiro","veleiro":return L*.32
		"escuna":return L*.25
		"rebocador":return L*.34
		"apoio":return L*.28
		"cargueiro":return 3.*2.55+2.4
		"gigante":return 9.*2.55+2.4
		"petroleiro":return L*.15
	return L*.3

# ---------------------------------------------------------------- helpers
static func _mat(color: Color,rough: float=.7,metal: float=0.) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;m.metallic=metal
	return m
static func _pick(rng: RandomNumberGenerator,list: Array) -> Variant:
	return list[rng.randi()%list.size()]
static func _detail(node: Node):
	node.set_meta("detail",true)
	return node
static func _rail(root: Node3D,at: Vector3,facing: float) -> void:
	(root.get_meta("rails") as Array).append([at,facing])
## Load carried in a small open boat: crates of fish on ice, a bundle of logs or sacks and a net.
## Kind is kept in the "cargo" meta ("peixe", "madeira", "redes").
static func _cargo(root: Node3D,at: Vector3,width: float,rng: RandomNumberGenerator) -> void:
	var bundle:=Node3D.new();bundle.name="Carga";bundle.position=at;root.add_child(bundle)
	var pick:=rng.randi()%3
	match pick:
		0:
			var crate:=_mat(Color("a07a4f"),.85);var ice:=_mat(Color("dbeef2"),.3);var fish:=_mat(Color("8fa7b0"),.35,.4)
			for i: int in 2:
				var z:=(float(i)-.5)*.55
				G.box(bundle,Vector3(0,.15,z),Vector3(width*.75,.3,.5),crate);G.box(bundle,Vector3(0,.31,z),Vector3(width*.68,.03,.44),ice)
				for k: int in 3:G.ellipsoid(bundle,Vector3(-width*.22+float(k)*width*.22,.34,z),Vector3(.09,.06,.34),fish,8)
			root.set_meta("cargo","peixe")
		1:
			var bark:=_mat(Color("6b4e33"),.95);var cut:=_mat(Color("d8b884"),.8)
			for i: int in 3:
				var piece:=G.cylinder(bundle,Vector3((float(i)-1.)*.2,.12+(.16 if i==1 else 0.),0),.11,1.5,bark,.1,8);piece.rotation.x=PI*.5
			G.beam(bundle,Vector3(-.3,.2,.45),Vector3(.3,.2,.45),.02,_mat(Color("c9b48a")))
			root.set_meta("cargo","madeira")
		_:
			var sack:=_mat(Color("bfa982"),.95);var net:=_mat(Color("5e7f7a"),.9);var float_mat:=_mat(Color("e69138"),.6)
			for i: int in 2:G.ellipsoid(bundle,Vector3((float(i)-.5)*.32,.18,-.15),Vector3(.3,.32,.38),sack,10)
			G.ellipsoid(bundle,Vector3(0,.12,.32),Vector3(width*.6,.18,.45),net,10)
			for k: int in 3:G.ellipsoid(bundle,Vector3(-.2+float(k)*.2,.24,.36),Vector3(.08,.08,.08),float_mat,6)
			root.set_meta("cargo","redes")

static func _seat(root: Node3D,at: Vector3,facing: float) -> void:
	(root.get_meta("seats") as Array).append([at,facing])

## Lofted hull with painted bands: antifouling below the waterline, hull colour, a decorative stripe
## under the gunwale and a deck. `pointed_stern` gives canoe/double-ended shapes; `sheer` lifts the bow.
static func _hull(root: Node3D,L: float,beam: float,freeboard: float,draft: float,hull: Color,bottom: Color,stripe: Color,deck: Color,pointed_stern: bool=false,sheer: float=0.,open_floor: float=-1.) -> void:
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.55;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var sections:=20
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array=[];var colors: Array[Color]=[bottom,bottom,bottom,hull,hull,stripe,stripe,hull,deck,deck,hull,stripe,stripe,hull,hull,bottom,bottom]
	for s: int in sections+1:
		var t:=float(s)/float(sections)
		var z:=lerpf(-L*.5,L*.5,t)
		var w: float
		if pointed_stern:w=beam*.5*pow(sin(PI*clampf(t,0.,1.)),.62)
		else:w=beam*.5*pow(smoothstep(0.,.36,t),.55)*(1.-.12*smoothstep(.8,1.,t))
		var f:=freeboard+sheer*pow(1.-t,2.)
		var d:=draft*(.35+.65*sin(PI*clampf(t*.9+.05,0.,1.)))
		# Open boats (canoes, rowing boats) have inner walls down to low floorboards instead of a deck.
		var inner_l:=Vector3(-w*.97,f,z) if open_floor<0. else Vector3(-w*.78,open_floor,z)
		var inner_r:=Vector3(w*.97,f,z) if open_floor<0. else Vector3(w*.78,open_floor,z)
		rings.append([Vector3(0,-d,z),Vector3(-w*.72,-d*.45,z),Vector3(-w*.98,-.05,z),Vector3(-w,.08,z),Vector3(-w*.995,f*.84,z),Vector3(-w*.99,f*.86,z),
			Vector3(-w*.975,f*.95,z),Vector3(-w*.97,f,z),inner_l,inner_r,Vector3(w*.97,f,z),Vector3(w*.975,f*.95,z),
			Vector3(w*.99,f*.86,z),Vector3(w*.995,f*.84,z),Vector3(w,.08,z),Vector3(w*.98,-.05,z),Vector3(w*.72,-d*.45,z)])
	var n:=17
	for s: int in sections:
		for k: int in n:
			var k2:=(k+1)%n
			var a: Vector3=rings[s][k];var b: Vector3=rings[s][k2];var c: Vector3=rings[s+1][k2];var dd: Vector3=rings[s+1][k]
			if a.distance_to(b)<.0001 and dd.distance_to(c)<.0001:continue
			st.set_color(colors[k]);st.add_vertex(a);st.set_color(colors[k2]);st.add_vertex(b);st.set_color(colors[k2]);st.add_vertex(c)
			st.set_color(colors[k]);st.add_vertex(a);st.set_color(colors[k2]);st.add_vertex(c);st.set_color(colors[k]);st.add_vertex(dd)
	if not pointed_stern:
		var last: Array=rings[sections];var centre:=Vector3.ZERO
		for p: Vector3 in last:centre+=p
		centre/=float(n)
		for k: int in n:
			st.set_color(hull);st.add_vertex(centre);st.set_color(colors[k]);st.add_vertex(last[k]);st.set_color(colors[(k+1)%n]);st.add_vertex(last[(k+1)%n])
	st.generate_normals()
	var node:=MeshInstance3D.new();node.name="Casco";node.mesh=st.commit();node.material_override=mat;root.add_child(node)
	root.set_meta("deck",freeboard)

## Cloth panel through three or four corners, subdivided and bellied out sideways by `belly` metres.
static func _sail(root: Node3D,corners: Array,color: Color,belly: float) -> MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad:=corners.size()==4
	var steps:=6
	var grid: Array=[]
	for i: int in steps+1:
		var row: Array=[]
		for j: int in steps+1:
			var u:=float(i)/steps;var v:=float(j)/steps
			var p: Vector3
			if quad:p=(corners[0] as Vector3).lerp(corners[1],u).lerp((corners[3] as Vector3).lerp(corners[2],u),v)
			else:p=(corners[0] as Vector3).lerp(corners[1],u).lerp(corners[2],v)
			var shape:=sin(PI*u)*sin(PI*v) if quad else sin(PI*u)*(1.-v)*minf(1.,v*4.)
			p.x+=belly*shape
			row.append([p,Color(1,1,1).lerp(Color(.86,.84,.78),v*.4)])
		grid.append(row)
	for i: int in steps:
		for j: int in steps:
			for tri: Array in [[[i,j],[i+1,j],[i+1,j+1]],[[i,j],[i+1,j+1],[i,j+1]]]:
				for idx: Array in tri:
					var cell: Array=grid[idx[0]][idx[1]]
					st.set_color(cell[1]);st.add_vertex(cell[0])
	st.generate_normals()
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.vertex_color_use_as_albedo=true;mat.roughness=.85;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.backlight_enabled=true;mat.backlight=Color(.35,.33,.3)
	var node:=MeshInstance3D.new();node.name="Vela";node.mesh=st.commit();node.material_override=mat;root.add_child(node)
	(root.get_meta("sails") as Array).append(node)
	return node

static func _line(root: Node3D,a: Vector3,b: Vector3,mat: Material,thickness: float=.018) -> void:
	_detail(G.beam(root,a,b,thickness,mat))

## Three-stripe flag on its own pivot so traffic_vessel can wave it.
static func _flag(root: Node3D,at: Vector3,size: float,rng: RandomNumberGenerator) -> void:
	var colors: Array=_pick(rng,FLAGS)
	var pivot:=Node3D.new();pivot.name="Bandeira";pivot.position=at;root.add_child(pivot)
	var vertical:=rng.randf()<.5
	for i: int in 3:
		var stripe: Node3D
		if vertical:stripe=G.box(pivot,Vector3(0,-size*.5,size*(.25+float(i)*.5)),Vector3(.02,size,size*.5),_mat(colors[i],.9))
		else:stripe=G.box(pivot,Vector3(0,-size*(1./6.+float(i)/3.),size*.75),Vector3(.02,size/3.,size*1.5),_mat(colors[i],.9))
		_detail(stripe)
	root.set_meta("flag",pivot)

static func _nav_lights(root: Node3D,port: Vector3,starboard: Vector3,masthead: Vector3) -> void:
	for data: Array in [[port,Color("ff3b30")],[starboard,Color("34e07a")],[masthead,Color("fff4d6")]]:
		var m:=_mat(data[1],.4);m.emission_enabled=true;m.emission=data[1];m.emission_energy_multiplier=2.5
		_detail(G.sphere(root,data[0],Vector3.ONE*.18,m,8))

static func _windows(root: Node3D,centre: Vector3,width: float,height: float,count: int,facing_x: bool=false) -> void:
	var mat: StandardMaterial3D=root.get_meta("windows")
	for i: int in count:
		var off:=(float(i)-float(count-1)*.5)*width/float(count)
		var size:=Vector3(.06,height,width/float(count)*.7) if facing_x else Vector3(width/float(count)*.7,height,.06)
		var pos:=centre+(Vector3(0,0,off) if facing_x else Vector3(off,0,0))
		G.box(root,pos,size,mat)

## Containers drawn as one MultiMesh with per-box colours.
static func _containers(root: Node3D,lanes: int,rows: int,levels: int,base_y: float,z_from: float,rng: RandomNumberGenerator) -> void:
	var box:=BoxMesh.new();box.size=Vector3(2.4,2.55,6.)
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=box
	var palette: Array[Color]=[Color("b5332b"),Color("1f5f8b"),Color("e0a526"),Color("3d8b5a"),Color("6d6f73"),Color("c45c26"),Color("2a3f6b"),Color("e8e2d4")]
	var items: Array=[]
	for lane: int in lanes:
		for row: int in rows:
			var height:=levels-(rng.randi()%2 if rng.randf()<.35 else 0)
			for level: int in height:
				var x:=(float(lane)-float(lanes-1)*.5)*2.55
				items.append([Vector3(x,base_y+1.28+float(level)*2.6,z_from+float(row)*6.3),palette[rng.randi()%palette.size()]])
	mm.instance_count=items.size()
	for i: int in items.size():
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,items[i][0]));mm.set_instance_color(i,(items[i][1] as Color).darkened(rng.randf()*.15))
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.6
	var node:=MultiMeshInstance3D.new();node.name="Conteineres";node.multimesh=mm;node.material_override=mat;root.add_child(node)

# ---------------------------------------------------------------- kinds
static func _canoa(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var wood: Color=_pick(rng,[Color("8a5a2b"),Color("a0522d"),Color("6b4226"),Color("b8433a"),Color("2f6f8f")])
	_hull(root,L,.95,.42,.16,wood,wood.darkened(.35),wood.lightened(.25),Color("c9a46a"),true,.18,.06)
	var oak:=_mat(Color("d8b07a"))
	for i: int in 2:_detail(G.box(root,Vector3(0,.3,(float(i)-.5)*L*.38),Vector3(.8,.04,.22),oak))
	_seat(root,Vector3(0,-.42,-L*.19),0.);_seat(root,Vector3(0,-.42,L*.19),0.)
	var paddle:=Node3D.new();paddle.name="Remo";paddle.position=Vector3(.42,.75,-L*.19);root.add_child(paddle)
	_detail(G.beam(paddle,Vector3(0,.3,0),Vector3(.25,-.85,.1),.03,oak));_detail(G.box(paddle,Vector3(.25,-.95,.1),Vector3(.04,.42,.16),oak))
	(root.get_meta("oars") as Array).append(paddle)
	root.set_meta("crew",rng.randi_range(1,2));root.set_meta("helm",Vector3(0,-.42,L*.19))
	_cargo(root,Vector3(0,-.38,0),.7,rng)

static func _bote_remo(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("f2f0ea"),Color("2f6fb0"),Color("3d8b5a"),Color("c8553d"),Color("e0b040")])
	_hull(root,L,1.65,.58,.22,paint,Color("6e2b25"),Color("2a2a2a") if paint.v>.6 else Color("f2f0ea"),Color("9c7a4e"),false,.2,.08)
	var wood:=_mat(Color("9c7a4e"))
	for z: float in [-L*.22,0.,L*.25]:_detail(G.box(root,Vector3(0,.42,z),Vector3(1.4,.05,.26),wood))
	# The rower sits on the middle thwart facing aft and pulls two oars.
	_seat(root,Vector3(0,-.36,0.),PI);root.set_meta("helm",Vector3(0,-.36,0.))
	for side: float in [-1.,1.]:
		var oar:=Node3D.new();oar.name="Remo";oar.position=Vector3(side*.78,.62,-.15);root.add_child(oar)
		_detail(G.beam(oar,Vector3(-side*.6,.15,0),Vector3(side*1.7,-.55,0),.03,wood));_detail(G.box(oar,Vector3(side*1.75,-.6,0),Vector3(.38,.04,.14),wood))
		(root.get_meta("oars") as Array).append(oar)
	if rng.randf()<.5:_seat(root,Vector3(0,-.36,L*.25),PI)
	else:_cargo(root,Vector3(0,-.32,L*.24),1.2,rng)
	root.set_meta("crew",(root.get_meta("seats") as Array).size())

static func _bote(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("2f6fb0"),Color("f2f2ee"),Color("c8553d"),Color("2e7d6b"),Color("e9c46a")])
	_hull(root,L,2.4,.95,.4,paint,Color("7a2620"),Color("f2f2ee") if paint.v<.7 else Color("1f3d5c"),Color("b9b4a6"),false,.25)
	var white:=_mat(Color("f2f2ee"))
	G.box(root,Vector3(0,1.55,-L*.05),Vector3(1.8,1.2,1.9),white);G.box(root,Vector3(0,2.2,-L*.05),Vector3(2.,.1,2.1),_mat(paint.darkened(.2)))
	_windows(root,Vector3(0,1.75,-L*.05-.97),1.5,.45,2)
	_detail(G.cylinder(root,Vector3(0,3.,-L*.05),.04,1.6,_mat(Color("8a8f96"),.4,.5)))
	_detail(G.box(root,Vector3(.6,1.15,L*.3),Vector3(.6,.38,.6),_mat(Color("e0b040"))))
	_nav_lights(root,Vector3(-.95,2.25,-L*.05),Vector3(.95,2.25,-L*.05),Vector3(0,3.85,-L*.05))
	_flag(root,Vector3(0,2.1,L*.48),.5,rng);_detail(G.cylinder(root,Vector3(0,1.55,L*.48),.025,1.2,white))
	root.set_meta("helm",Vector3(0,.95,L*.05));root.set_meta("walk",[Vector3(0,.95,L*.12),Vector3(0,.95,L*.4)])
	_rail(root,Vector3(-.85,.95,L*.32),PI*.5);_rail(root,Vector3(.85,.95,L*.36),-PI*.5)
	root.set_meta("crew",rng.randi_range(1,2))

static func _pesqueiro(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("c8553d"),Color("1f4e79"),Color("2e6b4f"),Color("e3b23c"),Color("3a3a3a")])
	var f:=1.6
	_hull(root,L,L*.32,f,.7,paint,Color("6e1f1a"),Color("f2f2ee"),Color("8a8578"),false,.6)
	var white:=_mat(Color("eeeeea"))
	var house_z:=-L*.12
	G.box(root,Vector3(0,f+1.,house_z),Vector3(L*.22,2.,L*.2),white)
	G.box(root,Vector3(0,f+2.1,house_z),Vector3(L*.24,.18,L*.22),_mat(paint.darkened(.25)))
	_windows(root,Vector3(0,f+1.45,house_z-L*.1-.01),L*.19,.6,4)
	var steel:=_mat(Color("9aa3a8"),.4,.6)
	_detail(G.cylinder(root,Vector3(0,f+4.,house_z),.08,4.,steel))
	for side: float in [-1.,1.]:
		_detail(G.beam(root,Vector3(side*L*.12,f,L*.3),Vector3(0,f+4.5,L*.3),.09,steel))
		_detail(G.beam(root,Vector3(side*L*.08,f+3.,house_z),Vector3(side*L*.45,f+1.5,house_z+1.),.05,steel))
	var net:=_mat(Color("2d5a3f"),.95)
	_detail(G.cylinder(root,Vector3(0,f+.55,L*.38),.55,L*.22,net,.55,10)).rotation.z=PI*.5
	for i: int in rng.randi_range(2,5):
		_detail(G.box(root,Vector3(rng.randf_range(-L*.1,L*.1),f+.25,rng.randf_range(L*.05,L*.25)),Vector3(.8,.5,.8),_mat(_pick(rng,[Color("e0b040"),Color("4a8fd0"),Color("d9534f"),Color("e8e8e8")]))))
	_nav_lights(root,Vector3(-L*.12,f+2.2,house_z),Vector3(L*.12,f+2.2,house_z),Vector3(0,f+6.1,house_z))
	_flag(root,Vector3(0,f+2.6,L*.47),.8,rng);_detail(G.cylinder(root,Vector3(0,f+1.7,L*.47),.03,1.8,white))
	root.set_meta("helm",Vector3(0,f,house_z+L*.04));root.set_meta("walk",[Vector3(-L*.08,f,L*.02),Vector3(-L*.08,f,L*.32)])
	_rail(root,Vector3(-L*.14,f,L*.22),PI*.5);_rail(root,Vector3(L*.14,f,L*.18),-PI*.5);_rail(root,Vector3(L*.1,f,L*.42),PI)
	root.set_meta("crew",rng.randi_range(3,4))

static func _veleiro(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("f4f4f0"),Color("1f3d5c"),Color("2e6b8a"),Color("7a1f2b"),Color("f4f4f0")])
	var f:=1.1
	_hull(root,L,L*.32,f,.45,paint,Color("23395d"),Color("c9a227") if paint.v<.5 else Color("1f3d5c"),Color("c8a878"),false,.3)
	G.box(root,Vector3(0,-.95,L*.02),Vector3(.12,1.3,L*.26),_mat(Color("2a2a2a")))
	var cabin:=_mat(Color("f4f4f0") if paint.v<.5 else Color("e4dccb"))
	G.box(root,Vector3(0,f+.3,-L*.02),Vector3(L*.18,.6,L*.3),cabin)
	_windows(root,Vector3(L*.09+.01,f+.35,-L*.02),L*.22,.18,3,true);_windows(root,Vector3(-L*.09-.01,f+.35,-L*.02),L*.22,.18,3,true)
	var mast_z:=-L*.12;var mast_h:=L*1.25
	var spar:=_mat(Color("c9ccd0"),.35,.6)
	G.cylinder(root,Vector3(0,f+mast_h*.5,mast_z),.07,mast_h,spar)
	_detail(G.beam(root,Vector3(0,f+1.,mast_z),Vector3(0,f+1.1,mast_z+L*.42),.06,spar))
	var cloth: Color=_pick(rng,[Color("f7f4ec"),Color("f7f4ec"),Color("efe6d2"),Color("e9e3d6")])
	_sail(root,[Vector3(0,f+1.1,mast_z+.1),Vector3(0,f+1.15,mast_z+L*.41),Vector3(0,f+mast_h*.95,mast_z+.1)],cloth,L*.035)
	_sail(root,[Vector3(0,f+.4,-L*.46),Vector3(0,f+.6,mast_z-.15),Vector3(0,f+mast_h*.86,mast_z-.05)],cloth,L*.03)
	var rope:=_mat(Color("3a3a3a"),.8)
	_line(root,Vector3(0,f+mast_h,mast_z),Vector3(0,f+.3,-L*.48),rope)
	_line(root,Vector3(0,f+mast_h,mast_z),Vector3(0,f+.6,L*.48),rope)
	for side: float in [-1.,1.]:_line(root,Vector3(0,f+mast_h*.8,mast_z),Vector3(side*L*.15,f,mast_z+L*.05),rope)
	_nav_lights(root,Vector3(-L*.14,f+.2,-L*.4),Vector3(L*.14,f+.2,-L*.4),Vector3(0,f+mast_h+.1,mast_z))
	_flag(root,Vector3(0,f+1.4,L*.5),.55,rng);_detail(G.cylinder(root,Vector3(0,f+.7,L*.5),.025,1.4,spar))
	root.set_meta("helm",Vector3(0,f-.2,L*.36));root.set_meta("walk",[Vector3(L*.08,f,-L*.25),Vector3(L*.08,f,L*.2)])
	_rail(root,Vector3(-L*.08,f,-L*.34),0.);_rail(root,Vector3(L*.1,f,L*.3),-PI*.5)
	root.set_meta("crew",rng.randi_range(2,3))

static func _escuna(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("1d1d1d"),Color("2b3a55"),Color("5a2a1f"),Color("1f4d3a")])
	var f:=2.2
	_hull(root,L,L*.25,f,1.3,paint,Color("6e1f1a"),Color("c9a227"),Color("b08d5a"),false,.9)
	var wood:=_mat(Color("6b4f32"),.8);var spar:=_mat(Color("5a4026"),.8)
	_detail(G.beam(root,Vector3(0,f+.6,-L*.5),Vector3(0,f+1.6,-L*.68),.12,spar))
	G.box(root,Vector3(0,f+.55,L*.25),Vector3(L*.14,1.1,L*.16),wood)
	_windows(root,Vector3(0,f+.65,L*.25-L*.08-.01),L*.1,.35,3)
	var cloth: Color=_pick(rng,[Color("efe6d2"),Color("e2d6bc"),Color("f2ede2"),Color("b7472a")])
	var rope:=_mat(Color("2a2420"),.85)
	for mast: Array in [[-L*.2,L*.95],[L*.08,L*1.05]]:
		var z: float=mast[0];var h: float=mast[1]
		G.cylinder(root,Vector3(0,f+h*.5,z),.16,h,spar)
		_detail(G.beam(root,Vector3(0,f+1.4,z+.2),Vector3(0,f+1.6,z+L*.24),.09,spar))
		_detail(G.beam(root,Vector3(0,f+h*.62,z+.2),Vector3(0,f+h*.86,z+L*.22),.08,spar))
		_sail(root,[Vector3(0,f+1.5,z+.25),Vector3(0,f+1.6,z+L*.23),Vector3(0,f+h*.84,z+L*.21),Vector3(0,f+h*.6,z+.25)],cloth,L*.03)
		for side: float in [-1.,1.]:
			_line(root,Vector3(0,f+h*.9,z),Vector3(side*L*.12,f,z+1.),rope);_line(root,Vector3(0,f+h*.9,z),Vector3(side*L*.12,f,z-1.),rope)
	_sail(root,[Vector3(0,f+1.,-L*.66),Vector3(0,f+.9,-L*.24),Vector3(0,f+L*.8,-L*.21)],cloth,L*.025)
	_line(root,Vector3(0,f+L*.95,-L*.2),Vector3(0,f+1.6,-L*.68),rope)
	_line(root,Vector3(0,f+L*1.05,L*.08),Vector3(0,f+L*.9,-L*.2),rope)
	for side: float in [-1.,1.]:
		var lamp:=_mat(Color("ffcf86"),.4);lamp.emission_enabled=true;lamp.emission=Color("ffb85c");lamp.emission_energy_multiplier=1.8
		_detail(G.sphere(root,Vector3(side*L*.11,f+1.3,L*.35),Vector3.ONE*.28,lamp,8))
	_nav_lights(root,Vector3(-L*.12,f+.6,-L*.3),Vector3(L*.12,f+.6,-L*.3),Vector3(0,f+L*1.05+.2,L*.08))
	_flag(root,Vector3(0,f+L*1.05+.1,L*.08),1.1,rng)
	root.set_meta("helm",Vector3(0,f,L*.4));root.set_meta("walk",[Vector3(-L*.07,f,-L*.35),Vector3(-L*.07,f,L*.15)])
	_rail(root,Vector3(L*.11,f,-L*.1),-PI*.5);_rail(root,Vector3(-L*.11,f,L*.32),PI*.5);_rail(root,Vector3(0,f,-L*.42),0.)
	root.set_meta("crew",rng.randi_range(3,5))

static func _rebocador(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("d9622b"),Color("c0392b"),Color("1f4e79"),Color("2a2a2a"),Color("e3b23c")])
	var f:=2.4
	_hull(root,L,L*.34,f,1.2,paint,Color("3a1a14"),Color("f2f2ee"),Color("6f6a5f"),false,.7)
	var white:=_mat(Color("f4f4f4"))
	G.box(root,Vector3(0,f+1.3,-L*.08),Vector3(L*.24,2.6,L*.24),white)
	G.box(root,Vector3(0,f+3.3,-L*.12),Vector3(L*.2,1.4,L*.14),white)
	_windows(root,Vector3(0,f+3.45,-L*.19-.01),L*.18,.6,5)
	var band: Color=_pick(rng,[Color("c0392b"),Color("1f4e79"),Color("e3b23c"),Color("2e7d6b")])
	G.cylinder(root,Vector3(0,f+3.4,L*.12),.6,2.6,_mat(Color("1a1a1a")),.7,12)
	_detail(G.cylinder(root,Vector3(0,f+4.,L*.12),.68,.5,_mat(band),.68,12))
	_detail(G.cylinder(root,Vector3(0,f+5.5,-L*.12),.07,3.,_mat(Color("9aa3a8"),.4,.6)))
	var tyre:=_mat(Color("161616"),.95)
	for i: int in 5:
		for side: float in [-1.,1.]:
			_detail(G.cylinder(root,Vector3(side*L*.17,f*.6,-L*.3+float(i)*L*.15),.35,.22,tyre,.35,10)).rotation.z=PI*.5
	_nav_lights(root,Vector3(-L*.1,f+4.1,-L*.12),Vector3(L*.1,f+4.1,-L*.12),Vector3(0,f+7.1,-L*.12))
	_flag(root,Vector3(0,f+2.4,L*.48),.8,rng)
	root.set_meta("helm",Vector3(0,f+2.6,-L*.1));root.set_meta("walk",[Vector3(L*.1,f,L*.05),Vector3(L*.1,f,L*.4)])
	_rail(root,Vector3(-L*.12,f,L*.3),PI*.5)
	root.set_meta("crew",2)

static func _apoio(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("36506e"),Color("e65c19"),Color("2e6b4f"),Color("c0392b"),Color("f2f2ee")])
	var f:=3.
	_hull(root,L,L*.28,f,1.6,paint,Color("4a1a14"),Color("f2f2ee") if paint.v<.8 else Color("36506e"),Color("7a7a72"),false,1.)
	var white:=_mat(Color("f0f0f0"))
	G.box(root,Vector3(0,f+2.,-L*.28),Vector3(L*.24,4.,L*.2),white)
	G.box(root,Vector3(0,f+4.6,-L*.3),Vector3(L*.26,1.2,L*.14),_mat(Color("2e4a63")))
	_windows(root,Vector3(0,f+4.6,-L*.37-.02),L*.22,.7,6);_windows(root,Vector3(0,f+2.6,-L*.38-.01),L*.2,.5,4)
	_detail(G.cylinder(root,Vector3(0,f+7.,-L*.3),.12,4.,_mat(Color("8a8a8a"),.4,.6)))
	_containers(root,2,rng.randi_range(2,4),1,f,L*.0,rng)
	_detail(G.beam(root,Vector3(L*.08,f+.5,L*.32),Vector3(L*.08,f+8.,L*.1),.18,_mat(Color("ffc400"),.4)))
	_nav_lights(root,Vector3(-L*.13,f+4.9,-L*.3),Vector3(L*.13,f+4.9,-L*.3),Vector3(0,f+9.,-L*.3))
	_flag(root,Vector3(0,f+2.5,L*.49),1.,rng)
	root.set_meta("helm",Vector3(0,f+4.,-L*.3));root.set_meta("walk",[Vector3(-L*.1,f,-L*.1),Vector3(-L*.1,f,L*.42)])
	_rail(root,Vector3(L*.13,f,L*.4),-PI*.5)
	root.set_meta("crew",3)

static func _cargueiro(root: Node3D,L: float,rng: RandomNumberGenerator,lanes: int,levels: int) -> void:
	var paint: Color=_pick(rng,[Color("1f3d5c"),Color("7a1f2b"),Color("2a2a2a"),Color("1f5f4b"),Color("3a4a5a"),Color("c45c26")])
	var beam:=float(lanes)*2.55+2.4
	var f:=maxf(4.5,L*.07)
	_hull(root,L,beam,f,L*.045,paint,Color("8a2a20"),Color("f2f2ee"),Color("6b6b62"),false,L*.012)
	var white:=_mat(Color("f2f2ee"))
	var bridge_z:=L*.36;var bridge_h:=8.+float(levels)*2.4
	G.box(root,Vector3(0,f+bridge_h*.5,bridge_z),Vector3(beam*.62,bridge_h,L*.09),white)
	G.box(root,Vector3(0,f+bridge_h+.3,bridge_z-L*.01),Vector3(beam*1.02,.6,L*.06),_mat(Color("2a2a2a")))
	for floor_i: int in int(bridge_h/2.6):
		var wy:=f+1.5+float(floor_i)*2.6
		_windows(root,Vector3(0,wy,bridge_z-L*.045-.02),beam*.55,.7,8)
		for side: float in [-1.,1.]:_windows(root,Vector3(side*(beam*.31+.02),wy,bridge_z),L*.07,.7,4,true)
	G.cylinder(root,Vector3(0,f+bridge_h+2.,bridge_z+L*.05),beam*.08,5.,_mat(Color("2a2a2a")),beam*.08,12)
	var rows:=int(L*.62/6.3)
	_containers(root,lanes,rows,levels,f,-L*.4,rng)
	_detail(G.cylinder(root,Vector3(0,f+bridge_h+4.,bridge_z),.15,6.,_mat(Color("9a9a9a"),.4,.6)))
	_nav_lights(root,Vector3(-beam*.5,f+bridge_h,bridge_z),Vector3(beam*.5,f+bridge_h,bridge_z),Vector3(0,f+bridge_h+7.,bridge_z))
	_flag(root,Vector3(0,f+4.,L*.5),1.6,rng);_detail(G.cylinder(root,Vector3(0,f+2.,L*.5),.06,4.,white))
	root.set_meta("helm",Vector3(0,f+bridge_h-1.9,bridge_z-L*.02));root.set_meta("walk",[Vector3(beam*.42,f,-L*.4),Vector3(beam*.42,f,L*.3)])
	_rail(root,Vector3(-beam*.45,f,L*.32),PI*.5)
	root.set_meta("crew",3)

static func _petroleiro(root: Node3D,L: float,rng: RandomNumberGenerator) -> void:
	var paint: Color=_pick(rng,[Color("2a2a2a"),Color("7a1f2b"),Color("1f3d5c"),Color("ececec")])
	var beam:=L*.15;var f:=L*.06
	_hull(root,L,beam,f,L*.05,paint,Color("8a2a20"),Color("f2f2ee") if paint.v<.8 else Color("2a2a2a"),Color("8a2f24"),false,L*.01)
	var white:=_mat(Color("f5f5f5"))
	var bridge_z:=L*.38
	G.box(root,Vector3(0,f+8.,bridge_z),Vector3(beam*.6,16.,L*.08),white)
	G.box(root,Vector3(0,f+16.3,bridge_z-L*.01),Vector3(beam*1.02,.7,L*.05),_mat(Color("333333")))
	for floor_i: int in 5:
		var wy:=f+2.+float(floor_i)*2.8
		_windows(root,Vector3(0,wy,bridge_z-L*.04-.02),beam*.5,.8,9)
		for side: float in [-1.,1.]:_windows(root,Vector3(side*(beam*.3+.02),wy,bridge_z),L*.06,.8,5,true)
	G.cylinder(root,Vector3(0,f+19.,bridge_z+L*.04),beam*.09,6.,_mat(Color("2a2a2a")),beam*.08,12)
	var pipe:=_mat(Color("b8a04a"),.5,.4)
	for x: float in [-2.,0.,2.]:_detail(G.beam(root,Vector3(x,f+.6,-L*.44),Vector3(x,f+.6,L*.32),.3,pipe))
	_detail(G.beam(root,Vector3(0,f+2.2,-L*.44),Vector3(0,f+2.2,L*.33),.25,_mat(Color("8a8f96"),.5,.5)))
	for i: int in 6:_detail(G.box(root,Vector3(0,f+.8,-L*.35+float(i)*L*.12),Vector3(beam*.7,.8,1.2),_mat(Color("6b6b62"))))
	_nav_lights(root,Vector3(-beam*.5,f+16.,bridge_z),Vector3(beam*.5,f+16.,bridge_z),Vector3(0,f+22.,bridge_z))
	_flag(root,Vector3(0,f+5.,L*.5),2.,rng)
	root.set_meta("helm",Vector3(0,f+14.2,bridge_z-L*.02));root.set_meta("walk",[Vector3(beam*.38,f,-L*.4),Vector3(beam*.38,f,L*.3)])
	_rail(root,Vector3(-beam*.4,f,-L*.45),0.)
	root.set_meta("crew",2)
