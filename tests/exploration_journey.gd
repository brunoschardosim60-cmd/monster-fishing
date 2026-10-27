extends SceneTree
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var game: Node3D
var failures: int=0
var distance: float=0.
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	Engine.time_scale=6.;Engine.physics_ticks_per_second=120
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.set_process_input(false)
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.world.ocean.weather.settle(0)
	# Calm sea for a collision test: no storm cells or whirlpools on the way (they damage the hull on purpose).
	game.world.storms.set_process(false);game.world.whirlpools.set_physics_process(false)
	preload("res://scripts/world/wave_field.gd").storm_cells.clear();preload("res://scripts/world/wave_field.gd").whirls.clear()
	game.player.position=Vector3(0,1.55,-23);game.interact()
	game.boat.position=Vector3(30,0,-100)
	var reached:=0
	for target: Vector2 in [Vector2(320,-80),Vector2(420,200),Vector2(420,750),Vector2(70,1170),Vector2(-530,1030),Vector2(-530,540),Vector2(-340,-90),Vector2(30,-100)]:
		for frame: int in 2200:
			var p:=Vector2(game.boat.position.x,game.boat.position.z);var diff:=target-p
			if diff.length()<15.:reached+=1;break
			var error:=wrapf(atan2(-diff.x,-diff.y)-game.boat.rotation.y,-PI,PI)
			Input.action_press("move_forward")
			Input.action_release("move_left");Input.action_release("move_right")
			Input.action_press("move_left" if error>0. else "move_right",clampf(absf(error)*2.,0.,1.))
			await physics_frame
			distance+=p.distance_to(Vector2(game.boat.position.x,game.boat.position.z))
		print("LEG ",target," actual ",game.boat.position)
	Input.action_release("move_forward");Input.action_release("move_left");Input.action_release("move_right")
	check(reached==8 and distance>2400.,"Complete circumnavigation with real throttle/steering: %d/8 legs, %.0f metres"%[reached,distance])
	check(game.boat.integrity>.95,"Offshore route has no invisible collision walls")
	# Approach an authored beach from the sea, leave the boat, swim/walk ashore.
	var coast_x:=220.
	for x: int in range(220,300):
		if Layout.coast(Vector2(x,105)).x>2.:coast_x=x;break
	game.boat.position=Vector3(coast_x,0,103);game.boat.rotation.y=0;game.boat.speed=0
	for i: int in 8:await physics_frame
	game.disembark()
	for i: int in 30:await physics_frame
	game.player.yaw=PI*.5;Input.action_press("move_forward")
	for i: int in 700:
		if game.player.position.x<200.:break
		await physics_frame
	Input.action_release("move_forward")
	check(not game.player.in_boat and not game.player.swimming and game.player.position.y>.4 and game.player.position.x<201.,"Disembark away from port and walk onto eastern beach")
	game.audio.stop_all();game.audio.fx.stop();game.world.life.birdsong.stop();OS.delay_msec(100);game.queue_free();await process_frame
	print("EXPLORATION JOURNEY 3 checks / ",failures," failures");quit(failures)
