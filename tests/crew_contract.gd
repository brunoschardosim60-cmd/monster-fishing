extends "res://tests/archipelago_contract.gd"
## Hired crew: berths by boat, paid daily; a deckhand walks to the rail on the gear's side before hauling,
## goes to a rod with a fish on and calls out, lashes the deck in a storm (less wave damage, reefs sails);
## a sailor set to the searchlight stands by it and aims it at night. Tasks change by talking (E).
## --headless --fixed-fps 60 --script res://tests/crew_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func _course_reset() -> void:
	game.crew._course={};game.crew._land_warned=false

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var crew: Node=game.crew;var boat: CharacterBody3D=game.boat;var inv=game.inventory
	inv.money=1000
	var hold0: int=inv.hold_limit
	var reply: String=crew.hire()
	check(crew.aboard()==1 and inv.money==1000-crew.HIRE_PRICE,"a sailor is hired at the inn (%s)"%reply)
	check(crew.hire().begins_with("Não há mais beliches"),"the launch has one berth")
	check(inv.hold_limit==hold0+2,"the crew keeps the catch in order: +2 places in the hold")
	var s: Node3D=crew.sailors[0]
	await frames(30)
	var deck: Dictionary=boat.deck_layout()
	check(s.get_parent()==boat._hull and absf(s.deck_local.y-float(deck.y))<.01 and absf(s.deck_local.x)<=float(deck.x)+.01,"the sailor stands on the real deck, riding the hull")
	# Haul a trap on the port side.
	var life=game.world.get_node("VidaNoFundo");var reef: Vector3=life.reefs[0]
	boat.global_position=Vector3(reef.x,0,reef.z);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	inv.traps=1
	var at: Vector3=boat.global_position-boat.global_basis.x*2.6
	var bottom: float=game.marine._seabed(Vector2(at.x,at.z))
	game.gear.traps.append({"at":Vector3(at.x,0,at.z),"bottom":bottom,"placed":0.,"soak":game.gear.TRAP_SOAK+5.,"node":game.gear._build_trap(at,bottom),"kind":"covo","baited":false})
	s.deck_local=Vector3(float(deck.x)-.2,float(deck.y),0.);s.assign("idle",s.deck_local,0.);await frames(5)
	var said: String=game.gear.trap_action()
	check(said.contains(s.sailor_name) and game.gear.hauling.is_empty(),"B asks the deckhand; nothing comes up before they reach the rail (%s)"%said)
	var started_at:=Vector3.INF
	for k: int in 600:
		await physics_frame
		if not game.gear.hauling.is_empty():started_at=s.deck_local;break
	check(started_at!=Vector3.INF and started_at.x<-float(deck.x)+.4,"the deckhand crosses to the port rail, then the trap comes up (x %.2f)"%started_at.x)
	await frames(10)
	check(s.job=="haul" and s.visual.haul==1. and s.visual._haul_blend>.3,"…hauling hand over hand")
	await frames(500)
	# A rod in a holder bends: the deckhand goes to it and calls the skipper.
	game.toggle_deck();await frames(3)
	game.fishing_visual.target=boat.global_position+boat.global_basis.x*9.;game.fishing.start_cast("coast");game.fishing.advance(2.)
	var hp: Vector3=(game.holders.holders[0].node as Node3D).position
	game.player.deck_local=Vector3(clampf(hp.x,-float(deck.x),float(deck.x)),float(deck.y),hp.z);await frames(3)
	game.interact();await frames(3)
	game.player.deck_local=Vector3(0,float(deck.y),float(deck.z0)+.3);await frames(3)
	game.holders._bite(0)
	var called:=false
	for k: int in 600:
		await physics_frame
		if game.hud.toast.text.contains(s.sailor_name+": Peixe"):called=true;break
	check(called and s.global_position.distance_to((game.holders.holders[0].node as Node3D).global_position)<1.,"the deckhand walks to the bent rod and calls out (%s)"%game.hud.toast.text)
	game.holders.take_rod(0)
	# Storm: lash the deck, reef the sail.
	game.world.ocean.process_mode=Node.PROCESS_MODE_DISABLED
	var old_energy: float=Waves.energy;Waves.energy=.97
	await frames(60)
	check(s.job=="secure" and boat.wave_damage_scale<1.,"in a storm the deckhand lashes the deck (wave damage ×%.2f)"%boat.wave_damage_scale)
	Waves.energy=old_energy;await frames(30)
	check(s.job=="idle","…and goes back to the station when it calms")
	# Searchlight duty at night.
	boat.searchlight_upgraded=true;game.world.ocean.hour=22.;game.world.ocean.process_mode=Node.PROCESS_MODE_INHERIT
	game.world.ocean.cycle_enabled=false
	game.player.deck_local=s.deck_local;await frames(3)
	game.interact();await frames(3)
	check(str(s.get_meta("task"))=="holofote","talking to the sailor (E) changes the task to the searchlight")
	var buoy: Vector3=boat.global_position+boat.global_basis.x*30.
	game.gear.traps.append({"at":Vector3(buoy.x,0,buoy.z),"bottom":-8.,"placed":0.,"soak":0.,"node":game.gear._build_trap(buoy,-8.),"kind":"covo","baited":false})
	for k: int in 400:await physics_frame
	check(s.job=="light" and s.at_target() and boat.light_yaw<-.6,"the sailor stands by the light and keeps it on the buoy to starboard (yaw %.2f)"%boat.light_yaw)
	# Wages at dawn.
	var money: int=inv.money
	game.world.ocean.hour=5.9;await frames(3);game.world.ocean.hour=6.2;await frames(3)
	check(inv.money==money-crew.DAILY_WAGE,"the crew is paid every morning (%d)"%(money-inv.money))
	# Fishing at the rail: E again sets the sailor to fish; with the boat still he puts a float out.
	game.player.deck_local=s.deck_local;await frames(3)
	game.interact();await frames(3)
	check(str(s.get_meta("task"))=="pesca","talking again sets the sailor to fish")
	for k: int in 600:
		await physics_frame
		if s.rod_out:break
	var side_ok: bool=absf(boat._hull.to_local(s.bob_point).x)>float(deck.x)+3.
	check(s.rod_out and s.job=="fish" and side_ok and absf(s.bob_point.y-Waves.height_at(s.bob_point))<.2,"he takes a spot at the rail and his float lies off the side")
	var st: Dictionary=s.get_meta("fishing")
	crew._crew_bite(s,st,s.bob_point);st.length=2.;st.land_odds=1.
	var before: int=inv.count();await frames(40)
	check(s.pull>.15 and s.visual.fishing_state==4,"a fish on: he reels, the rod bends (pull %.2f)"%s.pull)
	await frames(120)
	check(inv.count()==before+1 and str(inv.catches.back().get("crew",""))==s.sailor_name,"he lands it and it goes to the hold (%s)"%game.hud.toast.text)
	boat.speed=3.;await frames(5)
	check(not s.rod_out,"under way he keeps the line in")
	boat.speed=0.
	# The helm: he stands by while you steer and holds your course when you leave the wheel.
	game.player.deck_local=s.deck_local;await frames(3)
	game.interact();await frames(3)
	check(str(s.get_meta("task"))=="leme","…and once more puts him on the helm")
	var spot:=Vector3.INF;var heading:=0.
	for p: Vector3 in [Vector3(250,0,-300),Vector3(600,0,-700),Vector3(-600,0,-900),Vector3(900,0,400)]:
		for k: int in 8:
			var h: float=float(k)*TAU/8.;var fwd:=Vector3(-sin(h),0,-cos(h));var clear:=true
			for d: float in [0.,50.,100.,200.,300.,400.]:
				if preload("res://scripts/world/archipelago_layout.gd").coast(Vector2(p.x+fwd.x*d,p.z+fwd.z*d)).x<60.:clear=false;break
			if clear:spot=p;heading=h;break
		if spot!=Vector3.INF:break
	boat.global_position=spot;boat.rotation=Vector3(0,heading,0);boat.speed=0.;boat.yaw_rate=0.
	game.toggle_deck();await frames(30)
	check(boat.occupied and s.job=="helm_wait","at the wheel yourself, the helmsman waits beside you")
	boat.engine_rpm=.6
	game.toggle_deck()
	for k: int in 400:
		await physics_frame
		if not boat.autopilot.is_empty():break
	check(not boat.autopilot.is_empty() and s.job=="helm" and s.at_target() and absf(float(boat.autopilot.throttle)-.6)<.06,"leave the wheel: he walks to it and keeps your engine order (%s)"%str(boat.autopilot))
	boat.rotation.y+=.45;await frames(420)
	var err: float=absf(angle_difference(boat.rotation.y,heading))
	check(err<.12 and boat.speed>2.,"he brings her back on course and keeps her going (error %.2f rad, %.1f m/s)"%[err,boat.speed])
	# Land dead ahead: he stops the engine.
	# Put the boat 30 m off a coast, pointing at it.
	var probe:=Vector2(0,775)
	for k: int in 400:
		probe+=Vector2(0,-2.)
		if preload("res://scripts/world/archipelago_layout.gd").coast(probe).x>30.:break
	boat.global_position=Vector3(probe.x,0,probe.y);boat.rotation=Vector3(0,PI,0);boat.speed=1.;_course_reset()
	await frames(5)
	check(absf(float(boat.autopilot.get("throttle",1.)))<.01 and game.hud.toast.text.contains("Terra à frente"),"land ahead: he stops the engine (%s)"%game.hud.toast.text)
	game.toggle_deck();await frames(3)
	check(boat.autopilot.is_empty(),"take the wheel back and the helmsman lets go")
	# A canoe has no berth.
	inv.owned_boats.append("canoa");inv.boat_id="canoa";Economy.apply(inv,boat,game.fishing);await frames(5)
	check(crew.aboard()==0 and crew.hire().contains("não tem lugar"),"a canoe carries no crew")
	print("CREW %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
