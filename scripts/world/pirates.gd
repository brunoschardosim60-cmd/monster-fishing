extends Node3D
## Pirates. Out on open water, now and then a black-sailed schooner sights the player's boat and hunts it.
##   · "caçando": it closes in under sail and, from 25–110 m, fires its cannon (balls fly in an arc and
##     throw up a column of water; a close one hits the hull).
##   · "abordando": alongside, grapnels over the rail; the crew shouts. E pays a tribute (a quarter of
##     your coins) and they sheer off; wait ~8 s and they plunder half the hold and a third of the coins.
##   · H harpoons the ship (aimed through the camera): three hits and the pirates flee, leaving a chest
##     floating in their wake (coins, and sometimes a treasure map).
##   · Running: a boat that gets 170 m clear (turbo, a fast hull) makes them give up.
const Models=preload("res://scripts/boats/vessel_models.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const HUNT_SPEED: float=9.6
const GIVE_UP: float=170.
const BOARD_RANGE: float=16.
const PLUNDER_AFTER: float=8.
const HOME: Vector2=Vector2.ZERO
const SAFE_RADIUS: float=380.

var game: Node
var ship: Node3D
var state: String="ausente"     # ausente | caçando | abordando | fugindo
var heading: float=0.
var speed: float=0.
var hp: int=3
var clock: float=0.
var spawn_clock: float=0.
var cannon_clock: float=0.
var balls: Array[Dictionary]=[]
var chests: Array[Dictionary]=[]
var raids: int=0
var _board_side: float=1.
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize();spawn_clock=_rng.randf_range(200.,320.)

func active() -> bool:return state in ["caçando","abordando"]

## The ship: a schooner with black sails, a red-black hull, a skull flag and a crew of cut-throats.
func _build_ship() -> Node3D:
	var root:=Node3D.new();root.name="NavioPirata"
	var body: Node3D=Models.build("escuna",20.,666)
	root.add_child(body)
	var black:=StandardMaterial3D.new();black.albedo_color=Color("1c1a1c");black.roughness=.95;black.cull_mode=BaseMaterial3D.CULL_DISABLED
	black.backlight_enabled=true;black.backlight=Color(.25,.12,.1)
	for sail: Node3D in body.get_meta("sails",[]):(sail as MeshInstance3D).material_override=black
	if body.has_meta("flag"):(body.get_meta("flag") as Node3D).visible=false
	# Skull flag at the main masthead.
	var flag:=Node3D.new();flag.name="Caveira";flag.position=Vector3(0,2.2+21.,1.6);root.add_child(flag)
	var cloth:=StandardMaterial3D.new();cloth.albedo_color=Color("111111");cloth.cull_mode=BaseMaterial3D.CULL_DISABLED
	var bone:=StandardMaterial3D.new();bone.albedo_color=Color("efe9da")
	G.box(flag,Vector3(0,-.9,1.5),Vector3(.03,1.8,3.),cloth)
	G.sphere(flag,Vector3(.03,-.75,1.5),Vector3(.05,.6,.55),bone,10)
	for s: float in [-1.,1.]:
		var b:=G.box(flag,Vector3(.03,-1.35,1.5),Vector3(.04,.12,1.3),bone);b.rotation.x=s*.6
		G.sphere(flag,Vector3(.06,-.72,1.5+s*.13),Vector3(.03,.14,.12),cloth,6)
	root.set_meta("flag",flag)
	# Cannons on both sides.
	var iron:=StandardMaterial3D.new();iron.albedo_color=Color("202224");iron.metallic=.6;iron.roughness=.4
	for s: float in [-1.,1.]:
		for z: float in [-3.,1.,5.]:
			var gun:=G.cylinder(root,Vector3(s*2.7,2.6,z),.17,1.6,iron,.13,10);gun.rotation.z=s*PI*.5
	# Crew on deck.
	var Crew=preload("res://scripts/boats/crew_member.gd")
	for k: int in 4:
		var c=Crew.new();c.look_id=200+k*13;c.role="pirata";c.position=Vector3(-1.2+float(k%2)*2.4,2.2,-4.+float(k)*2.8);c.facing=PI*.5*(1. if k%2==0 else -1.)
		c.name="Pirata_%d"%k;root.add_child(c)
	return root

## Sends a pirate ship after the player from `at` (tests, scripted events).
func spawn_near(at: Vector3) -> void:
	if is_instance_valid(ship):ship.queue_free()
	ship=_build_ship();add_child(ship)
	ship.global_position=Vector3(at.x,0,at.z)
	var b: Vector3=game.boat.global_position
	heading=atan2(-(b.x-at.x),-(b.z-at.z));ship.rotation.y=heading
	state="caçando";hp=3;clock=0.;cannon_clock=4.;speed=HUNT_SPEED*.6
	game.hud.notify("Velas negras no horizonte! Um navio PIRATA vem atrás de você.")
	game.audio.cue("horn")

func _physics_process(delta: float) -> void:
	if game==null or game.boat==null:return
	var boat: Node3D=game.boat;var b: Vector3=boat.global_position
	_update_balls(delta,boat)
	_update_chests(delta,boat)
	if state=="ausente":
		if not game.player.in_boat:return
		spawn_clock-=delta
		if spawn_clock<=0.:
			spawn_clock=_rng.randf_range(260.,480.)
			if Vector2(b.x,b.z).distance_to(HOME)>SAFE_RADIUS and _rng.randf()<.7:
				var a:=_rng.randf()*TAU
				spawn_near(b+Vector3(cos(a),0,sin(a))*230.)
		return
	if not is_instance_valid(ship):state="ausente";return
	clock+=delta
	var p: Vector3=ship.global_position
	var gap:=Vector2(b.x-p.x,b.z-p.z).length()
	match state:
		"caçando":
			# Sail for a point just off the boat's side, leading it a little.
			var lead: Vector3=b+(-boat.global_basis.z)*float(boat.speed)*2.+boat.global_basis.x*7.
			_steer(lead,HUNT_SPEED,delta)
			cannon_clock-=delta
			if cannon_clock<=0. and gap>25. and gap<110.:
				cannon_clock=_rng.randf_range(5.,7.5);_fire(boat)
			if gap<BOARD_RANGE:
				state="abordando";clock=0.
				game.hud.notify("Os piratas lançam ganchos no seu barco! E · pagar tributo · H · arpão · fuja com turbo")
				game.audio.cue("chain")
			elif gap>GIVE_UP and clock>20.:_leave("Você despistou os piratas! O navio vira de bordo e some.")
		"abordando":
			# Alongside, held by the grapnels: the schooner lies beam to beam a couple of metres off,
			# on whichever side it came up, matching the boat's heading.
			if clock<delta*1.5:_board_side=signf((p-b).dot(boat.global_basis.x)) if (p-b).dot(boat.global_basis.x)!=0. else 1.
			var off: float=float(boat.hull_spec.beam)*.5*float(boat.size_factor)+2.5+1.6
			var side: Vector3=b+boat.global_basis.x*_board_side*off
			var k: float=1.-exp(-delta*1.1)
			var q: Vector3=ship.global_position.lerp(Vector3(side.x,ship.global_position.y,side.z),k)
			ship.global_position=q
			heading=lerp_angle(heading,boat.rotation.y,k);speed=absf(float(boat.speed))
			_grapnels(boat,true)
			if absf(float(boat.speed))>HUNT_SPEED or gap>BOARD_RANGE*2.2:_grapnels(boat,false);state="caçando";clock=0.;cannon_clock=3.;game.hud.notify("Você arrebenta os cabos dos ganchos e escapa da abordagem!")
			elif clock>PLUNDER_AFTER:_plunder()
		"fugindo":
			_steer(p+Vector3(p.x-b.x,0,p.z-b.z).normalized()*200.,HUNT_SPEED*1.2,delta)
			if clock>25. or gap>400.:ship.queue_free();ship=null;state="ausente"
	_float(delta)

func _steer(target: Vector3,top: float,delta: float,match_heading: bool=false) -> void:
	var p: Vector3=ship.global_position
	var to:=Vector3(target.x-p.x,0,target.z-p.z)
	var want: float=atan2(-to.x,-to.z) if to.length()>1. else heading
	if match_heading and to.length()<4.:want=game.boat.rotation.y
	heading=lerp_angle(heading,want,1.-exp(-delta*.55))
	speed=move_toward(speed,top if to.length()>3. else top*.4,delta*2.)
	p+=Vector3(-sin(heading),0,-cos(heading))*speed*delta
	ship.global_position=p

## Grapnel lines from the schooner's rail to the boat's while they are alongside.
var _lines: Array[MeshInstance3D]=[]
func _grapnels(boat: Node3D,show: bool) -> void:
	if _lines.is_empty():
		var rope:=StandardMaterial3D.new();rope.albedo_color=Color("bfa77a");rope.roughness=.95
		for k: int in 2:
			var m:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=.03;c.bottom_radius=.03;c.height=1.;c.radial_segments=5;m.mesh=c
			m.material_override=rope;add_child(m);_lines.append(m)
	for k: int in 2:
		var line: MeshInstance3D=_lines[k]
		line.visible=show and is_instance_valid(ship)
		if not line.visible:continue
		var along: float=-2.5+float(k)*5.
		var to_boat:=(boat.global_position-ship.global_position);to_boat.y=0.;to_boat=to_boat.normalized()
		var a: Vector3=ship.global_position+to_boat*2.4+Vector3(-sin(heading),0,-cos(heading))*along+Vector3(0,2.9,0)
		var gun: float=float(boat.hull_spec.get("gunwale",1.))*float(boat.size_factor)
		var b: Vector3=boat.global_position-to_boat*float(boat.hull_spec.beam)*.45*float(boat.size_factor)-boat.global_basis.z*along*.6+Vector3(0,(boat._hull as Node3D).position.y+gun,0)
		var d: Vector3=b-a;var len: float=d.length()
		var y:=d/len;var x:=y.cross(Vector3.UP).normalized() if absf(y.y)<.99 else Vector3.RIGHT;var z:=x.cross(y)
		line.global_transform=Transform3D(Basis(x,y*len,z),(a+b)*.5)

func _float(delta: float) -> void:
	var p: Vector3=ship.global_position
	var fwd:=Vector3(-sin(heading),0,-cos(heading));var right:=Vector3(cos(heading),0,-sin(heading))
	var h: float=Waves.height_at(p)
	var pitch: float=(Waves.height_at(p+fwd*8.)-Waves.height_at(p-fwd*8.))/16.
	var roll: float=(Waves.height_at(p+right*2.5)-Waves.height_at(p-right*2.5))/5.
	ship.global_position.y=lerpf(ship.global_position.y,h-.05,1.-exp(-delta*3.))
	ship.rotation=Vector3(lerpf(ship.rotation.x,atan(pitch)*.8,delta*2.),heading,lerpf(ship.rotation.z,-atan(roll)*.6+.04,delta*2.))
	var flag: Node3D=ship.get_meta("flag")
	flag.rotation.y=sin(Time.get_ticks_msec()*.004)*.25

## Cannon: a ball aimed where the boat will be, flying a ballistic arc (about 2.5 s).
func _fire(boat: Node3D) -> void:
	var p: Vector3=ship.global_position
	var side: float=signf((boat.global_position-p).dot(Vector3(cos(heading),0,-sin(heading))))
	var muzzle: Vector3=p+Vector3(cos(heading),0,-sin(heading))*side*3.4+Vector3(0,2.6,0)
	var flight:=2.4
	var target: Vector3=boat.global_position+boat.velocity*flight*.8+Vector3(_rng.randf_range(-7.,7.),0,_rng.randf_range(-7.,7.))
	var v:=(target-muzzle)/flight;v.y=(target.y-muzzle.y)/flight+9.8*flight*.5
	var ball:=MeshInstance3D.new();var m:=SphereMesh.new();m.radius=.22;m.height=.44;m.radial_segments=8;m.rings=4;ball.mesh=m
	var iron:=StandardMaterial3D.new();iron.albedo_color=Color("151515");ball.material_override=iron
	add_child(ball);ball.global_position=muzzle
	balls.append({"node":ball,"v":v})
	_smoke(muzzle,side)
	game.audio.cue_at("slam",muzzle,-2.)

func _smoke(at: Vector3,side: float) -> void:
	var puff:=CPUParticles3D.new();puff.one_shot=true;puff.amount=24;puff.lifetime=2.2;puff.explosiveness=.95
	var q:=QuadMesh.new();q.size=Vector2(1.6,1.6)
	var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo=true;mat.albedo_color=Color(.82,.8,.76,.7)
	var g:=Gradient.new();g.set_color(0,Color(1,1,1,1));g.set_color(1,Color(1,1,1,0));var tex:=GradientTexture2D.new();tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1.,.5);tex.gradient=g
	mat.albedo_texture=tex;q.material=mat;puff.mesh=q
	puff.direction=Vector3(cos(heading)*side,.3,-sin(heading)*side);puff.spread=25.;puff.initial_velocity_min=3.;puff.initial_velocity_max=7.
	puff.gravity=Vector3(0,.6,0);puff.damping_min=2.;puff.damping_max=3.;puff.scale_amount_min=.8;puff.scale_amount_max=2.2
	var ramp:=Gradient.new();ramp.set_color(0,Color(1,.85,.6,.9));ramp.set_color(1,Color(.7,.7,.7,0.));puff.color_ramp=ramp
	add_child(puff);puff.global_position=at;puff.emitting=true
	get_tree().create_timer(3.).timeout.connect(puff.queue_free)

