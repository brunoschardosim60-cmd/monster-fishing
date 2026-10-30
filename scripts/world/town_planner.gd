extends Node3D
## Builds the town that spreads over the main island around the old harbour village: districts with a
## paved square (fountain, benches, trees, lamps), a landmark building, houses of several styles facing
## the square, cobbled streets that follow the ground, stilt houses with boardwalks over the water at
## the western point, a stone bridge from the village to the west district, and residents who walk
## between their doors and the square. Placement reads the real terrain (Layout.height / coast / paths).
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
const House=preload("res://scripts/world/town_house.gd")
const Resident=preload("res://scripts/world/village_resident.gd")
const Props=preload("res://scripts/world/cc0_props.gd")
const PLAZA_R: float=10.
## name, centre (x,z), radius, houses, styles, landmark, links (where the avenue joins the rest of the town), over water
const DISTRICTS: Array=[
	["Bairro do Poente",Vector2(-160,30),62.,18,["costeira","costeira","sobrado","costeira","cabana","sobrado","galpao"],"capela",[Vector2(-97,-4)],false],
	["Bairro do Nascente",Vector2(165,22),58.,16,["costeira","sobrado","costeira","sobrado","costeira","cabana"],"prefeitura",[Vector2(88,22)],false],
	["Encosta Leste",Vector2(205,112),36.,7,["cabana","costeira","cabana","costeira"],"escola",[Vector2(165,22)],false],
	["Vale do Meio",Vector2(-80,108),26.,5,["cabana","cabana","costeira"],"",[Vector2(-40,66)],false],
	["Palafitas da Ponta",Vector2(-128,-24),34.,9,["palafita"],"galpao",[Vector2(-160,30)],true]]
## Lighthouses and landmarks the town keeps clear of.
const KEEP_CLEAR: Array[Vector3]=[Vector3(174,96,24),Vector3(-80,775,32),Vector3(90,345,14),Vector3(-170,210,18),Vector3(-110,310,30)]
var village: Node3D
var houses: Array[Node3D]=[]
var footprints: Array[Vector3]=[]
var districts: Array[Dictionary]=[]
var residents: Array[Node3D]=[]
## Fishing shops in the districts: walk-in buildings with a furnished sales floor and a shopkeeper.
var shops: Array[Node3D]=[]
## Building sites: a timber frame going up, with carpenters carrying planks to it and one on the scaffold.
var sites: Array[Node3D]=[]
var workers: Array[Node3D]=[]
const Porter=preload("res://scripts/world/village_porter.gd")
const Tools=preload("res://scripts/player/hand_tools.gd")
const SITE_DISTRICTS: Array[String]=["Bairro do Nascente","Bairro do Poente"]
const SHOP_TITLES: Dictionary={"Bairro do Poente":"Loja de Pesca do Poente","Bairro do Nascente":"Anzol do Nascente"}
var lamps: int=0
var _rng:=RandomNumberGenerator.new()
var _avenues: Array=[]
## [a, b, width] of every street and [centre, radius] of every square, to keep grass off the paving.
var _streets: Array=[]
var _plazas: Array=[]
var _clock: float=0.
var _street: Material
var _dirt: Material
var _curb: Material
## [district name, polyline] of each avenue; lanes of each district are kept in its record ("lanes").
var _avenue_curves: Array=[]
## Where the door path of the building being placed goes (a point on a lane, or the square's edge).
var _yaw_jitter: float=0.
## Cottages and shacks scattered over the island outside the districts.
var homesteads: Array=[]

func _ready() -> void:
	_rng.seed=1977
	_street=M.surface("cobblestone",Color("c7c1ad"),.35)
	_dirt=M.surface("forest_floor",Color("c9a878"),.45)
	_curb=House.flat(Color("9a9b90"),.9)
	# Every district's avenue is known before any house goes up, so no house is built across one. Avenues
	# bend: a gentle S between the square and where they join the rest of the town.
	for data: Array in DISTRICTS:
		for link: Vector2 in data[6]:
			var start: Vector2=data[1]+(link-data[1]).normalized()*(PLAZA_R-.5)
			var curve:=_bend(start,link,.18)
			_avenue_curves.append([data[0],curve])
			for i: int in curve.size()-1:_avenues.append([curve[i],curve[i+1]])
	for data: Array in DISTRICTS:_district(data)
	_scatter_homesteads()
	_bridge(Vector3(-61,1.4,-4),Vector3(-93,Layout.ground(Vector2(-93,-4))+.25,-4),1.6)
	_clear_ground_cover()
	var dynamic: Array[Node3D]=[];dynamic.append_array(residents)
	for shop: Node3D in shops:dynamic.append(shop.keeper)
	dynamic.append_array(workers)
	preload("res://scripts/world/static_batch.gd").build(self,dynamic)

