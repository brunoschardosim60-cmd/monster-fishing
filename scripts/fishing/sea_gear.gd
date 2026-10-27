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
## Traps being hauled up: the cage rises along its line and hangs dripping beside the boat for a moment.
var hauling: Array[Dictionary]=[]
var net_state: String="pronta"
var net_clock: float=0.
var net_cooldown: float=0.
var net_point: Vector3
var net_node: Node3D
var last_haul: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()
## What came up last (net or trap) and can still be let go with X while it hangs beside the boat:
## {"kind":"net"/"trap","first":index in inventory.catches,"count":n,"animals":[Node3D],"clock":s}
var fresh_haul: Dictionary={}
const RELEASE_WINDOW: float=6.
## Animals let go: they drop to the water and swim or sink away, then are freed.
var _released: Array[Dictionary]=[]
var _clock: float=0.
var net_catch: Node3D
## Set (gill) net: a line of floats on the surface with the net hanging below; fish swimming through get
## entangled while it soaks. {"a","b" (ends), "node", "soak", "caught": Array of species ids, "hauling"}
var gillnet: Dictionary={}
const GILLNET_SOAK: float=120.
const GILLNET_LENGTH: float=24.
## Fish pots (gaiolas) catch reef fish; placed instead of a crab trap when the boat is over a reef.
const POT_FISH: Array[String]=["sargo","cirurgiao","donzela","baiacu"]

func _ready() -> void:
	_rng.randomize()

## Point on the water `distance` metres in front of the angler (the way they face, like the rod cast),
## counted from the hull's side when aboard so it never lands on the boat.
func throw_point(distance: float=7.) -> Vector3:
	var from: Vector3=game.player.global_position
	var yaw: float=float(game.player.yaw)
	var fwd:=Vector3(-sin(yaw),0.,-cos(yaw))
	var clear:=0.
	if game.player.in_boat:
		var b: CharacterBody3D=game.boat
		var local: Vector3=b.global_basis.inverse()*fwd
		# Distance from the angler to the hull's edge along that heading.
		var half_b: float=float(b.hull_spec.beam)*.5*b.size_factor;var half_l: float=float(b.hull_spec.length)*.5*b.size_factor
		clear=minf(half_b/maxf(absf(local.x),.05),half_l/maxf(absf(local.z),.05))*.8
	var at: Vector3=from+fwd*(clear+distance);at.y=0.
	return at

## Pellets in flight: {"from","to","t","node"}; they land as the feed patch (marine.throw_feed).
var _feed_flights: Array[Dictionary]=[]

func throw_feed() -> String:
	var inv=game.inventory
	if inv.feed<=0:return "Sem ração. A loja de pesca vende 5 porções por 15 moedas."
	var at:=throw_point(5.)
	if Layout.coast(Vector2(at.x,at.z)).x<1.:return "Jogue a ração na água."
	inv.feed-=1;inv.stats.fed=int(inv.stats.fed)+1;inv.changed.emit()
	# A sweep of the arm and a handful of pellets flying out in front.
	if game.player.visual.has_method("play_action"):game.player.visual.play_action("ual/Interact",.7)
	var hand: Vector3=game.player.global_position+Vector3(0,1.3,0)
	var node:=Node3D.new();node.name="RacaoNoAr";add_child(node)
	var pellet:=G.material(Color("b88a4a"),.8)
	for k: int in 9:G.ellipsoid(node,Vector3(_rng.randf_range(-.25,.25),_rng.randf_range(-.1,.1),_rng.randf_range(-.25,.25)),Vector3.ONE*.035,pellet,4)
	node.global_position=hand
	_feed_flights.append({"from":hand,"to":at,"t":0.,"node":node})
	return "Ração jogada (%d restantes). Os peixes já vêm…"%inv.feed

func _update_feed_flights(delta: float) -> void:
	for f: Dictionary in _feed_flights.duplicate():
		f.t=float(f.t)+delta/.6
		var t: float=minf(float(f.t),1.)
		var to: Vector3=f.to;to.y=Waves.height_at(to)
		var p: Vector3=(f.from as Vector3).lerp(to,t)+Vector3(0,sin(t*PI)*1.6,0)
		(f.node as Node3D).global_position=p;(f.node as Node3D).scale=Vector3.ONE*(1.+t*2.5)
		if t>=1.:
			(f.node as Node3D).queue_free();_feed_flights.erase(f)
			game.marine.throw_feed(f.to);game.audio.cue("splash")

# --- Cast net ------------------------------------------------------------------------------------------

## Throwing the cast net is a knack: hold N and the net swings round (the meter goes up and down);
## let go in the green band and it flies out and opens into a full circle; too early or too late it
## opens halfway or falls in a tangle and catches little. How far it goes follows the swing too.
var net_charge: float=-1.
var net_quality: float=1.
var net_radius: float=4.
var _net_swing: float=0.
const NET_SWEET: float=.82
const NET_BAND: float=.07

func _net_blocked() -> String:
	if int(game.inventory.equipment.get("net",0))<1:return "Você não tem tarrafa. Compre uma na loja de pesca (90 moedas)."
	if not game.player.in_boat:return "A tarrafa é lançada do barco."
	if absf(float(game.boat.speed))>1.5:return "Pare o barco para lançar a tarrafa."
	if net_state!="pronta" or net_cooldown>0. or net_charge>=0.:return "A tarrafa ainda está na água."
	return ""

