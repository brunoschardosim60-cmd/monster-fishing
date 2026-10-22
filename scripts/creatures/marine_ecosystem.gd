extends Node3D
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Visual=preload("res://scripts/creatures/marine_visual.gd")
var game: Node3D
var schools: Array[Dictionary]=[]
var guardian: Node3D
var guardian_discovered: bool=false
var guardian_mode: String="patrulhando"
var elapsed: float=0.
var breach_clock: float=9.
func _ready() -> void:
	for data: Array in [[Vector3(-28,-3,-66),"mackerel"],[Vector3(250,-4,-170),"tuna"],[Vector3(480,-4,100),"tuna"]]:
		var school:={"origin":data[0],"center":data[0],"species":data[1],"members":[],"velocities":[],"mode":"cardume"}
		for i: int in 8:
			var fish:=Visual.new();fish.species=data[1];fish.scale=Vector3.ONE*(.48 if data[1]=="mackerel" else 1.5);fish.position=data[0]+Vector3(sin(i*2.4)*3.,sin(i)*.4,cos(i*2.4)*3.);fish.swim_phase=i*2.4;fish.set_meta("school",true);add_child(fish);school.members.append(fish);school.velocities.append(Vector3(0,0,-1.))
		schools.append(school)
	guardian=Visual.new();guardian.species="abyssal_guardian";guardian.name="VigiaAbissal";guardian.position=Vector3(380,-6,-220);add_child(guardian)
func region_at(at: Vector3) -> String:
	var depth:=Waves.depth_at(Vector2(at.x,at.z));var hour: float=game.world.ocean.hour
	if depth>80. and (hour<6. or hour>20.):return "abyss"
	return "open_water" if depth>50. else "coast"
func school_at(at: Vector3) -> String:
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
