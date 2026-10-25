extends "res://tests/archipelago_contract.gd"
func run() -> void:
	Engine.time_scale=6.;Engine.physics_ticks_per_second=120
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;await frames(10)
	check(game.world.traffic.vessels.size()==7,"Seven moving vessels, including a 30 m support ship, a 62 m cargo liner and a 150 m tanker")
	var route_clear:=true
	var route: Array[Vector3]=game.world.traffic.ROUTE
	for i: int in route.size():
		for j: int in 30:
			var p:=route[i].lerp(route[(i+1)%route.size()],float(j)/30.)
			if Layout.coast(Vector2(p.x,p.z)).x<35.:route_clear=false
	check(route_clear,"Authored shipping lanes keep at least 35 m clearance from every island")
	var starts: Array[Vector3]=[]
	for ship: CharacterBody3D in game.world.traffic.vessels:starts.append(ship.position)
	await frames(1200)
	var moved:=0
	for i: int in starts.size():
		var ship: CharacterBody3D=game.world.traffic.vessels[i]
		if ship.position.distance_to(starts[i])>100. and Layout.coast(Vector2(ship.position.x,ship.position.z)).x>20.:moved+=1
	check(moved==starts.size(),"All vessels physically advance along safe water routes")
	# Follow the actual CharacterBody controller through a complete shipping circuit.
	Engine.time_scale=12.
	var visited: Array[Dictionary]=[{},{},{}];var minimum_clearance:=10000.;var elapsed_frames:=0
	for frame: int in 18000:
		await physics_frame;elapsed_frames+=1
		for i: int in 3:
			var vessel: CharacterBody3D=game.world.traffic.vessels[i]
			visited[i][vessel.waypoint]=true
			minimum_clearance=minf(minimum_clearance,Layout.coast(Vector2(vessel.position.x,vessel.position.z)).x)
		if visited[0].size()==8 and visited[1].size()==8 and visited[2].size()==8:break
	check(visited[0].size()==8 and visited[1].size()==8 and visited[2].size()==8,"All three vessels reach every shipping leg (%d simulated frames)"%elapsed_frames)
	check(minimum_clearance>18.,"Actual ship trajectories stay off the beaches (minimum %.1f m)"%minimum_clearance)
	Engine.time_scale=6.
	var ship: CharacterBody3D=game.world.traffic.vessels[0];game.boat.position=ship.position-ship.basis.z*14.;await frames(60)
	check(ship.waiting_for_player and ship.speed<1.,"NPC vessel yields to the player boat")
	game.boat.reset_to_dock()
	game.world.ocean.hour=12.;check(game.marine.region_at(Vector3(400,0,-350))=="open_water","Deep daytime water selects ocean species")
	game.world.ocean.hour=23.;check(game.marine.region_at(Vector3(400,0,-350))=="abyss","Night fishing unlocks the abyssal species pool")
	check(game.marine.region_at(Vector3(0,0,-20))=="coast","Starter harbor keeps the beginner fish pool")
	game.fishing.set_process(false);game.fishing.rng.seed=89
	var caught_abyss:=false
	for i: int in 30:
		game.fishing.state=0;game.fishing.start_cast("abyss")
		if game.fishing.species_current.id=="lanternfish":caught_abyss=true
	check(caught_abyss,"Lanternfish is selectable by the real fishing state machine")
	game.fishing.cancel();game.fishing.state=0;game.fishing.start_cast("coast")
	# The lure must sit within casting reach of the angler, closer to the school than the angler is.
	var school_center: Vector3=game.marine.schools[0].center
	var toward: Vector3=(school_center-game.player.global_position);toward.y=0.;toward=toward.normalized()
	game.fishing_visual.target=game.player.global_position+toward*25.+Vector3(0,3,0);await frames(2)
	check(game.marine.schools[0].mode=="isca","Visible school approaches an active fishing lure")
	game.fishing.cancel();game.fishing.set_process(true)
	game.player.position=game.marine.guardian.position+Vector3(20,0,0);game.player.set_physics_process(false);game.boat.speed=6.;await frames(20)
	check(game.marine.guardian_mode=="mergulhando","Guardian dives away from a noisy boat")
	game.boat.speed=0.;await frames(20)
	var coins: int=game.inventory.money
	check(game.marine.observe_guardian() and game.inventory.encyclopedia.has("abyssal_guardian") and game.inventory.money==coins+40,"Slow observation records the guardian and awards discovery once")
	check(not game.marine.observe_guardian() and game.inventory.money==coins+40,"Guardian reward cannot be repeated")
	var query:=PhysicsRayQueryParameters3D.create(Vector3(285,2,225),Vector3(285,2,325),1)
	check(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Sea arch has a physically open navigable passage")
	game.graphics.apply(0,.75,false,false);check(is_equal_approx(game.get_viewport().scaling_3d_scale,.75) and not game.world.sun.shadow_enabled,"Low preset and render scaling apply immediately")
	game.graphics.apply(3,1.,true,false);check(game.world.sun.directional_shadow_max_distance==300. and game.get_tree().get_nodes_in_group("nature_near")[0].visibility_range_end==400.,"Ultra enables longer shadows and detailed vegetation distance")
	game.audio.stop_all();game.world.life.birdsong.stop();game.queue_free();await process_frame
	print("MARINE WORLD ",checks," checks / ",failures," failures");quit(1 if failures else 0)