## N pressed: start swinging the net.
func begin_net_throw() -> String:
	var why:=_net_blocked()
	if not why.is_empty():return why
	net_charge=0.;_net_swing=0.
	return "Girando a tarrafa… solte N na faixa verde."

## N released: the throw.
func release_net_throw() -> String:
	if net_charge<0.:return ""
	var charge: float=net_charge;net_charge=-1.
	var v=game.player.visual
	v.cast_hold=-1.;v.hide_rod=false
	var off: float=absf(charge-NET_SWEET)
	net_quality=1.-clampf((off-NET_BAND)/.3,0.,1.)
	net_radius=lerpf(1.1,4.2,net_quality)
	var at:=throw_point(lerpf(2.5,7.,clampf(charge,0.,1.)))
	if Layout.coast(Vector2(at.x,at.z)).x<1.:return "Lance a tarrafa na água."
	v.play_action("ual/FishCast",.8);v.hide_rod=true
	net_point=at;net_state="abrindo";net_clock=0.
	net_from=game.player.global_position+Vector3(0,1.5,0)
	_build_net()
	game.audio.cue("net")
	if net_quality>.8:return "Que lance! A tarrafa abriu redondinha."
	if net_quality>.4:return "A tarrafa abriu pela metade."
	return "Saiu embolada: a tarrafa quase não abriu."

## Kept for the dev tools and tests: a clean throw in one go.
func cast_net() -> String:
	var why:=begin_net_throw()
	if not why.begins_with("Girando"):return why
	net_charge=NET_SWEET
	return release_net_throw()

var net_from:=Vector3.ZERO

func _update_net_swing(delta: float) -> void:
	if net_charge<0.:return
	if not game.player.in_boat:net_charge=-1.;game.player.visual.cast_hold=-1.;game.player.visual.hide_rod=false;return
	_net_swing+=delta
	# Up and down over 1.6 s: there is a moment to let go on every swing.
	net_charge=pingpong(_net_swing/.8,1.)
	game.player.visual.hide_rod=true
	game.player.visual.cast_hold=net_charge

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
		G.ellipsoid(net_node,Vector3(cos(a),-.3,sin(a)),Vector3(.06,.06,.06),lead,6)
	net_node.position=net_point;net_node.scale=Vector3(.2,1.,.2)

func _update_net(delta: float) -> void:
	net_cooldown=maxf(0.,net_cooldown-delta)
	if net_state=="pronta" or net_node==null:return
	net_clock+=delta
	var surface:=Waves.height_at(net_point)
	match net_state:
		"abrindo":
			var t:=clampf(net_clock/.9,0.,1.)
			var arc: Vector3=net_from.lerp(Vector3(net_point.x,surface,net_point.z),t)
			net_node.position=arc+Vector3(0,sin(t*PI)*2.,0)
			# A good throw spreads into a full circle in the air; a bad one stays a bundle.
			var r:=lerpf(.3,net_radius,smoothstep(.1,.85,t));net_node.scale=Vector3(r,1.,r)
			net_node.rotation.y+=delta*(6.*net_quality+1.)
			if t>=1.:
				net_state="afundando";net_clock=0.;game.world.ocean.effects.splash(net_point,.5+net_radius*.2,true)
				game.player.visual.hide_rod=false
		"afundando":
			var t:=clampf(net_clock/2.4,0.,1.)
			net_node.position=Vector3(net_point.x,surface-t*2.4,net_point.z);net_node.scale=Vector3(net_radius,1.+t*.8,net_radius)
			if t>=1.:_haul();net_state="puxando";net_clock=0.
		"puxando":
			var t:=clampf(net_clock/1.8,0.,1.)
			var back: Vector3=net_point.lerp(game.boat.global_position,t)
			net_node.position=Vector3(back.x,lerpf(surface-2.4,surface+.6,t),back.z)
			var r:=lerpf(net_radius,.35,t);net_node.scale=Vector3(r,1.8-t,r)
			if is_instance_valid(net_catch):net_catch.global_position=net_node.position+Vector3(0,-.15,0)
			if t>=1.:
				net_state="pendurada";net_clock=0.
				game.hud.notify(_haul_text()+("    X · Soltar" if not last_haul.is_empty() else ""))
		"pendurada":
			# Hangs dripping from the gunwale while the catch is sorted; then it is emptied into the hold.
			var side: Vector3=game.boat.global_position+game.boat.global_basis.x*(float(game.boat.hull_spec.beam)*.5*game.boat.size_factor+.3)
			var hang:=Vector3(side.x,Waves.height_at(side)+1.1+sin(net_clock*2.)*.05,side.z)
			net_node.position=hang;net_node.scale=Vector3(.35,.8,.35)
			if is_instance_valid(net_catch):net_catch.global_position=hang+Vector3(0,-.2,0)
			if net_clock>RELEASE_WINDOW:
				net_node.queue_free();net_node=null;net_state="pronta";net_cooldown=NET_COOLDOWN
				if is_instance_valid(net_catch):net_catch.queue_free()
				if fresh_haul.get("kind","")=="net":fresh_haul={}

