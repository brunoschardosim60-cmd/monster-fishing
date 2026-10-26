extends RefCounted
## Procedural town buildings. Local frame: origin on the ground-floor level at the centre of the
## footprint, front door facing -Z. Each building gets a stone plinth reaching down to the lowest
## ground under it, so it sits properly on sloping streets, plus one simple collision volume.
## Materials are shared (cached) so the town batches into few draw calls.
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
const STYLES: Array[String]=["costeira","sobrado","cabana","palafita","capela","prefeitura","escola","galpao"]
const WALLS: Array[Color]=[Color("f3efe6"),Color("f1e3c4"),Color("cfe0e6"),Color("f2cfc3"),Color("f5e3a1"),Color("cde6d2"),Color("e9d8f0"),Color("f0c8a0")]
const SHUTTERS: Array[Color]=[Color("2f6f8f"),Color("3d8b5a"),Color("b5332b"),Color("1f3d5c"),Color("c9a227"),Color("6b4f32")]
const ROOFS: Array[Color]=[Color("b5532f"),Color("9a3f2a"),Color("c46a3a"),Color("4f5a63"),Color("6b3a2a")]
static var _cache: Dictionary={}
## Shared window glass: town_planner sets its glow every few seconds (dark by day, lamplit at night).
static var windows: StandardMaterial3D

static func flat(color: Color,rough: float=.8,metal: float=0.,two_sided: bool=false) -> StandardMaterial3D:
	var key:="%s/%.2f/%.2f/%s"%[color.to_html(),rough,metal,str(two_sided)]
	if _cache.has(key):return _cache[key]
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;m.metallic=metal
	if two_sided:m.cull_mode=BaseMaterial3D.CULL_DISABLED
	_cache[key]=m
	return m
static func _textured(kind: String,tint: Color,scale_value: float,two_sided: bool=false) -> StandardMaterial3D:
	var key:="tex/%s/%s/%.2f/%s"%[kind,tint.to_html(),scale_value,str(two_sided)]
	if _cache.has(key):return _cache[key]
	var m:=M.surface(kind,tint,scale_value)
	if two_sided:m=m.duplicate();m.cull_mode=BaseMaterial3D.CULL_DISABLED
	_cache[key]=m
	return m
static func _glass() -> StandardMaterial3D:
	if windows==null:
		windows=StandardMaterial3D.new();windows.albedo_color=Color("26343d");windows.roughness=.12;windows.metallic=.4
		windows.emission_enabled=true;windows.emission=Color("ffc875");windows.emission_energy_multiplier=0.
	return windows

