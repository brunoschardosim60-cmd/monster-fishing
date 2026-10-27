extends Node3D
## Rare creatures of the open sea: every few minutes a whale crosses the water nearby. The monsters (kraken, sea serpent,
## leviathan) live only in their territories, see monster_lairs.gd.
## Each one stays for about a minute and then leaves. The world map shows them while they are out.
signal event_started(text: String)
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Flora=preload("res://scripts/world/biome_flora.gd")
const WHALE_SPEED: float=2.6
const WHALE_LIFE: float=70.

var boat: Node3D
var clock: float=0.
var next_at: float=150.
var current: Node3D=null
var kind: String=""
var lived: float=0.
var rng:=RandomNumberGenerator.new()
var spawned: int=0

func _ready() -> void:
	rng.seed=7741

func set_player_boat(value: Node3D) -> void:
	boat=value

func _process(delta: float) -> void:
	if boat==null: return
	clock+=delta
	_update_ambient(delta)
	if current!=null:
		lived+=delta
		current.position+=-current.basis.z*WHALE_SPEED*delta
		# Breathing cycle: ~25 s near the surface (back awash, spouting), then a dive.
		var cycle:=fmod(lived+float(current.get_meta("dive",0.))*6.,40.)
		var depth:=-.6 if cycle<25. else -.6-sin((cycle-25.)/15.*PI)*7.
		current.position.y=lerpf(current.position.y,depth,1.-exp(-delta*.6))
		current.rotation.x=lerpf(current.rotation.x,(-.12 if cycle>25. and cycle<32. else (.1 if cycle>33. else 0.)),1.-exp(-delta))
		var spout: CPUParticles3D=current.get_meta("spout") if current.has_meta("spout") else null
		if spout!=null and cycle<25. and fmod(cycle,8.)<delta:spout.restart();spout.emitting=true
		preload("res://scripts/creatures/big_animals.gd").beat_fluke(current)
		if lived>WHALE_LIFE: _retire()
		return
	if clock>=next_at:
		_spawn()

func _retire() -> void:
	current.queue_free();current=null;kind=""
	var season: int=0
	var ocean=get_parent().get("ocean")
	if ocean!=null:season=ocean.season()
	next_at=clock+rng.randf_range(300.,540.)*(.4 if season==1 else 1.)

## A point in open water 260–420 m from the boat, or Vector3.INF if none is found.
func _open_point() -> Vector3:
	for attempt: int in 30:
		var angle:=rng.randf()*TAU;var dist:=rng.randf_range(260.,420.)
		var p:=boat.global_position+Vector3(cos(angle),0.,sin(angle))*dist
		if Layout.coast(Vector2(p.x,p.z)).x>80.:return Vector3(p.x,0.,p.z)
	return Vector3.INF

func _spawn() -> void:
	var at:=_open_point()
	if at==Vector3.INF:
		next_at=clock+20.;return
	spawned+=1
	lived=0.
	# Krakens and other monsters live only in their territories (monster_lairs.gd); out here, whales.
	kind="whale";current=_build_whale()
	var heading:=Vector3(cos(rng.randf()*TAU),0.,0.);heading=heading.normalized()
	current.rotation.y=atan2(-heading.x,-heading.z)
	current.position=at
	event_started.emit("Uma baleia cruza as águas ao seu redor.")
	add_child(current)

func _build_whale() -> Node3D:
	# Sculpted humpback (big_animals.gd): it cruises, blows at the surface and dives for a while.
	var whale:=preload("res://scripts/creatures/big_animals.gd").whale(rng.randf_range(12.,16.))
	whale.set_meta("dive",rng.randf()*TAU)
	return whale

