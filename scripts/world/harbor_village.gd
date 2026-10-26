extends Node3D
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Building=preload("res://scripts/world/village_building.gd")
var world: Node3D
var buildings: Array[Node3D]=[]
var residents: Array[Node3D]=[]
var services: Dictionary={}
var landmarks: Array[Dictionary]=[]
var night_lights: Array[OmniLight3D]=[]
var moored: Array[Node3D]=[]
var elapsed: float=0.
var discovered: Dictionary={}
var bridge_district: Node3D
var lighting_fixtures: Node3D
var town: Node3D
var shipyard: Node3D

func _ready() -> void:
	lighting_fixtures=Node3D.new();add_child(lighting_fixtures)
	var wood:=M.surface("weathered_wood",Color("b3a181"),1.5)
	var stone:=M.surface("granite",Color("a5a89a"),1.)
	world._make_market()
	_build("Sua cabana",Vector2(-14,7),8.,7.,"cabin",Color("577e79"),"cabin")
	_build("Casa das Marés",Vector2(16,20),9.,7.,"shop",Color("bfc0a0"),"gear")
	_build("Oficina Aurora",Vector2(-18,27),11.,8.,"workshop",Color("5d7b83"),"workshop")
	_build("Armazém do Porto",Vector2(-36,4),11.,9.,"warehouse",Color("a99579"),"storage")
	_build("Mercado da Vila",Vector2(35,5),9.,7.,"market",Color("b6bba3"),"market")
	_build("Pousada do Farol",Vector2(25,43),10.,8.,"inn",Color("c4b398"),"inn")
	for data: Vector4 in [Vector4(-17,49,7,6),Vector4(14,52,8,7),Vector4(-42,23,7,6),Vector4(49,22,8,7),Vector4(52,46,9,7),Vector4(71,44,7,6),Vector4(-65,43,8,7),Vector4(-64,13,7,6)]:
		_build("Casa de pescador",Vector2(data.x,data.y),data.z,data.w,"home",Color("71928b").lerp(Color("c2aa88"),fposmod(data.x*.13,1.)),"")
	# Seafront boardwalk and two working fingers leave the player's berth clear.
	for x: int in range(-15,16):
		G.box(self,Vector3(x*2.,1.29,-7.1),Vector3(1.96,.14,3.),wood,true)
	for x: float in [-29.,29.]:
		G.box(self,Vector3(x,1.2,-18),Vector3(3.4,.3,21.),wood,true)
		for z: int in range(-28,-6,4):
			for side: float in [-1.,1.]:G.cylinder(self,Vector3(x+side*1.5,.2,z),.15,3.4,wood)
	_make_streets(M.surface("cobblestone",Color("c7c1ad"),.35))
	# Street furniture follows the frontage and routes; the walking lanes stay clear.
	for p: Vector2 in [Vector2(-5,-6),Vector2(5,12),Vector2(-5,34),Vector2(5,56),Vector2(-32,10),Vector2(35,33),Vector2(63,33),Vector2(-62,33)]:
		_lamp(Vector3(p.x,1.3,p.y),wood)
	for p: Vector2 in [Vector2(-31,3),Vector2(39,2),Vector2(-23,27),Vector2(20,20)]:
		for i: int in 3:G.box(self,Vector3(p.x+float(i)*.8,1.65,p.y),Vector3(.7,.7,.7),wood,true)
	for x: float in [-24.,23.]:
		G.beam(self,Vector3(x,3.,-3),Vector3(x+5.,3.,-3),.04,wood)
		for i: int in 12:G.beam(self,Vector3(x+i*.4,3.,-3),Vector3(x+i*.4,1.6,-3.2),.008,wood)
	for i: int in 3:
		var resident:=preload("res://scripts/world/village_resident.gd").new()
		var x:=float(i)*1.1-.9
		resident.route.assign([Vector3(x,1.3,13.+i*12.),Vector3(x,1.3,35),Vector3(x+1,1.3,57),Vector3(x+1,1.3,13)])
		resident.speed=.8+float(i)*.12;resident.look_id=1+i;add_child(resident);residents.append(resident)
	for i: int in 3:
		var resident:=preload("res://scripts/world/village_resident.gd").new();resident.speed=1.+float(i)*.15;resident.look_id=4+i
		resident.follow_terrain=false
		resident.route.assign([Vector3(-24.+i*17,1.4,-7),Vector3(25,1.4,-7),Vector3(29,1.4,-23),Vector3(29,1.4,-7),Vector3(-25,1.4,-7)])
		add_child(resident);residents.append(resident)
	var social:=preload("res://scripts/world/village_social.gd").new();social.name="VidaSocial";social.residents=residents;add_child(social)
	_make_landmarks(stone,wood)
	for p: Vector2 in [Vector2(-8,35),Vector2(8,18),Vector2(-35,15),Vector2(57,32),Vector2(-55,55)]:world._make_tree(Vector3(p.x,Layout.height(p),p.y),1.5)
	var excluded: Array[Node3D]=[];excluded.append_array(residents)
	preload("res://scripts/world/static_batch.gd").build(self,excluded)
	_add_external_scenery()
	bridge_district=preload("res://scripts/world/harbor_bridges.gd").new();bridge_district.name="PontesDoMercado";bridge_district.village=self;add_child(bridge_district)
	shipyard=preload("res://scripts/world/shipyard.gd").new();shipyard.name="Estaleiro";shipyard.village=self;add_child(shipyard)
	services["shipyard"]=shipyard.counter
	# The town grows across the main island: districts, squares, streets, stilt houses and a stone bridge.
	town=preload("res://scripts/world/town_planner.gd").new();town.name="Cidade";town.village=self;add_child(town)
	for p: Vector2 in [Vector2(-18,-1),Vector2(17,7),Vector2(-20,20),Vector2(21,36),Vector2(0,24),Vector2(0,47),Vector2(-73,-4),Vector2(-88,-4),Vector2(-105,-4)]:_lamp(Vector3(p.x,1.3,p.y),wood)

	preload("res://scripts/world/static_batch.gd").build(lighting_fixtures,[])

