extends Node3D
## Whirlpools. Each site has its own conditions and a secret:
##   always    — the Dentes do Mar maelstroms never rest;
##   storm     — only while a storm cell covers it;
##   rough     — only when the swell is rough (energy > .55);
##   night     — only between dusk and dawn.
## While active the sea sinks into a funnel with a spiral of foam (ocean_common / wave_field), the current
## carries a boat around and inwards, spins it, and the centre batters the hull. Full throttle across the
## current escapes it. Under each one something waits: a sea cave with a chest (diving), an old wreck, or
## tentacles that rise if a boat lingers. Sites are revealed on the map once seen.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
var world: Node3D
var sites: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()
var _warned: bool=false
## Fine radial meshes drawing the funnels (rings packed towards the throat), one per shaped whirlpool,
## with the sea's own material: the regular grids leave the inside of each whirlpool to these.
var funnels: Array[MeshInstance3D]=[]
static var _funnel_mesh: ArrayMesh

static func funnel_mesh() -> ArrayMesh:
	if _funnel_mesh!=null:return _funnel_mesh
	const SEG: int=112
	const RINGS: int=72
	var verts:=PackedVector3Array();var idx:=PackedInt32Array()
	verts.append(Vector3.ZERO)
	for r: int in RINGS:
		# Unit radius; rings crowd towards the centre where the throat is steep.
		var rad: float=pow(float(r+1)/float(RINGS),1.7)
		for k: int in SEG:
			var a: float=float(k)/float(SEG)*TAU
			verts.append(Vector3(cos(a)*rad,0.,sin(a)*rad))
	for k: int in SEG:idx.append_array([0,1+k,1+(k+1)%SEG])
	for r: int in RINGS-1:
		var a0: int=1+r*SEG;var a1: int=1+(r+1)*SEG
		for k: int in SEG:
			var k1: int=(k+1)%SEG
			idx.append_array([a0+k,a1+k,a0+k1,a0+k1,a1+k,a1+k1])
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_INDEX]=idx
	var normals:=PackedVector3Array();normals.resize(verts.size());normals.fill(Vector3.UP);arrays[Mesh.ARRAY_NORMAL]=normals
	_funnel_mesh=ArrayMesh.new();_funnel_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _funnel_mesh

func _update_funnels() -> void:
	if world==null or world.get("ocean_material")==null:return
	while funnels.size()<4:
		var m:=MeshInstance3D.new();m.name="Funil_%d"%funnels.size();m.mesh=funnel_mesh();m.material_override=world.ocean_material
		m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;m.visible=false;add_child(m);funnels.append(m)
	for i: int in 4:
		var m: MeshInstance3D=funnels[i]
		if i>=Waves.whirls.size():m.visible=false;continue
		var wh: Vector4=Waves.whirls[i]
		m.visible=true
		# Unit mesh scaled to the whirlpool (in x/z only: heights come from the sea shader).
		m.position=Vector3(wh.x,0.,wh.y);m.scale=Vector3(wh.z,1.,wh.z)
		m.custom_aabb=AABB(Vector3(-1.,-50.,-1.),Vector3(2.,60.,2.))
		m.set_instance_shader_parameter("funnel",Vector4(wh.x,wh.y,wh.z,1.))

func _ready() -> void:
	_rng.seed=909
	# Dentes do Mar (shards) and the other storm/mystic waters get their whirlpools; plus open-sea ones.
	for i: int in Layout.LOBES.size():
		var region: Dictionary=Layout.region_for_lobe(i)
		if not bool(region.get("map_visible",false)):continue
		var biome: String=region.get("biome","")
		var id: String=region.get("id","")
		if id=="shards":
			_site(_off_coast(i,0.,140.),95.,"always","gruta");_site(_off_coast(i,180.,160.),75.,"always","criatura")
		elif id=="tempest":_site(_off_coast(i,90.,220.),110.,"storm","naufragio")
		elif biome=="mystic":_site(_off_coast(i,270.,170.),80.,"night","gruta")
		elif id=="adverse":_site(_off_coast(i,45.,200.),90.,"rough","naufragio")
	_site(Vector2(-900.,-1150.),85.,"rough","criatura")
	_site(Vector2(1900.,3200.),100.,"night","naufragio")
	_site(Vector2(763.,-2252.),70.,"rough","gruta")

