extends RefCounted
## Wildlife and ground cover for the remote islands: wind-swept grass tufts (batched per 100 m cell), orbiting birds and
## pacing animals (both animated in the vertex shader), plus the lake/stream water material.
const Flora=preload("res://scripts/world/biome_flora.gd")
const CREATURE=preload("res://assets/shaders/island_creature.gdshader")
const GRASS=preload("res://assets/shaders/grass_tuft.gdshader")
const CELL: float=100.

# [base, tip, tufts per 1000 m2, height]
const GRASS_STYLE: Dictionary={
	"tropical":[Color("2a5e28"),Color("8fcf55"),9.,.9],
	"verdant":[Color("23441f"),Color("86b04c"),8.,.8],
	"mountain":[Color("2b4a2a"),Color("8aa65a"),6.,.8],
	"mystic":[Color("143a3c"),Color("5fe0cc"),6.,.9],
	"shadow":[Color("3a2a5c"),Color("9a70d0"),4.,.8],
	"storm":[Color("2a3a38"),Color("7f9a8e"),4.,.7],
	"frost":[Color("5f7f78"),Color("dbe9e6"),3.,.55],
	"desert":[Color("94703a"),Color("d9b86a"),2.5,.6],
	"volcanic":[Color("3a2a26"),Color("7a5a4a"),1.5,.5],
}
static var meshes: Dictionary={}
static var water: StandardMaterial3D

static func water_material() -> StandardMaterial3D:
	if water==null:
		water=StandardMaterial3D.new();water.albedo_color=Color(.07,.36,.52,.92);water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		water.roughness=.08;water.metallic=.1;water.emission_enabled=true;water.emission=Color(.01,.07,.12);water.cull_mode=BaseMaterial3D.CULL_DISABLED
	return water

static func tuft_mesh() -> ArrayMesh:
	if meshes.has("tuft"):return meshes["tuft"]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 7:
		var a:=float(i)*2.4;var d:=Vector3(cos(a),0,sin(a));var side:=Vector3(-d.z,0,d.x)*.06
		var root:=d*.12*float(1+i%3);var h:=.55+float(i%3)*.22
		var tip:=root+d*.18+Vector3(0,h,0);var mid:=root+d*.06+Vector3(0,h*.5,0)
		for v: Array in [[root-side,0.],[root+side,0.],[mid-side*.6,.5],[root+side,0.],[mid+side*.6,.5],[mid-side*.6,.5],[mid-side*.6,.5],[mid+side*.6,.5],[tip,1.]]:
			st.set_uv(Vector2(0,float(v[1])));st.add_vertex(v[0])
	st.generate_normals();meshes["tuft"]=st.commit();return meshes["tuft"]

## `points` are world positions; they are grouped in 100 m cells so distance culling works per cell.
static func plant_grass(parent: Node3D,biome: String,points: Array[Vector3],rng: RandomNumberGenerator) -> int:
	if points.is_empty():return 0
	var style: Array=GRASS_STYLE.get(biome,GRASS_STYLE["verdant"])
	var mat:=ShaderMaterial.new();mat.shader=GRASS
	var b: Color=(style[0] as Color).srgb_to_linear();var t: Color=(style[1] as Color).srgb_to_linear()
	mat.set_shader_parameter("base_color",Vector3(b.r,b.g,b.b));mat.set_shader_parameter("tip_color",Vector3(t.r,t.g,t.b))
	var cells: Dictionary={}
	for p: Vector3 in points:
		var key:=Vector2i(int(floorf(p.x/CELL)),int(floorf(p.z/CELL)))
		if not cells.has(key):cells[key]=[] as Array[Vector3]
		(cells[key] as Array[Vector3]).append(p)
	for key: Vector2i in cells:
		var list: Array[Vector3]=cells[key]
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=tuft_mesh();mm.instance_count=list.size()
		var centre:=Vector3.ZERO
		for i: int in list.size():
			var s:=float(style[3])*rng.randf_range(.45,.95)
			mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s*rng.randf_range(.9,1.3),s,s*rng.randf_range(.9,1.3))),list[i]));centre+=list[i]
		var node:=MultiMeshInstance3D.new();node.add_to_group("grama");node.name="grama";node.multimesh=mm;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=170.;node.visibility_range_end_margin=25.;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(node)
	return points.size()