func _update_balls(delta: float,boat: Node3D) -> void:
	for i: int in range(balls.size()-1,-1,-1):
		var ball: Dictionary=balls[i];var node: MeshInstance3D=ball.node
		ball.v=(ball.v as Vector3)+Vector3(0,-9.8,0)*delta
		node.global_position+=(ball.v as Vector3)*delta
		var at: Vector3=node.global_position
		var near_hull: bool=Vector2(at.x-boat.global_position.x,at.z-boat.global_position.z).length()<3.2 and at.y<boat.global_position.y+3.
		if at.y<Waves.height_at(at) or near_hull:
			var fx=game.world.ocean.effects
			if near_hull:
				boat.take_hit(.05,.28)
				if fx!=null:fx.splash(at,1.8,true)
				game.hud.notify("Bala de canhão no casco! (%d%%)"%int(boat.integrity*100.))
			elif fx!=null:fx.splash(Vector3(at.x,Waves.height_at(at),at.z),2.6,true)
			game.audio.cue_at("slam",at,-4.)
			node.queue_free();balls.remove_at(i)

## E while they are alongside: pay a quarter of your coins and they let you go.
func pay_tribute() -> String:
	if state!="abordando":return ""
	var fee: int=maxi(10,int(game.inventory.money*.25))
	fee=mini(fee,int(game.inventory.money))
	game.inventory.money-=fee;game.inventory.changed.emit()
	game.audio.cue("coins")
	_leave("Você paga %d moedas de tributo. Os piratas recolhem os ganchos e seguem viagem."%fee,false)
	return "Tributo pago: %d moedas."%fee

