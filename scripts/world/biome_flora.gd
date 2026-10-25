extends RefCounted
## Procedural vegetation for the remote islands: one low-poly mesh per kind, planted as a single MultiMesh per kind and island.
## Vertex colours carry the palette; per-instance colour and scale give every plant its own look.
const KINDS: Array[String]=["cactus","agave","dead","charred","pine","snowpine","windpine","twisted_violet","twisted_teal","shrub","reed"]
static var meshes: Dictionary={}
static var material: StandardMaterial3D

static func mat() -> StandardMaterial3D:
	if material==null:
		material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.92
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

static func height_of(kind: String) -> float:
	return {"cactus":3.6,"agave":1.3,"dead":5.5,"charred":5.,"pine":9.,"snowpine":8.,"windpine":7.,"twisted_violet":6.5,"twisted_teal":6.5,"shrub":1.4,"reed":1.6}.get(kind,4.)

static func mesh(kind: String) -> ArrayMesh:
	if meshes.has(kind):return meshes[kind]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"cactus":_cactus(st)
		"agave":_agave(st)
		"dead":_dead(st,Color("6d5f52"),Color("8a7b69"),5.5,4)
		"charred":_dead(st,Color("231f1f"),Color("3b2c27"),5.,5)
		"pine":_pine(st,Color("5a3a24"),Color("2b5a35"),Color("3b7447"),9.,0.)
		"snowpine":_pine(st,Color("5a3a24"),Color("34584b"),Color("e8f1f2"),8.,0.)
		"windpine":_pine(st,Color("4a3425"),Color("35523a"),Color("4a6a45"),7.,1.8)
		"twisted_violet":_twisted(st,Color("34243f"),Color("7b43b8"),Color("b56cff"))
		"twisted_teal":_twisted(st,Color("2b4147"),Color("2fa6a2"),Color("7bf0e0"))
		"shrub":_shrub(st)
		"reed":_reed(st)
	st.generate_normals()
	var result:=st.commit();meshes[kind]=result;return result

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,col: Color) -> void:
	for p: Vector3 in [a,b,c]:
		st.set_color(col);st.add_vertex(p)

## Frustum from a to b, radii ra/rb. Tip colour blends towards col_top.
static func _frustum(st: SurfaceTool,a: Vector3,b: Vector3,ra: float,rb: float,col: Color,col_top: Color,segs: int=6) -> void:
	var axis:=(b-a).normalized()
	var side:=axis.cross(Vector3.RIGHT if absf(axis.x)<.9 else Vector3.UP).normalized()
	var fwd:=axis.cross(side)
	for i: int in segs:
		var t0:=float(i)/float(segs)*TAU;var t1:=float(i+1)/float(segs)*TAU
		var d0:=side*cos(t0)+fwd*sin(t0);var d1:=side*cos(t1)+fwd*sin(t1)
		var p0:=a+d0*ra;var p1:=a+d1*ra;var q0:=b+d0*rb;var q1:=b+d1*rb
		st.set_color(col);st.add_vertex(p0);st.set_color(col_top);st.add_vertex(q1);st.set_color(col_top);st.add_vertex(q0)
		st.set_color(col);st.add_vertex(p0);st.set_color(col);st.add_vertex(p1);st.set_color(col_top);st.add_vertex(q1)

static func _cap(st: SurfaceTool,center: Vector3,radius: float,col: Color,segs: int=6) -> void:
	for i: int in segs:
		var t0:=float(i)/float(segs)*TAU;var t1:=float(i+1)/float(segs)*TAU
		_tri(st,center,center+Vector3(cos(t0),0,sin(t0))*radius,center+Vector3(cos(t1),0,sin(t1))*radius,col)

static func _blob(st: SurfaceTool,center: Vector3,size: Vector3,col_lo: Color,col_hi: Color,segs: int=7) -> void:
	# Squashed double cone ring: a cheap faceted canopy.
	var ring:=[]
	for i: int in segs:ring.append(Vector3(cos(float(i)/segs*TAU),0,sin(float(i)/segs*TAU)))
	var top:=center+Vector3(0,size.y,0);var bottom:=center-Vector3(0,size.y*.7,0)
	for i: int in segs:
		var a:Vector3=center+ring[i]*size*Vector3(1,0,1);var b:Vector3=center+ring[(i+1)%segs]*size*Vector3(1,0,1)
		st.set_color(col_hi);st.add_vertex(top);st.set_color(col_lo);st.add_vertex(b);st.set_color(col_lo);st.add_vertex(a)
		st.set_color(col_lo);st.add_vertex(bottom);st.set_color(col_lo);st.add_vertex(a);st.set_color(col_lo);st.add_vertex(b)

static func _cactus(st: SurfaceTool) -> void:
	var green:=Color("4f7b45");var light:=Color("78a35c")
	_frustum(st,Vector3.ZERO,Vector3(0,3.2,0),.38,.3,green,light,7)
	_frustum(st,Vector3(0,3.2,0),Vector3(0,3.6,0),.3,0.,light,light,7)
	_frustum(st,Vector3(0,1.3,0),Vector3(.9,1.5,0),.18,.18,green,green,6)
	_frustum(st,Vector3(.9,1.5,0),Vector3(1.0,2.6,0),.18,.15,green,light,6)
	_frustum(st,Vector3(1.0,2.6,0),Vector3(1.0,2.85,0),.15,0.,light,light,6)
	_frustum(st,Vector3(0,1.9,0),Vector3(-.75,2.05,.2),.16,.16,green,green,6)
	_frustum(st,Vector3(-.75,2.05,.2),Vector3(-.85,2.9,.2),.16,.13,green,light,6)
	_frustum(st,Vector3(-.85,2.9,.2),Vector3(-.85,3.1,.2),.13,0.,light,light,6)