## Fish under the net come up with it; the boat's hold size limits the haul.
func _haul() -> void:
	last_haul.clear()
	var under: Dictionary={}
	for school: Node3D in game.marine.fish_schools:
		if school.predator or not school.mmi.visible:continue
		var n:=0
		for p: Vector3 in school.pos:
			if Vector2(p.x-net_point.x,p.z-net_point.z).length()<net_radius+.5 and p.y>Waves.height_at(net_point)-3.:n+=1
		if n>0:under[school.species]=int(under.get(school.species,0))+n
	var room:=int(round(6.*float(game.boat.capacity)))
	for species: String in under:
		var take:=mini(int(ceil(float(under[species])*.5)),room-last_haul.size())
		for i: int in take:last_haul.append(make_catch(species))
		if last_haul.size()>=room:break
	var first: int=game.inventory.catches.size();var added: int=0
	for c: Dictionary in last_haul:
		game.inventory.record(c)
		if game.inventory.add_catch(c):added+=1
	# The fish are visible in the mesh as it comes up, flapping.
	if is_instance_valid(net_catch):net_catch.queue_free()
	net_catch=Node3D.new();net_catch.name="PeixesNaTarrafa";add_child(net_catch)
	var animals: Array=[]
	for i: int in mini(last_haul.size(),12):
		var fish:=_net_fish(str(last_haul[i].id));net_catch.add_child(fish);animals.append(fish)
		fish.position=Vector3(_rng.randf_range(-.25,.25),_rng.randf_range(-.15,.1),_rng.randf_range(-.25,.25));fish.rotation=Vector3(_rng.randf()*.6,_rng.randf()*TAU,_rng.randf_range(-1.,1.))
	fresh_haul={"kind":"net","first":first,"count":added,"animals":animals,"clock":-2.}
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
	if not near.is_empty():
		# With a deckhand aboard, they walk to the rail on that side and haul it once they get there.
		if float(near.soak)>=TRAP_SOAK and game.player.in_boat and game.crew!=null and game.crew.can_haul() and not near.get("crew_called",false):
			near.crew_called=true
			return game.crew.request_haul(near.at,func() -> void:game.hud.notify(_collect(near)))
		return _collect(near)
	var pot: bool=int(game.inventory.equipment.get("pots",0))>0 and _over_reef(here)
	if game.inventory.traps<=0 and not pot:return "Sem armadilhas. A loja de pesca vende covos por 40 moedas."
	if game.player.in_boat and absf(float(game.boat.speed))>1.5:return "Pare o barco para baixar o covo."
	var side: Vector3=game.boat.global_basis.x if game.player.in_boat else Vector3.ZERO
	var at: Vector3=here+side*2.6
	if not game.player.in_boat:at=throw_point(4.)
	var bottom: float=game.marine._seabed(Vector2(at.x,at.z))
	if Layout.coast(Vector2(at.x,at.z)).x<1. or bottom>-1.5:return "Raso demais para o covo: procure 2 a 30 m de fundo."
	var max_depth: float=max_trap_depth()
	if bottom<-max_depth:return "Fundo demais para o covo (máx. %d m%s)."%[int(max_depth),"" if has_winch() else "; com guincho, 60 m"]
	if pot:game.inventory.equipment["pots"]=int(game.inventory.equipment.pots)-1
	else:game.inventory.traps-=1
	# A piece of bait in the trap draws more animals.
	var baited: bool=game.inventory.bait>0
	if baited:game.inventory.bait-=1
	game.inventory.changed.emit()
	traps.append({"at":Vector3(at.x,0,at.z),"bottom":bottom,"placed":Time.get_ticks_msec()/1000.,"soak":0.,"node":_build_trap(at,bottom,pot),"kind":"gaiola" if pot else "covo","baited":baited,"drop":0.})
	game.audio.cue("splash");game.world.ocean.effects.splash(at,.6,false)
	if game.player.visual.has_method("play_action"):game.player.visual.play_action("ual/PickUp",1.)
	return "%s baixad%s a %.0f m%s. Volte em uns minutos e pressione B junto à boia."%["Gaiola de peixe" if pot else "Covo","a" if pot else "o",-bottom," com isca" if baited else ""]

## Winch fitted and the hull can carry one: traps go deeper and everything comes up faster.
func has_winch() -> bool:
	return int(game.inventory.equipment.get("winch",0))>0 and str(game.inventory.boat_id) in WINCH_BOATS
const WINCH_BOATS: Array[String]=["traineira","escuna","expedicao"]
func max_trap_depth() -> float:
	return 60. if has_winch() else 30.
func _over_reef(at: Vector3) -> bool:
	var life=game.world.get_node_or_null("VidaNoFundo")
	if life==null:return false
	for r: Vector3 in life.reefs:
		if Vector2(r.x-at.x,r.z-at.z).length()<28.:return true
	return false

func _collect(t: Dictionary) -> String:
	if float(t.soak)<TRAP_SOAK:return "O covo ainda está vazio. Espere mais %d s."%int(TRAP_SOAK-float(t.soak))
	if not t.has("haul"):_fill(t)
	var haul: Array[Dictionary]=[]
	for id: String in t.haul:haul.append(make_catch(id))
	var first: int=game.inventory.catches.size();var added: int=0
	for c: Dictionary in haul:
		game.inventory.record(c)
		if game.inventory.add_catch(c):added+=1
	traps.erase(t);game.inventory.stats.traps=int(game.inventory.stats.traps)+1
	hauling.append({"node":t.node,"bottom":t.bottom,"clock":0.,"speed":2. if has_winch() else 1.})
	var cage: Node3D=(t.node as Node3D).get_node("Gaiola")
	fresh_haul={"kind":"trap","first":first,"count":added,"animals":cage.get_children().filter(func(n: Node) -> bool:return n.has_meta("critter")),"clock":0.}
	if str(t.get("kind","covo"))=="gaiola":game.inventory.equipment["pots"]=int(game.inventory.equipment.get("pots",0))+1
	else:game.inventory.traps+=1
	game.inventory.changed.emit()
	game.audio.cue("chain")
	var names: Array[String]=[]
	for c: Dictionary in haul:names.append(str(c.name))
	return ("Gaiola recolhida: " if str(t.get("kind","covo"))=="gaiola" else "Covo recolhido: ")+", ".join(names)+"    X · Soltar os animais"