func _plunder() -> void:
	var inv: RefCounted=game.inventory
	var taken: int=int(ceil(inv.catches.size()*.5))
	for k: int in taken:inv.catches.remove_at(_rng.randi()%inv.catches.size())
	var coins: int=int(inv.money)/3;inv.money-=coins;inv.changed.emit()
	raids+=1
	_leave("Os piratas SAQUEARAM o barco: levaram %d capturas e %d moedas!"%[taken,coins],false)

func _leave(text: String,beaten: bool=false) -> void:
	state="fugindo";clock=0.
	_grapnels(game.boat,false)
	game.hud.notify(text)
	if beaten and is_instance_valid(ship):_drop_chest(ship.global_position)

## H: a harpoon from the bow, aimed through the camera. Returns "" when no pirate ship is near enough
## to be the target (the monster lairs then take the shot).
func fire_harpoon() -> String:
	if not active() or not is_instance_valid(ship):return ""
	if ship.global_position.distance_to(game.boat.global_position)>130.:return ""
	if not game.player.in_boat:return "O arpão fica na proa do barco."
	if game.inventory.equipment.get("harpoon",0)<1:return "Sem arpão de proa. O estaleiro instala um por 140 moedas."
	if game.inventory.harpoons<=0:return "Sem arpões. O estaleiro vende 4 por 20 moedas."
	game.inventory.harpoons-=1;game.inventory.changed.emit()
	var eye: Vector3=game.player.camera.global_position
	var dir: Vector3=-(game.player.camera.global_basis.z as Vector3)
	var target: Vector3=ship.global_position+Vector3(0,3.,0)
	var t:=(target-eye).dot(dir)
	var hit:=t>0. and (eye+dir*t).distance_to(target)<9.
	game.audio.cue("harpoon")
	if game.lairs!=null and game.lairs.has_method("_harpoon_fx"):
		game.lairs._harpoon_fx(game.boat.global_position-game.boat.global_basis.z*3.+Vector3(0,1.6,0),eye+dir*(t if hit else 60.))
	if not hit:return "O arpão passa longe do navio pirata. (%d restantes)"%game.inventory.harpoons
	return hit_ship()

