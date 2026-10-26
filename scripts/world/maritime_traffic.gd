extends Node3D
## The fleet. Three kinds of routes keep the ocean busy at every scale:
##  · the trade lane (ROUTE) around the home waters, used by working ships and coasting sailers;
##  · a far ocean lane, an open-sea loop through the outer archipelago where tankers and huge
##    container ships give a real sense of scale on the horizon;
##  · coastal routes hugging other islands for canoes, rowing boats, small fishing boats (which stop
##    on their grounds) and sailing yachts — these run for shelter when a storm builds.
## The player can hail any vessel from the boat: it heaves to, the crew answers and offers trade,
## bait, or real news of what is out at sea.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Vessel=preload("res://scripts/boats/traffic_vessel.gd")
const ROUTE: Array[Vector3]=[Vector3(20,0,-140),Vector3(320,0,-140),Vector3(440,0,200),Vector3(450,0,800),Vector3(70,0,1170),Vector3(-530,0,1030),Vector3(-530,0,540),Vector3(-340,0,-140)]
## kind, length, cruise speed (m/s), turn rate, start waypoint
const TRADE_FLEET: Array=[["pesqueiro",14.,4.4,.5,1],["rebocador",21.,3.8,.6,4],["apoio",30.,5.2,.4,6],["cargueiro",72.,4.2,.15,2],["escuna",26.,4.6,.35,7],["galeao",44.,4.8,.28,5],["veleiro",12.,4.3,.55,3]]
const FAR_FLEET: Array=[["petroleiro",165.,4.,.08,0],["galeao",52.,5.,.22,3],["gigante",240.,5.,.06,6],["cargueiro",88.,4.6,.12,10]]
## kind, length, speed, turn, lobe, angle from, angle to (deg), distance off the coast, fishing stops
const COASTAL_FLEET: Array=[["canoa",5.,1.8,1.,3,150.,230.,38.,false],["canoa",4.5,1.7,1.,1,140.,220.,35.,false],
	["bote_remo",4.6,1.5,.8,2,-40.,40.,34.,false],["bote_remo",4.2,1.5,.8,8,160.,260.,36.,false],
	["bote",7.5,4.5,.9,9,0.,360.,60.,true],["bote",7.,4.4,.9,18,0.,360.,55.,true],
	["pesqueiro",13.,4.2,.5,17,0.,360.,80.,true],["veleiro",11.,4.5,.55,11,0.,360.,75.,false]]
var vessels: Array[CharacterBody3D]=[]
var far_lane: Array[Vector3]=[]
var night_clock: float=0.
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=4242
	var seed_value:=11
	for data: Array in TRADE_FLEET:
		seed_value+=17;_spawn(data[0],data[1],data[2],data[3],ROUTE,data[4],seed_value,[],Vector3.INF)
	far_lane=_far_lane()
	for data: Array in FAR_FLEET:
		seed_value+=17;_spawn(data[0],data[1],data[2],data[3],far_lane,int(data[4])%far_lane.size(),seed_value,[],Vector3.INF)
	for data: Array in COASTAL_FLEET:
		seed_value+=17
		var full: bool=float(data[6])-float(data[5])>=359.
		var route:=_coastal(int(data[4]),float(data[5]),float(data[6]),float(data[7]),10 if full else 6,not full)
		if route.size()<3:continue
		var stops: Array[int]=[]
		if data[8]:stops.assign([2,6])
		var shelter:=_water_near(int(data[4]),(float(data[5])+float(data[6]))*.5,22.)
		_spawn(data[0],data[1],data[2],data[3],route,_rng.randi()%route.size(),seed_value,stops,shelter)

func _spawn(kind: String,length_m: float,speed: float,turn: float,route: Array[Vector3],start: int,seed_value: int,stops: Array[int],shelter: Vector3) -> void:
	var ship:=Vessel.new()
	ship.kind=kind;ship.length_m=length_m;ship.cruise_speed=speed;ship.turn_rate=turn;ship.seed_value=seed_value
	ship.route.assign(route);ship.waypoint=start;ship.fishing_stops=stops;ship.shelter=shelter
	ship.ship_name=_name_for(kind)
	ship.name=ship.ship_name.replace(" ","")
	add_child(ship);vessels.append(ship)