func _off_coast(lobe: int,angle_deg: float,distance: float) -> Vector2:
	var l: Vector4=Layout.LOBES[lobe];var dir:=Vector2.from_angle(deg_to_rad(angle_deg));var p:=Vector2(l.x,l.y)
	for step: int in 900:
		p+=dir*3.
		if Layout.coast(p).x>=distance:return p
	return p

func _site(at: Vector2,radius: float,condition: String,secret: String) -> Dictionary:
	var floor_y:=-Waves.depth_at(at)
	var site:={"pos":at,"radius":radius,"condition":condition,"secret":secret,"strength":0.,"seen":false,"inside":0.,"floor":floor_y,
		"node":null,"tentacle":0.}
	var node:=Node3D.new();node.name="Redemoinho_%d"%sites.size();node.position=Vector3(at.x,0,at.y);add_child(node)
	site.node=node
	if secret=="gruta":_build_cave(node,floor_y)
	elif secret=="criatura":
		var Meshes:=preload("res://scripts/creatures/creature_meshes.gd")
		var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/kraken_skin.gdshader")
		mat.set_shader_parameter("tentacle",true);mat.set_shader_parameter("arm_length",16.);mat.set_shader_parameter("curl",.1)
		var arms: Array[MeshInstance3D]=[]
		for k: int in 3:
			var arm:=MeshInstance3D.new();arm.mesh=Meshes.tube("whirl_arm",16.,1.,.08,26,12);arm.material_override=mat
			arm.position=Vector3(cos(float(k)*2.1)*12.,-20.,sin(float(k)*2.1)*12.);arm.visible=false;arm.extra_cull_margin=20.;node.add_child(arm);arms.append(arm)
		site["arms"]=arms
	sites.append(site)
	return site

## A sea cave on the bottom: a rock arch with glowing crystals and a chest (opened by diving, see diving.gd).
func _build_cave(node: Node3D,floor_y: float) -> void:
	var rock:=StandardMaterial3D.new();rock.albedo_color=Color("3c4447");rock.roughness=.9
	var crystal:=StandardMaterial3D.new();crystal.albedo_color=Color("7fe6ff");crystal.emission_enabled=true;crystal.emission=Color("5fd8ff");crystal.emission_energy_multiplier=2.5
	var cave:=Node3D.new();cave.name="Gruta";cave.position=Vector3(0,floor_y,0);node.add_child(cave)
	for k: int in 9:
		var a:=float(k)/8.*PI
		var m:=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=3.2;sm.height=6.;m.mesh=sm;m.material_override=rock
		m.position=Vector3(cos(a)*7.,sin(a)*6.,0.);m.scale=Vector3(1.,1.,1.6+float(k%3)*.3);cave.add_child(m)
	for k: int in 7:
		var c:=MeshInstance3D.new();var pm:=PrismMesh.new();pm.size=Vector3(.6,1.8+float(k%3),.6);c.mesh=pm;c.material_override=crystal
		c.position=Vector3(_rng.randf_range(-5.,5.),.8,_rng.randf_range(-3.,3.));c.rotation=Vector3(_rng.randf_range(-.4,.4),0,_rng.randf_range(-.4,.4));cave.add_child(c)
	var glow:=OmniLight3D.new();glow.light_color=Color("5fd8ff");glow.light_energy=2.;glow.omni_range=14.;glow.position.y=2.;cave.add_child(glow)
	cave.set_meta("chest_at",Vector3(0,floor_y+.4,0))

func active(site: Dictionary) -> bool:
	var at: Vector2=site.pos
	match str(site.condition):
		"always":return true
		"storm":return Waves.storm_factor(at)>.35
		"rough":return Waves.energy>.55 or Waves.storm_factor(at)>.3
		"night":
			var ocean=world.ocean if world!=null else null
			return ocean!=null and (float(ocean.hour)>19.5 or float(ocean.hour)<5.5)
	return false

