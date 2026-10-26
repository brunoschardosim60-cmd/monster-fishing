extends Node3D
## Monster territories in the deep ocean. Each lair has a guardian that reacts to a boat entering its water:
##   outside the territory  -> asleep, nothing shows;
##   inside the territory   -> "alerta": the water darkens and bubbles rise, a warning is shown;
##   near the centre        -> the monster surfaces close to the boat and follows it;
##   lights on, engine fast or too close -> it attacks: tentacles slam down / the serpent rams / the
##                             leviathan breaches and its swell throws the boat around (hull damage);
##   slow (< 2 m/s) with the lights off for a while -> it only watches, and the sighting is recorded.
## Leaving the territory sends it back down. Territories are marked on the world map.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
## name, kind, rough position (searched for deep water), territory radius, observation reward.
## Height of the sea serpent model in metres (about a third of it stays under water).
const SERPENT_SIZE: float=30.
const LAIRS: Array=[["Fossa do Kraken","kraken",Vector2(-1500,-1450),240.,60],
	["Abismo da Serpente","serpente",Vector2(1700,-2250),260.,70],
	["Trono do Leviatã","leviata",Vector2(-2300,2300),300.,80]]
var game: Node3D
var lairs: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=5150
	for data: Array in LAIRS:
		var at:=_deep_water(data[2])
		var lair:={"name":data[0],"kind":data[1],"center":Vector3(at.x,0,at.y),"radius":float(data[3]),"reward":int(data[4]),
			"state":"dormindo","clock":0.,"strike":8.,"watched":0.,"observed":false,"warned":false,"hits":0,"pos":Vector3(at.x,-30.,at.y),"angle":0.}
		var node:=_build(str(data[1]));node.name=str(data[0]).replace(" ","");node.visible=false;add_child(node)
		lair["node"]=node
		var bubbles:=_bubbles();bubbles.emitting=false;add_child(bubbles);lair["bubbles"]=bubbles
		lairs.append(lair)

func _deep_water(near: Vector2) -> Vector2:
	var p:=near
	for ring: int in 60:
		if Layout.coast(p).x>320. and absf(p.x)<Layout.WORLD_HALF-300. and absf(p.y)<Layout.WORLD_HALF-300.:return p
		p=near+Vector2(cos(float(ring)*2.4),sin(float(ring)*2.4))*float(ring)*45.
	return near

## The lair whose territory contains a point, or {}.
func lair_at(at: Vector3) -> Dictionary:
	for lair: Dictionary in lairs:
		if Vector2(at.x-lair.center.x,at.z-lair.center.z).length()<float(lair.radius):return lair
	return {}

# --- Models ---------------------------------------------------------------------------------------------

func _wet(color: Color,rough: float=.35) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;m.metallic_specular=.7
	return m

func _glow(color: Color,energy: float) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=energy
	return m

func _ball(parent: Node3D,at: Vector3,size: Vector3,mat: Material,segments: int=20) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var s:=SphereMesh.new();s.radius=.5;s.height=1.;s.radial_segments=segments;s.rings=segments/2
	node.mesh=s;node.material_override=mat;node.position=at;node.scale=size;parent.add_child(node)
	return node

