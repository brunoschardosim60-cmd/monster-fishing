extends Node3D
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Visual=preload("res://scripts/creatures/marine_visual.gd")
var game: Node3D
var schools: Array[Dictionary]=[]
const School=preload("res://scripts/creatures/fish_school.gd")
## Procedural species. Entry: [form, lobe or -1, angle (deg), distance from shore (m), fish, spread (m), min depth, max depth, predator].
## When lobe is -1 the entry is an absolute open-water point: [form, -1, x, z, fish, spread, min depth, max depth, predator].
const SCHOOL_TABLE: Array=[
	["sardine",0,120,55,22,50,1.5,7,false],["sardine",2,20,70,18,45,1.5,6,false],["seabass",3,200,60,10,40,3,12,false],
	["sargo",9,200,45,16,35,1.2,5,false],["cirurgiao",9,300,40,14,32,1.5,6,false],["sargo",8,100,50,18,40,1.2,5,false],["cirurgiao",17,40,45,16,35,1.5,6,false],
	["baiacu",8,250,60,2,30,1.5,5,false],["baiacu",18,90,40,2,25,1.5,5,false],
	["pargo",10,240,45,16,40,3,12,false],["pargo",19,100,50,14,35,3,12,false],["pargo",12,120,60,14,40,3,12,false],
	["sardine",11,100,60,22,50,2,8,false],["seabass",11,300,60,10,40,4,14,false],["sargo",13,60,50,16,40,1.2,5,false],["cirurgiao",20,300,50,12,35,2,8,false],
	["tubarao_recife",9,60,70,2,90,2.5,6,true],["tubarao_recife",10,330,80,2,100,3,8,true],["peixe_serra",4,200,50,1,60,4,10,false],
	["tubarao_branco",-1,1400,700,1,260,.4,.9,true],["tubarao_branco",-1,-1100,-300,1,260,.4,.9,true],
	["peixe_lua",-1,-700,-500,2,80,.2,.7,false],["peixe_lua",-1,1950,-380,2,80,.2,.7,false],
	["atum_rei",-1,1700,-250,5,120,3,14,false],["atum_rei",-1,-1600,1200,5,120,3,14,false],
	["cirurgiao",22,200,45,16,35,1.5,6,false],["tubarao_recife",22,40,80,2,100,3,8,true],["pargo",23,90,50,14,40,3,12,false],
	["sargo",24,330,50,16,40,1.2,5,false],["seabass",25,180,60,10,40,4,14,false],["baiacu",26,60,45,2,30,1.5,5,false],["sardine",27,270,60,22,50,2,8,false],
	["atum_rei",-1,4200,-2100,5,120,3,14,false],["peixe_lua",-1,-3000,3400,2,80,.2,.7,false],["tubarao_branco",-1,3000,2600,1,260,.4,.9,true]]
var fish_schools: Array[Node3D]=[]
var predators: Array[Node3D]=[]
var guardian: Node3D
var guardian_discovered: bool=false
var guardian_mode: String="patrulhando"
var elapsed: float=0.
var breach_clock: float=9.
## Feed thrown by the player: {at, until, node}. Small fish, turtles and (after a while) sharks come to it.
var feed: Array[Dictionary]=[]
const FEED_LIFE: float=32.
## Seconds the current feeding frenzy has lasted.
var frenzy: float=0.
## Shallow, clear water off the beaches where small fish, turtles and rays live: Vector3(x, seabed y, z).
var shallow_spots: Array[Vector3]=[]
var shallow_schools: Array[Node3D]=[]
var creatures: Node3D
var _frame: int=0
func _ready() -> void:
	for data: Array in [[Vector3(-28,-3,-66),"mackerel"],[Vector3(250,-4,-170),"tuna"],[Vector3(480,-4,100),"tuna"]]:
		var school:={"origin":data[0],"center":data[0],"species":data[1],"members":[],"velocities":[],"mode":"cardume"}
		for i: int in 8:
			var fish:=Visual.new();fish.species=data[1];fish.scale=Vector3.ONE*(.48 if data[1]=="mackerel" else 1.5);fish.position=data[0]+Vector3(sin(i*2.4)*3.,sin(i)*.4,cos(i*2.4)*3.);fish.swim_phase=i*2.4;fish.set_meta("school",true);add_child(fish);school.members.append(fish);school.velocities.append(Vector3(0,0,-1.))
		schools.append(school)
	_build_schools()
	_build_shallow_life.call_deferred()
	guardian=Visual.new();guardian.species="abyssal_guardian";guardian.name="VigiaAbissal";guardian.position=Vector3(380,-6,-220);add_child(guardian)
