extends "res://tests/archipelago_contract.gd"
## Traps, fish pots, winch and the set net: catches depend on depth, bait and soak time; animals are
## visible in the gear as it comes up; the winch lets traps go deeper and turns while hauling; the set
## net soaks, entangles fish from schools passing through, and comes up with them visibly caught.
## --headless --fixed-fps 60 --script res://tests/gear_contract.gd

func _avg(gear: Node3D,depth: float,baited: bool,soak: float) -> Dictionary:
	var out:={"crab":0.,"deep":0.}
	for k: int in 300:
		var t:={"bottom":-depth,"at":Vector3(250,0,-300),"soak":soak,"baited":baited,"kind":"covo","node":gear._build_trap(Vector3(250,0,-300),-depth)}
		gear._fill(t)
		for id: String in t.haul:
			if id=="caranguejo":out.crab+=1.
			else:out.deep+=1.
		(t.node as Node3D).free()
	out.crab/=300.;out.deep/=300.
	return out

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var gear: Node3D=game.gear
	# Catch model.
	var shallow:=_avg(gear,4.,false,gear.TRAP_SOAK+60.)
	var deep:=_avg(gear,22.,false,gear.TRAP_SOAK+60.)
	check(shallow.crab>deep.crab and deep.deep>shallow.deep,"shallow traps catch more crabs, deep ones more lobster and octopus (%.1f/%.2f vs %.1f/%.2f)"%[shallow.crab,shallow.deep,deep.crab,deep.deep])
	var plain:=_avg(gear,10.,false,gear.TRAP_SOAK)
	var rich:=_avg(gear,10.,true,gear.TRAP_SOAK+300.)
	check(rich.crab>plain.crab*1.5,"bait and a long soak fill the trap (%.1f vs %.1f crabs)"%[rich.crab,plain.crab])
	# Winch: only for hulls that can carry one; deeper traps; turns while hauling.
	game.inventory.money=2000
	check(Economy.buy("winch",game.inventory,game.boat,game.fishing).begins_with("Este barco não"),"the small launch cannot carry a winch")
	game.inventory.owned_boats.append("traineira");game.inventory.boat_id="traineira";Economy.apply(game.inventory,game.boat,game.fishing)
	Economy.buy("winch",game.inventory,game.boat,game.fishing)
	check(gear.has_winch() and is_instance_valid(game.boat.winch) and gear.max_trap_depth()>=60.,"the trawler takes a winch: traps can go to 60 m")
	# Fish pot over a reef.
	var life=game.world.get_node("VidaNoFundo")
	var reef: Vector3=life.reefs[0]
	var boat: CharacterBody3D=game.boat
	boat.global_position=Vector3(reef.x,0,reef.z);boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	Economy.buy("pots",game.inventory,game.boat,game.fishing)
	var placed: String=gear.trap_action()
	check(placed.begins_with("Gaiola") and gear.traps.size()==1 and gear.traps[0].kind=="gaiola","over a reef B lowers a fish pot (%s)"%placed)
	gear.traps[0].soak=gear.TRAP_SOAK+10.;await frames(3)
	var drum_before: float=boat._winch_drum.rotation.x
	var hauled: String=gear.trap_action();await frames(20)
	var fish:=0
	for a: Node in gear.fresh_haul.animals:
		if str(a.get_meta("critter",""))=="peixe":fish+=1
	check(fish>=1 and fish==(gear.fresh_haul.animals as Array).size(),"the pot comes up with reef fish swimming inside (%s)"%hauled)
	check(absf(boat._winch_drum.rotation.x-drum_before)>.5,"the winch drum turns while hauling")
	gear.release_haul();await frames(400)
	# Set net.
	Economy.buy("gillnet",game.inventory,game.boat,game.fishing)
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.;await frames(3)
	var set_reply: String=gear.gillnet_action()
	check(not gear.gillnet.is_empty(),"Shift+N sets the net off the side (%s)"%set_reply)
	await frames(10)
	var net_root: Node3D=gear.gillnet.node
	var floats_ok:=true
	for k: int in 11:
		var f: Node3D=net_root.get_node("Boia_%d"%k)
		if absf(f.global_position.y-preload("res://scripts/world/wave_field.gd").height_at(f.global_position))>.3:floats_ok=false
	check(floats_ok,"its floats ride the waves along the net line")
	# Steer a school through the net and let it soak.
	var school: Node3D=null
	for sc: Node3D in game.marine.fish_schools:
		if not sc.predator:school=sc;break
	var mid: Vector3=(gear.gillnet.a+gear.gillnet.b)*.5
	school.mmi.visible=true
	for i: int in school.pos.size():school.pos[i]=Vector3(mid.x+randf_range(-8,8),-1.,mid.z+randf_range(-1.,1.))
	for k: int in 30:gear._sample_gillnet()
	gear.gillnet.soak=gear.GILLNET_SOAK
	check((gear.gillnet.caught as Array).size()>=3,"fish from a school swimming through get entangled (%d)"%(gear.gillnet.caught as Array).size())
	var before: int=game.inventory.count()
	var haul_reply: String=gear.gillnet_action()
	await frames(30)
	var tangled: int=net_root.get_node("Malhados").get_child_count()
	check(haul_reply.begins_with("Recolhendo") and tangled>=3,"hauling brings the net up with the fish visibly caught in it (%d)"%tangled)
	await frames(200)
	check(game.inventory.count()>before and gear.can_release(),"landed: the fish go to the hold and can still be let go")
	gear.release_haul();await frames(20)
	check(game.inventory.count()==before,"X lets them go")
	await frames(400)
	check(gear.gillnet.is_empty(),"the net is stowed")
	print("GEAR %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
