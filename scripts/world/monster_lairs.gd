extends Node3D
## Monster territories in the deep ocean. Each lair has a guardian that reacts to a boat entering its water:
##   outside the territory  -> asleep, nothing shows;
##   inside the territory   -> "alerta": the water darkens and bubbles rise, a warning is shown;
##   near the centre        -> the monster surfaces close to the boat and follows it;
##   lights on, engine fast or too close -> it attacks: tentacles slam down / the serpent rams / the
##                             leviathan breaches and its swell throws the boat around (hull damage);
##   slow (< 2 m/s) with the lights off for a while -> it only watches, and the sighting is recorded.
## Leaving the territory sends it back down. Territories are marked on the world map.
## The player can also deal with it:
##   flee  -> SHIFT turbo at the helm; monsters chase at a limited speed, outrun them out of the territory;
##   scare -> Y fires a flare: it dives and stays down for a while;
##   fight -> H fires the bow harpoon (boatyard upgrade): enough hits drive the guardian off for good this
##            visit (it stays calm for ten minutes) and pay a bounty.
## A hull at 0% sinks (fishing_boat.gd) and main.gd rescues the player.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
## name, kind, rough position (searched for deep water), territory radius, observation reward.
## Height of the sea serpent model in metres (about a third of it stays under water).
const SERPENT_SIZE: float=30.
const KRAKEN_SCALE: float=1.8
## Harpoon hits needed, chase speed (m/s) and bounty per guardian.
const HEALTH: Dictionary={"kraken":5,"serpente":6,"leviata":8,"megalodonte":6}
const CHASE: Dictionary={"kraken":7.,"serpente":10.,"leviata":8.,"megalodonte":12.}
const BOUNTY: Dictionary={"kraken":160,"serpente":190,"leviata":240,"megalodonte":200}
## Height above its node where each guardian is hit (the part above water).
const TARGET_HEIGHT: Dictionary={"kraken":5.,"serpente":7.,"leviata":7.,"megalodonte":3.}
const TARGET_RADIUS: Dictionary={"kraken":12.,"serpente":10.,"leviata":12.,"megalodonte":8.}
var _shots: Array[Dictionary]=[]
const LAIRS: Array=[["Fossa do Kraken","kraken",Vector2(-1500,-1450),240.,60],
	["Abismo da Serpente","serpente",Vector2(1700,-2250),260.,70],
	["Trono do Leviatã","leviata",Vector2(-2300,2300),300.,80],
	["Rota do Megalodonte","megalodonte",Vector2(2300,1700),260.,70]]
var game: Node3D
var lairs: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=5150
	for data: Array in LAIRS:
		var at:=_deep_water(data[2])
		var lair:={"name":data[0],"kind":data[1],"center":Vector3(at.x,0,at.y),"radius":float(data[3]),"reward":int(data[4]),
			"state":"dormindo","clock":0.,"strike":8.,"watched":0.,"observed":false,"warned":false,"hits":0,"pos":Vector3(at.x,-30.,at.y),"angle":0.,"hp":int(HEALTH.get(data[1],5)),"calm":0.}
		var node:=_build(str(data[1]));node.name=str(data[0]).replace(" ","");node.visible=false;add_child(node)
		lair["node"]=node
		var bubbles:=_bubbles();bubbles.emitting=false;add_child(bubbles);lair["bubbles"]=bubbles
		_nest(lair)
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
			# A real kraken: the mantle stands ~19 m out of the water and the arms reach 25 m.
			root.scale=Vector3.ONE*KRAKEN_SCALE
		"serpente":
			# A 60 m sea serpent, the leviathan's moss-green cousin with a blood-red crest (tools/blender/leviathan.py,
			# VARIANT=serpente), swum by the same shader.
			serpent_model(root,"res://assets/monsters/serpente/serpente.glb",60.)
		"megalodonte":
			# A 22 m prehistoric shark (tools/blender/megalodon.py): only the dorsal fin cuts the surface while
			# it circles; it rams the hull and breaches with the jaw wide open.
			serpent_model(root,"res://assets/monsters/megalodonte/megalodonte.glb",24.,{"jaw_hinge":Vector3(0,-1.6,-1.6),"head_start":-6.,"head_reach":10.,"wave_amp":3.})
		_:
			# The leviathan: a 90 m sea serpent modelled in Blender (tools/blender/leviathan.py): scaled back
			# in bands, dorsal spikes, fins and frills, a dragon head with horns and a jaw that opens, and
			# glowing photophores. leviathan_body.gdshader swims it, raises the head and lunges.
			serpent_model(root,"res://assets/monsters/leviata/leviata.glb",90.)
	return root