func _district(data: Array) -> void:
	var name_text: String=data[0];var centre: Vector2=data[1];var radius: float=data[2];var count: int=data[3]
	var styles: Array=data[4];var landmark: String=data[5];var links: Array=data[6];var water: bool=data[7]
	var record:={"name":name_text,"centre":centre,"houses":[],"doors":[]}
	var plaza_y:=Layout.ground(centre)+.08
	if not water:
		_plaza(centre,plaza_y)
		record["lanes"]=_lanes(centre,radius)
		for lane: PackedVector2Array in record.lanes:_street_path(lane,3.,_street)
	for av: Array in _avenue_curves:
		if av[0]==name_text:_street_path(av[1],3.2,_street)
	G.label(self,name_text,Vector3(centre.x,plaza_y+4.5,centre.y),28)
	if not landmark.is_empty():
		var size:=_size_of(landmark)
		var placed:=false
		for attempt: int in 24:
			var angle:=_rng.randf()*TAU
			var at:=centre+Vector2(cos(angle),sin(angle))*(PLAZA_R+size.y*.5+4.+float(attempt))
			if _place(landmark,at,size,centre,water,record):placed=true;break
		if not placed:push_warning("no room for "+landmark+" in "+name_text)
	if name_text=="Bairro do Poente" and Props.exists("Tabern"):
		for attempt: int in 40:
			var angle:=_rng.randf()*TAU
			if _place("taberna",centre+Vector2(cos(angle),sin(angle))*(PLAZA_R+11.+float(attempt)*.5),_size_of("taberna"),centre,water,record):break
	if SHOP_TITLES.has(name_text):
		record["shop_title"]=SHOP_TITLES[name_text]
		for attempt: int in 60:
			var angle:=_rng.randf()*TAU
			if _place("loja_pesca",centre+Vector2(cos(angle),sin(angle))*(PLAZA_R+8.+float(attempt)*.4),_size_of("loja_pesca"),centre,water,record):break
	if not water:
		for attempt: int in 80:
			var angle:=_rng.randf()*TAU
			if _place("obra",centre+Vector2(cos(angle),sin(angle))*(PLAZA_R+12.+float(attempt)*.4),_size_of("obra"),centre,water,record) and (record.houses as Array).filter(func(h: Node3D) -> bool:return str(h.get_meta("style",""))=="obra").size()>=2:break
	var tries:=0
	var lanes: Array=record.get("lanes",[])
	while (record.houses as Array).size()<count+(1 if not landmark.is_empty() else 0) and tries<1500:
		tries+=1
		var style: String=styles[_rng.randi()%styles.size()]
		var size:=_size_of(style)
		if water or lanes.is_empty():
			# Stilt houses: around the point, as before.
			var ring:=PLAZA_R+8.+_rng.randf()*(radius-PLAZA_R-6.+float(tries/250)*6.)
			var angle:=_rng.randf()*TAU
			_yaw_jitter=0.
			_place(style,centre+Vector2(cos(angle),sin(angle))*ring,size,centre,water,record)
			continue
		# Along a lane: either side, set back by a varying yard, turned a little off square to it; one in
		# four stands further back, up the slope, with its own path down.
		var lane: PackedVector2Array=lanes[_rng.randi()%lanes.size()]
		var k: int=_rng.randi_range(1,lane.size()-2)
		var p: Vector2=lane[k];var dir: Vector2=(lane[k+1]-lane[k-1]).normalized()
		var normal:=Vector2(-dir.y,dir.x)*(1. if _rng.randf()<.5 else -1.)
		var back: float=_rng.randf_range(2.5,6.) if _rng.randf()<.75 else _rng.randf_range(10.,22.)
		var at: Vector2=p+normal*(size.y*.5+back)+dir*_rng.randf_range(-2.,2.)
		_yaw_jitter=_rng.randf_range(-.3,.3)
		_place(style,at,size,p,water,record)
	_yaw_jitter=0.
	districts.append(record)
	if water:_boardwalks(record)
	_dress(record,water,radius)
	for link: Vector2 in links:
		var sign_at:=centre+(link-centre).normalized()*(PLAZA_R+3.)
		Props.spawn(self,"SignPost",Vector3(sign_at.x,Layout.ground(sign_at),sign_at.y),2.6,atan2(-(link-centre).x,-(link-centre).y))
	_people(record,plaza_y)

