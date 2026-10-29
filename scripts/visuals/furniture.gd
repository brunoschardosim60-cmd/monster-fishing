extends RefCounted
## Furniture built from parts, the way a joiner would: frames with legs and rails, panelled doors,
## drawers with pulls, plank tops with an edge, turned details, cloth with folds. Every builder takes a
## parent, a position on the floor (the piece's footprint centre), a yaw and returns the piece's node.
## `solid` pieces get one box collider over their footprint so the player cannot walk through them.
## Materials are shared (one per colour) so many rooms cost few materials.
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
static var _mats: Dictionary={}

static func mat(kind: String,tint: Color,rough: float=.75,metal: float=0.) -> Material:
	var key:="%s%s%.2f%.2f"%[kind,tint.to_html(),rough,metal]
	if _mats.has(key):return _mats[key]
	var m: Material
	if kind=="flat":
		var s:=StandardMaterial3D.new();s.albedo_color=tint;s.roughness=rough;s.metallic=metal;m=s
	else:m=M.surface(kind,tint,1.2)
	_mats[key]=m
	return m

static func _piece(parent: Node3D,at: Vector3,yaw: float,name: String) -> Node3D:
	var n:=Node3D.new();n.name=name;n.position=at;n.rotation.y=yaw;parent.add_child(n)
	return n

static func _solid(piece: Node3D,size: Vector3) -> void:
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box
	shape.position=Vector3(0,size.y*.5,0);body.add_child(shape);piece.add_child(body)

static func _wood() -> Material:return mat("teak",Color("9c7651"))
static func _dark() -> Material:return mat("weathered_wood",Color("5a4632"))
static func _iron() -> Material:return mat("flat",Color("2e2b28"),.5,.5)
static func _brass() -> Material:return mat("flat",Color("b58d3f"),.32,.8)

## Turned leg: a square top block, a tapered round shaft, a bead and a foot.
static func _leg(p: Node3D,at: Vector3,h: float,w: float,m: Material) -> void:
	G.box(p,at+Vector3(0,h-w*1.5,0),Vector3(w,w*3.,w),m)
	G.cylinder(p,at+Vector3(0,(h-w*3.)*.5,0),w*.38,h-w*3.,m,w*.48,8)
	G.cylinder(p,at+Vector3(0,h*.62,0),w*.55,w*.35,m,w*.55,8)
	G.cylinder(p,at+Vector3(0,w*.25,0),w*.45,w*.5,m,w*.32,8)

## Table: plank top with a rounded edge, apron rails, four turned legs.
static func table(parent: Node3D,at: Vector3,yaw: float,size: Vector3=Vector3(1.4,.76,.85),solid: bool=true) -> Node3D:
	var p:=_piece(parent,at,yaw,"Mesa");var w:=_wood();var d:=_dark()
	var planks: int=maxi(3,int(size.x/.22))
	for i: int in planks:
		G.box(p,Vector3(-size.x*.5+(float(i)+.5)*size.x/float(planks),size.y-.02,0),Vector3(size.x/float(planks)-.006,.04,size.z),w)
	G.box(p,Vector3(0,size.y-.045,0),Vector3(size.x+.03,.025,size.z+.03),d)
	for sx: float in [-1.,1.]:
		G.box(p,Vector3(sx*(size.x*.5-.08),size.y-.13,0),Vector3(.025,.12,size.z-.16),d)
		for sz: float in [-1.,1.]:_leg(p,Vector3(sx*(size.x*.5-.08),0,sz*(size.z*.5-.08)),size.y-.05,.07,d)
	for sz: float in [-1.,1.]:G.box(p,Vector3(0,size.y-.13,sz*(size.z*.5-.08)),Vector3(size.x-.16,.12,.025),d)
	if solid:_solid(p,size)
	return p

