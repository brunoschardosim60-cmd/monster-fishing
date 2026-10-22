extends SceneTree
## 30-second, VSync-capped observation on the actual GPU, after warmup.
var reports: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("_run")
func _frames(count: int) -> void:
	for i: int in count: await process_frame
func _run() -> void:
	# A fixed-size render target avoids Windows work-area/DPI resizing the test.
	var render_view:=SubViewport.new()
	render_view.size=Vector2i(1440,900)
	render_view.own_world_3d=true
	render_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	render_view.msaa_3d=Viewport.MSAA_2X
	root.add_child(render_view)
	var display:=TextureRect.new()
	display.texture=render_view.get_texture()
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	var game:=load("res://scenes/main/main.tscn").instantiate() as Node3D
	render_view.add_child(game)
	root.position=Vector2i(40,40)
	game.begin_play()
	game.set_process_input(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	game.player.controls_enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.audio.stop_all()
	await _frames(240)
	for stage: int in 4:
		if stage==1:
			game.player.yaw=PI
		elif stage==2:
			game.player.global_position=Vector3(0,1.55,-23)
			game.interact()
			game.boat.global_position=Vector3(20,0,-60)
			game.player.yaw=0
		elif stage==3:
			game.world.ocean.weather.settle(3)
			game.boat.global_position=Vector3(20,0,-80)
		await _frames(90)
		var times: Array[float]=[]
		var last:=Time.get_ticks_usec()
		for i: int in 600:
			await process_frame
			var now:=Time.get_ticks_usec()
			times.append(float(now-last)/1000.)
			last=now
		var total:=0.
		for dt: float in times: total+=dt
		times.sort()
		var report:={"scene":["pier","village","boat","storm"][stage],"frames":600,"fps_mean":600000./total,"frame_ms_p50":times[300],"frame_ms_p95":times[570],"frame_ms_p99":times[594],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.}
		reports.append(report)
		print(JSON.stringify(report))
	var file:=FileAccess.open("res://tests/output/visual/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"physical_window":str(root.size),"framebuffer":str(render_view.size),"samples":reports,"limits":"Fixed 1440x900 3D render target, MSAA 2x, TAA, VSync/60 FPS cap, 600 measured frames per view after warmup. Other applications may be active; not a full hardware benchmark."},"\t"))
	file.close()
	game.audio.stop_all()
	game.audio.fx.stop()
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	quit()
