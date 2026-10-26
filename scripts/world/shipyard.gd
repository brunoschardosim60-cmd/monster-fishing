extends Node3D
## The boatyard on the south-east shore: an open shed with the shop counter, a slipway with a
## fishing boat being built (shipwrights carry planks to it), a timber stack, and a pier with a marked
## berth. Bring the boat slowly into the berth and the yard's shop opens: hull, engine and light
## upgrades, repairs, and new boats for sale.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
const House=preload("res://scripts/world/town_house.gd")
const Props=preload("res://scripts/world/cc0_props.gd")
const Models=preload("res://scripts/boats/vessel_models.gd")
const Resident=preload("res://scripts/world/village_resident.gd")
const Porter=preload("res://scripts/world/village_porter.gd")
## Shore point and the direction out to sea (from the coast normal there).
const SITE: Vector2=Vector2(130,-2)
const BERTH_RADIUS: float=7.
var village: Node3D
var counter: Marker3D
var berth: Vector3
var footprint: Vector3
var workers: Array[Node3D]=[]
var _out: Vector2
var _side: Vector2

func _ready() -> void:
	var c:=Layout.coast(SITE)
	_out=Vector2(c.y,c.z).normalized();_side=Vector2(-_out.y,_out.x)
	var wood:=M.surface("weathered_wood",Color("9c8466"),1.5)
	var dark:=M.surface("weathered_wood",Color("5a4632"),1.5)
	var stone:=M.surface("granite",Color("a9aa9c"),1.)
	var yaw:=atan2(-_out.x,-_out.y)
	# Open shed facing the sea, set back from the shore.
	var shed_at:=SITE-_out*11.
	var floor_y:=Layout.height(shed_at)+.2
	# Shed, slipway and timber stack: the town keeps this whole stretch of shore clear.
	footprint=Vector3(SITE.x,SITE.y,30.)
	var shed:=Node3D.new();shed.name="Galpao";shed.position=Vector3(shed_at.x,floor_y,shed_at.y);shed.rotation.y=yaw;add_child(shed)
	G.box(shed,Vector3(0,-.4,0),Vector3(16.5,1.,13.),stone,true)
	G.box(shed,Vector3(0,3.,6.2),Vector3(16.,6.,.3),wood,true)
	for x: float in [-8.,8.]:G.box(shed,Vector3(x,3.,1.),Vector3(.3,6.,10.5),wood,true)
	for x: float in [-7.8,-2.6,2.6,7.8]:G.cylinder(shed,Vector3(x,3.,-5.9),.18,6.,dark)
	House._gable(shed,16.,12.6,6.,.42,Color("6b7178"),wood)
	G.label(shed,"ESTALEIRO DA AURORA",Vector3(0,7.6,-6.4),40)
	# Counter, tools and the shop marker.
	G.box(shed,Vector3(-5.,.55,2.),Vector3(3.6,1.1,1.),dark,true)
	G.box(shed,Vector3(-5.,1.12,2.),Vector3(3.8,.06,1.15),wood)
	for i: int in 5:G.beam(shed,Vector3(-6.6+float(i)*.7,1.6,5.95),Vector3(-6.4+float(i)*.7,3.2,5.95),.05,dark)
	counter=Marker3D.new();counter.name="Balcao";counter.position=Vector3(-5.,.1,.6);shed.add_child(counter)
	for i: int in 3:Props.spawn(shed,"Barrel",Vector3(6.,0.,4.2-float(i)*1.3),1.1,float(i))
	# Slipway with a hull under construction and scaffolding.
	var slip_start:=SITE-_out*2.+_side*14.
	var slip_end:=SITE+_out*9.+_side*14.
	var slip_mid:=(slip_start+slip_end)*.5
	var slip:=G.box(self,Vector3(slip_mid.x,(Layout.height(slip_start)+Layout.height(slip_end))*.5-.2,slip_mid.y),Vector3(6.,.4,slip_start.distance_to(slip_end)+2.),stone)
	slip.rotation=Vector3(atan2(Layout.height(slip_start)-Layout.height(slip_end),slip_start.distance_to(slip_end)),yaw,0)
	var hull_at:=slip_start+_out*1.
	var hull:=Models.build("pesqueiro",14.,77);hull.position=Vector3(hull_at.x,Layout.height(hull_at)+1.4,hull_at.y);hull.rotation.y=yaw+PI
	add_child(hull)
	for z: float in [-5.,0.,5.]:
		for s: float in [-1.,1.]:
			var post:=hull_at+_side*s*3.2+_out*z*.6
			G.cylinder(self,Vector3(post.x,Layout.height(post)+2.5,post.y),.08,5.,dark)
	var hull_body:=StaticBody3D.new();hull_body.collision_layer=1;hull_body.collision_mask=0
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5.,4.,14.);shape.shape=box;shape.position=Vector3(0,2.,0);hull_body.add_child(shape);hull.add_child(hull_body)
	# Timber stack and logs.
	var pile_at:=SITE-_out*6.+_side*22.
	for i: int in 4:Props.spawn(self,"Log_01_Art",Vector3(pile_at.x,Layout.height(pile_at)+float(i)*.45,pile_at.y)+Vector3(_side.x,0,_side.y)*float(i%2)*.4,1.1,yaw+PI*.5)
	# Pier out to the berth, with bollards and berth buoys.
	var pier_from:=SITE-_out*1.
	var pier_to:=SITE+_out*36.
	var pier_mid:=(pier_from+pier_to)*.5
	var deck:=G.box(self,Vector3(pier_mid.x,1.45,pier_mid.y),Vector3(3.,.25,pier_from.distance_to(pier_to)),wood,true);deck.rotation.y=yaw
	for i: int in 13:
		var p:=pier_from.lerp(pier_to,float(i)/12.)
		for s: float in [-1.4,1.4]:
			var q:=p+_side*s;var bottom:=Layout.height(q)
			G.cylinder(self,Vector3(q.x,(1.35+bottom)*.5,q.y),.14,1.35-bottom+.3,dark)
	for i: int in 4:
		var p:=pier_to-_out*(float(i)*7.)+_side*1.6
		G.cylinder(self,Vector3(p.x,1.75,p.y),.16,.5,House.flat(Color("2b2f33"),.4,.5))
	var b:=pier_to-_out*10.+_side*(BERTH_RADIUS*.75)
	berth=Vector3(b.x,0.,b.y)
	var yellow:=House.flat(Color("f2c84b"),.5)
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var q:=b+_side*corner.x*3.+_out*corner.y*6.
		G.sphere(self,Vector3(q.x,.15,q.y),Vector3(.5,.5,.5),yellow,10)
	G.label(self,"VAGA DO ESTALEIRO",Vector3(b.x,3.2,b.y),30)
	_people(hull_at,pile_at,shed_at,floor_y)

