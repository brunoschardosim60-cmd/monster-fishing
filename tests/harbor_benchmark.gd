extends "res://tests/living_visual.gd"
func run() -> void:
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_2X;root.add_child(view)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.hide();game.player.controls_enabled=false;game.set_process_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;camera=Camera3D.new();view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=23.;game.world.ocean.weather.settle(0)
	var reports: Array[Dictionary]=[]
	for quality: int in [1,2]:
		game.graphics.apply(quality,1.,true,false)
		for stage: int in 2:
			camera.position=Vector3(0,3.2,-1) if stage==0 else Vector3(77,4,-20)
			camera.look_at(Vector3(0,3,35) if stage==0 else Vector3(41,3,-20))
			for i: int in 90:await process_frame
			var times: Array[float]=[];var last:=Time.get_ticks_usec()
			for i: int in 300:
				await process_frame;var now:=Time.get_ticks_usec();times.append(float(now-last)/1000.);last=now
			var sum:=0.
			for ms: float in times:sum+=ms
			times.sort()
			var report:={"quality":quality,"view":"night_village" if stage==0 else "night_bridges","frames":300,"fps_mean":300000./sum,"frame_ms_p95":times[285],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			reports.append(report);print(JSON.stringify(report))
	var file:=FileAccess.open("res://tests/output/living/harbor-benchmark.json",FileAccess.WRITE);file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1440x900","vsync":true,"reports":reports},"\t"));file.close()
	game.audio.stop_all();game.world.life.birdsong.stop();view.queue_free();await process_frame;quit()