## Finds open water at roughly `distance` metres off the shore of a lobe, walking outward along `angle`.
func _water_near(lobe: int,angle_deg: float,distance: float) -> Vector2:
	var l:=Layout.LOBES[lobe];var dir:=Vector2(cos(deg_to_rad(angle_deg)),sin(deg_to_rad(angle_deg)))
	var p:=Vector2(l.x,l.y)
	for step: int in 400:
		p+=dir*(maxf(l.z,l.w)*.01+2.)
		if Layout.coast(p).x>=distance:return p
	return p
func _open_water(at: Vector2) -> Vector2:
	var p:=at
	for ring: int in 40:
		if Layout.coast(p).x>90. and absf(p.x)<3000. and absf(p.y)<3000.:return p
		p=at+Vector2(cos(float(ring)*2.4),sin(float(ring)*2.4))*float(ring)*40.
	return at
func _build_schools() -> void:
	var seed_value:=11
	for entry: Array in SCHOOL_TABLE:
		var form: String=entry[0];var lobe: int=entry[1]
		var water:Vector2=_water_near(lobe,float(entry[2]),float(entry[3])) if lobe>=0 else _open_water(Vector2(float(entry[2]),float(entry[3])))
		var school:=School.new();add_child(school)
		school.predator=bool(entry[8]);seed_value+=7
		school.setup(form,int(entry[4]),Vector3(water.x,0,water.y),float(entry[5]),Vector2(float(entry[6]),float(entry[7])),seed_value)
		fish_schools.append(school)
		if school.predator:predators.append(school)
## Finds clear shallows around the home island (and a few around other islands), then fills them with
## small fish shoals, turtles, stingrays and jellyfish. Waits for the terrain collision first.
func _build_shallow_life() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var home: Array[Vector3]=[];var away: Array[Vector3]=[]
	for lobe: int in [0,1,2,3,7,9,17,18,22,23]:
		var candidates: Array[Vector3]=home if lobe in [0,1,2,3,7] else away
		var l:=Layout.LOBES[lobe]
		for k: int in 36:
			var dir:=Vector2(cos(float(k)*TAU/36.),sin(float(k)*TAU/36.))
			var p:=Vector2(l.x,l.y)
			for step: int in 400:
				p+=dir*2.
				if Layout.coast(p).x>=3.:break
			# Walk on out over the shelf to the first point 2 m deep, as long as it stays shallow and near shore.
			for step: int in 20:
				var floor_y:=_seabed(p)
				var d:=Layout.coast(p).x
				if d>34.:break
				if floor_y<=-2.:
					if floor_y>-6.5 and Layout.coast(p).x>2.5 and absf(p.x)<Layout.WORLD_HALF-50. and absf(p.y)<Layout.WORLD_HALF-50.:candidates.append(Vector3(p.x,floor_y,p.y))
					break
				p+=dir*1.6
	# Home island first, nearest to the village, spread at least 60 m apart; then a few around other islands.
	home.sort_custom(func(a: Vector3,b: Vector3) -> bool: return Vector2(a.x,a.z-30.).length()<Vector2(b.x,b.z-30.).length())
	for gi: int in 2:
		var group: Array[Vector3]=home if gi==0 else away
		var limit:=shallow_spots.size()+(10 if gi==0 else 8)
		for c: Vector3 in group:
			var free:=true
			for s: Vector3 in shallow_spots:
				if Vector2(s.x-c.x,s.z-c.z).length()<(60. if gi==0 else 140.):free=false;break
			if free:shallow_spots.append(c)
			if shallow_spots.size()>=limit:break
	var seed_value:=901
	for i: int in shallow_spots.size():
		var spot:=shallow_spots[i]
		var forms: Array[String]=["manjuba","donzela","manjuba","sargo","cirurgiao","donzela"]
		var form:=forms[i%forms.size()]
		var school:=School.new();add_child(school);seed_value+=13
		var count:=26 if form=="manjuba" else 14
		var deepest:=minf(1.5,-spot.y-.6)
		school.setup(form,count,Vector3(spot.x,0,spot.z),14.,Vector2(.3,deepest),seed_value)
		school.shore_margin=5.;school.floor_limit=spot.y+.35;school.active_range=170.
		fish_schools.append(school);shallow_schools.append(school)
	var offshore: Array[Vector3]=[]
	for data: Vector2 in [Vector2(-420,-260),Vector2(620,-120),Vector2(260,-620),Vector2(-300,820),Vector2(980,520),Vector2(-820,260)]:
		var w:=_open_water(data);offshore.append(Vector3(w.x,0,w.y))
	creatures=preload("res://scripts/creatures/sea_creatures.gd").new();creatures.name="AnimaisDoMar";creatures.ecosystem=self;add_child(creatures)
	creatures.populate(shallow_spots,offshore)

