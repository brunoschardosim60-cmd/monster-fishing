extends Node3D
## Rare creatures of the open sea. Every few minutes a whale crosses the water nearby, or (rarer) a kraken rises beside the boat.
## Each one stays for about a minute and then leaves. The world map shows them while they are out.
signal event_started(text: String)
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Flora=preload("res://scripts/world/biome_flora.gd")
const WHALE_SPEED: float=2.6
const WHALE_LIFE: float=70.
const KRAKEN_LIFE: float=62.

var boat: Node3D
var clock: float=0.
var next_at: float=150.
var current: Node3D=null
var kind: String=""
var lived: float=0.
var rng:=RandomNumberGenerator.new()
var tentacles: Array[Node3D]=[]
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
		if kind=="whale":
			current.position+=-current.basis.z*WHALE_SPEED*delta
			if lived>WHALE_LIFE: _retire()
		else:
			_animate_kraken(lived)
			if lived>KRAKEN_LIFE: _retire()
		return
	if clock>=next_at:
		_spawn()

func _retire() -> void:
	current.queue_free();current=null;kind=""
	next_at=clock+rng.randf_range(300.,540.)

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
	if rng.randf()<.35:
		kind="kraken";current=_build_kraken();current.position=at+Vector3(0,-9.,0)
		event_started.emit("Algo se move nas profundezas... um kraken está perto do seu barco!")
	else:
		kind="whale";current=_build_whale()
		var heading:=Vector3(cos(rng.randf()*TAU),0.,0.);heading=heading.normalized()
		current.rotation.y=atan2(-heading.x,-heading.z)
		current.position=at
		event_started.emit("Uma baleia cruza as águas ao seu redor.")
	add_child(current)

func _build_whale() -> Node3D:
	var holder:=Node3D.new();holder.name="Baleia"
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark:=Color("2b3a4a");var belly:=Color("c9d6dc")
	Flora._blob(st,Vector3(0,0,0),Vector3(1.8,1.6,6.2),belly,dark)
	Flora._frustum(st,Vector3(0,0,-6.0),Vector3(0,.4,-8.4),1.0,.25,dark,dark,6)
	Flora._frustum(st,Vector3(0,.2,-8.4),Vector3(0,.25,-9.2),.6,.1,dark,dark,5)
	st.generate_normals()
	var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=Flora.mat();holder.add_child(node)
	return holder

func _build_kraken() -> Node3D:
	var holder:=Node3D.new();holder.name="Kraken";tentacles.clear()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var purple:=Color("3a1f4f");var glow:=Color("8a5fd0")
	Flora._blob(st,Vector3(0,0,0),Vector3(3.2,2.6,3.2),purple,glow)
	st.generate_normals()
	var body:=MeshInstance3D.new();body.mesh=st.commit();body.material_override=Flora.mat();holder.add_child(body)
	for i: int in 8:
		var a:=float(i)*TAU/8.
		var pivot:=Node3D.new();pivot.position=Vector3(cos(a)*2.4,-.6,sin(a)*2.4);holder.add_child(pivot)
		var ts:=SurfaceTool.new();ts.begin(Mesh.PRIMITIVE_TRIANGLES)
		Flora._frustum(ts,Vector3.ZERO,Vector3(0,-7.5,0),.7,.1,purple,glow,6)
		ts.generate_normals()
		var tentacle:=MeshInstance3D.new();tentacle.mesh=ts.commit();tentacle.material_override=Flora.mat();pivot.add_child(tentacle)
		pivot.set_meta("base",Vector3(sin(a)*.5,0.,-cos(a)*.5))
		tentacles.append(pivot)
	for side: float in [-1.,1.]:
		var eye:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.32;sphere.height=.64;eye.mesh=sphere
		var eye_mat:=StandardMaterial3D.new();eye_mat.albedo_color=Color("ffd34e");eye_mat.emission_enabled=true;eye_mat.emission=Color("ffd34e");eye_mat.emission_energy_multiplier=2.;eye.material_override=eye_mat
		eye.position=Vector3(side*1.1,.9,2.7);holder.add_child(eye)
	return holder

func _animate_kraken(t: float) -> void:
	if current==null:return
	var rise:=smoothstep(0.,6.,t)
	var sink:=smoothstep(KRAKEN_LIFE-8.,KRAKEN_LIFE,t)
	current.position.y=lerpf(-9.,-1.2,rise)-sink*8.
	for i: int in tentacles.size():
		var base: Vector3=tentacles[i].get_meta("base")
		var wave:=sin(t*1.4+float(i)*.8)*.22
		tentacles[i].rotation=base+Vector3(wave,0.,-wave*.5)
	current.rotation.y=t*.05

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
			for i: int in 9:
				var disc:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.9;sphere.height=.5;disc.mesh=sphere
				var mat:=StandardMaterial3D.new();var c:=Color("9be8ff") if i%2==0 else Color("ff9ee0")
				mat.albedo_color=Color(c.r,c.g,c.b,.75);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.emission_enabled=true;mat.emission=c;mat.emission_energy_multiplier=1.6
				disc.material_override=mat;disc.position=Vector3(rng.randf_range(-4.,4.),-.2,rng.randf_range(-4.,4.));holder.add_child(disc)
		"arraia":
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			Flora._blob(st,Vector3.ZERO,Vector3(2.4,.28,1.5),Color("5a6470"),Color("3a4350"))
			st.generate_normals()
			var wing:=MeshInstance3D.new();wing.mesh=st.commit();wing.material_override=Flora.mat();wing.name="Asas";holder.add_child(wing)
		"lula":
			var st2:=SurfaceTool.new();st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			Flora._blob(st2,Vector3(0,0,0),Vector3(.8,.8,2.6),Color("e9b4a0"),Color("c46f5c"))
			for i: int in 4:
				var a:=float(i)*PI*.5+.4;Flora._frustum(st2,Vector3(cos(a)*.2,0,-2.4),Vector3(cos(a)*.5,0,-4.2),.12,.02,Color("c46f5c"),Color("e9b4a0"),4)
			st2.generate_normals()
			var squid:=MeshInstance3D.new();squid.mesh=st2.commit();squid.material_override=Flora.mat();holder.add_child(squid)
	return holder

func _animate_ambient(record: Dictionary) -> void:
	var node: Node3D=record.node;var t: float=record.t;var seed_value: float=record.seed;var origin: Vector3=record.origin
	match str(record.kind):
		"agua_viva":
			node.position=origin+Vector3(sin(t*.25+seed_value)*6.,sin(t*1.3)*.5,cos(t*.2+seed_value)*6.)
			for i: int in node.get_child_count():
				(node.get_child(i) as Node3D).scale=Vector3.ONE*(1.+sin(t*2.2+float(i))*.18)
		"arraia":
			var r:=18.;node.position=origin+Vector3(cos(t*.09+seed_value)*r,-.1,sin(t*.09+seed_value)*r)
			node.rotation.y=-(t*.09+seed_value)+PI*.5
			var wing: Node3D=node.get_child(0);wing.scale.y=1.+sin(t*3.)*.35
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
