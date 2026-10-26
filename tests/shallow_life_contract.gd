extends "res://tests/archipelago_contract.gd"
## Clear shallows: small fish shoals, turtles, rays and jellyfish near the islands; feed draws fish to the
## surface; the cast net hauls them; crab traps soak and come back with crabs.
## --headless --fixed-fps 60 --script res://tests/shallow_life_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var marine=game.marine
	var spots: Array=marine.shallow_spots
	var close:=0
	for s: Vector3 in spots:
		if Vector2(s.x,s.z).length()<450.:close+=1
	check(spots.size()>=12 and close>=6 and spots.size()-close>=3,"%d clear shallow spots, %d near the village, the rest by other islands"%[spots.size(),close])
	check(marine.shallow_schools.size()==spots.size(),"each shallow spot has a shoal of small fish")
	var c=marine.creatures
	var mantas:=0
	for r: Dictionary in c.rays:
		if r.manta:mantas+=1
	check(c.turtles.size()>=5 and c.rays.size()-mantas>=4 and mantas>=2 and c.jellies.size()>=5,"%d turtles, %d stingrays, %d mantas, %d jellyfish swarms"%[c.turtles.size(),c.rays.size()-mantas,mantas,c.jellies.size()])
	# Go out by boat to the first shallow spot.
	var spot: Vector3=spots[0]
	game.boat.set_occupied(true);game.player.set_boating(true);game.boat.speed=0.
	var seaward:=Layout.coast(Vector2(spot.x,spot.z));var out:=Vector3(seaward.y,0,seaward.z).normalized()
	game.boat.global_position=Vector3(spot.x,0,spot.z)+out*9.;game.boat.velocity=Vector3.ZERO
	await frames(240)
	var school: Node3D=marine.shallow_schools[0]
	var shallow:=0;var dry:=0
	for p: Vector3 in school.pos:
		var surface:=Waves.height_at(p)
		if surface-p.y<2.2:shallow+=1
		if Layout.coast(Vector2(p.x,p.z)).x<.5:dry+=1
	check(shallow>=school.count*0.9 and dry==0,"the shoal swims within 2 m of the surface, in the water (%d/%d shallow)"%[shallow,school.count])
	# Feed: fish gather at the pellets and rise.
	var at: Vector3=game.gear.throw_point(6.5)
	var before: int=marine.fish_near(at,6.)
	var fed_before: int=game.inventory.feed
	var message: String=game.gear.throw_feed()
	check(game.inventory.feed==fed_before-1 and marine.feed.size()==1,"C throws a handful of feed (%s)"%message)
	await frames(900)
	var after: int=marine.fish_near(at,6.)
	check(after>before+5,"fish come to the feed (%d → %d within 6 m)"%[before,after])
	var feeding:=0
	for s: Node3D in marine.shallow_schools:
		if s.mode=="racao":feeding+=1
	check(feeding>=1,"%d shoals are feeding"%feeding)
	# The cast net catches the gathered fish.
	game.inventory.equipment.net=1
	var catches: int=game.inventory.count()
	check(game.gear.cast_net()=="Tarrafa lançada!","N casts the net from the stopped boat")
	await frames(400)
	check(game.gear.last_haul.size()>=2 and game.inventory.count()>=catches+2,"the net hauls %d fish"%game.gear.last_haul.size())
	check(game.gear.cast_net()!="Tarrafa lançada!","the net needs a moment before the next cast")
	# Crab trap: drop it, it is empty at first, full after the soak.
	game.inventory.traps=1
	var placed: String=game.gear.trap_action()
	check(game.gear.traps.size()==1 and game.inventory.traps==0,"B drops a crab trap with a buoy (%s)"%placed)
	await frames(10)
	var buoy: Node3D=(game.gear.traps[0].node as Node3D).get_node("Boia")
	check(absf(buoy.global_position.y-Waves.height_at(buoy.global_position))<.3,"the trap buoy floats on the surface")
	check(game.gear.trap_action().begins_with("O covo ainda"),"a fresh trap is still empty")
	game.gear.traps[0].soak=game.gear.TRAP_SOAK+1.
	catches=game.inventory.count()
	var hauled: String=game.gear.trap_action()
	check(hauled.contains("Caranguejo") and game.inventory.count()>catches and game.inventory.traps==1,"after the soak the trap comes up with crabs (%s)"%hauled)
	# A turtle comes up to breathe.
	var t: Dictionary=c.turtles[0]
	game.boat.global_position=(t.node as Node3D).position+Vector3(0,0,10);await frames(5)
	t.breathe=0.;t.surfacing=0.
	var best:=99.
	for i: int in 420:
		await physics_frame
		best=minf(best,float(t.depth))
	check(best<.5,"a turtle swims up to breathe at the surface (%.2f m deep)"%best)
	print("SHALLOW LIFE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