# ---------------------------------------------------------------- creature meshes
static func _col(c: Color,a: float=1.) -> Color:
	return Color(c.r,c.g,c.b,a)

static func _leg(st: SurfaceTool,x: float,z: float,hip: float,col: Color,r: float=.07) -> void:
	Flora._frustum(st,Vector3(x,0,z),Vector3(x,hip,z),r*.8,r,_col(col,0.),_col(col,1.),5)

static func _quadruped(st: SurfaceTool,body: Color,belly: Color,length: float,height: float,neck: float,horn: int,ear: float) -> void:
	var hip:=height*.55
	Flora._blob(st,Vector3(0,hip+height*.2,0),Vector3(length*.5,height*.32,height*.3),_col(belly),_col(body))
	Flora._frustum(st,Vector3(length*.4,hip+height*.2,0),Vector3(length*.55,hip+height*.2+neck,0),height*.13,height*.08,_col(body),_col(body),6)
	Flora._blob(st,Vector3(length*.68,hip+height*.2+neck,0),Vector3(height*.2,height*.12,height*.12),_col(body.darkened(.1)),_col(body))
	for sx: float in [-1.,1.]:
		for sz: float in [-1.,1.]:
			_leg(st,sx*length*.3,sz*height*.17,hip,body.darkened(.18),height*.06)
	Flora._frustum(st,Vector3(-length*.5,hip+height*.3,0),Vector3(-length*.7,hip+height*.1,0),height*.03,.0,_col(body),_col(body),4)
	if ear>0.:
		for sz: float in [-1.,1.]:
			Flora._frustum(st,Vector3(length*.62,hip+height*.2+neck+height*.1,sz*height*.08),Vector3(length*.6,hip+height*.2+neck+height*.1+ear,sz*height*.14),height*.03,0.,_col(body),_col(body.darkened(.2)),4)
	for i: int in horn:
		var sz:=-1. if i%2==0 else 1.
		Flora._frustum(st,Vector3(length*.64,hip+height*.2+neck+height*.08,sz*height*.07),Vector3(length*.55,hip+height*.2+neck+height*.5,sz*height*.18),height*.025,0.,_col(Color("d8cfb8")),_col(Color("f2ecd9")),4)

static func creature_mesh(kind: String) -> ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"gaivota":_bird(st,Color("f2f3f1"),Color("b7bcc4"),Color("f0b13a"),1.)
		"corvo":_bird(st,Color("1d1c24"),Color("2e2d3a"),Color("3a3a40"),.9)
		"papagaio":_bird(st,Color("d9322f"),Color("2d6fd6"),Color("f5c02e"),.7)
		"urubu":_bird(st,Color("4a3a30"),Color("2d2420"),Color("c9b38a"),1.5)
		"capivara":_quadruped(st,Color("8a6a46"),Color("6e5238"),.95,.5,.04,0,.06)
		"cabra":_quadruped(st,Color("e8e4da"),Color("c9c4b8"),.95,.75,.22,2,.1)
		"cervo":_quadruped(st,Color("b07a4b"),Color("e7d3b0"),1.3,1.1,.5,2,.14)
		"cervo_mistico":_quadruped(st,Color("5ec9c0"),Color("e6fffb"),1.3,1.1,.5,2,.14)
		"lagarto":_quadruped(st,Color("8a8a4a"),Color("b8b268"),.9,.22,.0,0,0.)
		"caranguejo":_quadruped(st,Color("d9482f"),Color("f2a07c"),.34,.16,.0,0,0.)
		"pinguim":_penguin(st)
	st.generate_normals();meshes[kind]=st.commit();return meshes[kind]

