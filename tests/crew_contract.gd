extends "res://tests/archipelago_contract.gd"
## Hired crew: berths by boat, paid daily; a deckhand walks to the rail on the gear's side before hauling,
## goes to a rod with a fish on and calls out, lashes the deck in a storm (less wave damage, reefs sails);
## a sailor set to the searchlight stands by it and aims it at night. Tasks change by talking (E).
## --headless --fixed-fps 60 --script res://tests/crew_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

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
	check(s.job=="haul" and s.visual.work_clip=="ual/FishReel","…hauling hand over hand")
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
	# A canoe has no berth.
	inv.owned_boats.append("canoa");inv.boat_id="canoa";Economy.apply(inv,boat,game.fishing);await frames(5)
	check(crew.aboard()==0 and crew.hire().contains("não tem lugar"),"a canoe carries no crew")
	print("CREW %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
