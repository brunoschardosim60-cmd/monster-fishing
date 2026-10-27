extends Node
## Hired crew (contracted at the inn, paid every morning). How many fit depends on the boat (berths in
## harbor_economy.BOATS). Each sailor has a standing task the skipper sets by walking up and pressing E:
##   convés   — hauls traps and the set net (walks to the rail on the gear's side first), calls out when a
##              rod in a holder bends, and in heavy weather goes round lashing the deck (less wave damage,
##              reefs an over-pressed sail)
##   holofote — at night stands by the searchlight and keeps it on whatever matters nearby: buoys of your
##              gear, other vessels, rocks and shore ahead (needs the searchlight upgrade)
##   pesca    — fishes with a hand line at the rail while the boat lies still: same bite odds as yours at
##              that spot (a little lower), fights what bites with your tackle, and loses what is too big
##              for it; what comes up goes to the hold
##   leme     — takes the wheel when you leave it: keeps the course and speed you had, and stops the
##              engine if land comes up ahead
## Crew also keep the catch in order: two more places in the hold per sailor aboard.
const Sailor=preload("res://scripts/boats/hired_sailor.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const HIRE_PRICE: int=60
const DAILY_WAGE: int=10
const NAMES: Array[String]=["Zé Maré","Tonho","Dalva","Bento","Iara","Quim","Lia","Severino"]
const TASKS: Array[String]=["convés","holofote","pesca","leme"]
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
## A crewman's bite rate against yours at the same spot.
const CREW_BITE: float=.7
var game: Node3D
var boat: CharacterBody3D
var sailors: Array[Node3D]=[]
## Jobs waiting for a sailor to reach the spot: {"sailor","on_arrive": Callable, "until": seconds after}
var _pending: Array[Dictionary]=[]
var _last_hour: float=-1.
var _storm: bool=false
## Course the helmsman holds: captured when the skipper lets go of the wheel.
var _course: Dictionary={}
var _land_warned: bool=false

func berths() -> int:
	return int(preload("res://scripts/inventory/harbor_economy.gd").BOATS.get(str(game.inventory.boat_id),{}).get("berths",0))

func aboard() -> int:
	return sailors.size()

## Recreates the sailors aboard from the inventory record (after hiring, loading, or changing boats).
func sync() -> void:
	for s: Node3D in sailors:s.queue_free()
	sailors.clear();_pending.clear()
	if boat!=null:boat.autopilot={}
	_course={}
	var crew: Array=game.inventory.crew
	for i: int in mini(crew.size(),berths()):
		var s:=Sailor.new();s.sailor_name=str(crew[i].name);s.look_id=int(crew[i].look);s.boat=boat;s.name="Marujo_%d"%i
		boat._hull.add_child(s)
		s.deck_local=_station(i);s.target=s.deck_local;s.assign("idle",_station(i),0.)
		s.set_meta("task",str(crew[i].get("task","convés")))
		s.arrived.connect(_on_arrived)
		sailors.append(s)

func _station(i: int) -> Vector3:
	var deck: Dictionary=boat.deck_layout()
	var side: float=1. if i%2==0 else -1.
	return Vector3(side*(float(deck.x)-.25),float(deck.y),lerpf(float(deck.z0),float(deck.z1),.35+.15*float(i)))

func hire() -> String:
	var inv=game.inventory
	if berths()<=0:return "Este barco não tem lugar para tripulação."
	if inv.crew.size()>=berths():return "Não há mais beliches neste barco (%d)."%berths()
	if inv.money<HIRE_PRICE:return "Contratar custa %d moedas."%HIRE_PRICE
	inv.money-=HIRE_PRICE
	var used: Array=[]
	for c: Dictionary in inv.crew:used.append(c.name)
	var pick: String=NAMES[0]
	for n: String in NAMES:
		if not n in used:pick=n;break
	inv.crew.append({"name":pick,"look":80+inv.crew.size()*9,"task":"convés"})
	preload("res://scripts/inventory/harbor_economy.gd").apply(inv,boat,game.fishing)
	inv.changed.emit();sync()
	return "%s embarcou. Salário: %d moedas por dia. Fale com ele no convés (E) para mudar a tarefa."%[pick,DAILY_WAGE]

func dismiss() -> String:
	var inv=game.inventory
	if inv.crew.is_empty():return "Não há ninguém para dispensar."
	var c: Dictionary=inv.crew.pop_back()
	preload("res://scripts/inventory/harbor_economy.gd").apply(inv,boat,game.fishing)
	inv.changed.emit();sync()
	return "%s desembarcou."%str(c.name)

## The sailor within reach of the player on deck, if any.
func near(to: Vector3) -> Node3D:
	for s: Node3D in sailors:
		if s.global_position.distance_to(to)<1.4:return s
	return null

func cycle_task(s: Node3D) -> String:
	var i: int=sailors.find(s)
	var task: String=str(s.get_meta("task","convés"))
	task=TASKS[(TASKS.find(task)+1)%TASKS.size()]
	if task=="holofote" and not boat.searchlight_upgraded:task="pesca"
	# One helmsman is enough.
	if task=="leme":
		for o: Node3D in sailors:
			if o!=s and str(o.get_meta("task",""))=="leme":task="convés";break
	var was: String=str(s.get_meta("task","convés"))
	if was=="leme":boat.autopilot={};_course={}
	s.rod_out=false;s.pull=0.;s.set_meta("fishing",{})
	s.set_meta("task",task);game.inventory.crew[i].task=task
	s.assign("idle",_station(i),0.)
	return "%s: %s"%[s.sailor_name,{"convés":"cuido do convés: covos, redes, varas e tempestade.","holofote":"fico no holofote.",
		"pesca":"vou pescar na amurada quando o barco estiver parado.","leme":"fico no leme: quando você soltar o timão, mantenho o rumo e a velocidade."}[task]]

func _free_deckhand() -> Node3D:
	for s: Node3D in sailors:
		if str(s.get_meta("task","convés"))=="convés" and s.job in ["idle","secure"]:return s
	for s: Node3D in sailors:
		if str(s.get_meta("task","convés"))=="convés" and s.job=="alert":return s
	return null

func can_haul() -> bool:
	return _free_deckhand()!=null

## A deckhand walks to the rail on the side of `world_point` and, once there, `on_arrive` runs (the haul
## itself). Returns the line for the HUD.
func request_haul(world_point: Vector3,on_arrive: Callable) -> String:
	var s:=_free_deckhand()
	if s==null:return ""
	var local: Vector3=boat._hull.to_local(world_point)
	var deck: Dictionary=boat.deck_layout()
	var side: float=signf(local.x) if absf(local.x)>.01 else 1.
	s.assign("haul",Vector3(side*(float(deck.x)-.1),0.,clampf(local.z,float(deck.z0)+.4,float(deck.z1)-.4)),-PI*.5*side)
	_pending.append({"sailor":s,"on_arrive":on_arrive,"until":5.})
	return "%s vai à amurada recolher."%s.sailor_name

## A rod in holder `i` has a fish on: a deckhand goes to it and calls the skipper.
func alert_holder(i: int) -> void:
	var s:=_free_deckhand()
	if s==null:return
	var node: Node3D=game.holders.holders[i].node
	var local: Vector3=node.position
	s.assign("alert",local-Vector3(signf(local.x)*.5,0,0),-PI*.5*signf(local.x))
	_pending.append({"sailor":s,"on_arrive":func() -> void:
		game.hud.notify("%s: Peixe na vara de %s!"%[s.sailor_name,"boreste" if local.x>0. else "bombordo"])
		game.audio.cue("bite"),"until":6.})

func _on_arrived(s: Node3D) -> void:
	for p: Dictionary in _pending:
		if p.sailor==s and not p.get("done",false):
			p.done=true;p.clock=0.
			(p.on_arrive as Callable).call()
			return

func _process(delta: float) -> void:
	if game==null or boat==null:return
	# Boat changed (or crew hired/dismissed elsewhere): bring the sailors aboard in line with the berths.
	if sailors.size()!=mini((game.inventory.crew as Array).size(),berths()) or (not sailors.is_empty() and not is_instance_valid(sailors[0])):sync()
	# Finished jobs: back to the station after a while.
	for p: Dictionary in _pending.duplicate():
		if p.get("done",false):
			p.clock=float(p.clock)+delta
			if float(p.clock)>float(p.until):
				_pending.erase(p)
				var i: int=sailors.find(p.sailor)
				if i>=0 and (p.sailor as Node3D).job in ["haul","alert"]:(p.sailor as Node3D).assign("idle",_station(i),0.)
	_storm_duty()
	_searchlight(delta)
	_crew_fishing(delta)
	_helm()
	_wages()

func _storm_duty() -> void:
	var here:=Vector2(boat.global_position.x,boat.global_position.z)
	var rough: bool=maxf(Waves.storm_factor(here),smoothstep(.68,1.,Waves.energy))>.4
	var securing:=0
	for i: int in sailors.size():
		var s: Node3D=sailors[i]
		if str(s.get_meta("task","convés"))!="convés":continue
		if rough and s.job in ["idle","alert"]:s.assign("secure",_station(i),0.)
		elif not rough and s.job=="secure":s.assign("idle",_station(i),0.)
		if s.job=="secure":securing+=1
	boat.wave_damage_scale=.55 if securing>0 else 1.
	if rough and not _storm and securing>0:game.hud.notify("A tripulação amarra o convés para a tormenta.")
	_storm=rough
	# A deckhand will not let a full sail tear in a gale.
	if securing>0 and boat.has_sails() and Waves.wind>.72 and boat.sail_target>.5:
		boat.sail_target=.5;game.hud.notify("%s rizou as velas."%sailors[0].sailor_name)

func _searchlight(delta: float) -> void:
	var operator: Node3D=null
	for s: Node3D in sailors:
		if str(s.get_meta("task",""))=="holofote":operator=s;break
	if operator==null or not boat.searchlight_upgraded or boat.searchlight==null:return
	var deck: Dictionary=boat.deck_layout()
	var post:=Vector3(.4,float(deck.y),float(deck.z0)+1.2)
	if operator.job!="light":operator.assign("light",post,0.);return
	if not operator.at_target():return
	var night: bool=game.world.ocean.daylight<.35
	if not night:return
	# Pick what deserves the light: gear buoys and other vessels close by, else whatever land lies ahead.
	var eye: Vector3=boat.global_position
	var best:=Vector3.INF;var best_d:=140.
	for t: Dictionary in game.gear.traps:
		var d: float=eye.distance_to(t.at)
		if d<best_d:best_d=d;best=t.at
	if not game.gear.gillnet.is_empty():
		for end: Vector3 in [game.gear.gillnet.a,game.gear.gillnet.b]:
			var d2: float=eye.distance_to(end)
			if d2<best_d:best_d=d2;best=end
	for v: Node3D in game.world.traffic.vessels:
		var d3: float=eye.distance_to(v.global_position)
		if d3<best_d:best_d=d3;best=v.global_position
	if best==Vector3.INF:
		for k: int in range(1,9):
			var probe:=eye-boat.global_basis.z*float(k)*15.
			if Layout.coast(Vector2(probe.x,probe.z)).x<4.:best=probe;break
	if best==Vector3.INF:best=eye-boat.global_basis.z*60.
	var local: Vector3=boat.searchlight.get_parent().to_local(best)-boat.searchlight.position
	var yaw: float=atan2(-local.x,-local.z);var pitch: float=atan2(local.y,Vector2(local.x,local.z).length())+.16
	boat.light_yaw=lerp_angle(boat.light_yaw,clampf(yaw,-1.2,1.2),1.-exp(-delta*2.))
	boat.light_pitch=lerpf(boat.light_pitch,clampf(pitch,-.9,.25),1.-exp(-delta*2.))

## Sailors set to fish: each takes a spot at the rail (starboard, port...), puts a float out and waits.
func _crew_fishing(delta: float) -> void:
	var deck: Dictionary=boat.deck_layout()
	var n:=0
	for i: int in sailors.size():
		var s: Node3D=sailors[i]
		if str(s.get_meta("task",""))!="pesca":continue
		var side: float=1. if n%2==0 else -1.
		var z: float=lerpf(float(deck.z0),float(deck.z1),.62-.2*float(n/2))
		n+=1
		if s.job!="fish":s.assign("fish",Vector3(side*(float(deck.x)-.15),0.,z),-PI*.5*side);s.set_meta("fishing",{});continue
		var st: Dictionary=s.get_meta("fishing",{})
		if st.is_empty():st={"state":"wait","clock":0.};s.set_meta("fishing",st)
		# Fishing wants a boat lying still and a sea that lets you stand at the rail.
		if not s.at_target() or absf(boat.speed)>1.2 or _storm or not game.player.in_boat:
			s.rod_out=false;s.pull=0.;st.state="wait";st.clock=0.;continue
		s.rod_out=true
		var bob: Vector3=boat._hull.to_global(Vector3(side*(float(deck.x)+6.),0.,z))
		bob.y=Waves.height_at(bob);s.bob_point=bob
		st.clock=float(st.clock)+delta
		match str(st.state):
			"wait":
				s.pull=0.
				var rate: float=float(game._fishing_conditions(bob).rate)*Fishing.BASE_BITE_RATE*CREW_BITE
				if st.clock>2. and randf()<1.-exp(-rate*delta):_crew_bite(s,st,bob)
			"fight":
				s.pull=clampf(.45+.3*sin(float(st.clock)*6.)+.2*float(st.overload),.2,1.)
				s.bob_point.y-=.35
				if randf()<delta*1.2 and game.world.ocean.effects!=null:game.world.ocean.effects.splash(bob,.2+minf(float(st.weight)*.02,.6),false)
				if float(st.clock)>=float(st.length):_crew_fight_end(s,st,bob)
			"rest":
				s.pull=0.
				if float(st.clock)>3.:st.state="wait";st.clock=0.

## A fish takes a crewman's bait: same species choice as a line of yours at that spot.
func _crew_bite(s: Node3D,st: Dictionary,bob: Vector3) -> void:
	var fishing: Node=game.fishing
	var region: String=game.marine.region_at(bob)
	if fishing._available(region).is_empty():return
	var keep_region: String=fishing.region_current;var keep_school: String=fishing._school
	fishing.region_current=region;fishing._school=game.marine.school_at(bob)
	var sp: Resource=fishing._pick_species()
	fishing.region_current=keep_region;fishing._school=keep_school
	var w: float=snappedf(randf_range(float(sp.min_weight),float(sp.max_weight)),.01)
	var over: float=w/fishing.tackle_capacity()
	st.species=sp;st.weight=w;st.overload=over;st.region=region
	# Longer fights for heavier fish; the odds of landing fall as the fish outweighs the tackle.
	st.length=(4.+sqrt(w)*3.5)*(1.+minf(over,2.)*.5)*(1.+float(sp.difficulty)*.4)
	st.land_odds=clampf(1.05-.55*over-.12*float(sp.difficulty),0.,.96)
	st.state="fight";st.clock=0.

func _crew_fight_end(s: Node3D,st: Dictionary,bob: Vector3) -> void:
	var sp: Resource=st.species;var w: float=st.weight
	st.state="rest";st.clock=0.;s.pull=0.
	if randf()>=float(st.land_odds):
		if w>=2.:game.hud.notify("%s perdeu um %s grande."%[s.sailor_name,str(sp.display_name).to_lower()])
		return
	var data:={"id":str(sp.id),"species_id":str(sp.id),"name":str(sp.display_name),"species_name":str(sp.display_name),"weight":w,
		"value":maxi(1,int(round(w*float(sp.value_per_kg)))),"rarity":str(sp.rarity),"region":str(st.region),
		"caught_at":Time.get_datetime_string_from_system(true),"timestamp":int(Time.get_unix_time_from_system()),"color":sp.color.to_html(),"crew":s.sailor_name}
	if game.world.ocean.effects!=null:game.world.ocean.effects.splash(boat._hull.to_global(Vector3(signf(s.deck_local.x)*(absf(s.deck_local.x)+.6),0,s.deck_local.z)),.3,false)
	s.visual.play_action("ual/PickUp",1.)
	if game.inventory.add_catch(data):
		game.inventory.record(data)
		game.hud.notify("%s pescou: %s · %.2f kg (porão %d/%d)."%[s.sailor_name,data.name,w,game.inventory.catches.size(),game.inventory.hold_limit])
	else:
		game.inventory.record(data,true)
		game.hud.notify("%s pescou um %s, mas o porão está cheio: devolveu."%[s.sailor_name,str(data.name).to_lower()])

## The helmsman: beside the wheel while you steer; at the wheel holding your course when you leave it.
func _helm() -> void:
	var s: Node3D=null
	for o: Node3D in sailors:
		if str(o.get_meta("task",""))=="leme":s=o;break
	if s==null:
		if not boat.autopilot.is_empty():boat.autopilot={}
		return
	var helm: Vector3=boat.hull_spec.helm
	if not game.player.in_boat or boat.occupied:
		boat.autopilot={};_course={};_land_warned=false
		if s.job!="helm_wait":s.assign("helm_wait",helm+Vector3(.75,0,.35),0.)
		return
	if _course.is_empty():
		# You just let go of the wheel: remember the course and the engine order you left.
		_course={"heading":boat.rotation.y,"throttle":snappedf(clampf(boat.engine_rpm,-.5,1.),.05)}
	if s.job!="helm":s.assign("helm",helm,0.)
	if not s.at_target():return
	if absf(float(_course.throttle))>.01:
		var dir: float=signf(float(_course.throttle))
		for d: float in [18.,40.,70.]:
			var p: Vector3=boat.global_position-boat.global_basis.z*d*dir
			if Layout.coast(Vector2(p.x,p.z)).x<8.:
				_course.throttle=0.
				if not _land_warned:_land_warned=true;game.hud.notify("%s: Terra à frente! Parei as máquinas."%s.sailor_name)
				break
	boat.autopilot=_course

## Every morning the crew is paid; whoever cannot be paid goes ashore.
func _wages() -> void:
	var hour: float=game.world.ocean.hour
	if _last_hour>=0. and _last_hour<6. and hour>=6. and not game.inventory.crew.is_empty():
		var inv=game.inventory;var due: int=DAILY_WAGE*inv.crew.size()
		if inv.money>=due:inv.money-=due;game.hud.notify("Salário da tripulação pago: %d moedas."%due)
		else:
			var left: Dictionary=inv.crew.pop_back()
			game.hud.notify("Sem dinheiro para o salário: %s desembarcou."%str(left.name))
			preload("res://scripts/inventory/harbor_economy.gd").apply(inv,boat,game.fishing);sync()
		inv.changed.emit()
	_last_hour=hour