func _build_trap(at: Vector3,bottom: float,pot: bool=false) -> Node3D:
	var root:=Node3D.new();root.name="Covo_%d"%traps.size();root.position=Vector3(at.x,0,at.z);add_child(root)
	var buoy:=Node3D.new();buoy.name="Boia";root.add_child(buoy)
	G.ellipsoid(buoy,Vector3(0,.15,0),Vector3(.42,.42,.42),G.material(Color("ef6c1a"),.5),12)
	G.cylinder(buoy,Vector3(0,.75,0),.025,1.1,G.material(Color("2b2f33"),.5))
	var flag:=G.box(buoy,Vector3(.18,1.15,0),Vector3(.34,.22,.02),G.material(Color("d8432f"),.6));flag.name="Bandeira"
	var rope:=G.beam(root,Vector3(0,0,0),Vector3(0,bottom+.5,0),.012,G.material(Color("c9b48a"),.9));rope.name="Cabo"
	var cage:=Node3D.new();cage.name="Gaiola";cage.position=Vector3(0,bottom+.25,0);root.add_child(cage)
	var wire:=G.material(Color("3c4a48") if not pot else Color("6b4a2a"),.5)
	if pot:
		# Fish pot: a round wicker-and-wire cage with a funnel mouth, marked by a yellow buoy.
		(buoy.get_child(0) as MeshInstance3D).material_override=G.material(Color("f2c230"),.5)
		for k: int in 10:
			var a:=float(k)*TAU/10.
			G.box(cage,Vector3(cos(a)*.42,0,sin(a)*.42),Vector3(.035,.55,.035),wire)
		for y: float in [-.26,0.,.26]:
			var ring:=TorusMesh.new();ring.inner_radius=.4;ring.outer_radius=.44;ring.rings=24;ring.ring_segments=4
			G.mesh_node(cage,ring,wire,Vector3(0,y,0))
		return root
	for x: float in [-.45,.45]:
		for z: float in [-.3,.3]:G.box(cage,Vector3(x,0,z),Vector3(.04,.5,.04),wire)
	for y: float in [-.25,.25]:
		for z: float in [-.3,.3]:G.box(cage,Vector3(0,y,z),Vector3(.94,.03,.03),wire)
		for x: float in [-.45,.45]:G.box(cage,Vector3(x,y,0),Vector3(.03,.03,.64),wire)
	return root

## Decides what walked into the trap and puts it in the cage, where it can be seen from the boat or diving.
## What walked (or swam) into the trap: depends on its kind, the depth, the sea it lies in, the bait and
## how long it soaked (a longer soak fills it up, to a point).
func _fill(t: Dictionary) -> void:
	var ids: Array[String]=[]
	var depth: float=-float(t.bottom)
	var at: Vector3=t.at
	var biome: String=str(Layout.region_at(Vector2(at.x,at.z)).get("biome","harbor"))
	var soak: float=clampf((float(t.soak)-TRAP_SOAK)/240.,0.,1.)
	var plenty: float=(.5+.5*soak)*(1.5 if bool(t.get("baited",false)) else 1.)
	if str(t.get("kind","covo"))=="gaiola":
		for i: int in int(round(_rng.randf_range(1.,3.)*plenty)):ids.append(POT_FISH[_rng.randi()%POT_FISH.size()])
	else:
		var crabs: float=_rng.randf_range(1.,3.5)*plenty*clampf(1.2-depth/30.,.2,1.)
		for i: int in int(round(crabs)):ids.append("caranguejo")
		var lobster: float=.2+.35*smoothstep(6.,12.,depth)*(1.-smoothstep(28.,40.,depth))+(.15 if biome=="tropical" else 0.)
		if _rng.randf()<lobster*plenty:ids.append("lagosta")
		if _rng.randf()<(.06+.12*smoothstep(10.,20.,depth))*plenty:ids.append("polvo")
	if ids.is_empty():ids.append("caranguejo" if str(t.get("kind","covo"))!="gaiola" else "donzela")
	t.haul=ids
	var cage: Node3D=(t.node as Node3D).get_node("Gaiola")
	var spots: Array[Vector3]=[Vector3(-.22,-.18,-.1),Vector3(.2,-.18,.12),Vector3(.05,-.18,-.14),Vector3(-.1,-.18,.15),Vector3(.25,-.18,-.12),Vector3(-.25,-.1,.05)]
	for i: int in ids.size():
		var animal:=_net_fish(ids[i]) if ids[i] in POT_FISH else _trap_animal(ids[i])
		animal.position=spots[i%spots.size()]+(Vector3(0,.12,0) if ids[i] in POT_FISH else Vector3.ZERO);animal.rotation.y=_rng.randf()*TAU;cage.add_child(animal)

