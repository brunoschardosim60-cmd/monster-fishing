extends Node3D
## Gear used from the boat besides the rod:
## - Feed (C): a handful of pellets on the water draws small fish, turtles and, if the frenzy lasts, sharks.
## - Cast net (N, bought at the boatyard or fishing shop): thrown beside the stopped boat, it sinks over the
##   school and is hauled back with the fish that were under it. Feed first and the haul is bigger.
## - Crab traps (B): dropped on a sandy or rocky bottom 2-30 m deep with a buoy; after a soak they hold crabs,
##   lobsters or an octopus. Come back, stop beside the buoy and press B to haul it.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const NET_COOLDOWN: float=14.
const TRAP_SOAK: float=90.
const TRAP_REACH: float=7.
## Catches that only come from the net or the traps: name, min kg, max kg, coins per kg, rarity, colour.
const EXTRA: Dictionary={
	"manjuba":["Manjuba",.03,.08,70.,"Comum","9fd0c8"],
	"donzela":["Donzela-amarela",.06,.16,80.,"Comum","f0c419"],
	"caranguejo":["Caranguejo-guaiamum",.3,.8,45.,"Comum","3f6fa0"],
	"lagosta":["Lagosta-pintada",.5,1.6,90.,"Incomum","c8553d"],
	"polvo":["Polvo-comum",1.,3.,55.,"Rara","b46a5a"]}
var game: Node3D
var traps: Array[Dictionary]=[]
var net_state: String="pronta"
var net_clock: float=0.
var net_cooldown: float=0.
var net_point: Vector3
var net_node: Node3D
var last_haul: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Point on the water a few metres ahead of where the player looks.
func throw_point(distance: float=7.) -> Vector3:
	var cam:=get_viewport().get_camera_3d()
	var from: Vector3=game.player.global_position
	var fwd:=Vector3(0,0,-1)
	if cam!=null:fwd=-cam.global_basis.z
	fwd.y=0.;fwd=fwd.normalized() if fwd.length()>.01 else Vector3(0,0,-1)
	return from+fwd*distance

func throw_feed() -> String:
	var inv=game.inventory
	if inv.feed<=0:return "Sem ração. A loja de pesca vende 5 porções por 15 moedas."
	var at:=throw_point(6.5)
	if not game.marine.throw_feed(at):return "Jogue a ração na água."
	inv.feed-=1;inv.changed.emit()
	game.audio.cue("splash")
	return "Ração na água (%d restantes). Os peixes já vêm…"%inv.feed

# --- Cast net ------------------------------------------------------------------------------------------

func cast_net() -> String:
	if int(game.inventory.equipment.get("net",0))<1:return "Você não tem tarrafa. Compre uma na loja de pesca (90 moedas)."
	if not game.player.in_boat:return "A tarrafa é lançada do barco."
	if absf(float(game.boat.speed))>1.5:return "Pare o barco para lançar a tarrafa."
	if net_state!="pronta" or net_cooldown>0.:return "A tarrafa ainda está na água."
	var at:=throw_point(6.)
	if Layout.coast(Vector2(at.x,at.z)).x<1.:return "Lance a tarrafa na água."
	net_point=at;net_state="abrindo";net_clock=0.
	_build_net()
	game.audio.cue("splash")
	return "Tarrafa lançada!"

func _build_net() -> void:
	if net_node!=null:net_node.queue_free()
	net_node=Node3D.new();net_node.name="Tarrafa";add_child(net_node)
	var img:=Image.create(64,64,false,Image.FORMAT_RGBA8);img.fill(Color(0,0,0,0))
	for i: int in 64:
		for k: int in [0,1,16,17,32,33,48,49]:
			img.set_pixel(k,i,Color(.86,.88,.8,.9));img.set_pixel(i,k,Color(.86,.88,.8,.9))
	var tex:=ImageTexture.create_from_image(img)
	var mat:=StandardMaterial3D.new();mat.albedo_texture=tex;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.3
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.uv1_scale=Vector3(6,6,1);mat.roughness=.9
	var disc:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=.05;cone.bottom_radius=1.;cone.height=.6;cone.radial_segments=24;cone.cap_top=false;cone.cap_bottom=false
	disc.mesh=cone;disc.material_override=mat;disc.name="Malha";net_node.add_child(disc)
	var lead:=G.material(Color("55595e"),.4)
	for i: int in 18:
		var a:=float(i)*TAU/18.
		G.sphere(net_node,Vector3(cos(a),-.3,sin(a)),Vector3(.06,.06,.06),lead,6)
	net_node.position=net_point;net_node.scale=Vector3(.2,1.,.2)