## Chair: seat with a rim, turned legs, stretchers, a back with three spindles and a top rail.
static func chair(parent: Node3D,at: Vector3,yaw: float) -> Node3D:
	var p:=_piece(parent,at,yaw,"Cadeira");var w:=_wood();var d:=_dark()
	G.box(p,Vector3(0,.45,0),Vector3(.44,.04,.42),w)
	for sx: float in [-1.,1.]:
		for sz: float in [-1.,1.]:_leg(p,Vector3(sx*.18,0,sz*.17),.44,.045,d)
		G.box(p,Vector3(sx*.18,.16,0),Vector3(.022,.022,.34),d)
		G.beam(p,Vector3(sx*.18,.46,.18),Vector3(sx*.19,.98,.22),.035,d)
	for k: int in 3:G.beam(p,Vector3(-.1+float(k)*.1,.47,.19),Vector3(-.1+float(k)*.1,.9,.22),.018,d)
	G.box(p,Vector3(0,.95,.215),Vector3(.44,.07,.035),w)
	return p

## Wardrobe: carcass on bracket feet, two panelled doors with brass pulls, a moulded cornice.
static func wardrobe(parent: Node3D,at: Vector3,yaw: float,size: Vector3=Vector3(1.1,2.05,.62)) -> Node3D:
	var p:=_piece(parent,at,yaw,"Armario");var w:=_wood();var d:=_dark();var b:=_brass()
	G.box(p,Vector3(0,size.y*.5+.04,0),Vector3(size.x,size.y-.12,size.z),d)
	G.box(p,Vector3(0,size.y-.02,0),Vector3(size.x+.1,.06,size.z+.08),w)
	G.box(p,Vector3(0,size.y-.07,0),Vector3(size.x+.05,.05,size.z+.04),d)
	G.box(p,Vector3(0,.07,0),Vector3(size.x+.04,.06,size.z+.03),w)
	for sx: float in [-1.,1.]:
		for sz: float in [-1.,1.]:G.box(p,Vector3(sx*(size.x*.5-.05),.02,sz*(size.z*.5-.05)),Vector3(.1,.05,.1),d)
		# Door: stiles and rails round a sunk panel.
		var cx:=sx*size.x*.25;var fz:=-size.z*.5-.012;var dw:=size.x*.5-.04;var dh:=size.y-.32
		G.box(p,Vector3(cx,size.y*.5+.04,fz),Vector3(dw,dh,.02),w)
		for py: float in [.3,.68]:
			G.box(p,Vector3(cx,size.y*py+.04,fz-.012),Vector3(dw-.14,dh*.3,.012),d)
		G.cylinder(p,Vector3(sx*.05,size.y*.5,fz-.03),.016,.05,b,.02,8).rotation.x=PI*.5
	_solid(p,size)
	return p

## Chest of drawers / bedside cabinet: drawers with pulls on short legs.
static func drawers(parent: Node3D,at: Vector3,yaw: float,size: Vector3=Vector3(.5,.62,.42),count: int=2) -> Node3D:
	var p:=_piece(parent,at,yaw,"Gaveteiro");var w:=_wood();var d:=_dark();var b:=_brass()
	G.box(p,Vector3(0,size.y*.5+.06,0),Vector3(size.x,size.y-.08,size.z),d)
	G.box(p,Vector3(0,size.y+.01,0),Vector3(size.x+.04,.03,size.z+.04),w)
	for sx: float in [-1.,1.]:
		for sz: float in [-1.,1.]:G.cylinder(p,Vector3(sx*(size.x*.5-.04),.04,sz*(size.z*.5-.04)),.022,.08,d,.016,6)
	var dh:=(size.y-.14)/float(count)
	for k: int in count:
		var y:=.1+dh*(float(k)+.5)
		G.box(p,Vector3(0,y,-size.z*.5-.01),Vector3(size.x-.06,dh-.03,.02),w)
		G.sphere(p,Vector3(0,y,-size.z*.5-.035),Vector3.ONE*.035,b,8)
	_solid(p,size)
	return p