func _name_for(kind: String) -> String:
	var first: Array[String]=["Estrela","Maré","Aurora","Gaivota","Sereia","Vento","Brisa","Âncora","Coral","Netuno","Albatroz","Iemanjá","Boa Sorte","Lua","Farol"]
	var second: Array[String]=["do Sul","Azul","Dourada","do Norte","Bravia","Mansa","de Prata","Ligeira","Real","do Mar"]
	var prefix: String=Vessel.NAMES.get(kind,"Barco")
	return "%s %s %s"%[prefix,first[_rng.randi()%first.size()],second[_rng.randi()%second.size()]]

## Finds open water at `distance` metres off the shore of a lobe, walking outward along `angle_deg`.
func _water_near(lobe: int,angle_deg: float,distance: float) -> Vector3:
	var l:=Layout.LOBES[lobe];var dir:=Vector2(cos(deg_to_rad(angle_deg)),sin(deg_to_rad(angle_deg)))
	var p:=Vector2(l.x,l.y)
	for step: int in 600:
		p+=dir*2.
		if Layout.coast(p).x>=distance:return Vector3(p.x,0,p.y)
	return Vector3.INF

## Waypoints hugging an island. Arcs become out-and-back routes so the return leg never cuts over land.
func _coastal(lobe: int,from_deg: float,to_deg: float,distance: float,count: int,ping_pong: bool) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for i: int in count:
		var a:=lerpf(from_deg,to_deg,float(i)/float(count-1 if ping_pong else count))
		var p:=_water_near(lobe,a,distance)
		if p!=Vector3.INF and absf(p.x)<Layout.WORLD_HALF-100. and absf(p.z)<Layout.WORLD_HALF-100.:points.append(p)
	if ping_pong and points.size()>2:
		for i: int in range(points.size()-2,0,-1):points.append(points[i])
	return points

## An open-ocean loop through the outer archipelago, kept well clear of every island.
func _far_lane() -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var centre:=Vector2(250.,700.)
	for i: int in 14:
		var angle:=TAU*float(i)/14.
		var placed:=false
		for shrink: int in 12:
			var r:=Vector2(2700.,2250.)*(1.-float(shrink)*.05)
			var p:=centre+Vector2(cos(angle)*r.x,sin(angle)*r.y)
			if absf(p.x)>Layout.WORLD_HALF-150. or absf(p.y)>Layout.WORLD_HALF-150.:continue
			if Layout.coast(p).x>180.:points.append(Vector3(p.x,0,p.y));placed=true;break
		if not placed:continue
	# Detour any leg that passes too near land through a point pushed further out.
	var safe: Array[Vector3]=[]
	for i: int in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()]
		safe.append(a)
		var worst:=1e9;var worst_t:=.5
		for j: int in 24:
			var t:=float(j)/24.;var q:=a.lerp(b,t)
			var c:=Layout.coast(Vector2(q.x,q.z)).x
			if c<worst:worst=c;worst_t=t
		if worst<120.:
			var q:=a.lerp(b,worst_t);var out:=Vector2(q.x-centre.x,q.z-centre.y).normalized()
			for k: int in 20:
				var candidate:=Vector2(q.x,q.z)+out*float(k+1)*60.
				if absf(candidate.x)<Layout.WORLD_HALF-150. and absf(candidate.y)<Layout.WORLD_HALF-150. and Layout.coast(candidate).x>180.:
					safe.append(Vector3(candidate.x,0,candidate.y));break
	return safe

func set_player_boat(boat: Node3D) -> void:
	for ship: CharacterBody3D in vessels:ship.player_boat=boat

func _process(delta: float) -> void:
	night_clock-=delta
	if night_clock>0.:return
	night_clock=2.
	var ocean=get_parent().get("ocean")
	if ocean==null:return
	var daylight: float=ocean.daylight
	for ship: CharacterBody3D in vessels:ship.set_night(1.-daylight)