## Gardens, fences, market stalls, barrels and carts, beach shells and rocks (CC0 models).
const PLANTS: Array=[["nature:Bush_Common_Flowers",1.1],["nature:Bush_Large_Flowers",1.35],["nature:Flower_3_Group",.5],["nature:Flower_4_Group",.5],["nature:Flower_1_Group",.45],["nature:Fern_1",.7],["nature:Plant_1_Big",.9],["Flower_02_a_Art",.55]]
func _dress(record: Dictionary,water: bool,radius: float) -> void:
	if not Props.exists("Barrel"):return
	var centre: Vector2=record.centre
	for building: Node3D in record.houses:
		var style: String=building.get_meta("style","")
		var size: Vector2=building.get_meta("size",Vector2(7,6))
		var basis:=building.basis
		if water:
			if style!="palafita":continue   # only the stilt houses have a front deck to keep barrels on
			for i: int in 2:
				var local:=Vector3(_rng.randf_range(-size.x*.4,size.x*.4),0.,-size.y*.5-1.)
				Props.spawn(self,"SmallBarrel_Art",building.position+basis*local,.8,_rng.randf()*TAU,false,110.)
			continue
		if style=="galpao":
			for i: int in 4:
				var local:=Vector3((-1. if i<2 else 1.)*(size.x*.5+.9),0.,-size.y*.5+float(i%2)*1.3)
				var p:=building.position+basis*local;p.y=_foot(Vector2(p.x,p.z),.45)
				Props.spawn(self,"Barrel",p,1.1,_rng.randf()*TAU)
			var cart:=building.position+basis*Vector3(size.x*.5+3.,0.,size.y*.2);cart.y=_foot(Vector2(cart.x,cart.z),1.3)
			if not on_paving(Vector2(cart.x,cart.z)) and not _near_street(Vector2(cart.x,cart.z),2.):
				Props.solid(Props.spawn(self,"Cart",cart,3.4,building.rotation.y+PI*.5,true,220.),Vector3(1.6,1.6,2.6))
			continue
		for i: int in _rng.randi_range(3,6):
			var side:=_rng.randi()%4;var t:=_rng.randf_range(-.45,.45)
			var local: Vector3
			match side:
				0:local=Vector3(t*size.x,0.,-size.y*.5-.75)
				1:local=Vector3(t*size.x,0.,size.y*.5+.75)
				2:local=Vector3(-size.x*.5-.75,0.,t*size.y)
				_:local=Vector3(size.x*.5+.75,0.,t*size.y)
			if side==0 and absf(local.x)<1.5:continue
			var p:=building.position+basis*local
			if on_paving(Vector2(p.x,p.z)) or Layout.coast(Vector2(p.x,p.z)).x>-2.:continue
			p.y=Layout.ground(Vector2(p.x,p.z))
			var plant: Array=PLANTS[_rng.randi()%PLANTS.size()]
			Props.spawn(self,plant[0],p,float(plant[1])*_rng.randf_range(.85,1.2),_rng.randf()*TAU,false,110.)
		if style in ["costeira","cabana"] and _rng.randf()<.4:
			var x:=size.x*.5+2.4
			for k: int in 3:
				var local:=Vector3(x,0.,-size.y*.5+float(k)*2.4+1.2)
				var p:=building.position+basis*local
				if on_paving(Vector2(p.x,p.z)):continue
				# A fence panel on a slope is set by its lower end (posts go into the ground uphill),
				# never left hanging at the downhill end.
				var along: Vector3=basis.z*1.2
				p.y=minf(Layout.ground(Vector2(p.x,p.z)),minf(Layout.ground(Vector2(p.x+along.x,p.z+along.z)),Layout.ground(Vector2(p.x-along.x,p.z-along.z))))
				Props.spawn(self,"Fence_01_Art",p,2.4,building.rotation.y+PI*.5,true,130.)
	# Market stalls around the square of the larger districts.
	if not water and (record.houses as Array).size()>=10:
		var stalls:=0
		for k: int in 16:
			if stalls>=2:break
			var a:=_rng.randf()*TAU;var q:=centre+Vector2(cos(a),sin(a))*(PLAZA_R+3.2)
			if on_paving(q):continue
			var clear:=true
			for st: Array in _streets:
				if _segment_distance(q,st[0],st[1])<float(st[2])*.5+1.8:clear=false;break
			if not clear:continue
			var y:=_foot(q,1.1)
			Props.solid(Props.spawn(self,"Table_Dinner",Vector3(q.x,y,q.y),2.6,atan2(-(centre-q).x,-(centre-q).y),true,200.),Vector3(2.4,1.,1.))
			var side:=Vector2(-sin(a),cos(a))*3.2
			Props.spawn(self,"Barrel",Vector3(q.x+side.x,_foot(q+side,.45),q.y+side.y),1.05,_rng.randf()*TAU)
			stalls+=1
	# Beach dressing: shells and rocks on the sand inside the district.
	for k: int in 40:
		var a:=_rng.randf()*TAU;var q:=centre+Vector2(cos(a),sin(a))*_rng.randf_range(0.,radius+20.)
		var c:=Layout.coast(q).x
		if c<-4. or c>.5:continue
		if k%4==0:Props.spawn(self,"nature:Rock_Medium_1" if k%8==0 else "nature:Rock_Medium_2",Vector3(q.x,Layout.ground(q)-.3,q.y),_rng.randf_range(.8,1.8),_rng.randf()*TAU,false,300.)
		else:Props.spawn(self,"Shell01",Vector3(q.x,Layout.ground(q),q.y),.18,_rng.randf()*TAU,false,60.)
	# Woodland edge: logs and mushrooms for the valley cabins.
	if String(record.name)=="Vale do Meio":
		for k: int in 10:
			var a:=_rng.randf()*TAU;var q:=centre+Vector2(cos(a),sin(a))*_rng.randf_range(PLAZA_R+2.,radius+6.)
			if on_paving(q) or Layout.path_at(q).x<3.:continue
			Props.spawn(self,"Log_01_Art" if k%3==0 else "Mushroom_01_Art",Vector3(q.x,Layout.ground(q),q.y),1.1 if k%3==0 else .45,_rng.randf()*TAU,false,140.)

func _near_street(p: Vector2,margin: float) -> bool:
	for st: Array in _streets:
		if _segment_distance(p,st[0],st[1])<float(st[2])*.5+margin:return true
	return false