func _build(title: String,p: Vector2,w: float,d: float,kind: String,color: Color,id: String) -> void:
	var building:=Building.new();building.title=title;building.width=w;building.depth=d;building.use=kind;building.tint=color
	building.position=Vector3(p.x,Layout.height(p),p.y);add_child(building);buildings.append(building)
	night_lights.append_array(building.lamps)
	if not id.is_empty(): services[id]=building.service

func _road(a: Vector3,b: Vector3,width: float,mat: Material) -> void:
	if a.distance_to(b)<.1: return
	var mesh:=G.box(self,(a+b)*.5,Vector3(width,.025,a.distance_to(b)),mat)
	mesh.rotation.y=atan2(b.x-a.x,b.z-a.z)

func _lamp(p: Vector3,mat: Material) -> void:
	G.cylinder(lighting_fixtures,p+Vector3(0,1.7,0),.07,3.4,mat)
	var glow:=G.material(Color("ffe0a0"));glow.emission_enabled=true;glow.emission=Color("ffc581")
	G.sphere(lighting_fixtures,p+Vector3(0,3.35,0),Vector3(.19,.28,.19),glow,12)
	var bronze:=G.material(Color("554737"),.3);bronze.metallic=.55
	G.cylinder(lighting_fixtures,p+Vector3(0,3.05,0),.23,.1,bronze,.23,12)
	G.cylinder(lighting_fixtures,p+Vector3(0,3.68,0),.28,.2,bronze,.08,12)
	for i: int in 4:
		var a:=float(i)*PI*.5+PI*.25
		G.beam(lighting_fixtures,p+Vector3(cos(a)*.19,3.08,sin(a)*.19),p+Vector3(cos(a)*.19,3.6,sin(a)*.19),.018,bronze)
	var light:=OmniLight3D.new();light.position=p+Vector3(0,3.3,0);light.light_color=Color("ffdcad");light.omni_range=15.;light.light_energy=2.4;light.omni_attenuation=.75;add_child(light);night_lights.append(light)

func _make_landmarks(stone: Material,wood: Material) -> void:
	for item: Dictionary in [{"id":"lighthouse","title":"Farol da Aurora","p":Vector2(-65,490),"reward":18},{"id":"lookout","title":"Mirante das Marés","p":Vector2(90,345),"reward":12},{"id":"grotto","title":"Gruta do Contrabandista","p":Vector2(-170,210),"reward":24},{"id":"ruins","title":"Ruínas da Vigia","p":Vector2(-110,310),"reward":20},{"id":"beach","title":"Praia dos Navegantes","p":Vector2(190,105),"reward":10},{"id":"summit","title":"Cume das Andorinhas","p":Vector2(50,775),"reward":35},{"id":"north_wood","title":"Bosque do Norte","p":Vector2(-170,650),"reward":20}]:
		var p: Vector2=item.p;var at:=Vector3(p.x,Layout.height(p),p.y)
		item["position"]=at;landmarks.append(item)
		G.label(self,item.title,at+Vector3(0,3.,0),21)
		var chest_at:=at+Vector3(4,0,-4)
		for offset: Vector2 in [Vector2(4,-4),Vector2(-4,-4),Vector2(4,4),Vector2(-4,4)]:
			var candidate:=p+offset
			if Layout.path_at(candidate).x>3.:
				chest_at=Vector3(candidate.x,Layout.height(candidate),candidate.y);break
		G.box(self,chest_at+Vector3.UP*.42,Vector3(1.2,.8,.7),wood,true)
		G.box(self,chest_at+Vector3.UP*.87,Vector3(1.23,.13,.74),wood)
		if item.id=="grotto":
			# Rock-built coastal grotto: an actual traversable arch, not a sealed facade.
			for side: float in [-1.,1.]:
				for z: float in [-3.,0.,3.]:world._make_rock(at+Vector3(side*4,2.,z),Vector3(2.3,3.,2.8))
			world._make_rock(at+Vector3(0,5.3,0),Vector3(5.3,1.8,5.))
		elif item.id=="ruins":
			for x: float in [-4.,4.]:
				for z: float in [-3.,3.]:G.cylinder(self,at+Vector3(x,2,z),.6,4.,stone,.5,12)
			G.box(self,at+Vector3(0,4.1,3),Vector3(9,1.,1.3),stone)
		else:
			for side: float in [-1.,1.]:G.beam(self,at+Vector3(side*5.,1.,-4.),at+Vector3(side*5.,1.,4.),.08,wood)
	# Direction signs mark junctions along both loops.
	for p: Vector3 in Layout.TRAIL:
		G.cylinder(self,p+Vector3(3,1.,0),.08,2.,wood)
		G.box(self,p+Vector3(3,2.,0),Vector3(1.4,.35,.12),wood)