func _update_net(delta: float) -> void:
	net_cooldown=maxf(0.,net_cooldown-delta)
	if net_state=="pronta" or net_node==null:return
	net_clock+=delta
	var surface:=Waves.height_at(net_point)
	match net_state:
		"abrindo":
			var t:=clampf(net_clock/.9,0.,1.)
			var arc: Vector3=game.boat.global_position.lerp(net_point,t)
			net_node.position=Vector3(arc.x,surface+sin(t*PI)*2.2+.2,arc.z)
			var r:=lerpf(.3,4.,t*t);net_node.scale=Vector3(r,1.,r)
			if t>=1.:net_state="afundando";net_clock=0.;game.world.ocean.effects.splash(net_point,1.1,true)
		"afundando":
			var t:=clampf(net_clock/2.4,0.,1.)
			net_node.position=Vector3(net_point.x,surface-t*2.4,net_point.z);net_node.scale=Vector3(4.,1.+t*.8,4.)
			if t>=1.:_haul();net_state="puxando";net_clock=0.
		"puxando":
			var t:=clampf(net_clock/1.8,0.,1.)
			var back: Vector3=net_point.lerp(game.boat.global_position,t)
			net_node.position=Vector3(back.x,lerpf(surface-2.4,surface+.6,t),back.z)
			var r:=lerpf(4.,.35,t);net_node.scale=Vector3(r,1.8-t,r)
			if t>=1.:
				net_node.queue_free();net_node=null;net_state="pronta";net_cooldown=NET_COOLDOWN
				game.hud.notify(_haul_text())

## Fish under the net come up with it; the boat's hold size limits the haul.
func _haul() -> void:
	last_haul.clear()
	var under: Dictionary={}
	for school: Node3D in game.marine.fish_schools:
		if school.predator or not school.mmi.visible:continue
		var n:=0
		for p: Vector3 in school.pos:
			if Vector2(p.x-net_point.x,p.z-net_point.z).length()<4.5 and p.y>Waves.height_at(net_point)-3.:n+=1
		if n>0:under[school.species]=int(under.get(school.species,0))+n
	var room:=int(round(6.*float(game.boat.capacity)))
	for species: String in under:
		var take:=mini(int(ceil(float(under[species])*.5)),room-last_haul.size())
		for i: int in take:last_haul.append(make_catch(species))
		if last_haul.size()>=room:break
	for c: Dictionary in last_haul:
		game.inventory.record(c);game.inventory.add_catch(c)

func _haul_text() -> String:
	if last_haul.is_empty():return "A tarrafa voltou vazia. Jogue ração (C) para juntar o cardume antes."
	var names: Dictionary={}
	for c: Dictionary in last_haul:names[c.name]=int(names.get(c.name,0))+1
	var parts: Array[String]=[]
	for n: String in names:parts.append("%d %s"%[names[n],n])
	return "Tarrafa cheia: "+", ".join(parts)

## Catch record in the same shape as a rod catch.
func make_catch(species: String) -> Dictionary:
	var name_text: String;var lo: float;var hi: float;var per_kg: float;var rarity: String;var colour: String
	var res: Resource=null
	for item: Resource in game.fishing.SPECIES:
		if item.id==species:res=item;break
	if res!=null:
		name_text=res.display_name;lo=res.min_weight;hi=res.max_weight;per_kg=res.value_per_kg;rarity=res.rarity;colour=res.color.to_html()
	else:
		var data: Array=EXTRA.get(species,["Peixe miúdo",.05,.2,40.,"Comum","9fb5b8"])
		name_text=data[0];lo=data[1];hi=data[2];per_kg=data[3];rarity=data[4];colour=data[5]
	var weight:=snappedf(_rng.randf_range(lo,hi),.01)
	return {"id":species,"species_id":species,"name":name_text,"species_name":name_text,"weight":weight,"value":maxi(1,int(round(weight*per_kg))),
		"rarity":rarity,"region":"coast","caught_at":Time.get_datetime_string_from_system(true),"timestamp":int(Time.get_unix_time_from_system()),"color":colour}

# --- Crab traps ----------------------------------------------------------------------------------------

func nearest_trap(at: Vector3) -> Dictionary:
	for t: Dictionary in traps:
		if Vector2((t.at as Vector3).x-at.x,(t.at as Vector3).z-at.z).length()<TRAP_REACH:return t
	return {}