## Builds a building. `plinth` is how far the stone base reaches below the floor (metres).
static func build(style: String,w: float,d: float,rng: RandomNumberGenerator,plinth: float) -> Node3D:
	var root:=Node3D.new();root.name="Casa_"+style
	var wall_color: Color=WALLS[rng.randi()%WALLS.size()]
	var wall:=_textured("lime_plaster",wall_color,.35)
	var stone:=_textured("granite",Color("a9aa9c"),1.)
	var trim:=flat(Color("f4f1ea"),.7)
	var shutter:=flat(SHUTTERS[rng.randi()%SHUTTERS.size()],.6)
	var roof_color: Color=ROOFS[rng.randi()%ROOFS.size()]
	var wood:=_textured("weathered_wood",Color("8a6a4a"),1.5)
	var door:=_textured("teak",Color("7a4e2d").lerp(SHUTTERS[rng.randi()%SHUTTERS.size()],.3),1.2)
	var height:=3.2
	match style:
		"costeira":
			_plinth(root,w,d,plinth,stone)
			_box_walls(root,w,d,height,wall,trim)
			_openings(root,w,d,1,height,door,shutter,rng,true)
			_gable(root,w,d,height,.62,roof_color,wall)
			if rng.randf()<.6:_chimney(root,w,d,height,stone)
			_collider(root,Vector3(w,height+2.,d),Vector3(0,(height+2.)*.5,0))
		"sobrado":
			height=6.4
			_plinth(root,w,d,plinth,stone)
			_box_walls(root,w,d,height,wall,trim)
			G.box(root,Vector3(0,3.2,0),Vector3(w+.12,.18,d+.12),trim)
			_openings(root,w,d,2,3.2,door,shutter,rng,true)
			_gable(root,w,d,height,.55,roof_color,wall)
			var balcony_w:=minf(w*.6,5.)
			G.box(root,Vector3(0,3.25,-d*.5-.6),Vector3(balcony_w,.14,1.2),stone)
			var rail:=flat(Color("2b2f33"),.4,.6)
			G.beam(root,Vector3(-balcony_w*.5,4.25,-d*.5-1.15),Vector3(balcony_w*.5,4.25,-d*.5-1.15),.04,rail)
			for i: int in int(balcony_w/.5)+1:
				var x:=-balcony_w*.5+float(i)*.5
				G.beam(root,Vector3(x,3.3,-d*.5-1.15),Vector3(x,4.25,-d*.5-1.15),.02,rail)
			_chimney(root,w,d,height,stone)
			_collider(root,Vector3(w,height+2.5,d),Vector3(0,(height+2.5)*.5,0))
		"cabana":
			var logs:=_textured("weathered_wood",Color("6b4f32").lerp(Color("8a6a4a"),rng.randf()),1.2)
			_plinth(root,w,d,plinth,stone)
			G.box(root,Vector3(0,height*.5,0),Vector3(w,height,d),logs)
			for i: int in 7:
				var y:=.25+float(i)*.45
				for side: float in [-1.,1.]:G.box(root,Vector3(0,y,side*(d*.5+.03)),Vector3(w+.25,.1,.06),wood)
			_openings(root,w,d,1,height,door,flat(Color("3a2a1c"),.8),rng,false)
			_gable(root,w,d,height,.9,Color("3e3a36").lerp(Color("5a4a3a"),rng.randf()),logs)
			_chimney(root,w,d,height,stone)
			G.box(root,Vector3(0,.15,-d*.5-1.),Vector3(w*.8,.25,2.),wood)
			for x: float in [-w*.38,w*.38]:G.cylinder(root,Vector3(x,1.4,-d*.5-1.8),.09,2.5,wood)
			var porch:=G.box(root,Vector3(0,2.75,-d*.5-1.),Vector3(w*.85,.08,2.2),wood);porch.rotation.x=-.18
			_collider(root,Vector3(w,height+2.,d),Vector3(0,(height+2.)*.5,0))
		"palafita":
			var planks:=_textured("weathered_wood",Color("a08a68").lerp(wall_color,.25),1.5)
			for x: float in [-w*.45,0.,w*.45]:
				for z: float in [-d*.45-1.5,-d*.15,d*.45]:G.cylinder(root,Vector3(x,-plinth*.5,z),.14,plinth+.2,wood)
			G.box(root,Vector3(0,-.12,-.75),Vector3(w+.6,.22,d+1.6),wood)
			G.box(root,Vector3(0,height*.5,0),Vector3(w,height,d),planks)
			_openings(root,w,d,1,height,door,shutter,rng,true)
			_gable(root,w,d,height,.5,Color("8a8f94").lerp(roof_color,.3),planks)
			var rail2:=wood
			G.beam(root,Vector3(-w*.5-.25,1.,-d*.5-1.5),Vector3(w*.5+.25,1.,-d*.5-1.5),.05,rail2)
			_collider(root,Vector3(w,height+2.,d),Vector3(0,(height+2.)*.5,0))
		"capela":
			height=7.
			_plinth(root,w,d,plinth,stone)
			_box_walls(root,w,d,height,_textured("lime_plaster",Color("f6f4ee"),.35),trim)
			_gable(root,w,d,height,1.,Color("9a3f2a"),_textured("lime_plaster",Color("f6f4ee"),.35))
			var tower:=Vector3(0,0,-d*.5-1.6)
			G.box(root,tower+Vector3(0,8.,0),Vector3(3.6,16.,3.6),_textured("lime_plaster",Color("f6f4ee"),.35))
			for side: float in [-1.,1.]:
				G.box(root,tower+Vector3(side*1.81,13.,0),Vector3(.06,1.8,1.1),flat(Color("1c1c1c"),.6))
				G.box(root,tower+Vector3(0,13.,side*1.81),Vector3(1.1,1.8,.06),flat(Color("1c1c1c"),.6))
			G.cylinder(root,tower+Vector3(0,17.4,0),2.7,2.8,flat(Color("2f6f8f"),.5),.02,4).rotation.y=PI*.25
			var gold:=flat(Color("d9b44a"),.3,.8)
			G.box(root,tower+Vector3(0,19.6,0),Vector3(.12,1.6,.12),gold);G.box(root,tower+Vector3(0,19.9,0),Vector3(.8,.12,.12),gold)
			G.box(root,tower+Vector3(0,1.4,-1.82),Vector3(1.6,2.8,.1),door)
			G.cylinder(root,tower+Vector3(0,6.,-1.82),.55,.08,_glass(),-1.,16).rotation.x=PI*.5
			for i: int in 4:
				var z:=-d*.3+float(i)*d*.2
				for side: float in [-1.,1.]:G.box(root,Vector3(side*(w*.5+.03),3.6,z),Vector3(.06,2.6,1.),_glass())
			_collider(root,Vector3(w,height+3.,d),Vector3(0,(height+3.)*.5,0))
			_collider(root,Vector3(3.6,18.,3.6),tower+Vector3(0,9.,0))
		"prefeitura":
			height=7.
			_plinth(root,w,d,plinth,stone)
			_box_walls(root,w,d,height,_textured("lime_plaster",Color("efe2c8"),.35),trim)
			G.box(root,Vector3(0,3.5,0),Vector3(w+.12,.2,d+.12),trim)
			_openings(root,w,d,2,3.5,door,flat(Color("1f3d5c"),.6),rng,true)
			_gable(root,w,d,height,.4,Color("4f5a63"),_textured("lime_plaster",Color("efe2c8"),.35))
			G.box(root,Vector3(0,.2,-d*.5-2.2),Vector3(w*.6,.4,4.4),stone)
			for i: int in 4:G.cylinder(root,Vector3(-w*.24+float(i)*w*.16,3.6,-d*.5-3.8),.32,6.8,trim,.28,14)
			G.box(root,Vector3(0,7.2,-d*.5-2.2),Vector3(w*.62,.5,4.6),trim)
			var tri:=PackedVector3Array([Vector3(-w*.31,7.45,-d*.5-4.5),Vector3(w*.31,7.45,-d*.5-4.5),Vector3(0,9.2,-d*.5-4.5)])
			G.mesh_node(root,G.polygon_mesh(tri,PackedInt32Array([0,2,1,0,1,2])),flat(Color("f4f1ea"),.7,0.,true),Vector3.ZERO)
			G.cylinder(root,Vector3(0,8.2,-d*.5-4.55),.7,.1,flat(Color("f7f2e2"),.4),-1.,24).rotation.x=PI*.5
			G.beam(root,Vector3(0,8.2,-d*.5-4.62),Vector3(0,8.6,-d*.5-4.62),.05,flat(Color("1c1c1c")))
			G.beam(root,Vector3(0,8.2,-d*.5-4.62),Vector3(.3,8.2,-d*.5-4.62),.05,flat(Color("1c1c1c")))
			G.cylinder(root,Vector3(w*.4,height+4.,0),.06,8.,flat(Color("c9ccd0"),.3,.7))
			_collider(root,Vector3(w,height+2.,d),Vector3(0,(height+2.)*.5,0))
		"escola":
			_plinth(root,w,d,plinth,stone)
			_box_walls(root,w,d,height+.4,_textured("lime_plaster",Color("f5e3a1"),.35),trim)
			_openings(root,w,d,1,height+.4,door,flat(Color("3d8b5a"),.6),rng,true)
			_gable(root,w,d,height+.4,.45,Color("b5532f"),_textured("lime_plaster",Color("f5e3a1"),.35))
			var bell:=Vector3(0,height+2.8,-d*.25)
			G.box(root,bell,Vector3(1.4,1.6,1.4),trim);G.cylinder(root,bell+Vector3(0,1.3,0),1.1,1.,flat(Color("b5532f"),.6),.02,4).rotation.y=PI*.25
			_collider(root,Vector3(w,height+2.,d),Vector3(0,(height+2.)*.5,0))
		_:
			var boards:=_textured("weathered_wood",Color("7a6a55").lerp(Color("9aa3a8"),rng.randf()*.5),1.4)
			_plinth(root,w,d,plinth,stone)
			G.box(root,Vector3(0,2.6,0),Vector3(w,5.2,d),boards)
			G.box(root,Vector3(0,1.8,-d*.5-.04),Vector3(w*.42,3.6,.08),door)
			for x: float in [-w*.3,w*.3]:G.box(root,Vector3(x,3.9,-d*.5-.04),Vector3(1.4,.8,.06),_glass())
			_gable(root,w,d,5.2,.3,Color("8a8f94"),boards)
			_collider(root,Vector3(w,7.,d),Vector3(0,3.5,0))
	return root