static var _painted_mat: ShaderMaterial
func _trap_animal(id: String) -> Node3D:
	var root:=Node3D.new();root.name=id.capitalize();root.set_meta("critter",id);root.set_meta("phase",_rng.randf()*TAU)
	match id:
		"caranguejo":
			# Crab from Bruno's marine pack, painted by the pipeline.
			if _painted_mat==null:_painted_mat=ShaderMaterial.new();_painted_mat.shader=preload("res://assets/shaders/imported_model.gdshader")
			var crab:=MeshInstance3D.new();crab.mesh=preload("res://assets/models/imported/crab.res");crab.material_override=_painted_mat
			var s:=_rng.randf_range(.26,.34);crab.scale=Vector3.ONE*s;crab.position.y=.04;crab.set_instance_shader_parameter("model_scale",s);root.add_child(crab)
		"lagosta":
			var shell:=G.material(Color("8a3a22"),.45);var pale:=G.material(Color("d98a52"),.5)
			for k: int in 3:G.ellipsoid(root,Vector3(0,.05,-.12+float(k)*.06),Vector3(.09-float(k)*.008,.07,.08),shell if k%2==0 else pale,8)
			# Tail on a hinge: it flicks under the body when the lobster struggles.
			var tail:=Node3D.new();tail.name="Cauda";tail.position=Vector3(0,.05,.05);root.add_child(tail)
			for k: int in 3:G.ellipsoid(tail,Vector3(0,0,.04+float(k)*.06),Vector3(.075-float(k)*.008,.065,.075),pale if k%2==0 else shell,8)
			G.ellipsoid(tail,Vector3(0,-.01,.22),Vector3(.14,.03,.07),shell,8)
			for side: float in [-1.,1.]:
				var antenna:=G.beam(root,Vector3(side*.03,.07,-.15),Vector3(side*.18,.12,-.48),.006,shell);antenna.name="Antena"
				G.ellipsoid(root,Vector3(side*.11,.04,-.2),Vector3(.05,.04,.1),shell,8)
		"polvo":
			var skin:=G.material(Color("b46a5a"),.35)
			G.ellipsoid(root,Vector3(0,.12,.05),Vector3(.16,.14,.2),skin,12)
			var eye:=G.material(Color("e8d27a"),.3)
			for side: float in [-1.,1.]:G.ellipsoid(root,Vector3(side*.06,.14,-.04),Vector3(.035,.035,.035),eye,6)
			# Eight arms, each two joints, curling and reaching through the mesh.
			for k: int in 8:
				var a:=float(k)*TAU/8.
				var arm:=Node3D.new();arm.name="Braco";arm.position=Vector3(cos(a)*.05,.04,sin(a)*.05);arm.rotation.y=-a;root.add_child(arm)
				G.beam(arm,Vector3.ZERO,Vector3(.11,-.01,0),.02,skin)
				var tip:=Node3D.new();tip.name="Ponta";tip.position=Vector3(.11,-.01,0);arm.add_child(tip)
				G.beam(tip,Vector3.ZERO,Vector3(.11,-.01,0),.012,skin)
	return root

func _update_traps(delta: float) -> void:
	# A trap just put over the side sinks down its line to the bottom.
	for t: Dictionary in traps:
		if float(t.get("drop",1.))>=1. or not is_instance_valid(t.node):continue
		t.drop=minf(1.,float(t.drop)+delta/3.5)
		var root: Node3D=t.node;var cage: Node3D=root.get_node("Gaiola");var rope: Node3D=root.get_node("Cabo")
		var surface:=Waves.height_at(root.global_position)
		var y:=lerpf(surface-.3,float(t.bottom)+.25,smoothstep(0.,1.,float(t.drop)))
		cage.position.y=y;cage.rotation.z=sin(float(t.drop)*9.)*.1*(1.-float(t.drop))
		var top:=minf(y+.25,0.)
		rope.position.y=top*.5;rope.scale.y=maxf(.01,-top/maxf(-float(t.bottom)-.5,.1));rope.visible=top<-.05
	for h: Dictionary in hauling.duplicate():
		# Up the line in 3 s, a few seconds dripping at the surface, then aboard.
		h.clock=float(h.clock)+delta*(float(h.get("speed",1.)) if float(h.clock)<3. else 1.)
		var root: Node3D=h.node
		if not is_instance_valid(root):hauling.erase(h);continue
		var cage: Node3D=root.get_node("Gaiola");var rope: Node3D=root.get_node("Cabo")
		var surface:=Waves.height_at(root.global_position)
		var y:=lerpf(float(h.bottom)+.25,surface+.55,smoothstep(0.,3.,float(h.clock)))
		cage.position.y=y;cage.rotation.z=sin(float(h.clock)*2.)*.12
		var top:=minf(y+.25,0.)
		rope.position.y=top*.5;rope.scale.y=maxf(.01,-top/maxf(-float(h.bottom)-.5,.1));rope.visible=top<-.05
		for animal: Node in cage.get_children():
			if animal.name in ["Caranguejo","Lagosta","Polvo"]:(animal as Node3D).rotation.y+=sin(float(h.clock)*6.+(animal as Node3D).position.x*9.)*delta*1.5
		if float(h.clock)>7.:root.queue_free();hauling.erase(h)
	for t: Dictionary in traps:
		t.soak=float(t.soak)+delta
		if float(t.soak)>=TRAP_SOAK and not t.has("haul"):_fill(t)
		var root: Node3D=t.node;var buoy: Node3D=root.get_node("Boia")
		var p: Vector3=t.at
		buoy.position.y=Waves.height_at(p)-.05+sin(Time.get_ticks_msec()*.002+p.x)*.05
		var full:=float(t.soak)>=TRAP_SOAK
		var flag: MeshInstance3D=buoy.get_node("Bandeira")
		(flag.material_override as StandardMaterial3D).albedo_color=Color("4caf50") if full else Color("d8432f")

