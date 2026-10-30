extends "res://tests/archipelago_contract.gd"
## A new career: old canoe, bamboo pole, no light. Lights are bought in two steps (the lamparina first,
## any boat; deck lamps only on a boat with a battery). A storm breaks the canoe up; the boatyard lends
## an old one if it was all you had.
## --headless --fixed-fps 60 --script res://tests/career_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var inv: RefCounted=game.inventory;var boat: CharacterBody3D=game.boat
	game.start_career();await frames(4)
	check(inv.boat_id=="canoa" and Array(inv.owned_boats)==["canoa"] and inv.money==Economy.START_MONEY and boat.hull_model=="canoa","a new career starts in an old canoe with %d coins"%inv.money)
	check(game.fishing.rod_level()==0 and boat.light_level==0 and not boat.lamparina.visible and not boat.lamparina_light.visible,"…a bamboo pole and no light at all")
	# The canoe points where it goes: bow (−Z) ahead, the rabeta (outboard) at the stern (+Z).
	var bow_z: float=-float(boat.hull_spec.length)*.5
	check(float(boat.hull_spec.helm.z)>0. and boat.helm_wheel.position.z>0.,"the canoe's rabeta and helm are at the stern, the bow leads")
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=4.;await frames(30)
	check(boat.global_position.z<-300.5,"going ahead moves the canoe bow-first (−Z) (z %.1f)"%boat.global_position.z)
	boat.speed=0.;boat.reset_to_dock()
	# Lights: the lamparina, then refused deck lamps on the canoe.
	inv.money=400
	var said: String=Economy.buy("lights",inv,boat,game.fishing)
	check(inv.equipment.lights==1 and boat.light_level==1 and boat.lamparina.visible and boat.lamparina_light.visible,"buying a lamparina hangs a lit oil lamp aft (%s)"%said)
	check(boat.lamparina_light.omni_range<=8. and boat.deck_lights.all(func(l: Light3D) -> bool: return not l.visible),"…a short warm light, no deck lamps")
	var money: int=inv.money
	said=Economy.buy("lights",inv,boat,game.fishing)
	check(inv.equipment.lights==1 and inv.money==money,"a canoe has no battery for deck lamps (%s)"%said)
	boat.toggle_lights()
	check(not boat.lamparina_light.visible and boat.lamparina.visible,"L puts the lamparina out (the lantern stays hung)")
	boat.toggle_lights()
	# A lancha: the lamps can now be fitted.
	said=Economy.buy_boat("aurora",inv,boat,game.fishing);await frames(3)
	check(inv.boat_id=="aurora" and inv.money==money-240,"the lancha is bought for 240 (%s)"%said)
	check(boat.light_level==1 and boat.lamparina.visible and boat.deck_lights.all(func(l: Light3D) -> bool: return not l.visible),"the lamparina comes along; still no deck lamps")
	said=Economy.buy("lights",inv,boat,game.fishing)
	check(inv.equipment.lights==2 and boat.light_level==2 and boat.deck_lights.any(func(l: Light3D) -> bool: return l.visible),"deck lamps installed on the lancha (%s)"%said)
	check(Economy.buy("lights",inv,boat,game.fishing).begins_with("Nível máximo"),"two light steps only")
	# Rods: each step names the new rod.
	said=Economy.buy("rod",inv,boat,game.fishing)
	check(game.fishing.rod_level()==1 and "fibra" in said,"buying a rod gives the fibre rod (%s)"%said)
	# A canoe in a storm breaks up.
	inv.boat_id="canoa";inv.owned_boats.assign(["canoa"]);Economy.apply(inv,boat,game.fishing);await frames(3)
	game.world.ocean.process_mode=Node.PROCESS_MODE_DISABLED;game.world.storms.process_mode=Node.PROCESS_MODE_DISABLED
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.,0);game.interact();await frames(5)
	var sank:=[false];boat.sank.connect(func() -> void: sank[0]=true)
	var t:=0
	while t<60*90 and not boat.sinking:
		Waves.advance(1./60.,.95,1.,0.,Vector2(0,1));await physics_frame;t+=1
	check(boat.sinking,"a storm swamps or breaks the canoe within 90 s (%.0f s, integrity %.2f, water %.0f%%)"%[t/60.,boat.integrity,boat.water_fraction()*100.])
	for i: int in 30:await physics_frame
	var debris=root.get_tree().get_first_node_in_group("destrocos")
	check(debris!=null and debris.pieces.size()>=4,"the canoe comes apart as it sinks: planks and the paddle float off (%d pieces)"%(debris.pieces.size() if debris!=null else 0))
	inv.money=30
	while not sank[0] and t<60*120:
		Waves.advance(1./60.,.95,1.,0.,Vector2(0,1));await physics_frame;t+=1
	await create_timer(5.6).timeout;await frames(5)
	check(Array(inv.owned_boats)==["canoa"] and inv.money==0 and boat.integrity>.99,"the canoe is lost; the boatyard lends an old one for what you have (money %d)"%inv.money)
	# With a lancha in the shed, losing the canoe sends you back to it.
	inv.owned_boats.assign(["aurora","canoa"]);inv.boat_id="canoa"
	var note: String=Economy.wreck(inv)
	check(inv.boat_id=="aurora" and not "canoa" in inv.owned_boats and "Lancha" in note,"with another boat owned, the wrecked canoe is simply gone (%s)"%note)
	check(Economy.wreck(inv)=="","proper hulls are towed and patched, not lost")
	print("CAREER %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