## Lowest ground under a prop's footprint (radius r): set there, it never hangs over a slope.
func _foot(p: Vector2,r: float) -> float:
	var y:=Layout.ground(p)
	for d: Vector2 in [Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:y=minf(y,Layout.ground(p+d))
	return y

func _size_of(style: String) -> Vector2:
	match style:
		"sobrado":return Vector2(_rng.randf_range(8.,9.5),_rng.randf_range(7.,8.))
		"cabana":return Vector2(_rng.randf_range(5.5,6.5),_rng.randf_range(5.,6.))
		"palafita":return Vector2(_rng.randf_range(6.,7.),_rng.randf_range(5.,6.))
		"capela":return Vector2(9.,16.)
		"prefeitura":return Vector2(15.,10.)
		"escola":return Vector2(14.,8.)
		"galpao":return Vector2(11.,9.)
		"taberna":return Vector2(9.5,8.5)
		"loja_pesca":return Vector2(9.,7.)
		"obra":return Vector2(8.,6.)
	return Vector2(_rng.randf_range(7.,9.),_rng.randf_range(6.,7.5))

## Tries to put a building at `at`, facing `face`. Returns false when the ground does not allow it.
func _place(style: String,at: Vector2,size: Vector2,face: Vector2,water: bool,record: Dictionary) -> bool:
	var to_face:=(face-at).normalized()
	if to_face.length()<.5:to_face=Vector2(0,-1)
	to_face=to_face.rotated(_yaw_jitter)
	var yaw:=atan2(-to_face.x,-to_face.y)
	var half:=size*.5;var reach:=half.length()
	# Village core, lighthouses, landmarks and other buildings stay clear.
	if absf(at.x)<92.+reach and at.y>-28.-reach and at.y<70.+reach:return false
	for k: Vector3 in KEEP_CLEAR:
		if at.distance_to(Vector2(k.x,k.y))<k.z+reach:return false
	var yard=village.get("shipyard")
	if yard!=null and at.distance_to(Vector2(yard.footprint.x,yard.footprint.y))<float(yard.footprint.z)+reach:return false
	if yard!=null and at.distance_to(Vector2(yard.camp_area.x,yard.camp_area.y))<float(yard.camp_area.z)+reach:return false
	for f: Vector3 in footprints:
		if at.distance_to(Vector2(f.x,f.y))<f.z+reach+2.5:return false
	for avenue: Array in _avenues:
		if _segment_distance(at,avenue[0],avenue[1])<reach+2.5:return false
	if Layout.path_at(at).x<reach+3.:return false
	# Never on top of a street already laid, and the new door's own street to the square must not run
	# through another house.
	for st: Array in _streets:
		if _rect_meets_segment(at,half,yaw,st[0],st[1],float(st[2])*.5+.6):return false
	for tree: Vector2 in _plaza_trees:
		if _rect_meets_segment(at,half+Vector2(0.,3.5),yaw,tree,tree,2.5):return false
	if not water and not bool(record.get("isolated",false)):
		var door_at:=at+to_face*(half.y+(3.42 if style=="capela" else 0.)+1.6)
		var square_at:=_door_target(record,door_at)
		for r: Array in _rects:
			if _rect_meets_segment(r[0],r[1],r[2],door_at,square_at,1.5):return false
	var basis:=Basis(Vector3.UP,yaw)
	var lowest:=1e9;var highest:=-1e9
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1),Vector2(0,0),Vector2(0,-1.35)]:
		var local:=basis*Vector3(corner.x*half.x,0,corner.y*half.y)
		var p:=at+Vector2(local.x,local.z)
		var c:=Layout.coast(p).x
		if water:
			if c<.5 or c>16.:return false
		elif c>-5.:return false
		var h:=Layout.ground(p);lowest=minf(lowest,h);highest=maxf(highest,h)
	if not water and (highest-lowest>2.6 or highest>42.):return false
	var floor_y:=1.9 if water else highest+.25
	var depth:=floor_y-lowest+(.3 if water else .5)
	var building: Node3D
	if style=="taberna":
		# The tavern: the two-storey plank house in the town's style, with a sign board over the door.
		building=House.build("sobrado",size.x,size.y,_rng,depth)
		var board:=G.box(building,Vector3(0,3.6,-size.y*.5-.9),Vector3(2.4,.7,.08),M.surface("weathered_wood",Color("6a4a32"),1.2))
		G.label(building,"TABERNA",Vector3(0,3.6,-size.y*.5-.96),20)
	elif style=="obra":
		building=Node3D.new()
		House._plinth(building,size.x,size.y,depth,M.surface("granite",Color("a9aa9c"),1.))
		_frame(building,size)
	elif style=="loja_pesca":
		building=preload("res://scripts/world/village_building.gd").new()
		building.title=record.get("shop_title","Loja de Pesca");building.width=size.x;building.depth=size.y;building.use="shop"
		building.tint=Color("c9b991") if shops.is_empty() else Color("8fb0a6")
	else:building=House.build(style,size.x,size.y,_rng,depth)
	building.set_meta("style",style);building.set_meta("size",size);building.set_meta("over_water",water)
	building.name="Casa_%s_%d"%[style,houses.size()]
	building.position=Vector3(at.x,floor_y,at.y);building.rotation.y=yaw
	add_child(building);houses.append(building);footprints.append(Vector3(at.x,at.y,reach))
	(record.houses as Array).append(building)
	if style=="obra":
		sites.append(building);_site_crew(building,size)
	if style=="loja_pesca":
		shops.append(building)
		village.services["gear_%d"%shops.size()]=building.service
		village.buildings.append(building);village.night_lights.append_array(building.lamps)
	if not water:_entrance_steps(building,size,floor_y)
	var front_dist: float=-float(building.get_meta("front",-half.y))
	# The street (and whoever lives there) starts at the foot of the front steps.
	var steps_len: float=float(building.get_meta("steps",0))*STEP_RUN+(front_dist-half.y)
	var door:=Vector2(at.x,at.y)+to_face*(half.y+steps_len+1.6)
	# The rectangle others keep clear of includes the front steps (or the capela's tower).
	_rects.append([at+to_face*steps_len*.5,half+Vector2(0.,steps_len*.5),yaw])
	(record.doors as Array).append(door)
	# A building site has no front door yet, so no street of its own.
	if not water and style!="obra" and not bool(record.get("isolated",false)):
		var target:=_door_target(record,door)
		# Landmarks and shops face the square on paving; houses have a beaten-earth path to their lane.
		if style in ["capela","prefeitura","escola","loja_pesca","taberna"]:_street_path(_bend(door,target,.12),1.8,_street)
		else:_street_path(PackedVector2Array([door,door.lerp(target,.5)+Vector2(-(target-door).y,(target-door).x).normalized()*_rng.randf_range(-.6,.6),target]),1.3,_dirt)
	return true

## Where a door's path joins the town: the nearest point on the district's lanes, or the square's edge.
func _door_target(record: Dictionary,door: Vector2) -> Vector2:
	var centre: Vector2=record.centre
	var best:=centre+(door-centre).normalized()*PLAZA_R*.9
	var best_d:=door.distance_to(best)
	for lane: PackedVector2Array in record.get("lanes",[]):
		for i: int in lane.size()-1:
			var ab:=lane[i+1]-lane[i];var t:=clampf((door-lane[i]).dot(ab)/maxf(ab.length_squared(),.001),0.,1.)
			var q:=lane[i]+ab*t
			if door.distance_to(q)<best_d:best_d=door.distance_to(q);best=q
	return best

## A gentle S from a to b: a cubic through two side offsets, sampled every ~4 m.
func _bend(a: Vector2,b: Vector2,amount: float) -> PackedVector2Array:
	var d:=b-a;var n:=Vector2(-d.y,d.x).normalized()
	var c1:=a+d*.33+n*d.length()*amount*_rng.randf_range(-1.,1.)
	var c2:=a+d*.66+n*d.length()*amount*_rng.randf_range(-1.,1.)
	var out:=PackedVector2Array()
	var steps: int=maxi(3,int(d.length()/4.))
	for i: int in steps+1:
		var t:=float(i)/float(steps);var u:=1.-t
		out.append(a*u*u*u+c1*3.*u*u*t+c2*3.*u*t*t+b*t*t*t)
	return out