func _process(delta: float) -> void:
	if game==null:return
	_clock+=delta
	_update_net_swing(delta)
	_update_feed_flights(delta)
	_update_net(delta)
	_update_traps(delta)
	_update_haul_life(delta)
	_update_gillnet(delta)
	if game.boat.has_method("set_winch_turning"):game.boat.set_winch_turning(not hauling.is_empty() or bool(gillnet.get("hauling",false)) and not gillnet.has("landed"))

## Animals in a cage or net are alive: crabs scuttle sideways and raise their claws, the octopus curls
## and reaches, a lobster flicks its tail; netted fish flap.
func _animate_critter(animal: Node3D,delta: float,lively: float) -> void:
	var ph: float=float(animal.get_meta("phase",0.))+_clock
	match str(animal.get_meta("critter","")):
		"caranguejo":
			var home: Vector3=animal.get_meta("home",animal.position);animal.set_meta("home",home)
			animal.position=home+animal.basis.x*sin(ph*1.7)*.12*lively
			animal.rotation.z=sin(ph*11.)*.08*lively
			animal.position.y=home.y+absf(sin(ph*11.))*.02*lively
		"lagosta":
			var tail: Node3D=animal.get_node_or_null("Cauda")
			if tail!=null:tail.rotation.x=maxf(0.,sin(ph*3.))*1.1*lively
			animal.rotation.y+=sin(ph*.7)*delta*.6*lively
		"polvo":
			for arm: Node in animal.get_children():
				if arm.name.begins_with("Braco"):
					var k: float=float(arm.get_index())
					(arm as Node3D).rotation.z=sin(ph*1.6+k*.8)*.45*lively
					var tip: Node3D=arm.get_node("Ponta");tip.rotation.z=sin(ph*2.1+k*1.3)*.8*lively;tip.rotation.y=cos(ph*1.3+k)*.4*lively
		"peixe":
			animal.rotation.z=sin(ph*14.)*.6*lively;animal.rotation.x=sin(ph*7.)*.3*lively

func _net_fish(id: String) -> Node3D:
	var root:=Node3D.new();root.name="Peixe";root.set_meta("critter","peixe");root.set_meta("phase",_rng.randf()*TAU)
	var Forms=preload("res://scripts/creatures/fish_forms.gd")
	var form_id: String=id if Forms.has_form(id) else "sardine"
	var mesh:=MeshInstance3D.new();mesh.mesh=Forms.mesh(form_id);mesh.material_override=Forms.material(form_id,true)
	mesh.scale=Vector3.ONE*clampf(Forms.length_of(form_id),.18,.5);root.add_child(mesh)
	return root

func _update_haul_life(delta: float) -> void:
	for t: Dictionary in traps:
		if t.has("haul"):
			for animal: Node in (t.node as Node3D).get_node("Gaiola").get_children():
				if animal.has_meta("critter"):_animate_critter(animal,delta,.6)
	for h: Dictionary in hauling:
		if is_instance_valid(h.node):
			for animal: Node in (h.node as Node3D).get_node("Gaiola").get_children():
				if animal.has_meta("critter"):_animate_critter(animal,delta,1.)
	if is_instance_valid(net_catch):
		for fish: Node in net_catch.get_children():_animate_critter(fish,delta,1.)
	if not fresh_haul.is_empty():
		fresh_haul.clock=float(fresh_haul.clock)+delta
		if float(fresh_haul.clock)>RELEASE_WINDOW+1.:fresh_haul={}
	for r: Dictionary in _released.duplicate():
		var node: Node3D=r.node
		if not is_instance_valid(node):_released.erase(r);continue
		r.clock=float(r.clock)+delta
		var surface: float=Waves.height_at(node.global_position)
		var v: Vector3=r.vel
		if node.global_position.y>surface:v.y-=9.8*delta
		else:
			# In the water: crabs and lobsters sink, fish and octopus swim off and down.
			var swim: Vector3=r.dir
			v=v.lerp(swim*(1.6 if r.kind!="caranguejo" else .3)+Vector3.DOWN*(.5 if r.kind in ["peixe","polvo"] else 1.2),1.-exp(-delta*2.))
			if not r.splashed:r.splashed=true;game.world.ocean.effects.splash(node.global_position,.35,true)
		r.vel=v;node.global_position+=v*delta
		var dir: Vector3=r.dir
		if str(r.kind)=="peixe":node.global_basis=Basis(Vector3.UP,atan2(-dir.z,dir.x))*Basis(Vector3.RIGHT,sin(float(r.clock)*12.)*.3)
		elif str(r.kind)!="caranguejo":_animate_critter(node,delta,1.)
		if float(r.clock)>4.5:node.queue_free();_released.erase(r)

func can_release() -> bool:
	return not fresh_haul.is_empty() and float(fresh_haul.clock)<=RELEASE_WINDOW and (fresh_haul.animals as Array).size()>0