func _seabed(p: Vector2) -> float:
	var plane:=-maxf(.85,.8+Layout.coast(p).x*.65)
	var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,-.3,p.y),Vector3(p.x,-160.,p.y));query.collision_mask=1
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return plane if hit.is_empty() else maxf(plane,(hit.position as Vector3).y)

## Scatter a handful of feed pellets on the water. Returns false on land.
func throw_feed(at: Vector3) -> bool:
	if Layout.coast(Vector2(at.x,at.z)).x<.5:return false
	var surface:=Waves.height_at(at)
	var node:=Node3D.new();node.name="Racao";node.position=Vector3(at.x,surface,at.z);add_child(node)
	var pellets:=CPUParticles3D.new();pellets.amount=60;pellets.lifetime=5.;pellets.one_shot=false;pellets.explosiveness=.1
	pellets.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;pellets.emission_sphere_radius=1.4
	pellets.direction=Vector3.DOWN;pellets.spread=25.;pellets.initial_velocity_min=.08;pellets.initial_velocity_max=.25;pellets.gravity=Vector3(0,-.18,0)
	var bit:=BoxMesh.new();bit.size=Vector3(.05,.04,.05);var bm:=StandardMaterial3D.new();bm.albedo_color=Color("9a6b3a");bm.roughness=.9;bit.material=bm
	pellets.mesh=bit;pellets.position.y=-.05;node.add_child(pellets)
	var slick:=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=1.8;disc.bottom_radius=1.8;disc.height=.01;disc.radial_segments=24;slick.mesh=disc
	var sm:=StandardMaterial3D.new();sm.albedo_color=Color(.7,.55,.33,.45);sm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;sm.roughness=.3;slick.material_override=sm
	slick.position.y=.03;slick.name="Mancha";node.add_child(slick)
	feed.append({"at":Vector3(at.x,surface,at.z),"until":elapsed+FEED_LIFE,"node":node})
	if game!=null and game.world.ocean.effects!=null:game.world.ocean.effects.splash(Vector3(at.x,surface,at.z),.5,true)
	return true

func feed_targets() -> Array[Vector3]:
	var out: Array[Vector3]=[]
	for f: Dictionary in feed:out.append(f.at)
	return out

## How many fish of all shallow and coastal schools are within `radius` of a point (tests, hints).
func fish_near(at: Vector3,radius: float) -> int:
	var n:=0
	for school: Node3D in fish_schools:
		if school.predator or not school.mmi.visible:continue
		for p: Vector3 in school.pos:
			if Vector2(p.x-at.x,p.z-at.z).length()<radius:n+=1
	return n

func _update_feed(delta: float) -> void:
	for f: Dictionary in feed.duplicate():
		var left: float=float(f.until)-elapsed
		var node: Node3D=f.node
		node.position.y=Waves.height_at(node.position)
		var slick: MeshInstance3D=node.get_node("Mancha")
		(slick.material_override as StandardMaterial3D).albedo_color.a=.45*clampf(left/10.,0.,1.)
		slick.scale=Vector3.ONE*(1.+(FEED_LIFE-left)*.04)
		if left<6.:(node.get_child(0) as CPUParticles3D).emitting=false
		if left<=0.:node.queue_free();feed.erase(f)
	var feeding:=false
	for school: Node3D in fish_schools:
		if school.mode=="racao" and not school.predator:feeding=true;break
	frenzy=frenzy+delta if feeding else 0.

func region_at(at: Vector3) -> String:
	var depth:=Waves.depth_at(Vector2(at.x,at.z));var hour: float=game.world.ocean.hour
	if depth>80. and (hour<6. or hour>20.):return "abyss"
	return "open_water" if depth>50. else "coast"
func school_at(at: Vector3) -> String:
	for school: Node3D in fish_schools:
		if Vector2(at.x-school.center.x,at.z-school.center.z).length()<22. and school.mmi.visible:return school.species
	for school: Dictionary in schools:
		if Vector2(at.x-school.center.x,at.z-school.center.z).length()<22.:return school.species
	return ""
func guardian_in_range() -> bool:
	return guardian.global_position.distance_to(game.player.global_position)<70.
func observe_guardian() -> bool:
	if guardian_discovered or not guardian_in_range() or (game.player.in_boat and absf(game.boat.speed)>3.):return false
	guardian_discovered=true
	game.inventory.record({"id":"abyssal_guardian","name":"Vigia Abissal","rarity":"Lendária","weight":0.,"observation":true})
	game.inventory.money+=40;game.inventory.changed.emit();return true
