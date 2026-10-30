extends SceneTree
## Contracts that can regress when visual waves are added to a level controller.
const Waves=preload("res://scripts/world/wave_field.gd")
var failures:=0
var checks:=0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+message)
func _run() -> void:
	var game:=load("res://scenes/main/main.tscn").instantiate() as Node3D
	root.add_child(game)
	for i: int in 3: await physics_frame
	game.begin_play()
	game.player.controls_enabled=false
	game.player.global_position=Vector3(0,1.55,-23)
	game.interact()
	game.boat.global_position=Vector3(20,0,-70)
	var min_y:=100.
	var max_y:=-100.
	var max_error:=0.
	for i: int in 240:
		await physics_frame
		var height: float=game.boat._hull.global_position.y
		min_y=minf(min_y,height)
		max_y=maxf(max_y,height)
		# The hull floats on buoyancy spread over its waterline (fishing_boat._simulate_hull): compare it with
		# the mean water level under its nine buoyancy points, allowing for its own inertia.
		var b: CharacterBody3D=game.boat;var plane:=0.
		for z: float in [-.45,0.,.45]:
			for x: float in [-.42,0.,.42]:plane+=Waves.height_at(b.global_position+b.global_basis.x*x*b.hydrodynamics.beam+b.global_basis.z*z*b.hydrodynamics.waterline_length)/9.
		max_error=maxf(max_error,absf(game.boat._hull.position.y-(plane-b.hydrodynamics.draft_offset)))
	_check(max_y-min_y>.25,"hull visibly rises and falls on the sea")
	_check(max_error<.45,"the floating hull stays close to the water under it (max %.2f m)"%max_error)
	_check(absf(game.boat.global_position.y)<.001,"visual waves do not displace the navigation collider")
	_check(game.player.in_boat and game.player.global_position.distance_to(game.boat.seat_position())<.08,"angler follows the moving seat")
	_check(game.player.camera.global_position.y>Waves.height_at(game.player.camera.global_position)+.2,"boat camera stays above wave crests")
	game.fishing_visual.target=Vector3(25,0,-80)
	game.fishing_visual.update_line(game.player.rod_tip(),2,0.)
	var bobber: Vector3=game.fishing_visual.bobber.global_position
	_check(absf(bobber.y-Waves.height_at(bobber)-.02)<.001,"fishing float rides in the rendered wave surface, half its bulb under water")
	var old_time:=Waves.time
	paused=true
	for i: int in 10: await process_frame
	_check(is_equal_approx(Waves.time,old_time),"pausing freezes the shared water clock")
	_check(is_equal_approx(float(game.world.ocean_material.get_shader_parameter("sea_time")),old_time),"shader and buoyancy share the paused time")
	paused=false
	game.audio.stop_all()
	game.audio.fx.stop()
	# Fixed-FPS simulation can outrun the real audio callback during teardown.
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	print("WATER CONTRACT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