## Shipwrights carry planks from the timber stack to the hull on the slipway; two woodcutters bring
## logs down from the woods behind the yard to the stack.
func _people(hull_at: Vector2,pile_at: Vector2,shed_at: Vector2,floor_y: float) -> void:
	for i: int in 3:
		var person:=Porter.new();person.look_id=40+i;person.speed=.9+float(i)*.1
		var a:=pile_at+_side*float(i)*1.2;var h:=hull_at+_side*(2.8 if i%2==0 else -2.8)+_out*float(i-1)*2.
		var route: Array[Vector3]=[Vector3(a.x,Layout.height(a),a.y),Vector3(h.x,Layout.height(h),h.y)]
		person.route.assign(route);person.loaded_legs.assign([1])
		person.cargo=Porter.plank_load();person.add_child(person.cargo)
		add_child(person);workers.append(person)
	for i: int in 2:
		var cutter:=Porter.new();cutter.look_id=50+i;cutter.speed=.8+float(i)*.08
		var wood:=_woods(pile_at)+_side*float(i)*1.5
		var drop:=pile_at+_side*(1.5+float(i))-_out*1.5
		var route: Array[Vector3]=[Vector3(wood.x,Layout.height(wood),wood.y),Vector3(drop.x,Layout.height(drop),drop.y)]
		cutter.route.assign(route);cutter.loaded_legs.assign([1])
		cutter.cargo=Porter.log_load();cutter.add_child(cutter.cargo)
		add_child(cutter);workers.append(cutter)
	# Felling site: standing trees, fresh stumps and a felled trunk where the woodcutters load up.
	var camp:=_woods(pile_at)
	var bark:=G.material(Color("6b4e33"),.95);var cut:=G.material(Color("d8b884"),.8)
	for k: int in 3:
		var t:=camp-_out*(4.+float(k)*2.5)+_side*(float(k)*3.-3.)
		Props.spawn(self,"nature:CommonTree_%d"%(k%3+1),Vector3(t.x,Layout.height(t),t.y),7.5+float(k),float(k)*1.7)
	for k: int in 3:
		var st:=camp+_side*(float(k)*2.2-1.)+_out*1.8
		G.cylinder(self,Vector3(st.x,Layout.height(st)+.22,st.y),.3,.5,bark,.28,10)
		G.cylinder(self,Vector3(st.x,Layout.height(st)+.475,st.y),.28,.02,cut,.28,10)
	Props.spawn(self,"Log_01_Art",Vector3(camp.x,Layout.height(camp),camp.y)-Vector3(_out.x,0,_out.y)*1.,1.,atan2(_side.x,_side.y))
	var keeper:=Resident.new();keeper.look_id=44;keeper.hide_backpack=true
	var desk:=shed_at+_side*-5.+_out*-1.4
	keeper.route.assign([Vector3(desk.x,floor_y,desk.y)]);keeper.follow_terrain=false;add_child(keeper);workers.append(keeper)

## A spot inland of the timber stack, on gentle dry ground, where the woodcutters fell trees.
func _woods(pile_at: Vector2) -> Vector2:
	for k: int in 12:
		var p:=pile_at-_out*(30.-float(k)*2.)+_side*float(k%3)*4.
		if Layout.coast(p).x<-8. and absf(Layout.height(p)-Layout.height(pile_at))<9.:return p
	return pile_at-_out*8.

## True when a (slow) boat lies inside the marked berth.
func in_berth(at: Vector3) -> bool:
	return Vector2(at.x-berth.x,at.z-berth.z).length()<BERTH_RADIUS