# ---------------------------------------------------------------- ambient life
# Small, harmless moments that keep long trips interesting: jellyfish swarms, rays, squid, shooting stars,
# rain squalls and rough seas. They never need the player to act, and they are never dangerous.
var ambient: Array[Dictionary]=[]
var next_ambient: float=70.
var next_star: float=12.
var rain: GPUParticles3D
var rain_until: float=0.
var rough_until: float=0.
var rough_saved: float=-1.
## Weather state before a rough-sea spell, restored afterwards (-1 means the cycle was automatic).
var rough_previous: int=-1
const AMBIENT_LIFE: Dictionary={"agua_viva":50.,"arraia":45.,"lula":40.}

func _update_ambient(delta: float) -> void:
	_update_rain()
	_update_rough_sea()
	for record: Dictionary in ambient.duplicate():
		record.t+=delta
		_animate_ambient(record)
		if record.t>float(record.life):
			(record.node as Node3D).queue_free();ambient.erase(record)
	var night: bool=_is_night()
	if night:
		next_star-=delta
		if next_star<=0.:
			_shooting_star();next_star=rng.randf_range(8.,20.)
	next_ambient-=delta
	if next_ambient<=0. and current==null:
		next_ambient=rng.randf_range(70.,130.)
		_spawn_ambient(night)

func _is_night() -> bool:
	var hour: float=float(get_parent().ocean.hour)
	return hour<6. or hour>20.

func _spawn_ambient(night: bool) -> void:
	if ambient.size()>=6:return
	var roll:=rng.randf()
	if roll<.18:
		rain_until=clock+rng.randf_range(70.,120.);_say("Uma chuva forte começa a cair sobre o mar.");return
	if roll<.3:
		# The weather owns the wind (Waves is rewritten from it every frame), so ask it for a rough sea.
		var weather=get_parent().ocean.weather
		rough_previous=-1 if weather.automatic else int(weather.state)
		rough_saved=1.;rough_until=clock+rng.randf_range(60.,90.);weather.choose(2)
		_say("O mar fica agitado: ondas grandes se formam.");return
	var kinds: Array=["agua_viva","arraia"]
	if night:kinds.append("lula")
	var kind: String=kinds[rng.randi() % kinds.size()]
	var at:=_open_point_near(140.,240.)
	if at==Vector3.INF:return
	var node:=_build_ambient(kind)
	node.position=at;add_child(node)
	ambient.append({"node":node,"kind":kind,"t":0.,"life":AMBIENT_LIFE[kind],"origin":at,"seed":rng.randf()*TAU})
	var text:Dictionary={"agua_viva":"Um cardume de águas-vivas brilha perto do barco.","arraia":"Uma arraia desliza pela superfície.","lula":"Uma lula surge à luz da noite."}
	_say(text[kind])

func _open_point_near(near: float,far: float) -> Vector3:
	for attempt: int in 30:
		var angle:=rng.randf()*TAU;var dist:=rng.randf_range(near,far)
		var p:=boat.global_position+Vector3(cos(angle),0.,sin(angle))*dist
		if Layout.coast(Vector2(p.x,p.z)).x>60.:return Vector3(p.x,0.,p.z)
	return Vector3.INF

func _say(text: String) -> void:
	event_started.emit(text)

