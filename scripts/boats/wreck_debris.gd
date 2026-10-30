extends Node3D
## Pieces that break off a hull: planks, a tyre fender, a life ring, crates, barrels, a paddle, a coil of
## rope. Each is thrown off with an impulse, falls, slaps into the water and then floats on the waves,
## turning and drifting downwind, until it slowly sinks out of sight a minute or two later.
## One node for the whole world (group "destrocos"); at most MAX pieces live at once.
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const F=preload("res://scripts/visuals/furniture.gd")
const MAX: int=48
const LIFE: float=100.
## {node, v (velocity), spin, afloat, age, draft}
var pieces: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()

## The shared debris node, made on first use as a sibling of `near` (so it lives in the same world).
static func get_or_make(near: Node) -> Node3D:
	var found:=near.get_tree().get_first_node_in_group("destrocos")
	if found!=null:return found
	var d=load("res://scripts/boats/wreck_debris.gd").new();d.name="Destrocos";d.add_to_group("destrocos")
	near.get_parent().add_child(d)
	return d

func _ready() -> void:_rng.randomize()

## Throws one piece of `kind` from `at` with velocity `v`. `tint`: the hull's paint for planks.
func spawn(kind: String,at: Vector3,v: Vector3,tint: Color=Color("8a6a4a")) -> void:
	if pieces.size()>=MAX:
		(pieces[0].node as Node3D).queue_free();pieces.remove_at(0)
	var n:=Node3D.new();n.name="Destroco_"+kind;add_child(n)
	var draft:=.05
	match kind:
		"plank":
			var len:=_rng.randf_range(1.,2.2)
			G.box(n,Vector3.ZERO,Vector3(.2,.045,len),F.mat("weathered_wood",tint.lerp(Color("8a6a4a"),.35)))
			# A splintered end.
			for k: int in 3:G.box(n,Vector3(-.07+float(k)*.07,0.,len*.5+.04+float(k%2)*.03),Vector3(.05,.04,.12+float(k)*.03),F.mat("weathered_wood",Color("c9a77a")))
		"tire":
			var t:=TorusMesh.new();t.inner_radius=.18;t.outer_radius=.36;t.rings=16;t.ring_segments=8
			G.mesh_node(n,t,F.mat("flat",Color("1c1c1c"),.9),Vector3.ZERO);draft=.12
		"ring":
			var t2:=TorusMesh.new();t2.inner_radius=.24;t2.outer_radius=.38;t2.rings=18;t2.ring_segments=8
			var ring:=G.mesh_node(n,t2,F.mat("flat",Color("e8462f"),.6),Vector3.ZERO)
			for k: int in 4:
				var band:=G.box(n,Vector3(cos(k*PI*.5)*.31,0.,sin(k*PI*.5)*.31),Vector3(.1,.15,.1),F.mat("flat",Color("f4f1e8"),.6));band.rotation.y=-k*PI*.5
			draft=.06
		"crate":
			F.crate(n,Vector3(0,-.22,0),_rng.randf()*TAU,Vector3(.55,.45,.45),false);draft=.2
		"barrel":
			var w:=F.mat("weathered_wood",Color("8a6238"));var iron:=F.mat("flat",Color("2a2622"),.5,.5)
			var b:=G.cylinder(n,Vector3.ZERO,.28,.8,w,.28,12);b.rotation.z=PI*.5
			for x: float in [-.3,.3]:
				var hoop:=G.cylinder(n,Vector3(x,0,0),.3,.04,iron,-1.,12);hoop.rotation.z=PI*.5
			draft=.18
		"paddle":
			var wood:=F.mat("teak",Color("c79a62"))
			G.cylinder(n,Vector3(0,0,0),.025,1.3,wood,.025,6).rotation.x=PI*.5
			G.box(n,Vector3(0,0,.75),Vector3(.18,.03,.4),wood)
		_:
			for r: int in 3:
				var c:=TorusMesh.new();c.inner_radius=.12+float(r)*.02;c.outer_radius=.15+float(r)*.02;c.rings=14;c.ring_segments=5
				G.mesh_node(n,c,F.mat("flat",Color("c8b58a"),.95),Vector3(0,float(r)*.02,0))
	n.global_position=at;n.rotation=Vector3(_rng.randf()*TAU,_rng.randf()*TAU,_rng.randf()*TAU)
	pieces.append({"node":n,"v":v,"spin":Vector3(_rng.randf_range(-4.,4.),_rng.randf_range(-3.,3.),_rng.randf_range(-4.,4.)),"afloat":false,"age":0.,"draft":draft,"phase":_rng.randf()*TAU})

func _physics_process(delta: float) -> void:
	for i: int in range(pieces.size()-1,-1,-1):
		var p: Dictionary=pieces[i];var n: Node3D=p.node
		p.age=float(p.age)+delta
		var at: Vector3=n.global_position
		var surface: float=Waves.height_at(at)
		if not bool(p.afloat):
			p.v=(p.v as Vector3)+Vector3(0,-9.8,0)*delta
			n.global_position+=(p.v as Vector3)*delta
			n.rotation+=(p.spin as Vector3)*delta
			if n.global_position.y<surface:
				p.afloat=true;p.v=Vector3((p.v as Vector3).x,0.,(p.v as Vector3).z)*.4
				var game:=get_tree().get_first_node_in_group("game")
				if game!=null and game.world.ocean.effects!=null:game.world.ocean.effects.splash(Vector3(at.x,surface,at.z),.45,false)
		else:
			# Afloat: riding the waves, slowly turning, drifting downwind; it sinks at the end of its life.
			p.v=(p.v as Vector3).lerp(Vector3(Waves.direction.x,0.,Waves.direction.y)*(.25+Waves.wind*.5),1.-exp(-delta*.3))
			var sink: float=smoothstep(LIFE-12.,LIFE,float(p.age))*1.2
			n.global_position=Vector3(at.x,surface-float(p.draft)-sink,at.z)+(p.v as Vector3)*delta
			var ph: float=float(p.phase)+float(p.age)
			var lean: float=(Waves.height_at(at+Vector3(.6,0,0))-Waves.height_at(at-Vector3(.6,0,0)))*.6
			n.rotation=Vector3(lerp_angle(n.rotation.x,sin(ph*1.3)*.12,delta*2.),n.rotation.y+delta*.15*sin(ph*.3),lerp_angle(n.rotation.z,-lean+sin(ph*1.7)*.1,delta*2.))
			if float(p.age)>LIFE:n.queue_free();pieces.remove_at(i)
