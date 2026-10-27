extends "res://tests/archipelago_contract.gd"
const Waves=preload("res://scripts/world/wave_field.gd")
## Boat handling: the wheel moves the rudder at a limited rate, the hull's turn builds up and dies away
## with inertia, the engine spools up, each hull class handles differently, the physical hull matches the
## visible size, and the camera collides with hulls instead of slipping inside them.
## --headless --fixed-fps 60 --script res://tests/boat_handling_contract.gd

func _open_sea(boat: CharacterBody3D) -> void:
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.;boat.velocity=Vector3.ZERO
	boat.rudder=0.;boat.yaw_rate=0.;boat.engine_rpm=0.

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var boat: CharacterBody3D=game.boat
	boat.set_occupied(true);_open_sea(boat)
	# Engine spool.
	Input.action_press("move_forward");await frames(6)
	check(boat.engine_rpm>0.05 and boat.engine_rpm<.4,"the engine spools up instead of jumping to full power (rpm %.2f)"%boat.engine_rpm)
	await frames(240)
	check(boat.engine_rpm>.98 and boat.speed>boat.max_speed*.6,"at full throttle the boat reaches cruising speed (%.1f m/s)"%boat.speed)
	# Rudder rate and the animated wheel.
	Input.action_press("move_right");await frames(6)
	check(boat.rudder>.05 and boat.rudder<.4,"the rudder follows the wheel at a limited rate (%.2f)"%boat.rudder)
	var heading: float=boat.rotation.y
	await frames(90)
	check(boat.rudder>.99,"hard over after a second (%.2f)"%boat.rudder)
	check(is_instance_valid(boat.helm_wheel) and absf(boat.helm_wheel.rotation.y)>4.,"the helm wheel turns with the rudder (%.1f rad)"%(boat.helm_wheel.rotation.y if is_instance_valid(boat.helm_wheel) else 0.))
	check(boat.rotation.y<heading-.4,"starboard rudder turns the bow to starboard (Δ %.2f rad)"%(boat.rotation.y-heading))
	# Inertia: after letting go, the hull keeps swinging for a moment and the rudder self-centres.
	Input.action_release("move_right")
	var before: float=boat.rotation.y;await frames(10)
	check(boat.rotation.y<before-.03,"the hull keeps swinging after the wheel is released")
	await frames(120)
	check(absf(boat.rudder)<.01 and absf(boat.yaw_rate)<.05,"rudder self-centres and the turn dies away (yaw rate %.3f)"%boat.yaw_rate)
	Input.action_release("move_forward")
	# Reverse is gentle.
	_open_sea(boat);Input.action_press("move_back");await frames(300);Input.action_release("move_back")
	check(boat.speed<-1. and boat.speed>=-float(boat.handling.reverse)-.01,"astern speed is limited by the hull class (%.1f m/s)"%boat.speed)
	# Classes: the light launch answers faster than the heavy trawler.
	var answers: Dictionary={}
	for id: String in ["veloz","traineira"]:
		game.inventory.owned_boats.append(id);game.inventory.boat_id=id
		Economy.apply(game.inventory,boat,game.fishing)
		_open_sea(boat);boat.speed=6.;boat.engine_rpm=.5
		Input.action_press("move_forward",.5);Input.action_press("move_left");await frames(45)
		answers[id]=boat.rotation.y
		Input.action_release("move_left");Input.action_release("move_forward")
	check(float(answers.veloz)>float(answers.traineira)+.05,"the light launch turns quicker than the heavy trawler (%.2f vs %.2f rad)"%[answers.veloz,answers.traineira])
	var shape: BoxShape3D=boat._collision_box
	check(is_equal_approx(shape.size.z,boat._base_box.z*1.18),"the physical hull grows with the trawler's size (%.2f m)"%shape.size.z)
	game.inventory.boat_id="aurora";Economy.apply(game.inventory,boat,game.fishing)
	check(is_equal_approx(shape.size.z,boat._base_box.z),"and shrinks back for the launch")
	check(game.player.arm.collision_mask&2!=0,"the camera arm collides with boat hulls")
	await _fleet(boat)
	var hull_before: Color=boat.livery_hull;game.inventory.money+=100
	var reply: String=Economy.buy("paint",game.inventory,boat,game.fishing)
	check(game.inventory.boat_paint==1 and boat.livery_hull!=hull_before,"the shipyard repaints the boat (%s)"%reply)
	print("BOAT_HANDLING %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

## Each hull class: its own size, helm, deck to walk and (for sailing hulls) sails driven by the wind.
func _fleet(boat: CharacterBody3D) -> void:
	for id: String in ["canoa","veleiro","escuna","aurora"]:
		if not id in game.inventory.owned_boats:game.inventory.owned_boats.append(id)
		game.inventory.boat_id=id;Economy.apply(game.inventory,boat,game.fishing)
		_open_sea(boat);await frames(20)
		var spec: Dictionary=boat.hull_spec
		var model: String=str(Economy.BOATS[id].get("model","tripo"))
		check(boat.hull_model==model and is_equal_approx(boat._collision_box.size.z,float(spec.length)),"%s: hull class %s, %.1f m hull"%[id,boat.hull_model,boat._collision_box.size.z])
		var helm: Vector3=boat._hull.to_local(boat.seat_position())
		check(absf(helm.y-float(spec.deck.y))<.3 and absf(helm.z)<float(spec.length)*.5,"%s: helm stands on the deck (%.2f, %.2f)"%[id,helm.y,helm.z])
		check(is_instance_valid(boat.helm_wheel) and boat.helm_wheel.is_inside_tree() and boat.helm_wheel.is_visible_in_tree(),"%s: helm wheel or tiller is visible"%id)
		# Walk the deck: stay aboard and never inside a cabin or mast.
		game.player.position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(3)
		check(game.player.in_boat,"%s: boarding works"%id)
		game.toggle_deck();await frames(3)
		var inside:=false;var left:=false
		for dir: StringName in ["move_forward","move_back","move_left","move_right"]:
			Input.action_press(dir);Input.action_press("sprint")
			for f: int in 120:
				await physics_frame
				var p: Vector3=game.player.deck_local
				if absf(p.x)>float(spec.deck.x)+.01 or p.z<float(spec.deck.z0)-.01 or p.z>float(spec.deck.z1)+.01:left=true
				for b: Rect2 in spec.deck.blocks:
					if b.grow(-.02).has_point(Vector2(p.x,p.z)):inside=true
			Input.action_release(dir);Input.action_release("sprint")
		check(not left and not inside,"%s: deck walking stays on deck and out of cabins/masts"%id)
		for roof: Dictionary in spec.deck.get("roofs",[]):
			var pl=game.player
			pl.deck_local=roof.ladder;pl.deck_level=-1;await frames(2)
			check(pl.ladder_hint()=="ESPAÇO · Subir","%s: the ladder offers a climb"%id)
			pl.jump_buffer=.16;await frames(60)
			check(pl.deck_level==0 and absf(pl.deck_local.y-float(roof.y))<.02,"%s: climbs the ladder onto the cabin roof (y %.2f)"%[id,pl.deck_local.y])
			Input.action_press("move_forward");await frames(90);Input.action_release("move_forward")
			var r: Rect2=roof.rect
			check(r.has_point(Vector2(pl.deck_local.x,pl.deck_local.z)),"%s: walking on the roof stays on the roof"%id)
			pl.deck_local=roof.top;await frames(2);pl.jump_buffer=.16;await frames(60)
			check(pl.deck_level==-1 and absf(pl.deck_local.y-float(spec.deck.y))<.02,"%s: climbs back down to the deck"%id)
		game.toggle_deck();await frames(2)
		game.interact();await frames(2)
		check(not game.player.in_boat and game.player.global_position.distance_to(boat.global_position)>float(spec.beam)*.5,"%s: stepping off lands beside the hull"%id)
	# Sailing: veleiro, engine off, wind on the beam.
	game.inventory.boat_id="veleiro";Economy.apply(game.inventory,boat,game.fishing)
	boat.set_occupied(true);_open_sea(boat)
	var old_dir: Vector2=Waves.direction;var old_wind: float=Waves.wind
	game.world.ocean.process_mode=Node.PROCESS_MODE_DISABLED
	Waves.direction=Vector2(-1,0);Waves.wind=.45
	boat.sail_target=1.;await frames(400)
	check(boat.sail_speed>1.5 and boat.speed>1.5,"beam reach under sail alone moves the boat (%.1f m/s)"%boat.speed)
	check(boat.point_of_sail()=="través","the HUD names the point of sail (%s)"%boat.point_of_sail())
	var pivot: Node3D=boat.sail_rig.pivots[0]
	check(pivot.basis.x.x<0. or pivot.basis.get_euler().y<-.1,"the boom swings to leeward")
	check(absf(boat.sail_heel)>.01,"the wind heels the hull (%.3f rad)"%boat.sail_heel)
	Waves.direction=Vector2(0,1);await frames(120)
	check(boat.sail_speed<.2,"head to wind the sails flog and give no drive (%.2f)"%boat.sail_speed)
	Waves.direction=Vector2(-1,0)
	check(boat.cycle_sails()!="" and boat.sail_target==0.,"P furls the sails")
	await frames(240)
	check(boat.sail_rig.hoist<.05 and boat.sail_speed<.05,"furled sails stop the drive")
	# Gale with full sail: warning and strain.
	var warned:=[false];boat.warning.connect(func(_t: String) -> void:warned[0]=true)
	boat.sail_target=1.;boat.sail_rig.hoist=1.;Waves.wind=.85;var before: float=boat.integrity
	await frames(120)
	check(warned[0] and boat.integrity<before,"full sail in a gale strains the hull and warns the skipper")
	# Spray torn off the crests in a gale, none in light airs; bow wave at speed.
	var spray: Node=game.world.spray
	var old_energy: float=Waves.energy;Waves.energy=.9
	await frames(150)
	check(spray.active_count()>4,"a gale tears spray off the crests (%d puffs)"%spray.active_count())
	boat.sail_target=0.;boat.speed=0.;boat.sail_rig.hoist=0.
	Waves.wind=.2;Waves.energy=.3;await frames(260)
	check(spray.active_count()==0,"no spray in light airs")
	Waves.energy=old_energy
	boat.speed=8.;await frames(3)
	check(boat._bow_left.visible and boat._bow_left.scale.z>1.,"a bow wave peels off the stem at speed")
	Waves.direction=old_dir;Waves.wind=old_wind;boat.integrity=1.
	game.world.ocean.process_mode=Node.PROCESS_MODE_INHERIT
	game.inventory.boat_id="aurora";Economy.apply(game.inventory,boat,game.fishing)
	check(boat.hull_model=="tripo" and boat.imported_model.visible and boat._propeller.is_inside_tree(),"back to the launch: imported model and propeller restored")