## X while the trap or net hangs beside the boat: everything that came up goes back alive.
func release_haul() -> String:
	if not can_release():return ""
	var inv=game.inventory
	var first: int=int(fresh_haul.first);var count: int=int(fresh_haul.count)
	if count>0 and inv.catches.size()>=first+count:
		for i: int in count:inv.catches.remove_at(first)
		inv.changed.emit()
	var away: Vector3=game.boat.global_basis.x if game.player.in_boat else Vector3.FORWARD
	for animal: Node3D in fresh_haul.animals:
		if not is_instance_valid(animal):continue
		var at: Vector3=animal.global_position
		animal.reparent(self,false);animal.global_position=at
		var dir:=(away+Vector3(_rng.randf_range(-.6,.6),0.,_rng.randf_range(-.6,.6))).normalized()
		_released.append({"node":animal,"vel":away*1.2+Vector3.UP*1.2,"dir":dir,"clock":0.,"kind":str(animal.get_meta("critter","")),"splashed":false})
	var kind: String=str(fresh_haul.kind)
	fresh_haul={}
	if kind=="net" and net_state=="pendurada":net_clock=RELEASE_WINDOW-.5
	return "Você soltou os animais de volta ao mar."

# --- Set net (rede de espera) --------------------------------------------------------------------------

## Shift+N: set the net from the stopped boat, or haul it back when beside one of its end buoys.
func gillnet_action() -> String:
	if int(game.inventory.equipment.get("gillnet",0))<1:return "Você não tem rede de espera. A loja de pesca vende por 120 moedas."
	if not game.player.in_boat:return "A rede de espera é lançada do barco."
	var boat: CharacterBody3D=game.boat
	if not gillnet.is_empty():
		if gillnet.get("hauling",false):return "A rede está subindo."
		var near:=false
		for end: Vector3 in [gillnet.a,gillnet.b]:
			if Vector2(end.x-boat.global_position.x,end.z-boat.global_position.z).length()<12.:near=true
		if not near:return "Vá até uma das boias da rede (Shift+N para recolher)."
		if float(gillnet.soak)<GILLNET_SOAK*.5:return "A rede acabou de ser posta. Deixe pescar mais %d s."%int(GILLNET_SOAK*.5-float(gillnet.soak))
		if game.crew!=null and game.crew.can_haul() and not gillnet.get("crew_called",false):
			gillnet.crew_called=true
			return game.crew.request_haul(gillnet.a,func() -> void:game.hud.notify(gillnet_action()))
		gillnet.hauling=true;gillnet.haul_clock=0.;gillnet.haul_from=boat.global_position
		_entangle_visuals()
		game.audio.cue("chain")
		return "Recolhendo a rede…"
	if absf(float(boat.speed))>1.5:return "Pare o barco para lançar a rede."
	var a: Vector3=boat.global_position+boat.global_basis.x*(float(boat.hull_spec.beam)*.5*boat.size_factor+3.)
	var b: Vector3=a+boat.global_basis.x*GILLNET_LENGTH
	for k: int in 7:
		var q:=a.lerp(b,float(k)/6.)
		if Layout.coast(Vector2(q.x,q.z)).x<2. or game.marine._seabed(Vector2(q.x,q.z))>-4.:return "Água rasa demais para a rede: procure mais de 4 m de fundo."
	a.y=0.;b.y=0.
	gillnet={"a":a,"b":b,"soak":0.,"caught":[],"node":_build_gillnet(a,b),"hauling":false,"sample":0.}
	game.audio.cue("net")
	return "Rede de espera lançada. Deixe pescar uns minutos e volte à boia (Shift+N)."

func _build_gillnet(a: Vector3,b: Vector3) -> Node3D:
	var root:=Node3D.new();root.name="RedeDeEspera";add_child(root)
	var orange:=G.material(Color("ef6c1a"),.5);var white:=G.material(Color("eeeae0"),.5);var rope:=G.material(Color("c9b48a"),.9)
	for k: int in 11:
		var f:=Node3D.new();f.name="Boia_%d"%k;root.add_child(f)
		if k==0 or k==10:
			G.ellipsoid(f,Vector3(0,.15,0),Vector3(.45,.45,.45),orange,12);G.cylinder(f,Vector3(0,.75,0),.025,1.1,G.material(Color("2b2f33"),.5))
			G.box(f,Vector3(.18,1.15,0),Vector3(.34,.22,.02),G.material(Color("d8432f"),.6))
		else:G.ellipsoid(f,Vector3.ZERO,Vector3(.22,.16,.22),white,8)
	# The net hangs from the float line: a meshed panel 2.5 m deep with a lead line along the bottom.
	var img:=Image.create(64,64,false,Image.FORMAT_RGBA8);img.fill(Color(0,0,0,0))
	for i: int in 64:
		for k: int in [0,1,32,33]:img.set_pixel(k,i,Color(.8,.84,.78,.85));img.set_pixel(i,k,Color(.8,.84,.78,.85))
	var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(img);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold=.3;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.uv1_scale=Vector3(GILLNET_LENGTH*1.5,4,1)
	var panel:=MeshInstance3D.new();panel.name="Pano";var q:=QuadMesh.new();q.size=Vector2(GILLNET_LENGTH,2.5);panel.mesh=q;panel.material_override=mat
	panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(panel)
	var lead:=G.beam(root,Vector3(-GILLNET_LENGTH*.5,0,0),Vector3(GILLNET_LENGTH*.5,0,0),.025,rope);lead.name="Chumbada"
	var catch_root:=Node3D.new();catch_root.name="Malhados";root.add_child(catch_root)
	return root