func _build_ambient(kind: String) -> Node3D:
	var holder:=Node3D.new();holder.name=kind
	match kind:
		"agua_viva":
			# Jellyfish from Bruno's marine pack, translucent and glowing.
			var jelly_mat:=ShaderMaterial.new();jelly_mat.shader=preload("res://assets/shaders/jelly.gdshader")
			jelly_mat.set_shader_parameter("tint",Color("b8f0ff") if rng.randf()<.5 else Color("ffc4ec"));jelly_mat.set_shader_parameter("glow",1.2)
			for i: int in 9:
				var jelly:=MeshInstance3D.new();jelly.mesh=load("res://assets/models/imported/jelly_%s.res"%"abcd"[i%4]);jelly.material_override=jelly_mat
				jelly.scale=Vector3.ONE*rng.randf_range(1.,1.7);jelly.set_instance_shader_parameter("phase",rng.randf()*TAU)
				jelly.position=Vector3(rng.randf_range(-4.,4.),-.6,rng.randf_range(-4.,4.));holder.add_child(jelly)
		"arraia":
			# A manta cruising just under the surface (same disc and skin as the shallow-water rays).
			var Meshes:=preload("res://scripts/creatures/creature_meshes.gd")
			var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/ray_skin.gdshader")
			mat.set_shader_parameter("manta",true);mat.set_shader_parameter("span",4.6);mat.set_shader_parameter("beat",1.);mat.set_shader_parameter("top_color",Color("1d1f22"))
			var disc:=MeshInstance3D.new();disc.mesh=Meshes.ray_disc("manta",4.2,4.2*.62,4.2*.1);disc.material_override=mat;disc.name="Asas";holder.add_child(disc)
		"lula":
			var squid:=preload("res://scripts/creatures/big_animals.gd").squid(2.6);holder.add_child(squid)
	return holder

func _animate_ambient(record: Dictionary) -> void:
	var node: Node3D=record.node;var t: float=record.t;var seed_value: float=record.seed;var origin: Vector3=record.origin
	match str(record.kind):
		"agua_viva":
			node.position=origin+Vector3(sin(t*.25+seed_value)*6.,sin(t*1.3)*.5,cos(t*.2+seed_value)*6.)
			pass
		"arraia":
			var r:=18.;node.position=origin+Vector3(cos(t*.09+seed_value)*r,-.1,sin(t*.09+seed_value)*r)
			node.rotation.y=-(t*.09+seed_value)+PI*.5
			pass
		"lula":
			var r2:=10.;node.position=origin+Vector3(cos(t*.5+seed_value)*r2,sin(t*2.)*.4,sin(t*.5+seed_value)*r2)
			node.rotation.y=-(t*.5+seed_value)+PI*.5

func _shooting_star() -> void:
	if boat==null:return
	next_star=rng.randf_range(8.,20.)
	var from:=boat.global_position+Vector3(rng.randf_range(-120.,120.),rng.randf_range(90.,130.),rng.randf_range(-120.,120.))
	var dir:=Vector3(rng.randf_range(-1.,1.),-.35,rng.randf_range(-1.,1.)).normalized()
	var streak:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.12,.12,9.);streak.mesh=box
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(1.,.97,.85);mat.emission_enabled=true;mat.emission=Color(1.,.95,.8);mat.emission_energy_multiplier=4.;streak.material_override=mat
	add_child(streak);streak.look_at_from_position(from,from+dir,Vector3.UP)
	var tween:=create_tween();tween.tween_property(streak,"position",from+dir*70.,1.2);tween.tween_callback(streak.queue_free)

func _update_rain() -> void:
	if rain==null:
		rain=GPUParticles3D.new();rain.amount=900;rain.lifetime=.9;rain.visibility_aabb=AABB(Vector3(-40,-30,-40),Vector3(80,60,80))
		var pm:=ParticleProcessMaterial.new();pm.direction=Vector3(0,-1,0);pm.spread=4.;pm.initial_velocity_min=22.;pm.initial_velocity_max=26.
		pm.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;pm.emission_box_extents=Vector3(38.,1.,38.);pm.gravity=Vector3.ZERO
		rain.process_material=pm
		var drop:=BoxMesh.new();drop.size=Vector3(.03,.6,.03);var dm:=StandardMaterial3D.new();dm.albedo_color=Color(.75,.85,.95,.6);dm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;drop.material=dm
		rain.draw_pass_1=drop;add_child(rain)
	var raining:=clock<rain_until
	rain.emitting=raining
	if raining and boat!=null:rain.global_position=boat.global_position+Vector3(0,22.,0)

func _update_rough_sea() -> void:
	if rough_saved>=0. and clock>=rough_until:
		get_parent().ocean.weather.choose(rough_previous);rough_saved=-1.