static func _plinth(root: Node3D,w: float,d: float,depth: float,stone: Material) -> void:
	G.box(root,Vector3(0,-depth*.5+.05,0),Vector3(w+.35,depth+.1,d+.35),stone)

static func _box_walls(root: Node3D,w: float,d: float,h: float,wall: Material,trim: Material) -> void:
	G.box(root,Vector3(0,h*.5,0),Vector3(w,h,d),wall)
	for x: float in [-1.,1.]:
		for z: float in [-1.,1.]:G.box(root,Vector3(x*(w*.5-.08),h*.5,z*(d*.5-.08)),Vector3(.3,h,.3),trim)
	G.box(root,Vector3(0,h-.1,0),Vector3(w+.14,.2,d+.14),trim)

## Front door, then windows on every face and floor, with shutters on coastal styles.
static func _openings(root: Node3D,w: float,d: float,floors: int,floor_h: float,door: Material,shutter: Material,rng: RandomNumberGenerator,shutters: bool) -> void:
	var glass:=_glass();var sill:=flat(Color("f4f1ea"),.7)
	# Own generator for decoration, so the town layout drawn from `rng` stays the same.
	var flowers:=RandomNumberGenerator.new();flowers.seed=hash(Vector3(w,d,floor_h))
	G.box(root,Vector3(0,1.1,-d*.5-.05),Vector3(1.15,2.2,.1),door)
	G.box(root,Vector3(0,.08,-d*.5-.45),Vector3(1.6,.16,.8),flat(Color("a9aa9c"),.9))
	# Wall lantern beside the door and a small house-number plate.
	var lamp_glow:=flat(Color("ffe0a8"),.4);lamp_glow.emission_enabled=true;lamp_glow.emission=Color("ffc477");lamp_glow.emission_energy_multiplier=.8
	G.box(root,Vector3(.85,2.15,-d*.5-.12),Vector3(.05,.05,.22),flat(Color("2b2f33"),.5))
	G.box(root,Vector3(.85,2.05,-d*.5-.24),Vector3(.16,.24,.16),lamp_glow)
	G.box(root,Vector3(.85,2.19,-d*.5-.24),Vector3(.2,.04,.2),flat(Color("2b2f33"),.5))
	G.box(root,Vector3(-.85,1.75,-d*.5-.07),Vector3(.26,.18,.03),flat(Color("2f5f8a"),.6))
	for f: int in floors:
		var y:=float(f)*floor_h+1.75
		for face: Array in [[-1.,w,true],[1.,w,true],[-1.,d,false],[1.,d,false]]:
			var span: float=face[1];var front: bool=face[2];var sign_value: float=face[0]
			var count:=maxi(1,int(span/2.8))
			for i: int in count:
				var off:=(float(i)-float(count-1)*.5)*span/float(count)
				if front and sign_value<0. and f==0 and absf(off)<1.2:continue
				var pos:Vector3;var size:Vector3
				if front:pos=Vector3(off,y,sign_value*(d*.5+.04));size=Vector3(.95,1.25,.06)
				else:pos=Vector3(sign_value*(w*.5+.04),y,off);size=Vector3(.06,1.25,.95)
				G.box(root,pos,size,glass)
				G.box(root,pos+Vector3(0,-.7,0)+(Vector3(0,0,sign_value*.06) if front else Vector3(sign_value*.06,0,0)),Vector3(1.15,.1,.18) if front else Vector3(.18,.1,1.15),sill)
				# Window boxes with flowers on about half the street-facing windows.
				if front and sign_value<0. and flowers.randf()<.55:
					var box_at:=pos+Vector3(0,-.86,-.16)
					G.box(root,box_at,Vector3(1.,.22,.24),flat(Color("6b4a32"),.85))
					G.box(root,box_at+Vector3(0,.13,0),Vector3(.94,.06,.18),flat(Color("4f7a3a"),.9))
					var petals: Array[Color]=[Color("d8432f"),Color("f2a7c3"),Color("f1c232"),Color("f3f3f3"),Color("a64d79")]
					var pick:=flowers.randi()%petals.size()
					for k: int in 4:
						G.ellipsoid(root,box_at+Vector3(-.36+float(k)*.24,.2,0),Vector3(.16,.13,.16),flat(Color("4f7a3a"),.9),6)
						G.ellipsoid(root,box_at+Vector3(-.3+float(k)*.24,.27,-.03),Vector3(.09,.08,.09),flat(petals[(pick+k%2)%petals.size()],.7),6)
				if shutters:
					for s: float in [-1.,1.]:
						var sp:=pos+(Vector3(s*.72,0,sign_value*.03) if front else Vector3(sign_value*.03,0,s*.72))
						G.box(root,sp,Vector3(.42,1.3,.05) if front else Vector3(.05,1.3,.42),shutter)