## Lanes leaving a square: 3–4 of them, each wandering outwards a step at a time, choosing at every step
## the heading (of three) that climbs least, so they wind along the slopes instead of running straight.
func _lanes(centre: Vector2,radius: float) -> Array:
	var lanes: Array=[]
	var count: int=3+_rng.randi()%2
	var start_angle:=_rng.randf()*TAU
	for l: int in count:
		var out_angle:=start_angle+TAU*float(l)/float(count)+_rng.randf_range(-.35,.35)
		var p:=centre+Vector2(cos(out_angle),sin(out_angle))*(PLAZA_R-.5)
		# Leave the square at a slant, not straight out like a spoke.
		var heading:=out_angle+_rng.randf_range(.55,.95)*(1. if _rng.randf()<.5 else -1.)
		var pts:=PackedVector2Array([p])
		var drift:=_rng.randf_range(-.1,.1)
		var pull:=-signf(angle_difference(out_angle,heading))*.09   # curls back outwards over the first steps
		for step: int in int(radius*1.25/4.5):
			var best_h:=heading;var best_cost:=1e9
			for dh: float in [-.32,0.,.32]:
				var h:=heading+dh+drift+(pull if step<6 else 0.)
				var q:=p+Vector2(cos(h),sin(h))*4.5
				var cost:=absf(Layout.ground(q)-Layout.ground(p))+absf(dh)*.6+_rng.randf()*.25
				if q.distance_to(centre)>radius*1.25 or Layout.coast(q).x>-6. or not _lane_clear(q):cost+=100.
				if cost<best_cost:best_cost=cost;best_h=h
			if best_cost>=100.:break
			heading=best_h;p+=Vector2(cos(heading),sin(heading))*4.5;pts.append(p)
		if pts.size()>=4:lanes.append(pts)
	return lanes

func _lane_clear(q: Vector2) -> bool:
	if absf(q.x)<95. and q.y>-30. and q.y<72.:return false
	for k: Vector3 in KEEP_CLEAR:
		if q.distance_to(Vector2(k.x,k.y))<k.z+3.:return false
	for f: Vector3 in footprints:
		if q.distance_to(Vector2(f.x,f.y))<f.z+2.:return false
	return true

## A ribbon following a polyline and the ground: mitred joints, so a winding lane reads as one paved way.
func _street_path(pts: PackedVector2Array,width: float,material: Material) -> void:
	if pts.size()<2:return
	for i: int in pts.size()-1:_streets.append([pts[i],pts[i+1],width])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dense:=PackedVector2Array()
	for i: int in pts.size()-1:
		var n: int=maxi(1,int(pts[i].distance_to(pts[i+1])/1.5))
		for k: int in n:dense.append(pts[i].lerp(pts[i+1],float(k)/float(n)))
	dense.append(pts[pts.size()-1])
	var any:=false
	var prev_l:=Vector3.ZERO;var prev_r:=Vector3.ZERO;var have:=false
	for i: int in dense.size():
		var a:=dense[maxi(i-1,0)];var b:=dense[mini(i+1,dense.size()-1)]
		var dir:=(b-a).normalized();var side:=Vector2(-dir.y,dir.x)*width*.5
		# Edges wobble a little, so the way looks laid by hand.
		var wob:=1.+.08*sin(float(i)*1.7)
		var l2:=dense[i]-side*wob;var r2:=dense[i]+side*wob
		var dry:=Layout.coast(dense[i]).x<-.5
		var l3:=Vector3(l2.x,Layout.ground(l2)+.07,l2.y);var r3:=Vector3(r2.x,Layout.ground(r2)+.07,r2.y)
		if have and dry:
			for v: Vector3 in [prev_l,r3,prev_r,prev_l,l3,r3,prev_l,prev_r,r3,prev_l,r3,l3]:st.set_normal(Vector3.UP);st.add_vertex(v)
			any=true
		prev_l=l3;prev_r=r3;have=dry
	if not any:return
	var node:=MeshInstance3D.new();node.name="Rua_%d"%get_child_count();node.mesh=st.commit();node.material_override=material;add_child(node)

## Fishermen's homesteads all over the island, away from the districts: a cottage or a shack on its own
## plot (some on the hillsides, some by the shore), a few with a frame going up beside them.
func _scatter_homesteads() -> void:
	var rec:={"name":"Sítios","centre":Vector2.ZERO,"houses":[],"doors":[],"isolated":true}
	var placed:=0;var tries:=0
	while placed<16 and tries<2500:
		tries+=1
		var at:=Vector2(_rng.randf_range(-460.,380.),_rng.randf_range(-60.,1100.))
		if Layout.coast(at).x>-10.:continue
		var near:=false
		for data: Array in DISTRICTS:
			if at.distance_to(data[1])<float(data[2])+18.:near=true;break
		if near:continue
		var style: String=["cabana","cabana","costeira","cabana","obra"][placed%5]
		rec.centre=at+Vector2(_rng.randf_range(-1.,1.),_rng.randf_range(-1.,1.)).normalized()*20.
		_yaw_jitter=_rng.randf_range(-.5,.5)
		if _place(style,at,_size_of(style),rec.centre,false,rec):placed+=1
	_yaw_jitter=0.
	homesteads=rec.houses


## Hides the island's grass tufts that would poke through streets, squares and floors.
func _clear_ground_cover() -> void:
	var region=village.world.get("region")
	if region==null or region.get("grass_mesh")==null:return
	for chunk: Node3D in region.chunks:
		for child: Node in chunk.get_children():
			if not child is MultiMeshInstance3D or (child as MultiMeshInstance3D).multimesh.mesh!=region.grass_mesh:continue
			var mm:=(child as MultiMeshInstance3D).multimesh
			for i: int in mm.instance_count:
				var t:=mm.get_instance_transform(i)
				var p:=chunk.position+t.origin
				if on_paving(Vector2(p.x,p.z)):mm.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),t.origin))

func on_paving(p: Vector2) -> bool:
	for sq: Array in _plazas:
		if p.distance_to(sq[0])<float(sq[1])+.8:return true
	for st: Array in _streets:
		if _segment_distance(p,st[0],st[1])<float(st[2])*.5+.6:return true
	for f: Vector3 in footprints:
		if p.distance_to(Vector2(f.x,f.y))<f.z*.85:return true
	return false