## Dev: a whirlpool right here, at full strength, for three minutes.
func spawn_near(at: Vector3) -> String:
	var s:=_site(Vector2(at.x,at.z),90.,"always","criatura")
	s["expires"]=180.
	return "Um redemoinho se abre à frente!"

func _physics_process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	var eye:=Vector2.ZERO if camera==null else Vector2(camera.global_position.x,camera.global_position.z)
	var shaping: Array[Vector4]=[]
	for site: Dictionary in sites.duplicate():
		if site.has("expires"):
			site.expires=float(site.expires)-delta
			if float(site.expires)<=0.:(site.node as Node3D).queue_free();sites.erase(site);continue
		var want:=1. if active(site) else 0.
		site.strength=move_toward(float(site.strength),want,delta/25.)
		if float(site.strength)>.01 and (site.pos as Vector2).distance_to(eye)<1800.:
			shaping.append(Vector4((site.pos as Vector2).x,(site.pos as Vector2).y,float(site.radius),float(site.strength)))
			if not bool(site.seen) and (site.pos as Vector2).distance_to(eye)<500.:site.seen=true
	shaping.sort_custom(func(a: Vector4,b: Vector4) -> bool:return Vector2(a.x,a.y).distance_squared_to(eye)<Vector2(b.x,b.y).distance_squared_to(eye))
	Waves.whirls=shaping.slice(0,4)
	_update_funnels()
	var game=get_tree().get_first_node_in_group("game")
	if game!=null and game.started:_pull(game,delta)

## The current: carries the boat around the funnel and inwards; the centre spins it and batters the hull.
func _pull(game: Node,delta: float) -> void:
	var boat: CharacterBody3D=game.boat
	var b:=Vector2(boat.global_position.x,boat.global_position.z)
	var caught:=false
	for site: Dictionary in sites:
		var s: float=site.strength;if s<.05:continue
		var c: Vector2=site.pos;var r: float=site.radius
		var d:=b.distance_to(c);if d>r*1.15:site.inside=0.;continue
		caught=true
		var t:=clampf(1.-d/r,0.,1.)
		var inward:=(c-b)/maxf(d,.1);var around:=Vector2(-inward.y,inward.x)
		var drift:=around*s*(3.+9.*pow(t,.8))+inward*s*(1.+3.5*t)
		boat.global_position+=Vector3(drift.x,0,drift.y)*delta
		boat.rotation.y+=s*(.25+.9*t)*delta
		site.inside=float(site.inside)+delta
		if t>.78 and fmod(float(site.inside),1.5)<delta:
			boat.take_hit(.03*s,.25)
			if game.world.ocean.effects!=null:game.world.ocean.effects.splash(boat.global_position,1.6,true)
			game.audio.cue("slam")
		if str(site.secret)=="criatura":_tentacles(site,game,delta,t)
	if caught and not _warned:
		_warned=true;game.hud.notify("Um redemoinho puxa o barco! Acelere contra a corrente para escapar (SHIFT dá turbo).")
	elif not caught:_warned=false

func _tentacles(site: Dictionary,game: Node,delta: float,t: float) -> void:
	var arms: Array=site.get("arms",[])
	var rise:=clampf((float(site.inside)-6.)/4.,0.,1.) if t>.3 else 0.
	site.tentacle=move_toward(float(site.tentacle),rise,delta*.5)
	for k: int in arms.size():
		var arm: MeshInstance3D=arms[k]
		arm.visible=float(site.tentacle)>.02
		arm.position.y=lerpf(-20.,-4.,float(site.tentacle))
		var to: Vector3=game.boat.global_position-arm.global_position;to.y=0.
		arm.rotation.y=atan2(to.x,to.z)+float(k)
	if float(site.tentacle)>.9 and fmod(float(site.inside),4.)<delta:
		game.boat.take_hit(.05,.35);game.audio.cue_at("roar",game.boat.global_position+Vector3(0,4,10),-4.)
		game.hud.notify("Tentáculos sobem do fundo do redemoinho!")

## Sites seen so far, for the map: [Vector2 position, radius, active].
func seen_sites() -> Array:
	var out:=[]
	for site: Dictionary in sites:
		if bool(site.seen):out.append([site.pos,site.radius,float(site.strength)>.3])
	return out