## A harpoon (or anything else) strikes the pirate ship.
func hit_ship() -> String:
	hp-=1
	var fx=game.world.ocean.effects
	if fx!=null:fx.splash(ship.global_position+Vector3(0,1,0),2.,true)
	if hp<=0:
		_leave("O navio pirata está avariado e FOGE! Deixou um baú boiando para trás.",true)
		return "Piratas derrotados!"
	if state=="abordando":_grapnels(game.boat,false);state="caçando";clock=0.;cannon_clock=6.
	return "Arpão no casco pirata! (%d até eles fugirem)"%hp

## Loot left by a beaten crew: a chest bobbing on the water. Sail over it to pick it up.
func _drop_chest(at: Vector3) -> void:
	var chest:=Node3D.new();chest.name="BauPirata";add_child(chest)
	var F=preload("res://scripts/visuals/furniture.gd")
	var wood:=F.mat("weathered_wood",Color("6b4a2c"));var iron:=F.mat("flat",Color("2a2622"),.5,.5);var gold:=F.mat("flat",Color("e2b23c"),.3,.9)
	G.box(chest,Vector3(0,.3,0),Vector3(1.,.6,.65),wood)
	var lid:=G.cylinder(chest,Vector3(0,.62,0),.33,1.,wood,.33,12);lid.rotation.z=PI*.5;lid.scale=Vector3(1.,1.,.98)
	for x: float in [-.38,0.,.38]:G.box(chest,Vector3(x,.45,0),Vector3(.06,.95,.68),iron)
	G.box(chest,Vector3(0,.5,-.34),Vector3(.12,.16,.04),gold)
	var light:=OmniLight3D.new();light.light_color=Color("ffd27a");light.omni_range=6.;light.light_energy=1.2;light.position.y=1.;chest.add_child(light)
	chest.global_position=at
	chests.append({"node":chest,"coins":_rng.randi_range(90,170),"map":_rng.randf()<.5})

func _update_chests(delta: float,boat: Node3D) -> void:
	for i: int in range(chests.size()-1,-1,-1):
		var c: Dictionary=chests[i];var node: Node3D=c.node
		var p: Vector3=node.global_position
		node.global_position.y=Waves.height_at(p)-.25
		node.rotation.y+=delta*.2;node.rotation.z=sin(Time.get_ticks_msec()*.002+float(i))*.08
		if game.player.in_boat and Vector2(p.x-boat.global_position.x,p.z-boat.global_position.z).length()<4.5:
			game.inventory.money+=int(c.coins)
			var text:="Baú pirata recolhido: %d moedas"%int(c.coins)
			if bool(c.map) and game.get("treasure")!=null and game.treasure.has_method("give_map"):text+=" e "+game.treasure.give_map()
			game.inventory.changed.emit();game.audio.cue("coins");game.hud.notify(text+"!")
			node.queue_free();chests.remove_at(i)

## Interaction hint while they are alongside.
func hint() -> String:
	if state!="abordando":return ""
	return "PIRATAS! E · Pagar tributo (%d)    H · Arpão (%d)    SHIFT · Fugir"%[mini(maxi(10,int(game.inventory.money*.25)),int(game.inventory.money)),int(game.inventory.harpoons)]