func _physics_process(delta: float) -> void:
	elapsed+=delta
	var threats: Array[Vector3]=[]
	for hunter: Node3D in predators:threats.append(hunter.center)
	_update_feed(delta)
	var ctx:={"boat":game.boat.position,"boat_speed":game.boat.speed,"player":game.player.global_position,"line_target":game.fishing_visual.target,"line_active":game.fishing.active(),"threats":threats,"feed":feed_targets(),"frenzy":frenzy}
	# Shoals far from the player update at half rate (alternating), the nearest ones every frame.
	_frame+=1
	var me: Vector3=game.player.global_position
	for si: int in fish_schools.size():
		var school: Node3D=fish_schools[si]
		if Vector2(school.center.x-me.x,school.center.z-me.z).length()>70.:
			if (si+_frame)%2==1:continue
			school.step(delta*2.,ctx)
		else:school.step(delta,ctx)
	for s: int in schools.size():
		var school:=schools[s];var target: Vector3=school.origin+Vector3(cos(elapsed*.07+s)*10.,0,sin(elapsed*.07+s)*10.)
		school.mode="cardume"
		if game.fishing.active() and school.center.distance_to(game.fishing_visual.target)<42.:
			target=game.fishing_visual.target+Vector3(0,-1.8,0);school.mode="isca"
		if absf(game.boat.speed)>4. and school.center.distance_to(game.boat.position)<35.:
			target=school.center+(school.center-game.boat.position).normalized()*20.;school.mode="fuga"
		if Layout.coast(Vector2(target.x,target.z)).x>6.:school.center=school.center.move_toward(target,delta*(3.5 if school.mode=="fuga" else 1.3))
		for i: int in school.members.size():
			var fish: Node3D=school.members[i];var phase:=float(i)*2.4+elapsed*.18
			var at: Vector3=school.center+Vector3(cos(phase)*(3.+i*.3),sin(phase*1.3)*.6,sin(phase)*(3.+i*.3))
			var separation:=Vector3.ZERO
			for other: Node3D in school.members:
				if other==fish:continue
				var offset:=fish.position-other.position
				if offset.length_squared()<1.4:separation+=offset/maxf(offset.length_squared(),.1)
			var desired: Vector3=(at-fish.position)*.65+separation*.7
			var limit:=4. if school.mode=="fuga" else 1.7
			desired=desired.limit_length(limit)
			var velocity: Vector3=school.velocities[i]
			velocity=velocity.move_toward(desired,delta*1.6)
			var next: Vector3=fish.position+velocity*delta
			if Layout.coast(Vector2(next.x,next.z)).x>3.:fish.position=next
			else:velocity=Vector3.ZERO
			fish.position.y=minf(fish.position.y,Waves.height_at(fish.position)-.7)
			school.velocities[i]=velocity
			if velocity.length_squared()>.01:
				var heading:=atan2(-velocity.x,-velocity.z)
				var turn:=angle_difference(fish.rotation.y,heading)
				fish.rotation.y+=clampf(turn,-delta*1.8,delta*1.8)
				fish.rotation.x=lerpf(fish.rotation.x,atan2(velocity.y,Vector2(velocity.x,velocity.z).length()),1.-exp(-delta*3.))
				fish.rotation.z=lerpf(fish.rotation.z,-clampf(turn*.18,-.22,.22),1.-exp(-delta*2.))
			fish.set_swim(.45+velocity.length()*.55,delta)
			fish.visible=fish.position.distance_squared_to(game.player.position)<160000.

	var phase:=elapsed*.024;var target:=Vector3(380+cos(phase)*45.,-3.5,-220+sin(phase)*45.)
	guardian_mode="patrulhando"
	if guardian_in_range() and absf(game.boat.speed)>3.:target.y=-14.;guardian_mode="mergulhando"
	elif guardian_in_range():target.y=-1.6;guardian_mode="curioso"
	var direction:=target-guardian.position;guardian.position=guardian.position.lerp(target,1.-exp(-delta*.35))
	if direction.length_squared()>.01:guardian.rotation.y=lerp_angle(guardian.rotation.y,atan2(-direction.x,-direction.z),delta*.45)
	breach_clock-=delta
	if breach_clock<0. and not game.fishing.active():
		breach_clock=16.+fposmod(elapsed,12.)
		for school: Dictionary in schools:
			if school.center.distance_to(game.player.position)<120.:
				game.surface_fish.breach(school.center,preload("res://data/fish/mackerel.tres") if school.species=="mackerel" else preload("res://data/fish/tuna.tres"));break
