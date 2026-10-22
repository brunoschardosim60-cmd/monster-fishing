extends SceneTree
const Waves=preload("res://scripts/world/wave_field.gd")
const Weather=preload("res://scripts/ocean/sea_weather.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+message)

func _run() -> void:
	var weather:=Weather.new(); weather.settle(0)
	weather.choose(3); weather.advance(1./60.)
	check(weather.wind<.10 and weather.rain<.002,"choosing storm never jumps directly to storm values")
	for i: int in 7200: weather.advance(1./60.)
	check(weather.wind>.8 and weather.rain>.95 and weather.energy>.75,"front develops wind, rain and accumulated swell")
	weather.choose(4)
	for i: int in 2400: weather.advance(1./60.)
	check(weather.rain<.2 and weather.energy>.6,"rain clears before residual swell dissipates")
	for i: int in 18000: weather.advance(1./60.)
	check(weather.energy<.3,"residual energy eventually dissipates")
	Waves.reset(); Waves.advance(0.,1.,.9,1.,Vector2(.9,.43).normalized())
	check(Waves.exposure(Vector2(0,-20))<Waves.exposure(Vector2(20,-100))*.5,"port receives less than half the open-water wind exposure")
	check(Waves.exposure(Vector2(35,20))<Waves.exposure(Vector2(-35,20)),"lee protection changes with the coast normal and wind direction")
	check(Waves.depth_at(Vector2(29,18))<Waves.depth_at(Vector2(60,-70)),"bathymetry deepens away from the island")
	check(absf(Waves.height_at(Vector3(0,0,18)))<.0001,"wave displacement vanishes inside land")
	check(Waves.channel_at(Vector2(84,-136))>.99 and Waves.channel_at(Vector2(30,-100))==0.,"authored ice passage guides local ripples without changing open water")
	if DisplayServer.get_name()!="headless":
		var probe:=SubViewport.new(); probe.size=Vector2i(16,16); probe.disable_3d=true
		probe.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(probe)
		var rect:=ColorRect.new(); rect.size=Vector2(16,16)
		var mat:=ShaderMaterial.new(); mat.shader=preload("res://tests/sea_probe.gdshader"); rect.material=mat; probe.add_child(rect)
		var maximum:=0.; var shelter_error:=0.
		for state: int in 5:
			weather.settle(state)
			Waves.advance(3.7,weather.wind,weather.energy,weather.rain,Vector2.from_angle(weather.heading)); Waves.bind(mat)
			for i: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			var image:=probe.get_texture().get_image()
			for y: int in 16:
				for x: int in 16:
					var p:=Vector3(-140.+x*18.,0,-160.+y*24.)
					if x==15 and y<8: p=Vector3(84.+float(y%3-1)*3.,0,-136.+floorf(float(y)/3.)*4.)
					var color:=image.get_pixel(x,y)
					var decoded: float=(roundf(color.r*255.)*256.+roundf(color.g*255.))/4096.-8.
					maximum=maxf(maximum,absf(decoded-Waves.height_at(p)))
					shelter_error=maxf(shelter_error,absf(color.b-Waves.exposure(Vector2(p.x,p.z))))
		check(maximum<.003,"CPU/GPU agree across 1280 samples / five states (packed height error %.5f m)"%maximum)
		check(shelter_error<.005,"CPU/GPU coast shelter agrees (error %.5f)"%shelter_error)
		probe.queue_free(); await process_frame
	var game:=load("res://scenes/main/main.tscn").instantiate() as Node3D
	root.add_child(game); game.begin_play(); game.set_process_input(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; game.player.controls_enabled=false
	game.player.global_position=Vector3(0,1.55,-23); game.interact()
	game.world.ocean.weather.settle(3); game.boat.global_position=Vector3(20,0,-80)
	var floe: Vector3=game.world.ocean.ice_footprints[0]
	check(game.world.is_land(Vector3(floe.x,0,floe.y)),"fishing rejects the solid surface of an ice floe")
	for i: int in 90: await physics_frame
	var max_tilt:=0.; var max_gap: float=0.
	for i: int in 720:
		await physics_frame
		max_tilt=maxf(max_tilt,maxf(absf(game.boat._hull.rotation.x),absf(game.boat._hull.rotation.z)))
		max_gap=maxf(max_gap,absf(game.boat._hull.position.y-Waves.height_at(game.boat.global_position)))
	check(max_tilt>.05 and max_tilt<=.381,"storm pitch/roll follows water and stays within the vessel limit")
	check(max_gap<.6,"storm hull remains near the sampled surface (max %.3f m)"%max_gap)
	var trail: Node=game.boat.trail
	for i: int in 80: trail.advance(Vector3(i*.8,0,-70),Basis(Vector3.UP,float(i)*.01),8.,.13)
	var count: int=trail.samples.size(); var stationary: Vector3=trail.samples[40].p
	trail.advance(Vector3(63.2,0,-70),Basis.IDENTITY,0.,.5)
	check(count>50 and trail.samples.size()==count,"wake survives releasing throttle")
	check(trail.samples[40].p==stationary,"old wake samples stay in world space")
	trail.advance(Vector3(63.2,0,-70),Basis.IDENTITY,0.,13.)
	check(trail.samples.is_empty(),"wake dissipates and its sample budget is released")
	game.boat.reset_to_dock(); check(trail.samples.is_empty(),"harbor recovery clears the previous wake")
	var heavy:=load("res://data/boats/heavy_fishing_boat.tres")
	check(heavy.mass_kg>game.boat.hydrodynamics.mass_kg and heavy.angular_response<game.boat.hydrodynamics.angular_response,"heavier vessel resource has greater inertia and slower angular response")
	game.audio.stop_all(); OS.delay_msec(100); game.queue_free(); await process_frame
	print("OCEAN CONTRACT: %d checks, %d failures"%[checks,failures]); quit(0 if failures==0 else 1)
