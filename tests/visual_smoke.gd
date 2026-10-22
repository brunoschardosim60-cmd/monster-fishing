extends SceneTree
## Actual GPU-rendered smoke captures; no desktop screenshot APIs.
## Run without --headless. Output is ignored by Git under tests/output/.

const Fishing = preload("res://scripts/fishing/fishing_system.gd")
var OUTPUT: String = "res://tests/output/visual"
var game: Node3D
var failures: int = 0
var checks: int = 0
var samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for index: int in range(count):
		await process_frame

func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var capture: Image = root.get_texture().get_image()
	_check(not capture.is_empty(), label + " framebuffer is readable")
	if capture.is_empty():
		return
	var path: String = ProjectSettings.globalize_path(OUTPUT.path_join(label + ".png"))
	_check(capture.save_png(path) == OK, label + " PNG saved")
	print("CAPTURE: ", path, " (", capture.get_width(), "x", capture.get_height(), ")")

func _hud_bounds(label: String, control: Control) -> void:
	var viewport_rect: Rect2 = root.get_visible_rect()
	var control_rect: Rect2 = control.get_global_rect()
	var fits: bool = viewport_rect.grow(1.0).encloses(control_rect)
	_check(fits, label + " fits viewport: " + str(control_rect))

func _sample(label: String) -> void:
	var sample: Dictionary = {
		"scene": label,
		"fps_engine_monitor": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	}
	samples.append(sample)
	print("PERFORMANCE_SAMPLE: " + JSON.stringify(sample))

func _run() -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		OUTPUT="res://tests/output/compatibility"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	print("GPU: ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_vendor())
	print("RENDERER: ", RenderingServer.get_current_rendering_method(), " / ", RenderingServer.get_current_rendering_driver_name())
	print("NOTICE: short real GPU observations; use render_benchmark.gd for frame-time measurements.")
	var scene: PackedScene = load("res://scenes/main/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	# This test never captures desktop content, and leaves the native UI alone.
	root.position = Vector2i(40, 40) if "--visible-visual" in OS.get_cmdline_user_args() else Vector2i(-2500, -1500)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.audio.stop_all()
	await _frames(120)
	await _capture("01_title")
	game.begin_play()
	game.set_process_input(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.controls_enabled = false
	await _frames(180)
	_hud_bounds("stats", game.hud.stats)
	_hud_bounds("prompt", game.hud.prompt)
	_hud_bounds("toast", game.hud.toast)
	_sample("pier_idle")
	await _capture("02_pier_idle")
	# Keep real main signal connections and normal presentation, but advance
	# just the fishing system deterministically to avoid waiting on a bite.
	game.fishing.set_process(false)
	game.fishing.rng.seed = 81347
	game.fish_action()
	for tick: int in range(500):
		game.fishing.advance(0.02)
		if game.fishing.state == Fishing.State.BITE:
			break
	_check(game.fishing.state == Fishing.State.BITE, "actual cast reaches bite")
	game.fish_action()
	_check(game.fishing.state == Fishing.State.REELING, "actual strike starts reel")
	game.fishing.set_reeling(true)
	for tick: int in range(75):
		game.fishing.advance(0.02)
	await _frames(6)
	_hud_bounds("fishing panel", game.hud.fishing_box)
	_hud_bounds("fishing hint", game.hud.fishing_hint)
	_hud_bounds("active fishing toast", game.hud.toast)
	await _capture("03_fishing_reel")
	var holding: bool = true
	for tick: int in range(2000):
		if game.fishing.tension > 0.72:
			holding = false
		elif game.fishing.tension < 0.25:
			holding = true
		game.fishing.set_reeling(holding)
		game.fishing.advance(0.02)
		if game.fishing.state != Fishing.State.REELING:
			break
	_check(game.fishing.state == Fishing.State.CAUGHT and game.inventory.count() == 0 and not game.pending_catch.is_empty(), "real catch waits in hand for disposition")
	_check(game.catch_display.visible and game.catch_display.get_child_count() > 0, "real 3D catch display is visible")
	await _frames(10)
	_hud_bounds("capture toast", game.hud.toast)
	await _capture("04_catch_model")
	game.finish_catch(false)
	_check(game.inventory.count()==1,"keeping real catch credits inventory")
	game.fishing.advance(6.0)
	await _frames(240)
	game.player.global_position = Vector3(0.0, 1.55, -23.0)
	game.interact()
	_check(game.player.in_boat, "boat camera entered through interaction")
	game.boat.global_position = Vector3(18.0, 0.0, -55.0)
	game.boat.rotation.y = -0.2
	game.player.yaw = 0.20
	game.player.pitch = -0.26
	await _frames(150)
	_sample("boat_ocean")
	await _capture("05_boat_ocean")
	var inspection_camera:=Camera3D.new()
	game.add_child(inspection_camera)
	inspection_camera.fov=56.
	inspection_camera.global_position=game.boat.global_position+Vector3(4.4,2.6,4.4)
	inspection_camera.look_at(game.boat.global_position+Vector3(0,.85,0))
	inspection_camera.current=true
	game.hud.visible=false
	await _frames(30)
	await _capture("07_boat_detail")
	game.boat.speed=7.
	for frame: int in 45:
		await process_frame
		inspection_camera.global_position=game.boat.global_position+Vector3(5.,3.8,7.)
		inspection_camera.look_at(game.boat.global_position+Vector3(0,0,1.5))
	await _capture("10_boat_wake")
	inspection_camera.current=false
	game.player.camera.current=true
	game.hud.visible=true
	game.return_to_harbor()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.controls_enabled = false
	game.player.yaw = PI
	game.player.pitch = -0.12
	await _frames(150)
	_sample("village")
	await _capture("06_village")
	inspection_camera.global_position=Vector3(15,1.65,-75)
	inspection_camera.look_at(Vector3(22,-3.5,-100))
	inspection_camera.fov=68.
	inspection_camera.current=true
	game.hud.visible=false
	await _frames(90)
	_sample("ocean_close")
	await _capture("08_ocean_close")
	inspection_camera.global_position=game.player.global_position+Vector3(1.7,1.35,-2.6)
	inspection_camera.look_at(game.player.global_position+Vector3(0,.95,0))
	inspection_camera.fov=48.
	await _frames(30)
	await _capture("09_angler_detail")
	var report: FileAccess = FileAccess.open(OUTPUT.path_join("metrics.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "viewport": str(root.get_visible_rect()), "samples": samples, "checks": checks, "failures": failures, "visible_window": "--visible-visual" in OS.get_cmdline_user_args(), "limitations": "Short rendered smoke observations; other applications active. Not a sustained benchmark."}, "\t"))
		report.close()
	game.audio.stop_all()
	game.audio.fx.stop()
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	print("VISUAL SMOKE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