## Loads a serpent GLB (body, jaw, teeth, glow) under `root` with leviathan_body.gdshader on every surface.
static func serpent_model(root: Node3D,path: String,length: float,extra: Dictionary={}) -> void:
	var model: Node3D=load(path).instantiate();model.name="Modelo";root.add_child(model)
	var parts: Array[GeometryInstance3D]=[]
	var shader:=preload("res://assets/shaders/leviathan_body.gdshader")
	for mi: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for i: int in mi.mesh.get_surface_count():
			var src: Material=mi.mesh.surface_get_material(i)
			var nm: String=str(src.resource_name) if src!=null else ""
			var m:=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("body_length",length)
			m.set_shader_parameter("is_jaw",nm.begins_with("Mandibula"));m.set_shader_parameter("glow",nm.begins_with("Brilho"))
			for key: String in extra:m.set_shader_parameter(key,extra[key])
			mi.set_surface_override_material(i,m)
		mi.extra_cull_margin=30.;parts.append(mi)
	root.set_meta("parts",parts)

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
	_update_boarding(delta)

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
			lair.calm=maxf(0.,float(lair.calm)-delta)
			if gap<radius and aboard and float(lair.calm)<=0.:
				lair.state="alerta";lair.clock=0.
				if not bool(lair.warned):game.hud.notify("A água escurece e borbulha… você entrou no %s."%lair.name);lair.warned=true
		"alerta":
			bubbles.emitting=true;bubbles.global_position=Vector3(b.x,Waves.height_at(b)-6.,b.z)+(c-b).normalized()*20.
			if gap>radius*1.08:lair.state="dormindo";bubbles.emitting=false;lair.warned=false
			elif gap<radius*.6 or float(lair.clock)>25.:_emerge(lair,b)
		"caca","atacando","observando":
			_hunt(lair,delta,b,boat,stealthy)
			if gap>radius*1.1 or not aboard:
				lair.state="recuando";lair.clock=0.
				game.hud.notify("Você escapou! A criatura afunda e volta às profundezas." if aboard else "A criatura afunda e volta às profundezas.")
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
	var text: Dictionary={"kraken":"O KRAKEN emerge ao lado do barco! Apague as luzes e vá devagar…","serpente":"Uma SERPENTE MARINHA rodeia o barco!","leviata":"Uma sombra colossal passa sob o casco… o LEVIATÃ!","megalodonte":"Uma barbatana enorme corta a água em volta do barco… o MEGALODONTE!"}
	game.hud.notify(text.get(lair.kind,"Algo enorme emerge!"))
	game.audio.cue_at("roar",(lair.pos as Vector3)+Vector3(0,14,0))