## Placed buildings as rectangles: [centre, half size, yaw].
var _rects: Array=[]
## Trees planted round the squares: houses, doors and their streets keep clear of them.
var _plaza_trees: Array[Vector2]=[]
## Whether a street (a→b) passes within `margin` of a building's rectangle.
static func _rect_meets_segment(c: Vector2,half: Vector2,yaw: float,a: Vector2,b: Vector2,margin: float) -> bool:
	var n: int=maxi(2,int(a.distance_to(b)/.5))
	var cs: float=cos(yaw);var sn: float=sin(yaw)
	for i: int in n+1:
		var p: Vector2=a.lerp(b,float(i)/float(n))-c
		# Into the building's frame (rotation by -yaw about Y, x/z → x/y here).
		var lx: float=p.x*cs-p.y*sn;var lz: float=p.x*sn+p.y*cs
		if absf(lx)<half.x+margin and absf(lz)<half.y+margin:return true
	return false

static func _segment_distance(p: Vector2,a: Vector2,b: Vector2) -> float:
	var ab:=b-a;var t:=clampf((p-a).dot(ab)/maxf(ab.length_squared(),.001),0.,1.)
	return p.distance_to(a+ab*t)

## Cobbled ribbon that follows the ground (skips water, where bridges and boardwalks take over).
func _street_line(a: Vector2,b: Vector2,width: float) -> void:
	var length:=a.distance_to(b)
	if length<.5:return
	_streets.append([a,b,width])
	var dir:=(b-a)/length;var side:=Vector2(-dir.y,dir.x)*width*.5
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps:=maxi(1,int(length/1.5))
	var any:=false
	for i: int in steps:
		var p0:=a+dir*length*float(i)/float(steps);var p1:=a+dir*length*float(i+1)/float(steps)
		if Layout.coast(p0).x>-.5 or Layout.coast(p1).x>-.5:continue
		var q:=[p0-side,p0+side,p1+side,p1-side]
		var v: Array[Vector3]=[]
		for pt: Vector2 in q:v.append(Vector3(pt.x,Layout.ground(pt)+.07,pt.y))
		for idx: int in [0,2,1,0,3,2]:st.set_normal(Vector3.UP);st.add_vertex(v[idx])
		any=true
	if not any:return
	st.generate_normals()
	var node:=MeshInstance3D.new();node.name="Rua_%d"%get_child_count();node.mesh=st.commit();node.material_override=_street;add_child(node)

func _plaza(centre: Vector2,y: float) -> void:
	_plazas.append([centre,PLAZA_R])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs:=36
	for i: int in segs:
		var a0:=TAU*float(i)/segs;var a1:=TAU*float(i+1)/segs
		var p0:=centre+Vector2(cos(a0),sin(a0))*PLAZA_R;var p1:=centre+Vector2(cos(a1),sin(a1))*PLAZA_R
		var c:=Vector3(centre.x,y,centre.y)
		var v0:=Vector3(p0.x,maxf(y,Layout.ground(p0)+.08),p0.y);var v1:=Vector3(p1.x,maxf(y,Layout.ground(p1)+.08),p1.y)
		# Both windings: the square must show from above whatever the triangle order.
		for v: Vector3 in [c,v1,v0,c,v0,v1]:st.set_normal(Vector3.UP);st.add_vertex(v)
	var node:=MeshInstance3D.new();node.name="Praca_%d"%get_child_count();node.mesh=st.commit();node.material_override=_street;add_child(node)
	var at:=Vector3(centre.x,y,centre.y)
	G.cylinder(self,at+Vector3(0,.35,0),2.8,.7,_curb,2.8,28)
	var water:=House.flat(Color("2f7f9a"),.06,.1);water.emission_enabled=true;water.emission=Color("0d3a46");water.emission_energy_multiplier=.5
	G.cylinder(self,at+Vector3(0,.62,0),2.5,.08,water,2.5,28)
	G.cylinder(self,at+Vector3(0,1.4,0),.4,1.7,_curb,.3,14)
	G.cylinder(self,at+Vector3(0,2.3,0),1.2,.22,_curb,.85,18)
	G.cylinder(self,at+Vector3(0,2.6,0),.18,.5,_curb,.12,10)
	var stone_body:=StaticBody3D.new();stone_body.collision_layer=1;stone_body.collision_mask=0
	var stone_shape:=CollisionShape3D.new();var cyl:=CylinderShape3D.new();cyl.radius=2.8;cyl.height=1.4;stone_shape.shape=cyl;stone_shape.position=at+Vector3(0,.7,0)
	stone_body.add_child(stone_shape);add_child(stone_body)
	var wood:=M.surface("teak",Color("8a6a4a"),1.2)
	for i: int in 4:
		var a:=float(i)*PI*.5+PI*.25
		var p:=at+Vector3(cos(a),0,sin(a))*(PLAZA_R-2.2)
		var bench:=G.box(self,p+Vector3(0,.45,0),Vector3(1.9,.1,.5),wood);bench.rotation.y=-a+PI*.5
		var back:=G.box(self,p+Vector3(0,.8,0)+Vector3(cos(a),0,sin(a))*.25,Vector3(1.9,.45,.07),wood);back.rotation.y=-a+PI*.5
		for leg: float in [-.8,.8]:
			var off:=Vector3(-sin(a),0,cos(a))*leg
			G.box(self,p+off+Vector3(0,.22,0),Vector3(.08,.44,.45),House.flat(Color("2b2f33"),.4,.6)).rotation.y=-a+PI*.5
		var lamp_a:=a+PI*.25
		var lamp_at:=at+Vector3(cos(lamp_a),0,sin(lamp_a))*(PLAZA_R-.8)
		village._lamp(lamp_at,wood);lamps+=1
	for i: int in 3:
		var a:=float(i)*TAU/3.+.4
		var p:=centre+Vector2(cos(a),sin(a))*(PLAZA_R+3.)
		var tree_at:=Vector3(p.x,Layout.ground(p),p.y)
		_plaza_trees.append(p)
		# The island's own broadleaf trees (tools/blender/naturalist.py), kept a size smaller in the square.
		preload("res://scripts/world/nature_library.gd").plant(self,i%2,tree_at,_rng.randf_range(.55,.7),_rng.randf()*TAU)