## Oil lamp: brass foot, glass font, chimney, a warm glow and a small light.
static func oil_lamp(parent: Node3D,at: Vector3,light: bool=true) -> Node3D:
	var p:=_piece(parent,at,0.,"Lampiao");var b:=_brass()
	var glow:=StandardMaterial3D.new();glow.albedo_color=Color("ffe2a8");glow.emission_enabled=true;glow.emission=Color("ffb35c");glow.emission_energy_multiplier=1.6
	var glass:=mat("flat",Color(.85,.92,.9,.35),.05);(glass as StandardMaterial3D).transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	G.cylinder(p,Vector3(0,.015,0),.07,.03,b,.08,12)
	G.cylinder(p,Vector3(0,.07,0),.025,.08,b,.03,8)
	G.sphere(p,Vector3(0,.14,0),Vector3(.11,.08,.11),glass,10)
	G.cylinder(p,Vector3(0,.19,0),.03,.03,b,.03,8)
	G.cylinder(p,Vector3(0,.22,0),.012,.03,glow,.012,6)
	G.cylinder(p,Vector3(0,.27,0),.04,.16,glass,.028,10)
	if light:
		var l:=OmniLight3D.new();l.position=Vector3(0,.25,0);l.light_color=Color("ffc27a");l.light_energy=.7;l.omni_range=3.5;l.shadow_enabled=false;p.add_child(l)
	return p

## Bed: head and foot boards with posts and knobs, a mattress, a folded quilt and pillows.
static func bed(parent: Node3D,at: Vector3,yaw: float,size: Vector2=Vector2(1.,2.)) -> Node3D:
	var p:=_piece(parent,at,yaw,"Cama");var w:=_wood();var d:=_dark()
	var linen:=mat("fabric",Color("ece6d6"));var quilt:=mat("fabric",Color("3f6f8f"));var quilt2:=mat("fabric",Color("b8573f"))
	var hx:=size.x*.5;var hz:=size.y*.5
	for end: Array in [[hz,1.05],[-hz,.7]]:
		var z: float=end[0];var h: float=end[1]
		for sx: float in [-1.,1.]:
			G.box(p,Vector3(sx*hx,h*.5,z),Vector3(.07,h,.07),d)
			G.sphere(p,Vector3(sx*hx,h+.03,z),Vector3.ONE*.08,w,8)
		G.box(p,Vector3(0,h-.08,z),Vector3(size.x,.08,.04),w)
		for k: int in 5:G.box(p,Vector3(-hx*.75+float(k)*hx*.375,(h-.1+.35)*.5,z),Vector3(.035,h-.45,.025),d)
	for sx: float in [-1.,1.]:G.box(p,Vector3(sx*hx,.3,0),Vector3(.05,.15,size.y),d)
	G.box(p,Vector3(0,.42,0),Vector3(size.x-.08,.16,size.y-.1),linen)
	G.box(p,Vector3(0,.51,-.12),Vector3(size.x-.02,.05,size.y*.62),quilt)
	G.box(p,Vector3(0,.535,-.12-size.y*.31+.2),Vector3(size.x,.03,.38),quilt2)
	for k: int in 2 if size.x>1.1 else 1:
		var x:=0. if size.x<=1.1 else (float(k)-.5)*size.x*.48
		G.ellipsoid(p,Vector3(x,.56,hz-.28),Vector3(minf(size.x*.8,.62),.14,.36),linen,10)
	_solid(p,Vector3(size.x+.1,.6,size.y+.1))
	return p

