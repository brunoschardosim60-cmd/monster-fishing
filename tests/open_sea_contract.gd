extends "res://tests/archipelago_contract.gd"
## Deep ocean: monster territories react to the boat, storms raise big swells far from land, long swells
## reach the horizon, and cloud shadows drift over land and sea.
## --headless --fixed-fps 60 --script res://tests/open_sea_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	check(Layout.WORLD_HALF>=5000. and Layout.LOBES.size()>=28,"the sea now spans %.0f km with %d island lobes"%[Layout.WORLD_HALF*2./1000.,Layout.LOBES.size()])
	var lairs: Array=game.lairs.lairs
	var deep:=0
	for l: Dictionary in lairs:
		if Layout.coast(Vector2(l.center.x,l.center.z)).x>300.:deep+=1
	check(lairs.size()==3 and deep==3,"three monster territories in deep water")
	var lair: Dictionary=lairs[0]
	var c: Vector3=lair.center;var r: float=lair.radius
	game.boat.set_occupied(true);game.player.set_boating(true);game.boat.speed=0.
	if game.boat.lights_enabled:game.boat.toggle_lights()
	game.boat.global_position=c+Vector3(r*.85,0,0);game.boat.velocity=Vector3.ZERO
	await frames(20)
	check(lair.state=="alerta" and (lair.bubbles as CPUParticles3D).emitting,"entering the territory wakes it: dark water and bubbles (%s)"%lair.state)
	game.boat.global_position=c+Vector3(r*.4,0,0);await frames(30)
	check(lair.state in ["caca","observando","atacando"] and (lair.node as Node3D).visible,"near the centre the %s surfaces beside the boat"%lair.kind)
	# Quiet and dark: it only watches, and the sighting pays.
	var money: int=game.inventory.money
	game.boat.speed=0.
	await frames(660)
	check(lair.observed and game.inventory.money>money,"slow with the lights off, the monster only watches (+%d coins)"%(game.inventory.money-money))
	var surface:=Waves.height_at(lair.pos)
	check(lair.pos.y>surface-5. and (lair.pos as Vector3).distance_to(game.boat.global_position)<60.,"it stays close, at the surface (%.1f m below)"%(surface-lair.pos.y))
	# Lights on: it attacks and damages the hull.
	game.boat.toggle_lights();game.boat.integrity=1.
	for i: int in 900:
		game.boat.global_position=c+Vector3(r*.4,0,0);game.boat.speed=0.
		await physics_frame
		if int(lair.hits)>=1:break
	check(int(lair.hits)>=1 and game.boat.integrity<1.,"with the lights on it strikes the boat (hull %d%%)"%int(game.boat.integrity*100.))
	# Leave: it dives and the water calms.
	game.boat.global_position=c+Vector3(r*1.4,0,0);await frames(20)
	check(lair.state=="recuando","leaving the territory sends it back down")
	await frames(560)
	check(lair.state=="dormindo" and not (lair.node as Node3D).visible,"it is gone again")
	# Long swells reach well past the fine water grid.
	var far_point: Vector3=game.boat.global_position+Vector3(0,0,600)
	var lo:=99.;var hi:=-99.
	for i: int in 240:
		await physics_frame
		var h:=Waves.height_at(far_point);lo=minf(lo,h);hi=maxf(hi,h)
	check(hi-lo>.4,"swells still move 600 m from the boat (%.2f m range)"%(hi-lo))
	var mid:=0
	for n: Node in game.world.water_root.get_children():
		if String(n.name).begins_with("OceanoMedio"):mid+=1
	check(mid==4,"a mid-resolution ring carries them towards the horizon")
	# Storm: far from land the swell is much bigger than near the coast.
	game.world.ocean.weather.settle(3)
	await frames(30)
	var open_range:=0.;var coast_range:=0.
	var coast_point:=Vector3.ZERO
	for k: int in 200:
		var probe:=Vector2(c.x,c.z)+Vector2(cos(float(k)*.7),sin(float(k)*.7))*float(k)*15.
		var d:=Layout.coast(probe).x
		if d>40. and d<70.:coast_point=Vector3(probe.x,0,probe.y);break
	for which: int in 2:
		var at: Vector3=c if which==0 else coast_point
		game.boat.global_position=at;game.boat.velocity=Vector3.ZERO;await frames(10)
		# Wave height range over a 160 m line, at a few instants.
		var a:=99.;var b:=-99.
		for k: int in 4:
			await frames(20)
			for j: int in 80:
				var h:=Waves.height_at(at+Vector3(float(j)*2.-80.,0,0));a=minf(a,h);b=maxf(b,h)
		if which==0:open_range=b-a
		else:coast_range=b-a
	check(coast_point!=Vector3.ZERO and open_range>coast_range*1.35 and open_range>3.5,"storm swell offshore %.1f m vs %.1f m near the coast"%[open_range,coast_range])
	# Cloud shadows in daylight with broken cloud.
	game.world.ocean.weather.settle(1);game.world.ocean.cycle_enabled=false;game.world.ocean.hour=12.
	await frames(60)
	var shade: float=game.world.ocean_material.get_shader_parameter("cloud_shadow_strength")
	var land: float=(game.world.terrain_materials[0] as ShaderMaterial).get_shader_parameter("cloud_shadow_strength")
	check(shade>.4 and land>.4,"cloud shadows drift over the sea and the land (%.2f)"%shade)
	game.world.ocean.hour=23.;await frames(60)
	check(float(game.world.ocean_material.get_shader_parameter("cloud_shadow_strength"))<.05,"no cloud shadows at night")
	print("OPEN SEA %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