## A house on sloping ground stands on its plinth with the floor level; where the ground in front of the
## door is lower than a step, stone steps lead down to it (each block reaches the ground, so none hangs
## in the air), with a low cheek wall either side when the flight is tall.
const STEP_RISE: float=.19
const STEP_RUN: float=.34
func _entrance_steps(building: Node3D,size: Vector2,floor_y: float) -> void:
	var stone:=M.surface("granite",Color("a9aa9c"),1.)
	var front: float=float(building.get_meta("front",-size.y*.5))
	var out: Vector3=building.global_transform*Vector3(0.,0.,front-.6)
	var drop: float=floor_y-Layout.ground(Vector2(out.x,out.z))
	if drop<.24:return
	var count: int=clampi(int(ceil(drop/STEP_RISE)),1,18)
	var rise: float=drop/float(count)
	var width: float=minf(1.8,size.x*.4)
	for i: int in count:
		# The first block is a landing level with the floor; each one after is a rise lower.
		var top: float=-float(i)*rise
		var z: float=front-.18-float(i)*STEP_RUN
		var p: Vector3=building.global_transform*Vector3(0.,0.,z)
		var g: float=Layout.ground(Vector2(p.x,p.z))
		var height: float=maxf(.12,floor_y+top-g+.25)
		G.box(building,Vector3(0.,top-height*.5,z),Vector3(width,height,STEP_RUN+.02),stone,true).name="Degrau_%d"%i
	# A tall flight gets a low cheek wall on each side that steps down with the treads.
	if drop>.9:
		for i: int in count:
			var top: float=-float(i)*rise
			var z: float=front-.18-float(i)*STEP_RUN
			var p: Vector3=building.global_transform*Vector3(0.,0.,z)
			var g: float=Layout.ground(Vector2(p.x,p.z))
			var height: float=maxf(.4,floor_y+top-g+.6)
			for side: float in [-1.,1.]:
				G.box(building,Vector3(side*(width*.5+.14),top+.35-height*.5,z),Vector3(.28,height,STEP_RUN+.02),stone,true).name="Mureta"
	building.set_meta("steps",count)

## Stilt houses get a boardwalk from their porch to dry land.
func _boardwalks(record: Dictionary) -> void:
	var wood:=M.surface("weathered_wood",Color("a08a68"),1.5)
	var post:=M.surface("weathered_wood",Color("5a4a3a"),1.5)
	for door: Vector2 in record.doors:
		var dir:=(Vector2(record.centre)-door).normalized()
		var end:=door
		for i: int in 40:
			end=door+dir*float(i)
			if Layout.coast(end).x<-1.5:break
		var length:=door.distance_to(end)
		record["landings"]=(record.get("landings",{}) as Dictionary)
		record.landings[door]=end
		if length<1.:continue
		var mid:=(door+end)*.5
		var deck:=G.box(self,Vector3(mid.x,1.78,mid.y),Vector3(1.6,.14,length+1.),wood,true)
		deck.rotation.y=atan2(dir.x,dir.y)
		for i: int in int(length/2.5)+1:
			var p:=door+dir*float(i)*2.5
			for s: float in [-.7,.7]:
				var q:=p+Vector2(-dir.y,dir.x)*s
				var bottom:=Layout.ground(q)
				G.cylinder(self,Vector3(q.x,(1.75+bottom)*.5,q.y),.08,1.75-bottom+.3,post)

func _people(record: Dictionary,plaza_y: float) -> void:
	var doors: Array=record.doors
	if doors.size()<2:return
	var centre: Vector2=record.centre
	var social=village.get_node_or_null("VidaSocial")
	for i: int in mini(3,doors.size()-1):
		var person:=Resident.new();person.speed=_rng.randf_range(.8,1.15);person.look_id=20+residents.size()*3
		var a: Vector2=doors[(i*2)%doors.size()];var b: Vector2=doors[(i*2+1)%doors.size()]
		var plaza_a:=centre+(a-centre).normalized()*PLAZA_R*.7;var plaza_b:=centre+(b-centre).normalized()*PLAZA_R*.7
		# Over the water there is no square: people go along their boardwalk to the shore and back.
		var landings: Dictionary=record.get("landings",{})
		if landings.has(a) and landings.has(b):plaza_a=landings[a];plaza_b=landings[b]
		var route: Array[Vector3]=[]
		for p: Vector2 in [a,plaza_a,plaza_b,b,plaza_b,plaza_a]:route.append(Vector3(p.x,Layout.ground(p),p.y))
		person.route.assign(route)
		add_child(person);residents.append(person)
		if social!=null:social.residents.append(person)