func _hunt(lair: Dictionary,delta: float,b: Vector3,boat: Node3D,stealthy: bool) -> void:
	var node: Node3D=lair.node
	var kind: String=lair.kind
	var t: float=lair.clock
	lair.angle=float(lair.angle)+delta*{"kraken":.12,"serpente":.1,"megalodonte":.22}.get(kind,.08)
	var orbit:={"kraken":38.,"serpente":40.,"leviata":55.,"megalodonte":26.}
	var r: float=orbit.get(kind,30.)
	var want:=b+Vector3(cos(float(lair.angle)),0,sin(float(lair.angle)))*r
	var surface:=Waves.height_at(want)
	var rise:=smoothstep(0.,5.,t)
	var depth: float={"kraken":-2.5,"serpente":-.9,"leviata":-1.2,"megalodonte":-3.8}.get(kind,-2.)
	want.y=lerpf(surface-(34. if kind=="serpente" else 14.),surface+depth,rise)
	# It chases at a limited speed: a boat on turbo can open the gap and leave the territory.
	var p: Vector3=lair.pos
	var flat:=Vector3(want.x-p.x,0,want.z-p.z)
	var max_step: float=float(CHASE.get(kind,8.))*delta*(1.6 if t<5. else 1.)
	if flat.length()>max_step:flat=flat.normalized()*max_step
	p+=flat;p.y=lerpf(p.y,want.y,1.-exp(-delta*.6))
	lair.pos=p;node.position=p
	var look:=b-p;look.y=0.
	if look.length()>.1:node.rotation.y=lerp_angle(node.rotation.y,atan2(-look.x,-look.z),1.-exp(-delta*1.5))
	_animate(lair,t)
	# Over the nest it defends: no patience at all, it strikes twice as often.
	var c: Vector3=lair.center
	var over_nest:=Vector2(b.x-c.x,b.z-c.z).length()<float(lair.radius)*.22
	if over_nest and not bool(lair.get("nest_warned",false)):
		lair["nest_warned"]=true;game.hud.notify("Ovos brilham no fundo: você está sobre o ninho do guardião! Ele defende sem trégua.")
	if over_nest:stealthy=false
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
	lair.strike=float(lair.strike)-delta*(2. if over_nest else 1.)
	var reach:=Vector2(p.x-b.x,p.z-b.z).length()<r+18.
	if float(lair.strike)<=0. and t>4. and reach:
		lair.strike=_rng.randf_range(5.,8.)
		_strike(lair,b,boat)

## Kraken arms that break the surface right beside the hull, rear up, whip down across the deck and
## slide back under: {node, mat, t, side}.
var boarding: Array[Dictionary]=[]
func _boarding_arm(boat: Node3D,side: float,along: float) -> void:
	var Meshes:=preload("res://scripts/creatures/creature_meshes.gd")
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/kraken_skin.gdshader")
	mat.set_shader_parameter("tentacle",true);mat.set_shader_parameter("arm_length",16.)
	mat.set_shader_parameter("curl",.05);mat.set_shader_parameter("phase",_rng.randf()*TAU);mat.set_shader_parameter("wave",.05)
	var arm:=MeshInstance3D.new();arm.name="TentaculoNoCasco";arm.mesh=Meshes.tube("kraken_boarding_arm_big",16.,1.4,.09,34,14)
	arm.material_override=mat;arm.extra_cull_margin=20.;add_child(arm)
	var beam: float=float(boat.hull_spec.beam)*.5*float(boat.size_factor)
	var at: Vector3=boat.global_position+boat.global_basis.x*side*(beam+1.4)+boat.global_basis.z*along
	# Arm grows along +Y; its sucker side (+Z) faces the boat, so it curls over onto the deck.
	var to_boat: Vector3=-boat.global_basis.x*side
	arm.global_transform=Transform3D(Basis(to_boat.cross(Vector3.UP).normalized(),Vector3.UP,to_boat),at-Vector3(0,15,0))
	boarding.append({"node":arm,"mat":mat,"t":0.,"base":at})
	var fx=game.world.ocean.effects
	if fx!=null:fx.splash(at,2.6,true)

