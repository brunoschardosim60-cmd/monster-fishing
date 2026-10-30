extends Node3D
## Treasure hunting. A treasure map (from a beaten pirate crew's chest, or a bottle drifting at sea)
## marks a spot on an island: on the world map a red X, on the island a cross of red-painted planks
## and a mound of turned earth. Walk up to it and E digs up the chest: coins, and sometimes a rare
## piece of gear. Bottles with a message turn up near the boat every few minutes out at sea.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const F=preload("res://scripts/visuals/furniture.gd")
const DIG_REACH: float=2.6
const BOTTLE_REACH: float=4.

var game: Node
## {pos: Vector3, island: String, node: Node3D, found: bool}
var maps: Array[Dictionary]=[]
var bottle: Node3D
var bottle_clock: float=0.
var found: int=0
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize();bottle_clock=_rng.randf_range(150.,260.)

func open_maps() -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	for m: Dictionary in maps:
		if not bool(m.found):out.append(m)
	return out

## A dry, gentle spot on an island, clear of the town: on the home island's outskirts for the first
## map, then mostly on distant islands.
func _pick_spot() -> Dictionary:
	var candidates: Array[int]=[]
	var distant:=maps.size()>0 and _rng.randf()<.75
	for i: int in Layout.LOBES.size():
		if i==0:continue
		var region:=Layout.region_for_lobe(i)
		if distant and (Layout.is_aurora_lobe(i) or not bool(region.get("map_visible",false))):continue
		if not distant and not Layout.is_aurora_lobe(i):continue
		candidates.append(i)
	for attempt: int in 400:
		var i: int=candidates[_rng.randi()%candidates.size()]
		var l: Vector4=Layout.LOBES[i]
		var a:=_rng.randf()*TAU;var r:=sqrt(_rng.randf())*.7
		var p:=Vector2(l.x+cos(a)*l.z*r,l.y+sin(a)*l.w*r)
		var h: float=Layout.ground(p)
		if h<1.6 or h>30.:continue
		if Layout.in_town(p) or Layout.plot_ground(p) or Layout.near_avenue(p,6.):continue
		var slope: float=absf(Layout.ground(p+Vector2(1.5,0))-h)+absf(Layout.ground(p+Vector2(0,1.5))-h)
		if slope>.9:continue
		var name: String=str(Layout.region_for_lobe(i).get("map","Ilha"))
		if name=="":name="Ilha de Aurora"
		return {"pos":Vector3(p.x,h,p.y),"island":name}
	return {}

## Adds a treasure map and marks its spot. Returns the text for the notification.
func give_map() -> String:
	var spot:=_pick_spot()
	if spot.is_empty():return "um mapa ilegível"
	spot.found=false;spot.node=_mark(spot.pos)
	maps.append(spot)
	return "um MAPA DO TESOURO (%s · veja o X no mapa, tecla M)"%spot.island

## The X on the ground: two crossed planks painted red, a mound of earth and a spade stuck in it.
func _mark(at: Vector3) -> Node3D:
	var n:=Node3D.new();n.name="XDoTesouro";add_child(n);n.global_position=at
	var red:=F.mat("weathered_wood",Color("a3352a"));var earth:=F.mat("flat",Color("6b4f36"),.95)
	# Lie the X along the slope: tilt the mark to the ground's normal there.
	var h0: float=Layout.ground(Vector2(at.x,at.z))
	var dx: float=Layout.ground(Vector2(at.x+1.,at.z))-h0;var dz: float=Layout.ground(Vector2(at.x,at.z+1.))-h0
	var up:=Vector3(-dx,1.,-dz).normalized()
	n.basis=Basis(Quaternion(Vector3.UP,up))
	for s: float in [-1.,1.]:
		var plank:=G.box(n,Vector3(0,.04,0),Vector3(.32,.05,2.3),red);plank.rotation.y=s*PI*.25
	G.ellipsoid(n,Vector3(1.4,.0,.6),Vector3(.8,.22,.6),earth,10)
	var wood:=F.mat("teak",Color("8a6a4a"));var iron:=F.mat("flat",Color("3a3632"),.5,.5)
	G.beam(n,Vector3(1.45,.1,.6),Vector3(1.55,1.15,.55),.035,wood)
	var blade:=G.box(n,Vector3(1.44,.05,.61),Vector3(.2,.28,.02),iron);blade.rotation.z=-.1
	return n

## Saved maps come back with their X marks (found ones stay dug up and leave no mark).
func restore(data: Dictionary) -> void:
	found=int(data.get("found",0))
	for m: Dictionary in data.get("maps",[]):
		var spot:={"pos":m.pos,"island":m.island,"found":bool(m.found)}
		if not bool(m.found):spot.node=_mark(m.pos)
		maps.append(spot)

func nearest_dig(at: Vector3) -> Dictionary:
	for m: Dictionary in maps:
		if bool(m.found):continue
		if Vector2(at.x-m.pos.x,at.z-m.pos.z).length()<DIG_REACH and absf(at.y-float(m.pos.y))<3.:return m
	return {}