func _limb(parent: Node3D,length: float,r0: float,r1: float,mat: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=r1;c.bottom_radius=r0;c.height=length;c.radial_segments=10;c.rings=1
	node.mesh=c;node.material_override=mat;node.position=Vector3(0,length*.5,0);parent.add_child(node)
	return node

func _build(kind: String) -> Node3D:
	var root:=Node3D.new()
	match kind:
		"kraken":
			# Sculpted mantle (lathe) and eight continuous arms bent by the kraken_skin shader; eyes with slit pupils.
			var Meshes:=preload("res://scripts/creatures/creature_meshes.gd")
			var body_mat:=ShaderMaterial.new();body_mat.shader=preload("res://assets/shaders/kraken_skin.gdshader")
			var profile:=PackedVector2Array([Vector2(0.,-.6),Vector2(2.6,-.4),Vector2(3.9,.4),Vector2(3.5,1.4),Vector2(2.9,2.4),Vector2(3.1,3.6),
				Vector2(3.6,5.),Vector2(3.7,6.4),Vector2(3.3,7.8),Vector2(2.4,9.),Vector2(1.2,9.9),Vector2(0.,10.3)])
			var mantle:=MeshInstance3D.new();mantle.mesh=Meshes.lathe("kraken_mantle",profile,36,Vector2(1.,1.1));mantle.material_override=body_mat
			mantle.rotation.x=.32;mantle.name="Manto";root.add_child(mantle)
			var eye:=_glow(Color("ffcf3a"),2.6);var pupil:=_wet(Color("0a0507"),.2)
			for s: float in [-1.,1.]:
				var socket:=_ball(root,Vector3(s*2.75,2.6,-1.6),Vector3(1.9,1.7,1.5),body_mat,16)
				_ball(root,Vector3(s*3.1,2.65,-2.05),Vector3(1.25,1.25,.8),eye,16)
				_ball(root,Vector3(s*3.25,2.65,-2.4),Vector3(.22,.95,.2),pupil,10)
				var lid:=_ball(root,Vector3(s*2.95,3.25,-1.95),Vector3(1.7,.45,1.1),body_mat,12);lid.rotation.z=s*.25
				socket.name="Orbita"
			var arms: Array[ShaderMaterial]=[]
			for k: int in 8:
				var a:=float(k)*TAU/8.+.2
				var out:=Vector3(cos(a),.28+.25*float(k%2),sin(a)).normalized()
				var up:=(Vector3.UP-out*out.dot(Vector3.UP)).normalized()
				var side:=out.cross(up)
				var arm_mat:=body_mat.duplicate() as ShaderMaterial
				arm_mat.set_shader_parameter("tentacle",true);arm_mat.set_shader_parameter("arm_length",14.)
				arm_mat.set_shader_parameter("phase",float(k)*.9);arm_mat.set_shader_parameter("curl",.12+.05*float(k%3))
				var arm:=MeshInstance3D.new();arm.mesh=Meshes.tube("kraken_arm",14.,1.15,.08,30,14);arm.material_override=arm_mat
				arm.transform=Transform3D(Basis(side,out,up),Vector3(cos(a)*2.6,.2,sin(a)*2.6));arm.name="Tentaculo_%d"%k
				arm.extra_cull_margin=16.;root.add_child(arm);arms.append(arm_mat)
			root.set_meta("arms",arms)
		"serpente":
			# Bruno's sea-dragon model, painted by the pipeline: the coil stays under water, neck and head
			# rise above it. The shader sways the upper body and throws it forward when it strikes.
			var body:=MeshInstance3D.new();body.name="Corpo";body.mesh=load("res://assets/models/imported/serpent.res")
			var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/imported_model.gdshader");body.material_override=mat
			body.scale=Vector3.ONE*SERPENT_SIZE;body.position.y=-.3*SERPENT_SIZE
			body.set_instance_shader_parameter("model_scale",SERPENT_SIZE);body.set_instance_shader_parameter("sway",1.)
			body.extra_cull_margin=12.;root.add_child(body)
			root.set_meta("body",body)
		_:
			var hide:=_wet(Color("3a4a5c"),.4);var pale:=_wet(Color("c9d6dc"),.5);var glow:=_glow(Color("7fe6ff"),1.8)
			var body:=_ball(root,Vector3(0,0,0),Vector3(9.,8.,34.),hide,24)
			_ball(root,Vector3(0,-2.2,-2.),Vector3(8.,3.,28.),pale,18)
			for k: int in 9:_ball(root,Vector3(0,3.7,-12.+float(k)*3.),Vector3(.6,1.2+float(k%3)*.4,1.6),hide,8)
			for k: int in 14:_ball(root,Vector3((1. if k%2==0 else -1.)*3.6,.5,-14.+float(k)*2.1),Vector3(.35,.35,.35),glow,6)
			var tail:=Node3D.new();tail.position=Vector3(0,0,16.);tail.name="Cauda";root.add_child(tail)
			var fluke:=_ball(tail,Vector3(0,0,3.),Vector3(14.,.8,4.),hide,14);fluke.name="Barbatana"
			for s: float in [-1.,1.]:
				var flip:=_ball(root,Vector3(s*5.,-1.,-6.),Vector3(6.,.6,2.4),hide,10);flip.rotation.z=s*.4
			body.name="Corpo"
	return root

func _bubbles() -> CPUParticles3D:
	var p:=CPUParticles3D.new();p.amount=90;p.lifetime=3.;p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=18.
	p.direction=Vector3.UP;p.spread=10.;p.initial_velocity_min=.6;p.initial_velocity_max=1.4;p.gravity=Vector3(0,.4,0)
	var mesh:=SphereMesh.new();mesh.radius=.18;mesh.height=.36;mesh.radial_segments=6;mesh.rings=3
	var m:=StandardMaterial3D.new();m.albedo_color=Color(.85,.95,1.,.55);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.roughness=.1;mesh.material=m
	p.mesh=mesh;p.scale_amount_min=.5;p.scale_amount_max=1.6
	return p

# --- Behaviour ------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game==null:return
	var boat: Node3D=game.boat
	var b: Vector3=boat.global_position
	for lair: Dictionary in lairs:_update(lair,delta,b,boat)

func _update(lair: Dictionary,delta: float,b: Vector3,boat: Node3D) -> void:
	var c: Vector3=lair.center
	var gap:=Vector2(b.x-c.x,b.z-c.z).length()
	var radius: float=lair.radius
	var node: Node3D=lair.node
	var bubbles: CPUParticles3D=lair.bubbles
	var state: String=lair.state
	var aboard: bool=game.player.in_boat
	lair.clock=float(lair.clock)+delta
	var stealthy:=absf(float(boat.speed))<2. and not bool(boat.lights_enabled)
	match state:
		"dormindo":
			if gap<radius and aboard:
				lair.state="alerta";lair.clock=0.
				if not bool(lair.warned):game.hud.notify("A água escurece e borbulha… você entrou no %s."%lair.name);lair.warned=true
		"alerta":
			bubbles.emitting=true;bubbles.global_position=Vector3(b.x,Waves.height_at(b)-6.,b.z)+(c-b).normalized()*20.
			if gap>radius*1.08:lair.state="dormindo";bubbles.emitting=false;lair.warned=false
			elif gap<radius*.6 or float(lair.clock)>25.:_emerge(lair,b)
		"caca","atacando","observando":
			_hunt(lair,delta,b,boat,stealthy)
			if gap>radius*1.1 or not aboard:lair.state="recuando";lair.clock=0.;game.hud.notify("A criatura afunda e volta às profundezas.")
		"recuando":
			var p: Vector3=lair.pos;p.y-=delta*(5. if lair.kind=="serpente" else 3.);lair.pos=p
			node.position=p
			if float(lair.clock)>8.:lair.state="dormindo";node.visible=false;bubbles.emitting=false;lair.warned=false

func _emerge(lair: Dictionary,b: Vector3) -> void:
	var away:=Vector3(cos(_rng.randf()*TAU),0,sin(_rng.randf()*TAU))
	lair.angle=atan2(away.z,away.x)
	lair.pos=b+away*35.+Vector3(0,-34. if lair.kind=="serpente" else -14.,0)
	lair.state="caca";lair.clock=0.;lair.strike=6.;lair.watched=0.
	(lair.node as Node3D).visible=true;(lair.node as Node3D).position=lair.pos
	var text: Dictionary={"kraken":"O KRAKEN emerge ao lado do barco! Apague as luzes e vá devagar…","serpente":"Uma SERPENTE MARINHA rodeia o barco!","leviata":"Uma sombra colossal passa sob o casco… o LEVIATÃ!"}
	game.hud.notify(text.get(lair.kind,"Algo enorme emerge!"))
	game.audio.cue("horn")

func _hunt(lair: Dictionary,delta: float,b: Vector3,boat: Node3D,stealthy: bool) -> void:
	var node: Node3D=lair.node
	var kind: String=lair.kind
	var t: float=lair.clock
	lair.angle=float(lair.angle)+delta*(.12 if kind=="kraken" else (.1 if kind=="serpente" else .08))
	var orbit:={"kraken":30.,"serpente":30.,"leviata":45.}
	var r: float=orbit.get(kind,30.)
	var want:=b+Vector3(cos(float(lair.angle)),0,sin(float(lair.angle)))*r
	var surface:=Waves.height_at(want)
	var rise:=smoothstep(0.,5.,t)
	var depth: float={"kraken":-1.5,"serpente":0.,"leviata":-6.}.get(kind,-2.)
	want.y=lerpf(surface-(34. if kind=="serpente" else 14.),surface+depth,rise)
	var p: Vector3=lair.pos
	p=p.lerp(want,1.-exp(-delta*(.9 if kind=="serpente" else .5)))
	lair.pos=p;node.position=p
	var look:=b-p;look.y=0.
	if look.length()>.1:node.rotation.y=lerp_angle(node.rotation.y,atan2(-look.x,-look.z),1.-exp(-delta*1.5))
	_animate(lair,t)
	# Calm, dark and slow: it only watches. Otherwise it attacks every few seconds.
	if stealthy:
		lair.state="observando";lair.watched=float(lair.watched)+delta
		if float(lair.watched)>8. and not bool(lair.observed):
			lair.observed=true
			game.inventory.record({"id":"monstro_"+kind,"name":lair.name,"rarity":"Lendária","weight":0.,"observation":true})
			game.inventory.money+=int(lair.reward);game.inventory.changed.emit()
			game.hud.notify("Você observou o guardião do %s em silêncio · +%d moedas"%[lair.name,int(lair.reward)])
		return
	lair.state="atacando"
	lair.strike=float(lair.strike)-delta
	if float(lair.strike)<=0. and t>4.:
		lair.strike=_rng.randf_range(5.,8.)
		_strike(lair,b,boat)

func _strike(lair: Dictionary,b: Vector3,boat: Node3D) -> void:
	var kind: String=lair.kind
	var damage: float={"kraken":.08,"serpente":.06,"leviata":.05}.get(kind,.06)
	var kick:=(.42 if kind=="leviata" else .3)*(1. if _rng.randf()<.5 else -1.)
	boat.take_hit(damage,kick)
	lair.hits=int(lair.hits)+1
	var fx=game.world.ocean.effects
	if fx!=null:
		var side:=b+boat.global_basis.x*(3. if kick>0. else -3.)
		fx.splash(side,2.2,true);fx.splash(b,1.4,true)
	var text: Dictionary={"kraken":"Um tentáculo golpeia o casco! (%d%%)","serpente":"A serpente investe contra o barco! (%d%%)","leviata":"O leviatã salta: a onda joga o barco! (%d%%)"}
	game.hud.notify(str(text.get(kind,"Impacto! (%d%%)"))%int(boat.integrity*100.))
	game.audio.cue("splash")
	lair["slam"]=1.2

func _animate(lair: Dictionary,t: float) -> void:
	var node: Node3D=lair.node
	var slam: float=float(lair.get("slam",0.))
	if slam>0.:lair.slam=maxf(0.,slam-get_physics_process_delta_time())
	match str(lair.kind):
		"kraken":
			# The arms move in the shader; a strike whips the first arm down onto the water.
			var arms: Array=node.get_meta("arms")
			(arms[0] as ShaderMaterial).set_shader_parameter("slam",clampf(slam/1.2,0.,1.))
		"serpente":
			# Swaying while it watches; a strike throws the head forward onto the boat and back.
			var body: GeometryInstance3D=node.get_meta("body")
			var strike:=clampf(slam/1.2,0.,1.)
			body.set_instance_shader_parameter("lunge",sin(strike*PI))
			body.set_instance_shader_parameter("sway",lerpf(.6,1.4,.5+.5*sin(t*.37)))
		_:
			var tail: Node3D=node.get_node("Cauda")
			tail.rotation.x=sin(t*.8)*.25
			if slam>0.:node.position.y+=sin(slam/1.2*PI)*.12