func _update_boarding(delta: float) -> void:
	for i: int in range(boarding.size()-1,-1,-1):
		var a: Dictionary=boarding[i];a.t=float(a.t)+delta
		var t: float=a.t;var arm: MeshInstance3D=a.node;var base: Vector3=a.base
		# 0–1.1 s rise out of the water, 1.1–1.7 s whip down, hold, 3.2–4.6 s slide back under.
		var y: float=lerpf(-15.,-3.,smoothstep(0.,1.1,t))-lerpf(0.,14.,smoothstep(3.2,4.6,t))
		arm.global_position=Vector3(base.x,Waves.height_at(base)+y,base.z)
		(a.mat as ShaderMaterial).set_shader_parameter("slam",smoothstep(1.1,1.7,t)*(1.-smoothstep(2.6,3.4,t)))
		(a.mat as ShaderMaterial).set_shader_parameter("curl",lerpf(.02,.09,smoothstep(.4,1.1,t)))
		if t>4.7:arm.queue_free();boarding.remove_at(i)

func _strike(lair: Dictionary,b: Vector3,boat: Node3D) -> void:
	var kind: String=lair.kind
	if kind=="kraken":
		var side: float=1. if _rng.randf()<.5 else -1.
		_boarding_arm(boat,side,_rng.randf_range(-2.,2.))
		if _rng.randf()<.6:_boarding_arm(boat,-side,_rng.randf_range(-2.5,2.5))
	var damage: float={"kraken":.08,"serpente":.06,"leviata":.05,"megalodonte":.09}.get(kind,.06)
	var kick:=(.42 if kind=="leviata" else .3)*(1. if _rng.randf()<.5 else -1.)
	boat.take_hit(damage,kick)
	lair.hits=int(lair.hits)+1
	var fx=game.world.ocean.effects
	if fx!=null:
		var side:=b+boat.global_basis.x*(3. if kick>0. else -3.)
		fx.splash(side,2.2,true);fx.splash(b,1.4,true)
	var text: Dictionary={"kraken":"Um tentáculo golpeia o casco! (%d%%)","serpente":"A serpente investe contra o barco! (%d%%)","leviata":"O leviatã salta: a onda joga o barco! (%d%%)","megalodonte":"O megalodonte morde o casco! (%d%%)"}
	game.hud.notify(str(text.get(kind,"Impacto! (%d%%)"))%int(boat.integrity*100.))
	game.audio.cue_at("slam",b+boat.global_basis.x*(3. if kick>0. else -3.))
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
		"megalodonte":
			# Low in the water, fin up; a strike rears the head out and opens the jaw on the hull.
			var bite:=sin(clampf(slam/1.2,0.,1.)*PI)
			for part: GeometryInstance3D in node.get_meta("parts"):
				part.set_instance_shader_parameter("raise",bite*.55)
				part.set_instance_shader_parameter("lunge",bite*.5)
				part.set_instance_shader_parameter("jaw",.05+bite*.7)
		_:
			# Head held up out of the water, swaying; a strike lunges at the boat with the jaw wide open.
			var strike:=sin(clampf(slam/1.2,0.,1.)*PI)
			var raise_head: float=smoothstep(2.,6.,t)*(.75+.25*sin(t*.4))
			for part: GeometryInstance3D in node.get_meta("parts"):
				part.set_instance_shader_parameter("raise",raise_head)
				part.set_instance_shader_parameter("lunge",strike)
				part.set_instance_shader_parameter("jaw",.12+.08*sin(t*.9)+strike*.55)


## Glowing eggs on the bottom at the heart of the territory.
func _nest(lair: Dictionary) -> void:
	var c: Vector3=lair.center
	var floor_y:=-Waves.depth_at(Vector2(c.x,c.z))
	var nest:=Node3D.new();nest.name="Ninho";nest.position=Vector3(c.x,floor_y,c.z);add_child(nest)
	var color: Color={"kraken":Color("ff7a5a"),"serpente":Color("8aff7a"),"leviata":Color("7fe6ff"),"megalodonte":Color("e8e8f0")}.get(lair.kind,Color("ffd27d"))
	var egg:=_glow(color,2.2)
	for k: int in 7:
		var a:=float(k)*TAU/7.
		_ball(nest,Vector3(cos(a)*2.2,1.,sin(a)*2.2),Vector3(1.6,2.2,1.6),egg,12)
	var light:=OmniLight3D.new();light.light_color=color;light.omni_range=22.;light.light_energy=2.;light.position.y=3.;nest.add_child(light)