## Timber frame of a house under construction: posts, plates, joists, half the rafters, a ladder,
## a scaffold board, a plank stack and a sawhorse beside it.
func _frame(root: Node3D,size: Vector2) -> void:
	var fresh:=M.surface("teak",Color("d2b07c"),1.2)
	var old:=M.surface("weathered_wood",Color("8c7356"),1.5)
	var hx:=size.x*.5;var hz:=size.y*.5;var h:=3.
	G.box(root,Vector3(0,.07,0),Vector3(size.x,.1,size.y),old)
	for x: float in [-hx,-hx*.33,hx*.33,hx]:
		for z: float in [-hz,hz]:G.box(root,Vector3(x,h*.5,z),Vector3(.18,h,.18),fresh,true)
	for x: float in [-hx,hx]:G.box(root,Vector3(x,h*.5,0),Vector3(.18,h,.18),fresh,true)
	for z: float in [-hz,hz]:G.box(root,Vector3(0,h,z),Vector3(size.x+.2,.2,.2),fresh)
	for x: float in [-hx,hx]:G.box(root,Vector3(x,h,0),Vector3(.2,.2,size.y+.2),fresh)
	for i: int in 7:G.box(root,Vector3(-hx+float(i)*size.x/6.,h+.05,0),Vector3(.12,.16,size.y),old)
	# Diagonal braces and the first rafter pairs.
	for z: float in [-hz,hz]:G.beam(root,Vector3(-hx,.3,z),Vector3(-hx*.33,h-.2,z),.06,fresh)
	for i: int in 3:
		var x:=-hx+float(i)*1.4
		G.beam(root,Vector3(x,h,-hz-.3),Vector3(x,h+1.7,0),.07,fresh);G.beam(root,Vector3(x,h+1.7,0),Vector3(x,h,hz+.3),.07,fresh)
	G.box(root,Vector3(-hx+1.4,h+1.7,0),Vector3(2.9,.14,.14),fresh)
	# Half-boarded back wall.
	for i: int in 6:G.box(root,Vector3(0,.35+float(i)*.22,hz+.03),Vector3(size.x,.2,.04),fresh)
	# Ladder and a scaffold board on trestles along the front.
	var ladder:=Node3D.new();ladder.position=Vector3(hx-.8,0,-hz-.7);ladder.rotation.x=-.25;root.add_child(ladder)
	for x: float in [-.25,.25]:G.box(ladder,Vector3(x,1.6,0),Vector3(.06,3.2,.06),old)
	for i: int in 8:G.box(ladder,Vector3(0,.3+float(i)*.38,0),Vector3(.5,.04,.05),old)
	for x: float in [-hx+.6,-.6]:
		for z: float in [-hz-.5,-hz-1.2]:G.box(root,Vector3(x,.9,z),Vector3(.08,1.8,.08),old)
	G.box(root,Vector3(-hx*.5-.3,1.8,-hz-.85),Vector3(hx+.6,.07,.8),fresh,true)
	# Plank stack and sawhorse on the side.
	for i: int in 5:G.box(root,Vector3(hx+1.8,.12+float(i)*.06,-.5+float(i%2)*.06),Vector3(.24,.05,3.4),fresh)
	for z: float in [-.4,.4]:
		G.beam(root,Vector3(hx+3.4,0,z-.25),Vector3(hx+3.4,.8,z),.04,old);G.beam(root,Vector3(hx+3.4,0,z+.25),Vector3(hx+3.4,.8,z),.04,old)
	G.box(root,Vector3(hx+3.4,.82,0),Vector3(.1,.08,1.2),old)
	G.label(root,"OBRA · CASA NOVA",Vector3(0,h+.8,-hz-.15),22)

## Two carpenters carry planks from the stack to the frame; one works up on the scaffold board.
func _site_crew(site: Node3D,size: Vector2) -> void:
	var hx:=size.x*.5;var hz:=size.y*.5
	for i: int in 2:
		var p:=Porter.new();p.look_id=60+sites.size()*4+i;p.speed=.8+float(i)*.12;p.follow_terrain=true
		var stack:=site.position+site.basis*Vector3(hx+1.3,0,-.3+float(i)*.6)
		var frame:=site.position+site.basis*Vector3(-hx*.2+float(i)*1.5,0,-hz-1.6)
		var route: Array[Vector3]=[Vector3(stack.x,0,stack.z),Vector3(frame.x,0,frame.z)]
		p.route.assign(route);p.cargo=Porter.plank_load();p.add_child(p.cargo);p.loaded_legs.assign([1])
		add_child(p);workers.append(p)
	var up:=Resident.new();up.look_id=63+sites.size()*4;up.follow_terrain=false;up.hide_backpack=true;up.work_pose="ual/Hammer"
	var board:=site.position+site.basis*Vector3(-hx*.5,1.85,-hz-.85)
	up.route.assign([board]);up.rotation.y=site.rotation.y+PI;add_child(up);workers.append(up)
	up.visual.hold_prop(Tools.hammer(),Tools.GRIP)

## Stone arch bridge with parapets and lamps, walkable (collision on every deck segment).
func _bridge(a: Vector3,b: Vector3,rise: float) -> void:
	var stone:=M.surface("granite",Color("b7b3a4"),1.)
	var cap:=House.flat(Color("d8d3c4"),.8)
	var length:=Vector2(a.x-b.x,a.z-b.z).length()
	var steps:=int(length/1.5)
	var dir:=(Vector3(b.x,0,b.z)-Vector3(a.x,0,a.z)).normalized()
	var side:=dir.cross(Vector3.UP)
	var yaw:=atan2(dir.x,dir.z)
	for i: int in steps:
		var t0:=float(i)/steps;var t1:=float(i+1)/steps
		var p0:=a.lerp(b,t0)+Vector3.UP*rise*sin(PI*t0);var p1:=a.lerp(b,t1)+Vector3.UP*rise*sin(PI*t1)
		var mid:=(p0+p1)*.5;var seg:=p0.distance_to(p1)
		var deck:=G.box(self,mid-Vector3(0,.2,0),Vector3(3.6,.4,seg+.05),stone,true)
		deck.rotation=Vector3(-atan2(p1.y-p0.y,Vector2(p1.x-p0.x,p1.z-p0.z).length()),yaw,0)
		for s: float in [-1.,1.]:
			var wall:=G.box(self,mid+side*s*1.7+Vector3(0,.45,0),Vector3(.3,.9,seg+.05),stone,true)
			wall.rotation=deck.rotation
			var top:=G.box(self,mid+side*s*1.7+Vector3(0,.95,0),Vector3(.42,.1,seg+.06),cap);top.rotation=deck.rotation
	# Two stone piers carry the arch.
	for end: Vector3 in [a.lerp(b,.12),a.lerp(b,.88)]:
		G.box(self,end+Vector3(0,-1.6,0),Vector3(3.8,3.6,2.),stone)
	var wood:=M.surface("teak",Color("8a6a4a"),1.2)
	for end: Vector3 in [a,b]:
		for s: float in [-1.,1.]:village._lamp(end+side*s*1.9+dir*(1.5 if end==a else -1.5),wood);lamps+=1
	G.label(self,"Ponte do Poente",a.lerp(b,.5)+Vector3.UP*(rise+2.4),24)

func _process(delta: float) -> void:
	_clock-=delta
	if _clock>0.:return
	_clock=2.
	var ocean=village.world.get("ocean")
	if ocean!=null and House.windows!=null:House.windows.emission_energy_multiplier=(1.-float(ocean.daylight))*1.8