static func _agave(st: SurfaceTool) -> void:
	for i: int in 11:
		var a:=float(i)*TAU/11.+float(i%3)*.2;var lean:=.9+float(i%2)*.35
		var base:=Vector3(cos(a)*.05,0,sin(a)*.05);var tip:=Vector3(cos(a)*lean,.65+float(i%3)*.25,sin(a)*lean)
		var side:=Vector3(-sin(a),0,cos(a))*.16
		var mid:=base.lerp(tip,.45)+Vector3(0,.18,0)
		var col:=Color("6a9a7a").lerp(Color("a4c78f"),float(i%3)/3.)
		_tri(st,base-side*.4,mid-side,mid+side,col.darkened(.15));_tri(st,mid-side,tip,mid+side,col)

static func _dead(st: SurfaceTool,bark: Color,tip: Color,h: float,branches: int) -> void:
	_frustum(st,Vector3.ZERO,Vector3(.15,h*.62,0),.38,.2,bark.darkened(.2),bark,6)
	_frustum(st,Vector3(.15,h*.62,0),Vector3(-.1,h,.1),.2,0.,bark,tip,6)
	for i: int in branches:
		var y:=h*(.35+.12*float(i));var a:=float(i)*2.4+.5;var d:=Vector3(cos(a),0,sin(a))
		var from:=Vector3(.15*y/(h*.62),y,0)
		var mid:=from+d*1.1+Vector3(0,.7,0);var end:=mid+d*.8+Vector3(0,.9,0)
		_frustum(st,from,mid,.13,.09,bark,bark,5);_frustum(st,mid,end,.09,0.,bark,tip,5)

static func _pine(st: SurfaceTool,bark: Color,dark: Color,light: Color,h: float,lean: float) -> void:
	var bend:=func(y: float) -> Vector3: return Vector3(lean*pow(y/h,2.),y,lean*.35*pow(y/h,2.))
	_frustum(st,Vector3.ZERO,bend.call(h*.35),.34,.24,bark,bark,6)
	var tiers:=5
	for i: int in tiers:
		var f:=float(i)/float(tiers)
		var y:=h*(.22+f*.62);var r:=h*.2*(1.-f*.72)+.35;var th:=h*.3*(1.-f*.35)
		var c:Vector3=bend.call(y)
		_frustum(st,c,c+Vector3(lean*.08,th,0),r,0.,dark.lerp(light,f*.4),light,8)
		_cap(st,c,r,dark.darkened(.25),8)

static func _twisted(st: SurfaceTool,bark: Color,leaf: Color,glow: Color) -> void:
	var p:=Vector3.ZERO
	var r:=.42
	for i: int in 4:
		var q:=p+Vector3(sin(float(i)*1.7)*.7,1.25,cos(float(i)*1.3)*.5)
		_frustum(st,p,q,r,r*.78,bark,bark.lightened(.08),6);p=q;r*=.78
	_blob(st,p+Vector3(0,.6,0),Vector3(2.5,1.1,2.5),leaf.darkened(.2),leaf)
	_blob(st,p+Vector3(1.5,-.3,.7),Vector3(1.4,.7,1.4),leaf.darkened(.1),glow)
	_blob(st,p+Vector3(-1.3,-.5,-.6),Vector3(1.2,.6,1.2),leaf.darkened(.25),leaf)

static func _shrub(st: SurfaceTool) -> void:
	_blob(st,Vector3(0,.55,0),Vector3(1.0,.7,1.0),Color("2f5f38"),Color("5c9a4a"))
	_blob(st,Vector3(.7,.4,.3),Vector3(.6,.45,.6),Color("33683b"),Color("6aa650"))
	_blob(st,Vector3(-.55,.35,-.4),Vector3(.55,.4,.55),Color("2c5a35"),Color("55904a"))

static func _reed(st: SurfaceTool) -> void:
	for i: int in 9:
		var a:=float(i)*2.4;var d:=Vector3(cos(a),0,sin(a));var h:=1.0+float(i%4)*.18
		_frustum(st,d*.18,d*.18+d*.28+Vector3(0,h,0),.05,0.,Color("5f7a3a"),Color("b5b86a"),4)

## Plants `transforms` of one kind as a single MultiMesh; each instance is tinted slightly.
static func plant(parent: Node3D,kind: String,transforms: Array[Transform3D],rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	if transforms.is_empty():return null
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh(kind);mm.instance_count=transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i,transforms[i])
		var v:=rng.randf_range(.8,1.12);mm.set_instance_color(i,Color(v,v*rng.randf_range(.94,1.06),v*rng.randf_range(.92,1.06)))
	var node:=MultiMeshInstance3D.new();node.name="flora_"+kind;node.multimesh=mm;node.material_override=mat()
	node.visibility_range_end=700.;node.visibility_range_end_margin=40.
	parent.add_child(node);return node