# --- Player actions: flare and harpoon ------------------------------------------------------------------

func _active() -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	for lair: Dictionary in lairs:
		if str(lair.state) in ["caca","atacando","observando"]:out.append(lair)
	return out

## True while a guardian is up next to the boat (used for the on-screen hint).
func encounter() -> bool:return not _active().is_empty()

## Y: a red distress flare. Any guardian surfaced or stirring nearby dives and stays down for 90 s.
func fire_flare() -> String:
	if not game.player.in_boat:return "Sinalizadores só do barco."
	if game.inventory.flares<=0:return "Sem sinalizadores. A loja de pesca vende 3 por 25 moedas."
	game.inventory.flares-=1;game.inventory.changed.emit()
	var b: Vector3=game.boat.global_position
	_flare_fx(b+Vector3(0,2.,0))
	var scared:=false
	for lair: Dictionary in lairs:
		var c: Vector3=lair.center
		if str(lair.state) in ["alerta","caca","atacando","observando"] and Vector2(b.x-c.x,b.z-c.z).length()<float(lair.radius)*1.2:
			lair.state="recuando";lair.clock=0.;lair.calm=90.;scared=true
			(lair.bubbles as CPUParticles3D).emitting=false
	game.audio.cue("flare")
	return "O clarão vermelho espanta a criatura! Ela mergulha… você tem 90 s." if scared else "O sinalizador sobe e se apaga. Nada por perto."

## H: the bow harpoon, aimed where the camera looks. Hits wear the guardian down; at zero it flees and pays.
func fire_harpoon() -> String:
	if not game.player.in_boat:return "O arpão fica na proa do barco."
	if game.inventory.equipment.get("harpoon",0)<1:return "Sem arpão de proa. O estaleiro instala um por 140 moedas."
	if game.inventory.harpoons<=0:return "Sem arpões. O estaleiro vende 4 por 20 moedas."
	game.inventory.harpoons-=1;game.inventory.changed.emit()
	var boat: Node3D=game.boat
	var from: Vector3=boat.global_position-boat.global_basis.z*3.+Vector3(0,1.6,0)
	# Aimed through the camera like a sight; the harpoon itself flies from the bow to the hit point.
	var eye: Vector3=game.player.camera.global_position
	var dir: Vector3=-(game.player.camera.global_basis.z as Vector3)
	var hit_lair: Dictionary={};var hit_point:=eye+dir*80.
	if hit_point.y<0.:hit_point=eye+dir*(eye.y/maxf(-dir.y,.01))
	for lair: Dictionary in _active():
		var node: Node3D=lair.node
		var target:=node.global_position+Vector3.UP*float(TARGET_HEIGHT.get(lair.kind,2.))
		var t:=(target-eye).dot(dir)
		if t<0. or t>130.:continue
		if (eye+dir*t).distance_to(target)<float(TARGET_RADIUS.get(lair.kind,7.)):hit_lair=lair;hit_point=eye+dir*t;break
	_harpoon_fx(from,hit_point)
	game.audio.cue("harpoon")
	if hit_lair.is_empty():return "O arpão cai na água. (%d restantes)"%game.inventory.harpoons
	hit_lair.hp=int(hit_lair.hp)-1
	hit_lair.strike=float(hit_lair.strike)+3.;hit_lair["slam"]=.6
	var fx=game.world.ocean.effects
	if fx!=null:fx.splash(Vector3(hit_point.x,0,hit_point.z),1.8,true)
	game.audio.cue_at("roar",hit_point,-6. if int(hit_lair.hp)>0 else 2.)
	if int(hit_lair.hp)>0:
		return "Arpão cravado no %s! (%d/%d)"%[hit_lair.name,int(HEALTH.get(hit_lair.kind,5))-int(hit_lair.hp),int(HEALTH.get(hit_lair.kind,5))]
	# Driven off: it dives, stays calm for ten minutes and the harbour pays the bounty.
	hit_lair.state="recuando";hit_lair.clock=0.;hit_lair.calm=600.;hit_lair.hp=int(HEALTH.get(hit_lair.kind,5))
	var bounty: int=int(BOUNTY.get(hit_lair.kind,150))
	game.inventory.money+=bounty
	game.inventory.record({"id":"vitoria_"+str(hit_lair.kind),"name":"Vitória: "+str(hit_lair.name),"rarity":"Lendária","weight":0.,"observation":true})
	game.inventory.changed.emit()
	return "O guardião do %s foge ferido para o abismo! Recompensa do porto: +%d moedas."%[hit_lair.name,bounty]