func hint(at: Vector3) -> String:
	return "E · Cavar o tesouro" if not nearest_dig(at).is_empty() else ""

## E on the X: the chest comes up open with its loot.
func dig(at: Vector3) -> String:
	var m:=nearest_dig(at)
	if m.is_empty():return ""
	m.found=true;found+=1
	var node: Node3D=m.node
	for child: Node in node.get_children():child.queue_free()
	var chest:=Node3D.new();node.add_child(chest);chest.rotation.y=_rng.randf()*TAU
	var away:=Vector3(m.pos.x-at.x,0,m.pos.z-at.z)
	chest.global_position=Vector3(m.pos.x,m.pos.y,m.pos.z)+(away.normalized()*.4 if away.length()>.05 else Vector3(.4,0,0))
	var wood:=F.mat("weathered_wood",Color("6b4a2c"));var iron:=F.mat("flat",Color("2a2622"),.5,.5);var gold:=F.mat("flat",Color("e8bd45"),.25,.95)
	G.box(chest,Vector3(0,.28,0),Vector3(.9,.5,.6),wood)
	for x: float in [-.33,.33]:G.box(chest,Vector3(x,.28,0),Vector3(.06,.52,.62),iron)
	var lid:=G.box(chest,Vector3(0,.62,.3),Vector3(.9,.06,.6),wood);lid.rotation.x=-1.1
	for k: int in 14:G.cylinder(chest,Vector3(_rng.randf_range(-.35,.35),.5+_rng.randf()*.06,_rng.randf_range(-.22,.22)),.045,.012,gold,.045,10)
	var glow:=OmniLight3D.new();glow.light_color=Color("ffd27a");glow.light_energy=1.4;glow.omni_range=4.;glow.position.y=.8;chest.add_child(glow)
	var coins: int=_rng.randi_range(160,360)
	game.inventory.money+=coins
	var extra:=""
	if _rng.randf()<.35:
		game.inventory.harpoons+=3;extra=" e 3 arpões"
	elif _rng.randf()<.5:
		game.inventory.materials+=4;extra=" e 4 materiais"
	game.inventory.changed.emit();game.audio.cue("coins")
	if game.player.visual!=null and game.player.visual.has_method("play_action"):game.player.visual.play_action("ual/PickUp",1.)
	return "TESOURO! Você desenterra um baú na %s: %d moedas%s."%[m.island,coins,extra]

func _physics_process(delta: float) -> void:
	if game==null or game.boat==null:return
	var b: Vector3=game.boat.global_position
	if is_instance_valid(bottle):
		var p: Vector3=bottle.global_position
		bottle.global_position.y=Waves.height_at(p)-.05
		bottle.rotation=Vector3(sin(Time.get_ticks_msec()*.0021)*.5,bottle.rotation.y+delta*.3,.9+sin(Time.get_ticks_msec()*.0017)*.2)
		if game.player.in_boat and Vector2(p.x-b.x,p.z-b.z).length()<BOTTLE_REACH:
			bottle.queue_free();bottle=null
			game.hud.notify("Uma garrafa com mensagem! Dentro dela: "+give_map()+".")
			game.audio.cue("catch")
		elif Vector2(p.x-b.x,p.z-b.z).length()>500.:bottle.queue_free();bottle=null
		return
	if not game.player.in_boat:return
	bottle_clock-=delta
	if bottle_clock>0.:return
	bottle_clock=_rng.randf_range(200.,360.)
	if Vector2(b.x,b.z).length()<300.:return
	spawn_bottle(b-game.boat.global_basis.z*70.+game.boat.global_basis.x*_rng.randf_range(-20.,20.))

## A corked green bottle with a rolled paper inside, drifting.
func spawn_bottle(at: Vector3) -> void:
	if is_instance_valid(bottle):bottle.queue_free()
	bottle=Node3D.new();bottle.name="GarrafaComMensagem";add_child(bottle)
	var glass:=F.mat("flat",Color(.25,.55,.35,.75),.08);(glass as StandardMaterial3D).transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var paper:=F.mat("flat",Color("eadfc2"),.9);var cork:=F.mat("flat",Color("b08a5a"),.9)
	G.cylinder(bottle,Vector3(0,0,0),.12,.5,glass,.12,12)
	G.cylinder(bottle,Vector3(0,.33,0),.05,.18,glass,.04,10)
	G.cylinder(bottle,Vector3(0,.45,0),.045,.07,cork,.045,8)
	G.cylinder(bottle,Vector3(0,0,0),.06,.36,paper,.06,8)
	var glint:=OmniLight3D.new();glint.light_color=Color("e8ffd0");glint.light_energy=.6;glint.omni_range=3.;bottle.add_child(glint)
	bottle.scale=Vector3.ONE*1.6
	bottle.global_position=Vector3(at.x,Waves.height_at(at),at.z)
	game.hud.notify("Algo brilha na água à frente… uma garrafa boiando!")