static func _bird(st: SurfaceTool,body: Color,wing: Color,beak: Color,size: float) -> void:
	Flora._blob(st,Vector3.ZERO,Vector3(.5,.16,.16),_col(body.darkened(.1)),_col(body))
	Flora._frustum(st,Vector3(.45,.04,0),Vector3(.7,.04,0),.05,0.,_col(beak),_col(beak),4)
	Flora._frustum(st,Vector3(-.4,0,0),Vector3(-.85,.0,0),.12,.02,_col(body),_col(body),4)
	for sz: float in [-1.,1.]:
		var root:=Vector3(.12,.1,sz*.12);var mid:=Vector3(-.05,.14,sz*.8);var tip:=Vector3(-.5,.1,sz*1.5);var back:=Vector3(-.32,.05,sz*.18)
		for v: Array in [[root,1.],[mid,.5],[back,1.],[mid,.5],[tip,0.],[back,1.]]:
			st.set_color(_col(wing,float(v[1])));st.add_vertex(Vector3(v[0])*size)
		for v: Array in [[back,1.],[mid,.5],[root,1.],[back,1.],[tip,0.],[mid,.5]]:
			st.set_color(_col(wing.darkened(.1),float(v[1])));st.add_vertex(Vector3(v[0])*size)

static func _penguin(st: SurfaceTool) -> void:
	Flora._blob(st,Vector3(0,.42,0),Vector3(.2,.38,.17),_col(Color("f1f1ee")),_col(Color("1f2430")))
	Flora._blob(st,Vector3(.04,.82,0),Vector3(.12,.13,.11),_col(Color("1f2430")),_col(Color("22283a")))
	Flora._frustum(st,Vector3(.14,.82,0),Vector3(.24,.8,0),.03,0.,_col(Color("f0a13a")),_col(Color("f0a13a")),4)
	for sz: float in [-1.,1.]:
		_leg(st,0.,sz*.07,.1,Color("f0a13a"),.035)
		Flora._frustum(st,Vector3(0,.6,sz*.17),Vector3(-.12,.3,sz*.26),.03,.015,_col(Color("1f2430"),.0),_col(Color("1f2430"),1.),4)

## One MultiMesh of `count` orbiting birds around `centre`.
static func make_birds(parent: Node3D,kind: String,centre: Vector3,radius: float,count: int,rng: RandomNumberGenerator) -> void:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=creature_mesh(kind);mm.instance_count=count
	for i: int in count:
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3.ZERO))
		var dir:=1. if i%5!=0 else -1.
		mm.set_instance_custom_data(i,Color(radius*rng.randf_range(.45,1.1),dir*rng.randf_range(.05,.11)*(60./maxf(radius,40.)),rng.randf()*TAU,rng.randf_range(1.,1.5)*(1.8 if kind!="papagaio" else 1.)))
	var mat:=ShaderMaterial.new();mat.shader=CREATURE;mat.set_shader_parameter("fly",1.)
	var node:=MultiMeshInstance3D.new();node.add_to_group("aves");node.name="aves_"+kind;node.multimesh=mm;node.material_override=mat;node.position=centre
	node.custom_aabb=AABB(Vector3(-radius*1.3,-20,-radius*1.3),Vector3(radius*2.6,60,radius*2.6));node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end=1400.;parent.add_child(node)

## Animals pacing on small circles at the given flat spots.
static func make_animals(parent: Node3D,kind: String,spots: Array[Vector3],rng: RandomNumberGenerator,scale_range: Vector2=Vector2(.9,1.2)) -> void:
	if spots.is_empty():return
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=creature_mesh(kind);mm.instance_count=spots.size()
	var low:=spots[0];var high:=spots[0]
	for i: int in spots.size():
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,spots[i]))
		var r:=rng.randf_range(1.2,2.6)
		mm.set_instance_custom_data(i,Color(r,(1. if i%2==0 else -1.)*rng.randf_range(.05,.1)/r*2.,rng.randf()*TAU,rng.randf_range(scale_range.x,scale_range.y)))
		low=low.min(spots[i]);high=high.max(spots[i])
	var mat:=ShaderMaterial.new();mat.shader=CREATURE;mat.set_shader_parameter("fly",0.);mat.set_shader_parameter("bob",.04 if kind=="pinguim" else 0.)
	var node:=MultiMeshInstance3D.new();node.add_to_group("fauna");node.name="fauna_"+kind;node.multimesh=mm;node.material_override=mat
	node.custom_aabb=AABB(low-Vector3(6,1,6),(high-low)+Vector3(12,6,12))
	node.visibility_range_end=420.;node.visibility_range_end_margin=30.;parent.add_child(node)