func _add_external_scenery() -> void:
	for data: Dictionary in [{"path":"res://assets/boats/tugboat.glb","at":Vector3(-34,0,-22),"length":11.,"family":"boat"}]:
		if not ResourceLoader.exists(data.path): continue
		var wrapper:=preload("res://scripts/assets/external_model.gd").new();wrapper.asset_path=data.path;wrapper.length_m=data.length;wrapper.material_family=data.family;wrapper.waterline_m=.75 if data.family=="boat" else 0.;wrapper.position=data.at
		add_child(wrapper)
		if data.family=="boat":
			moored.append(wrapper)
			var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
			var collider:=CollisionShape3D.new();var hull:=BoxShape3D.new();hull.size=Vector3(3.2,2.,10.)
			collider.shape=hull;collider.position.y=.5;body.add_child(collider);add_child(body);body.position=data.at

func nearby_service(at: Vector3) -> String:
	for key: String in services:
		if at.distance_to(services[key].global_position)<2.7: return key
	return ""

func indoors(at: Vector3) -> bool:
	for b: Node3D in buildings:
		var p:=b.to_local(at)
		if absf(p.x)<b.width*.5 and absf(p.z)<b.depth*.5 and p.y>0. and p.y<3.4:return true
	return false

func nearby_discovery(at: Vector3) -> Dictionary:
	for item: Dictionary in landmarks:
		if not discovered.has(item.id) and at.distance_to(item.position)<5.: return item
	return {}

func _process(delta: float) -> void:
	elapsed+=delta
	var camera:=get_viewport().get_camera_3d()
	for light: OmniLight3D in night_lights:
		light.visible=camera!=null and camera.global_position.distance_squared_to(light.global_position)<14400. and (light.has_meta("interior") or world.ocean==null or world.ocean.daylight<.45)
	for b: Node3D in buildings:
		b.windows.emission_energy_multiplier=0. if world.ocean==null else (1.-world.ocean.daylight)*1.5
	for ship: Node3D in moored:
		ship.position.y=preload("res://scripts/world/wave_field.gd").height_at(ship.global_position)

func _make_streets(material: Material) -> void:
	var grid:=AStarGrid2D.new();grid.region=Rect2i(-45,-5,90,42);grid.cell_size=Vector2(2,2);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for b: Node3D in buildings:
		for x: int in range(floori((b.position.x-b.width*.5-.6)/2.),ceili((b.position.x+b.width*.5+.6)/2.)):
			for z: int in range(floori((b.position.z-b.depth*.5-.6)/2.),ceili((b.position.z+b.depth*.5+.6)/2.)):
				if grid.is_in_boundsv(Vector2i(x,z)):grid.set_point_solid(Vector2i(x,z))
	_road(Vector3(0,1.31,-7),Vector3(0,1.31,62),3.4,material)
	for b: Node3D in buildings:
		var e: Vector3=b.entry.global_position+Vector3(0,0,-1.)
		var start:=Vector2i(roundi(e.x/2.),roundi(e.z/2.));grid.set_point_solid(start,false)
		var end:=Vector2i(0,start.y)
		var path:=grid.get_point_path(start,end)
		for i: int in path.size()-1:
			_road(Vector3(path[i].x,1.31,path[i].y),Vector3(path[i+1].x,1.31,path[i+1].y),1.9,material)
		_road(Vector3(e.x,1.31,e.z),Vector3(b.entry.global_position.x,1.31,b.entry.global_position.z),1.9,material)
