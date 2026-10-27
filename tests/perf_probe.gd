extends SceneTree
## CPU cost per frame of the game logic (headless, no rendering): calm harbour vs. a storm at sea with
## the full fishing kit out (line, two rods in holders, set net, crew aboard).
## --headless --fixed-fps 60 --script res://tests/perf_probe.gd
const Waves=preload("res://scripts/world/wave_field.gd")
func _initialize() -> void: call_deferred("run")
func _measure(frames: int) -> Vector2:
	var proc:=0.;var phys:=0.
	for i: int in frames:
		await physics_frame
		proc+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.;phys+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
	return Vector2(proc,phys)/float(frames)
func run() -> void:
	var game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for a in InputMap.get_actions():InputMap.action_erase_events(a)
	for i in 400:await physics_frame
	var calm:=await _measure(300)
	var boat=game.boat
	boat.global_position=Vector3(250,0,-300);game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact()
	game.inventory.money=5000;game.crew.hire()
	game.inventory.equipment["gillnet"]=1;game.gear.gillnet_action()
	for i in 2:game.holders.set_rod(i,boat.global_position+boat.global_basis.x*(8. if i==0 else -8.),"coast","")
	game.fishing_visual.target=boat.global_position-boat.global_basis.z*15.;game.fishing.start_cast("coast")
	game.world.ocean.weather.settle(3)
	for i in 200:await physics_frame
	var storm:=await _measure(600)
	print("PERF calm: process %.2f ms, physics %.2f ms | storm + full kit: process %.2f ms, physics %.2f ms"%[calm.x,calm.y,storm.x,storm.y])
	quit()