func _flare_fx(at: Vector3) -> void:
	var flare:=Node3D.new();add_child(flare);flare.global_position=at
	var light:=OmniLight3D.new();light.light_color=Color("ff3b2a");light.light_energy=6.;light.omni_range=90.;flare.add_child(light)
	var ball:=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=.35;sm.height=.7;ball.mesh=sm
	ball.material_override=_glow(Color("ff4a30"),8.);flare.add_child(ball)
	var smoke:=CPUParticles3D.new();smoke.amount=40;smoke.lifetime=2.5;smoke.direction=Vector3.DOWN;smoke.spread=25.;smoke.initial_velocity_min=.5;smoke.initial_velocity_max=1.5
	smoke.gravity=Vector3(0,-.3,0);var pm:=SphereMesh.new();pm.radius=.3;pm.height=.6;var smat:=StandardMaterial3D.new();smat.albedo_color=Color(1.,.55,.5,.45);smat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.material=smat;smoke.mesh=pm;flare.add_child(smoke)
	_shots.append({"node":flare,"clock":0.,"kind":"flare","from":at,"to":at+Vector3(0,60,0)})

func _harpoon_fx(from: Vector3,to: Vector3) -> void:
	var shot:=Node3D.new();add_child(shot);shot.global_position=from
	var shaft:=MeshInstance3D.new();var cm:=CylinderMesh.new();cm.top_radius=.04;cm.bottom_radius=.04;cm.height=2.2;shaft.mesh=cm
	shaft.material_override=_wet(Color("6b6f72"),.3);shaft.rotation.x=-PI*.5;shot.add_child(shaft)
	var tip:=MeshInstance3D.new();var tm:=CylinderMesh.new();tm.top_radius=0.;tm.bottom_radius=.1;tm.height=.4;tip.mesh=tm
	tip.material_override=_wet(Color("c9c9c4"),.2);tip.rotation.x=-PI*.5;tip.position.z=-1.25;shot.add_child(tip)
	shot.look_at(to if to.distance_to(from)>.1 else from+Vector3.FORWARD)
	_shots.append({"node":shot,"clock":0.,"kind":"harpoon","from":from,"to":to})

func _process(delta: float) -> void:
	for s: Dictionary in _shots.duplicate():
		s.clock=float(s.clock)+delta
		var node: Node3D=s.node
		if s.kind=="harpoon":
			var k:=clampf(float(s.clock)/.45,0.,1.)
			node.global_position=(s.from as Vector3).lerp(s.to,k)+Vector3.UP*sin(k*PI)*1.2
			if float(s.clock)>3.:node.queue_free();_shots.erase(s)
		else:
			var k:=clampf(float(s.clock)/2.5,0.,1.)
			node.global_position=(s.from as Vector3).lerp(s.to,1.-pow(1.-k,2.))-Vector3(0,maxf(0.,float(s.clock)-2.5)*3.,0)
			(node.get_child(0) as OmniLight3D).light_energy=6.*clampf(8.-float(s.clock),0.,1.)
			if float(s.clock)>9.:node.queue_free();_shots.erase(s)