# ---------------------------------------------------------------- hailing and trade
## The closest vessel close enough to talk to from the player's boat, or null.
func hailable(at: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D=null;var best_d:=1e9
	for ship: CharacterBody3D in vessels:
		var d: float=Vector2(ship.position.x-at.x,ship.position.z-at.z).length()-float(ship.length_m)*.5-float(ship.beam_m)*.5
		if d<28. and d<best_d:best=ship;best_d=d
	return best

## What a vessel offers, by kind.
func offer_kind(ship: CharacterBody3D) -> String:
	match ship.kind:
		"bote","pesqueiro":return "isca"
		"cargueiro","gigante","apoio","escuna","petroleiro","galeao":return "comercio"
	return "noticias"

func greeting(ship: CharacterBody3D) -> String:
	match offer_kind(ship):
		"isca":return "%s: \"Ô de bordo! Trocamos isca fresca: 6 iscas por um peixe seu.\" (E para trocar)"%ship.ship_name
		"comercio":return "%s: \"Compramos pescado fresco, pagamos 25%% acima do porto.\" (E para vender)"%ship.ship_name
	return "%s: \"Bons ventos! Quer saber o que vimos no mar?\" (E para ouvir)"%ship.ship_name

## Carries out the vessel's offer. Returns the line to show the player.
func trade(ship: CharacterBody3D,game: Node) -> String:
	var inventory=game.inventory
	match offer_kind(ship):
		"isca":
			if inventory.catches.is_empty():
				if inventory.money>=12:inventory.money-=12;inventory.bait+=6;return "Sem peixe? Tudo bem: 6 iscas por 12 moedas."
				return "Volte quando tiver um peixe para trocar."
			var cheapest:=0
			for i: int in inventory.catches.size():
				if int(inventory.catches[i].get("value",0))<int(inventory.catches[cheapest].get("value",0)):cheapest=i
			var fish: Dictionary=inventory.catches[cheapest];inventory.catches.remove_at(cheapest);inventory.bait+=6;inventory.changed.emit()
			return "Trocado: %s por 6 iscas."%str(fish.get("name","peixe"))
		"comercio":
			var value: int=inventory.total_value()
			if value<=0:return "Não temos o que comprar hoje: seu porão está vazio."
			var earned: int=inventory.sell_all();var bonus:=int(round(float(earned)*.25));inventory.money+=bonus
			return "Vendido a bordo: +%d moedas (inclui %d de bônus)."%[earned+bonus,bonus]
	return _news(ship,game)

## Real news: the nearest rare school, predator or sea monster, with bearing and distance.
func _news(ship: CharacterBody3D,game: Node) -> String:
	var at: Vector3=ship.position;var best:="";var best_d:=1e9;var best_p:=Vector3.ZERO
	var marine=game.get("marine")
	if marine!=null:
		for school in marine.fish_schools:
			var rare: bool=school.species in ["atum_rei","peixe_lua","peixe_serra","tubarao_branco","tubarao_recife"]
			if not rare:continue
			var d: float=at.distance_to(school.center)
			if d<best_d and d>60.:best_d=d;best_p=school.center;best=str(school.species).replace("_"," ")
	var events=game.world.get("sea_events")
	if events!=null and events.current!=null and is_instance_valid(events.current):
		var monster: Node3D=events.current;best="uma baleia" if events.kind=="whale" else "algo enorme na água";best_p=monster.global_position;best_d=at.distance_to(best_p)
	# Crews also warn about the nearest monster territory.
	var warning:=""
	var lairs=game.get("lairs")
	if lairs!=null:
		var near_d:=1e9
		for lair: Dictionary in lairs.lairs:
			var c: Vector3=lair.center;var d:=Vector2(c.x-at.x,c.z-at.z).length()-float(lair.radius)
			if d<near_d and d<1800.:
				near_d=d
				var ld:=Vector2(c.x-at.x,c.z-at.z)
				warning=" Cuidado: o %s fica a %s, uns %d m. Lá, só de luzes apagadas e devagar."%[lair.name,_heading(ld),int(round(maxf(d,0.)/50.)*50.)]
	if best.is_empty():return "Mar tranquilo por aqui. Dizem que à noite os peixes-lanterna sobem."+warning
	var dir:=Vector2(best_p.x-at.x,best_p.z-at.z)
	return "\"Vimos %s a %s, uns %d m daqui.\""%[best,_heading(dir),int(round(best_d/10.)*10.)]+warning

func _heading(dir: Vector2) -> String:
	return ["N","NE","L","SE","S","SO","O","NO"][int(round(fposmod(atan2(dir.x,-dir.y),TAU)/(TAU/8.)))%8]