func trap_action() -> String:
	var here: Vector3=game.boat.global_position if game.player.in_boat else game.player.global_position
	var near:=nearest_trap(here)
	if not near.is_empty():return _collect(near)
	if game.inventory.traps<=0:return "Sem armadilhas. A loja de pesca vende covos por 40 moedas."
	if game.player.in_boat and absf(float(game.boat.speed))>1.5:return "Pare o barco para baixar o covo."
	var side: Vector3=game.boat.global_basis.x if game.player.in_boat else Vector3.ZERO
	var at: Vector3=here+side*2.6
	if not game.player.in_boat:at=throw_point(4.)
	var bottom: float=game.marine._seabed(Vector2(at.x,at.z))
	if Layout.coast(Vector2(at.x,at.z)).x<1. or bottom>-1.5:return "Raso demais para o covo: procure 2 a 30 m de fundo."
	if bottom<-30.:return "Fundo demais para o covo (máx. 30 m)."
	game.inventory.traps-=1;game.inventory.changed.emit()
	traps.append({"at":Vector3(at.x,0,at.z),"bottom":bottom,"placed":Time.get_ticks_msec()/1000.,"soak":0.,"node":_build_trap(at,bottom)})
	game.audio.cue("splash")
	return "Covo baixado a %.0f m. Volte em uns minutos e pressione B junto à boia."%-bottom

func _collect(t: Dictionary) -> String:
	if float(t.soak)<TRAP_SOAK:return "O covo ainda está vazio. Espere mais %d s."%int(TRAP_SOAK-float(t.soak))
	var haul: Array[Dictionary]=[]
	var crabs:=_rng.randi_range(1,3)
	for i: int in crabs:haul.append(make_catch("caranguejo"))
	if _rng.randf()<.55:haul.append(make_catch("lagosta"))
	if _rng.randf()<.15:haul.append(make_catch("polvo"))
	for c: Dictionary in haul:game.inventory.record(c);game.inventory.add_catch(c)
	(t.node as Node3D).queue_free();traps.erase(t)
	game.inventory.traps+=1;game.inventory.changed.emit()
	game.audio.cue("chain")
	var names: Array[String]=[]
	for c: Dictionary in haul:names.append(str(c.name))
	return "Covo recolhido: "+", ".join(names)

func _build_trap(at: Vector3,bottom: float) -> Node3D:
	var root:=Node3D.new();root.name="Covo_%d"%traps.size();root.position=Vector3(at.x,0,at.z);add_child(root)
	var buoy:=Node3D.new();buoy.name="Boia";root.add_child(buoy)
	G.sphere(buoy,Vector3(0,.15,0),Vector3(.42,.42,.42),G.material(Color("ef6c1a"),.5),12)
	G.cylinder(buoy,Vector3(0,.75,0),.025,1.1,G.material(Color("2b2f33"),.5))
	var flag:=G.box(buoy,Vector3(.18,1.15,0),Vector3(.34,.22,.02),G.material(Color("d8432f"),.6));flag.name="Bandeira"
	var rope:=G.beam(root,Vector3(0,0,0),Vector3(0,bottom+.5,0),.012,G.material(Color("c9b48a"),.9));rope.name="Cabo"
	var cage:=Node3D.new();cage.position=Vector3(0,bottom+.25,0);root.add_child(cage)
	var wire:=G.material(Color("3c4a48"),.5)
	for x: float in [-.45,.45]:
		for z: float in [-.3,.3]:G.box(cage,Vector3(x,0,z),Vector3(.04,.5,.04),wire)
	for y: float in [-.25,.25]:
		for z: float in [-.3,.3]:G.box(cage,Vector3(0,y,z),Vector3(.94,.03,.03),wire)
		for x: float in [-.45,.45]:G.box(cage,Vector3(x,y,0),Vector3(.03,.03,.64),wire)
	return root

func _update_traps(delta: float) -> void:
	for t: Dictionary in traps:
		t.soak=float(t.soak)+delta
		var root: Node3D=t.node;var buoy: Node3D=root.get_node("Boia")
		var p: Vector3=t.at
		buoy.position.y=Waves.height_at(p)-.05+sin(Time.get_ticks_msec()*.002+p.x)*.05
		var full:=float(t.soak)>=TRAP_SOAK
		var flag: MeshInstance3D=buoy.get_node("Bandeira")
		(flag.material_override as StandardMaterial3D).albedo_color=Color("4caf50") if full else Color("d8432f")

func _process(delta: float) -> void:
	if game==null:return
	_update_net(delta)
	_update_traps(delta)