## Rag rug: an oval of concentric coloured bands lying on the floor.
static func rug(parent: Node3D,at: Vector3,yaw: float,size: Vector2=Vector2(1.6,1.1)) -> Node3D:
	var p:=_piece(parent,at,yaw,"Tapete")
	var colors: Array[Color]=[Color("8a3b2e"),Color("d8c08a"),Color("3f6f8f"),Color("c9583f"),Color("e8dfc8")]
	for k: int in colors.size():
		var f:=1.-float(k)*.17
		G.cylinder(p,Vector3(0,.025+float(k)*.003,0),.5,.006,mat("fabric",colors[k]),.5,24).scale=Vector3(size.x*f,1.,size.y*f)
	return p

## Wall shelf on brackets with jars, books and a bottle.
static func shelf(parent: Node3D,at: Vector3,yaw: float,width: float=1.) -> Node3D:
	var p:=_piece(parent,at,yaw,"Prateleira");var w:=_wood();var d:=_dark()
	G.box(p,Vector3(0,0,0),Vector3(width,.035,.22),w)
	for sx: float in [-1.,1.]:G.beam(p,Vector3(sx*width*.4,-.02,.1),Vector3(sx*width*.4,-.2,.1),.03,d)
	var colors: Array[Color]=[Color("7a2f26"),Color("2f4f6f"),Color("5d6b3a"),Color("8a6a3a"),Color("3a3a48")]
	var x:=-width*.42
	for k: int in 5:
		var h:=.16+float(k%3)*.03
		G.box(p,Vector3(x,h*.5+.02,-.01),Vector3(.04,h,.16),mat("flat",colors[k],.8));x+=.05
	x+=.08
	G.cylinder(p,Vector3(x,.09,0),.05,.14,mat("flat",Color(.55,.75,.7,.6),.1),.05,10);x+=.13
	G.cylinder(p,Vector3(x,.1,0),.045,.16,mat("flat",Color("c9b48a"),.9),.04,10);x+=.12
	G.cylinder(p,Vector3(x,.13,0),.035,.22,mat("flat",Color("2e5a3a"),.15,.1),.012,10)
	return p

## Framed picture: moulded frame, a mount and a painted sea with a sail on it.
static func picture(parent: Node3D,at: Vector3,yaw: float,size: Vector2=Vector2(.8,.6)) -> Node3D:
	var p:=_piece(parent,at,yaw,"Quadro");var w:=mat("flat",Color("8a6a3a"),.5,.3)
	G.box(p,Vector3.ZERO,Vector3(size.x,size.y,.04),w)
	G.box(p,Vector3(0,0,-.022),Vector3(size.x-.08,size.y-.08,.01),mat("flat",Color("efe6d0"),.9))
	G.box(p,Vector3(0,size.y*.1,-.03),Vector3(size.x-.16,size.y*.4,.006),mat("flat",Color("9cc3d4"),.9))
	G.box(p,Vector3(0,-size.y*.15,-.03),Vector3(size.x-.16,size.y*.3,.006),mat("flat",Color("2f6f86"),.9))
	G.box(p,Vector3(size.x*.05,-size.y*.02,-.034),Vector3(.02,size.y*.24,.004),mat("flat",Color("5a4632")))
	G.box(p,Vector3(size.x*.1,0.,-.034),Vector3(size.x*.12,size.y*.18,.004),mat("flat",Color("f4efe2")))
	return p

## Wooden crate with corner battens and rope handles.
static func crate(parent: Node3D,at: Vector3,yaw: float,size: Vector3=Vector3(.6,.45,.45),solid: bool=true) -> Node3D:
	var p:=_piece(parent,at,yaw,"Caixote");var w:=mat("weathered_wood",Color("a2875f"));var d:=_dark()
	for k: int in 3:G.box(p,Vector3(0,size.y*(float(k)+.5)/3.,0),Vector3(size.x,size.y/3.-.012,size.z),w)
	for sx: float in [-1.,1.]:
		for sz: float in [-1.,1.]:G.box(p,Vector3(sx*(size.x*.5-.02),size.y*.5,sz*(size.z*.5-.02)),Vector3(.05,size.y+.01,.05),d)
	if solid:_solid(p,size)
	return p
