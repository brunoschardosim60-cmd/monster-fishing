extends "res://tests/archipelago_contract.gd"
## Procedural fish species and schools: every form has a catchable species, schools live in water, act like schools,
## and scatter from boats and predators.  --headless --fixed-fps 60 --script res://tests/fish_life_contract.gd
const Forms=preload("res://scripts/creatures/fish_forms.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Fishing=preload("res://scripts/fishing/fishing_system.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;await frames(10)
	var ids:={}
	for species: Resource in Fishing.SPECIES:ids[str(species.id)]=species
	var all_forms:=true
	for id: String in Forms.FORMS:
		if not ids.has(id):all_forms=false;push_error("form without species: "+id)
		if Forms.mesh(id).get_surface_count()!=1 or Forms.mesh(id).get_faces().size()<300:all_forms=false;push_error("empty mesh: "+id)
	check(all_forms,"every procedural form (%d) has a catchable species and a real mesh"%Forms.FORMS.size())
	check(Fishing.SPECIES.size()>=14,"the fishing pool holds %d species"%Fishing.SPECIES.size())
	var rarities:={}
	for species: Resource in Fishing.SPECIES:rarities[str(species.rarity)]=true
	check(rarities.size()>=4,"species span %d rarities"%rarities.size())
	var marine: Node3D=game.marine
	check(marine.fish_schools.size()>=22,"%d procedural schools and loners populate the sea"%marine.fish_schools.size())
	var forms_used:={}
	var in_water:=true
	for school: Node3D in marine.fish_schools:
		forms_used[school.form_id]=true
		for i: int in school.count:
			if Layout.coast(Vector2(school.pos[i].x,school.pos[i].z)).x<0.:in_water=false
	check(forms_used.size()==Forms.FORMS.size(),"every form swims somewhere (%d of %d)"%[forms_used.size(),Forms.FORMS.size()])
	check(in_water,"every fish starts in open water")
	# Pick a sardine school and bring the player to it.
	var sardines: Node3D=null
	for school: Node3D in marine.fish_schools:
		if school.form_id=="sardine" and school.count>=18:sardines=school;break
	game.player.global_position=sardines.center+Vector3(0,3,60)
	game.boat.position=sardines.center+Vector3(0,0,400)
	await frames(30)
	check(sardines.mmi.visible,"a school simulates and draws when the player is near")
	var start_center: Vector3=sardines.center
	await frames(600)
	check(sardines.center.distance_to(start_center)>3.,"the school travels (%.1f m)"%sardines.center.distance_to(start_center))
	var spread:=0.;var land:=0;var deep_ok:=true
	for i: int in sardines.count:
		spread=maxf(spread,Vector2(sardines.pos[i].x-sardines.center.x,sardines.pos[i].z-sardines.center.z).length())
		if Layout.coast(Vector2(sardines.pos[i].x,sardines.pos[i].z)).x<0.:land+=1
		if sardines.pos[i].y>Waves.height_at(sardines.pos[i]):deep_ok=false
	check(spread<sardines.radius*1.4+12.,"the school keeps together (widest %.0f m, home radius %.0f m)"%[spread,sardines.radius])
	check(land==0,"no fish wander onto land")
	check(deep_ok,"all fish stay under the surface")
	var speeds:Array[float]=[]
	for i: int in sardines.count:speeds.append(sardines.vel[i].length())
	speeds.sort()
	check(speeds[-1]-speeds[0]>.05,"fish swim at individual speeds (%.2f to %.2f m/s)"%[speeds[0],speeds[-1]])
	var headings:=Vector3.ZERO
	for i: int in sardines.count:headings+=sardines.vel[i].normalized()
	check(headings.length()/float(sardines.count)>.45,"fish are aligned like a school (alignment %.2f)"%(headings.length()/float(sardines.count)))
	# A fast boat scatters the school.
	game.boat.position=sardines.center+Vector3(15,0,0)
	game.boat.speed=7.
	await frames(60)
	check(sardines.mode=="fuga","a fast boat makes the school flee")
	game.boat.speed=0.;game.boat.position=sardines.center+Vector3(0,0,500)
	# A predator near a school makes it flee as well.
	var shark: Node3D=marine.predators[0]
	var prey: Node3D=null
	for school: Node3D in marine.fish_schools:
		if school.form_id=="sargo" and not school.predator:prey=school;break
	game.player.global_position=prey.center+Vector3(0,3,80)
	await frames(20)
	for i: int in shark.count:shark.pos[i]=prey.center+Vector3(10,-3,0)
	shark.center=prey.center+Vector3(10,-3,0)
	await frames(30)
	check(prey.mode=="fuga","a shark close by scatters the reef school")
	# Fishing odds: casting near a school favours its species.
	var spot: Vector3=prey.center+Vector3(2,0,0)
	check(marine.school_at(spot)==prey.species,"school_at reports the species under the line")
	print("FISH LIFE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