func _update_gillnet(delta: float) -> void:
	if gillnet.is_empty():return
	var root: Node3D=gillnet.node
	var a: Vector3=gillnet.a;var b: Vector3=gillnet.b
	var t_haul: float=0.
	if gillnet.hauling:
		gillnet.haul_clock=float(gillnet.haul_clock)+delta*(1.9 if has_winch() else 1.)
		t_haul=clampf(float(gillnet.haul_clock)/3.,0.,1.)
		# The whole net comes in over the gunwale: ends converge on the boat side as it rises.
		var side: Vector3=game.boat.global_position+game.boat.global_basis.x*(float(game.boat.hull_spec.beam)*.5*game.boat.size_factor+.6)
		a=a.lerp(side,t_haul);b=b.lerp(side+game.boat.global_basis.z*.1,t_haul)
	else:
		gillnet.soak=float(gillnet.soak)+delta
		gillnet.sample=float(gillnet.sample)+delta
		if float(gillnet.sample)>=2.:
			gillnet.sample=0.;_sample_gillnet()
	var mid: Vector3=(a+b)*.5
	var along: Vector3=(b-a);var length: float=maxf(along.length(),.5);along/=length
	root.global_position=Vector3(mid.x,0,mid.z)
	root.global_basis=Basis(along,Vector3.UP,along.cross(Vector3.UP))
	for k: int in 11:
		var f: Node3D=root.get_node("Boia_%d"%k)
		var p:=a.lerp(b,float(k)/10.)
		f.global_position=Vector3(p.x,Waves.height_at(p)+(.6*t_haul if gillnet.hauling else 0.)-.02,p.z)
	var panel: MeshInstance3D=root.get_node("Pano");var lead: Node3D=root.get_node("Chumbada")
	var depth: float=lerpf(1.35,-.3,t_haul)
	panel.scale=Vector3(length/GILLNET_LENGTH,lerpf(1.,.35,t_haul),1.);panel.position=Vector3(0,Waves.height_at(mid)-depth,0)
	lead.position=Vector3(0,Waves.height_at(mid)-depth*2.+(.3 if gillnet.hauling else 0.),0);lead.scale=Vector3(1.,length/GILLNET_LENGTH,1.)
	var catch_root: Node3D=root.get_node("Malhados")
	catch_root.position=panel.position;catch_root.scale=Vector3(length/GILLNET_LENGTH,lerpf(1.,.35,t_haul),1.)
	for fish: Node in catch_root.get_children():_animate_critter(fish,delta,1.)
	if gillnet.hauling and t_haul>=1. and not gillnet.has("landed"):
		gillnet.landed=true;_land_gillnet()
	if gillnet.has("landed"):
		gillnet.hang=float(gillnet.get("hang",0.))+delta
		if float(gillnet.hang)>RELEASE_WINDOW:
			root.queue_free();gillnet={}
			if fresh_haul.get("kind","")=="gillnet":fresh_haul={}

## Every couple of seconds: fish from schools passing through the net's line get entangled.
func _sample_gillnet() -> void:
	var a: Vector3=gillnet.a;var b: Vector3=gillnet.b
	var caught: Array=gillnet.caught
	if caught.size()>=14:return
	for school: Node3D in game.marine.fish_schools:
		if school.predator or not school.mmi.visible:continue
		var hits:=0
		for p: Vector3 in school.pos:
			var ab:=Vector2(b.x-a.x,b.z-a.z);var ap:=Vector2(p.x-a.x,p.z-a.z)
			var t:=clampf(ap.dot(ab)/ab.length_squared(),0.,1.)
			if (ap-ab*t).length()<2.5 and p.y>-3.:hits+=1
		for h: int in hits:
			if _rng.randf()<.05 and caught.size()<14:caught.append(str(school.species))
	# Open-water passers-by that no school marks on the map.
	if _rng.randf()<.08 and caught.size()<14:caught.append("sardine" if _rng.randf()<.6 else "mackerel")

## Visible fish tangled along the net as it comes up.
func _entangle_visuals() -> void:
	var catch_root: Node3D=(gillnet.node as Node3D).get_node("Malhados")
	for i: int in (gillnet.caught as Array).size():
		var fish:=_net_fish(str(gillnet.caught[i]));catch_root.add_child(fish)
		fish.position=Vector3(_rng.randf_range(-GILLNET_LENGTH*.45,GILLNET_LENGTH*.45),_rng.randf_range(-.9,.9),0.);fish.rotation=Vector3(0,_rng.randf_range(-.4,.4)+(PI if _rng.randf()<.5 else 0.),_rng.randf_range(-.6,.6))

func _land_gillnet() -> void:
	var first: int=game.inventory.catches.size();var added: int=0
	var names: Dictionary={}
	for id: Variant in gillnet.caught:
		var c: Dictionary=make_catch(str(id))
		game.inventory.record(c)
		if game.inventory.add_catch(c):added+=1;names[c.name]=int(names.get(c.name,0))+1
	var catch_root: Node3D=(gillnet.node as Node3D).get_node("Malhados")
	fresh_haul={"kind":"gillnet","first":first,"count":added,"animals":catch_root.get_children(),"clock":0.}
	var parts: Array[String]=[]
	for n: String in names:parts.append("%d %s"%[names[n],n])
	game.hud.notify(("Rede recolhida: "+", ".join(parts)+"    X · Soltar") if not parts.is_empty() else "A rede voltou vazia. Ponha-a no caminho de um cardume.")