## Gable roof with overhang; ridge along X, gable triangles at the sides in the wall material.
static func _gable(root: Node3D,w: float,d: float,h: float,pitch: float,color: Color,gable: Material) -> void:
	var o:=.45;var rise:=d*.5*pitch
	var roof:=_textured("weathered_wood",color,.9,true)
	var verts:=PackedVector3Array([Vector3(-w*.5-o,h-.05,-d*.5-o),Vector3(w*.5+o,h-.05,-d*.5-o),Vector3(w*.5+o,h+rise,0),Vector3(-w*.5-o,h+rise,0),
		Vector3(-w*.5-o,h-.05,d*.5+o),Vector3(w*.5+o,h-.05,d*.5+o)])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in [[0,3,2],[0,2,1],[4,5,2],[4,2,3]]:
		for i: int in tri:st.add_vertex(verts[i])
	# Thickness: a second, slightly lower skin so the roof reads as tiles with depth from below.
	for tri: Array in [[0,2,3],[0,1,2],[4,2,5],[4,3,2]]:
		for i: int in tri:st.add_vertex(verts[i]-Vector3(0,.16,0))
	st.generate_normals()
	G.mesh_node(root,st.commit(),roof,Vector3.ZERO)
	var ends:=PackedVector3Array([Vector3(-w*.5,h,-d*.5),Vector3(-w*.5,h,d*.5),Vector3(-w*.5,h+rise-.1,0),Vector3(w*.5,h,-d*.5),Vector3(w*.5,h,d*.5),Vector3(w*.5,h+rise-.1,0)])
	var gm:=G.polygon_mesh(ends,PackedInt32Array([0,1,2,0,2,1,3,5,4,3,4,5]))
	var gable_mat: Material=gable
	if gable is StandardMaterial3D:gable_mat=_two_sided(gable)
	G.mesh_node(root,gm,gable_mat,Vector3.ZERO)
	G.box(root,Vector3(0,h+rise+.02,0),Vector3(w+o*2.+.1,.16,.3),flat(color.darkened(.3),.7))

static func _two_sided(m: StandardMaterial3D) -> StandardMaterial3D:
	var key:="two/%d"%m.get_instance_id()
	if _cache.has(key):return _cache[key]
	var copy:=m.duplicate() as StandardMaterial3D;copy.cull_mode=BaseMaterial3D.CULL_DISABLED
	_cache[key]=copy
	return copy

static func _chimney(root: Node3D,w: float,d: float,h: float,stone: Material) -> void:
	G.box(root,Vector3(w*.28,h+d*.3,d*.18),Vector3(.7,d*.5+1.2,.7),stone)
	G.box(root,Vector3(w*.28,h+d*.55+.65,d*.18),Vector3(.85,.15,.85),flat(Color("5a5a55")))

static func _collider(root: Node3D,size: Vector3,at: Vector3) -> void:
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;shape.position=at
	body.add_child(shape);root.add_child(body)
