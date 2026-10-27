extends "res://tests/archipelago_contract.gd"
## The fleet sails, varies, reacts to weather, carries crew, can be hailed; the anchor holds the boat.
## --headless --fixed-fps 60 --script res://tests/fleet_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var traffic=game.world.traffic
	var ships: Array=traffic.vessels
	var kinds:={};var shortest:=1e9;var longest:=0.
	for ship in ships:kinds[ship.kind]=true;shortest=minf(shortest,ship.length_m);longest=maxf(longest,ship.length_m)
	check(ships.size()>=15,"%d vessels at sea"%ships.size())
	check(kinds.size()>=10,"%d kinds of vessel (canoes to giant container ships)"%kinds.size())
	check(shortest<6. and longest>200.,"sizes from %.1f m to %.0f m"%[shortest,longest])
	var lane_ok: bool=traffic.far_lane.size()>=8
	for p: Vector3 in traffic.far_lane:
		if Layout.coast(Vector2(p.x,p.z)).x<120. or absf(p.x)>Layout.WORLD_HALF or absf(p.z)>Layout.WORLD_HALF:lane_ok=false
	check(lane_ok,"far ocean lane of %d waypoints stays in open water"%traffic.far_lane.size())
	var roles:={};var crewed:=0;var sails:=0
	for ship in ships:
		if ship.crew.size()>0:crewed+=1
		for person in ship.crew:roles[person.role]=true
		sails+=(ship.model.get_meta("sails",[]) as Array).size()
	check(crewed==ships.size(),"every vessel has people aboard")
	check(roles.has("helm") and roles.has("deckhand") and roles.has("fisher") and roles.has("rower"),"crew roles: %s"%str(roles.keys()))
	check(sails>=6,"%d sails on the sailing ships"%sails)
	await frames(30)
	# Sails are animated within 700 m of the camera (far ships are not animated at all).
	var trimmed:=0;var near_sailing:=0;var eye: Vector3=game.get_viewport().get_camera_3d().global_position
	for ship in ships:
		if ship.sail_rig==null or ship.position.distance_to(eye)>650.:continue
		near_sailing+=1
		if absf((ship.sail_rig.pivots[0] as Node3D).basis.get_euler().y)>.05:trimmed+=1
	check(near_sailing>=1 and trimmed==near_sailing,"%d of %d nearby sailing ships trim their sails to the wind"%[trimmed,near_sailing])
	var names:={}
	for ship in ships:names[ship.ship_name]=true
	check(names.size()>=ships.size()-1,"vessels carry their own names")
	# Everyone gets under way (fishing boats may already be stopped on their grounds).
	Engine.time_scale=6.;Engine.physics_ticks_per_second=120
	# Distance sailed, not net displacement: coastal routes go out and back along the shore.
	var last: Array=[];var sailed: Array=[]
	for ship in ships:last.append(ship.position);sailed.append(0.)
	for step: int in 40:
		await frames(30)
		for i: int in ships.size():sailed[i]+=ships[i].position.distance_to(last[i]);last[i]=ships[i].position
	var moving:=0
	for i: int in ships.size():
		if sailed[i]>60. or ships[i].activity=="pescando":moving+=1
	check(moving==ships.size(),"all %d vessels make way along their routes (%d did)"%[ships.size(),moving])
	# A storm sends the small boats to shelter; calm sends them back out.
	game.world.ocean.weather.settle(3);await frames(30)
	var sheltering:=0;var small:=0
	for ship in ships:
		if ship.is_small() and ship.shelter!=Vector3.INF:
			small+=1
			if ship.activity in ["abrigando","abrigado"]:sheltering+=1
	check(small>=6 and sheltering==small,"%d/%d small boats run for shelter in a storm"%[sheltering,small])
	game.world.ocean.weather.settle(0);await frames(30)
	var back:=0
	for ship in ships:
		if ship.is_small() and ship.activity=="navegando":back+=1
	check(back>=small-2,"small boats sail again when the wind drops (%d)"%back)
	Engine.time_scale=1.;Engine.physics_ticks_per_second=60
	# Hail a fishing boat from the player's boat and trade a fish for bait.
	var fisher=null
	for ship in ships:
		if ship.kind=="pesqueiro":fisher=ship;break
	game.boat.set_occupied(true);game.player.set_boating(true)
	game.boat.global_position=fisher.position+fisher.basis.x*(fisher.beam_m*.5+8.);game.boat.speed=0.
	await frames(2)
	game.interact()
	check(fisher.activity=="saudado","hailed vessel heaves to (%s)"%fisher.activity)
	await frames(240)
	check(fisher.speed<.6,"it stops beside the player (%.2f m/s)"%fisher.speed)
	game.inventory.add_catch({"id":"sardine","name":"Sardinha","weight":.3,"value":4})
	var bait: int=game.inventory.bait;var fish: int=game.inventory.count()
	game.interact()
	check(game.inventory.bait==bait+6 and game.inventory.count()==fish-1,"trade: one fish for six bait")
	# Anchor: drop it in open water, the engine is locked out and the boat stays on its chain.
	# Too deep offshore: the chain cannot reach.
	game.boat.global_position=Vector3(250,0,-300);game.boat.speed=0.;await frames(5)
	game.toggle_anchor()
	check(game.boat.anchor.state=="up","anchoring is refused in deep water")
	# Over a shallow reef the anchor bites.
	var reef: Vector3=game.world.get_node("VidaNoFundo").reefs[0]
	game.boat.global_position=Vector3(reef.x,0,reef.z);game.boat.speed=0.;await frames(5)
	game.toggle_anchor()
	check(game.boat.anchor.state=="dropping","anchor is dropped")
	for i: int in 600:
		await physics_frame
		if game.boat.anchor.state=="down":break
	check(game.boat.anchor.state=="down" and game.boat.anchor.hold_point.y<-2.,"anchor reaches the sea floor (%.1f m)"%game.boat.anchor.hold_point.y)
	var hold: Vector3=game.boat.global_position
	Input.action_press("move_forward");await frames(400);Input.action_release("move_forward")
	var drift:=Vector2(game.boat.global_position.x-hold.x,game.boat.global_position.z-hold.z).length()
	check(absf(game.boat.speed)<.2 and drift<game.boat.anchor.rode_length+1.5,"anchored boat holds its position with the throttle open (drift %.1f m)"%drift)
	game.toggle_anchor()
	for i: int in 900:
		await physics_frame
		if game.boat.anchor.state=="up":break
	check(game.boat.anchor.state=="up","anchor is hauled back aboard")
	Input.action_press("move_forward");await frames(120);Input.action_release("move_forward")
	check(game.boat.speed>1.,"boat motors away once the anchor is up (%.1f m/s)"%game.boat.speed)
	# Night: windows light up.
	game.world.ocean.hour=23.;await frames(200)
	var lit: StandardMaterial3D=ships[0].model.get_meta("windows")
	check(lit.emission_energy_multiplier>1.,"cabin windows glow at night")
	print("FLEET %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
