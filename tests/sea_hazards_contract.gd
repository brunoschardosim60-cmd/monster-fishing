extends "res://tests/archipelago_contract.gd"
## Dynamic sea: storm cells raise the swell where they are and drive the weather at the camera; whirlpools
## sink the surface and carry the boat; the sonar reads the bottom and what is around; diving has limited
## air and depth and chests to open; developer mode lends tools and gives the inventory back; lighthouse
## beams stop at obstacles.  --headless --fixed-fps 60 --script res://tests/sea_hazards_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(20)
	var world=game.world
	# --- Storms
	var sea:=Vector3(140,0,-330)
	var probe:=Vector2(sea.x,sea.z)
	var calm:=0.
	for k: int in 40:calm=maxf(calm,absf(Waves.height_at(Vector3(probe.x+k*3.1,0,probe.y))))
	world.storms.spawn_at(sea)
	var cam:=Camera3D.new();game.add_child(cam);cam.global_position=sea+Vector3(0,6,0);cam.current=true
	await frames(30)
	var rough:=0.
	for k: int in 40:rough=maxf(rough,absf(Waves.height_at(Vector3(probe.x+k*3.1,0,probe.y))))
	check(Waves.storm_factor(probe)>.5,"a storm cell covers the sea where it was spawned (%.2f)"%Waves.storm_factor(probe))
	check(rough>calm*1.4,"waves inside the storm are much higher (%.2f m vs %.2f m)"%[rough,calm])
	check(world.ocean.weather.local_storm>.5 and world.ocean.weather.rain>.3,"the storm at the camera brings wind and rain (rain %.2f)"%world.ocean.weather.rain)
	var far:=Vector2(probe.x+3000.,probe.y)
	check(Waves.storm_factor(far)<.01,"far from the cell the sea is not stormy")
	for c in world.storms.cells.duplicate():
		if not c.anchored:(c.node as Node3D).queue_free();world.storms.cells.erase(c)
	await frames(5)
	# --- Whirlpool
	var wp_at:=sea+Vector3(0,0,-200)
	world.whirlpools.spawn_near(wp_at);world.whirlpools.sites[-1].strength=1.
	await frames(3)
	var centre:=Waves.height_at(wp_at);var edge:=Waves.height_at(wp_at+Vector3(95,0,0))
	check(centre<edge-25.,"the whirlpool sinks a deep funnel into the sea, down to a throat (centre %.1f m, edge %.1f m)"%[centre,edge])
	var funnel_on: bool=world.whirlpools.funnels.size()>0 and world.whirlpools.funnels[0].visible and is_equal_approx(world.whirlpools.funnels[0].scale.x,90.)
	check(funnel_on,"it is drawn by its own fine radial mesh, not the coarse far grid")
	game.player.set_boating(true);game.boat.set_occupied(true);game.player.in_boat=true
	game.boat.global_position=wp_at+Vector3(50,0,0);game.boat.speed=0.
	var before: Vector3=game.boat.global_position;var yaw: float=game.boat.rotation.y
	await frames(120)
	var moved: float=game.boat.global_position.distance_to(before)
	check(moved>5. and absf(angle_difference(yaw,game.boat.rotation.y))>.1,"the current carries and turns the boat (%.1f m)"%moved)
	game.boat.global_position=wp_at+Vector3(12,0,0);game.boat.speed=0.
	await frames(90)
	check(game.boat._hull.global_position.y< -6.,"near the throat the boat goes down the wall of the funnel (hull at %.1f m)"%game.boat._hull.global_position.y)
	game.boat.global_position=sea+Vector3(0,0,400)
	# --- Sonar
	game.inventory.equipment["sonar"]=0
	check(game.sonar.ping().begins_with("Sem sonar"),"the sonar has to be bought first")
	game.inventory.equipment["sonar"]=1
	var reading: String=game.sonar.ping()
	check(reading.begins_with("Fundo:") and game.sonar.visible,"a ping reads the depth and opens the sonar screen (%s)"%reading)
	# --- Diving
	game.inventory.equipment["diving"]=0;await frames(2)
	check(is_equal_approx(game.player.breath,30.) and is_equal_approx(game.diving.max_depth(),12.),"free diving: 30 s of air, 12 m")
	game.inventory.equipment["diving"]=2;await frames(2)
	check(game.player.breath>=150. and game.diving.max_depth()>=80.,"the deep rig gives 150 s and 80 m")
	check(game.diving.sites.size()>=6,"there are wrecks and caves to dive to (%d)"%game.diving.sites.size())
	var site: Dictionary=game.diving.sites[0]
	game.player.set_boating(false);game.player.in_boat=false;game.boat.set_occupied(false)
	game.player.global_position=(site.pos as Vector3)+Vector3(1,0,0);game.player.swimming=true
	var money: int=game.inventory.money
	check(game.diving.try_open() and game.inventory.money>money,"a chest on a wreck opens and pays")
	check(not game.diving.try_open(),"an opened chest stays open")
	# --- Developer mode
	var real_money: int=game.inventory.money
	game.dev.set_active(true)
	check(game.inventory.money==99999 and not game.save_progress(),"developer mode lends money and never saves")
	game.dev.set_active(false)
	check(game.inventory.money==real_money,"leaving developer mode gives the real inventory back")
	# --- Lighthouse beam stops at obstacles
	world.ocean.hour=23.;await frames(10)
	var lh=world.harbor_lighthouse
	# The home lighthouse stands on the summit now, so put a wall right in front of its beam.
	var wall:=StaticBody3D.new();var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(30,40,30);wall_shape.shape=wall_box;wall.add_child(wall_shape)
	world.add_child(wall);wall.global_position=lh.rotor.global_position-(lh.arms[0] as Node3D).global_basis.z*60.
	var shortest:=1.
	for k: int in 60:
		await frames(1)
		for cone: MeshInstance3D in lh.cones:shortest=minf(shortest,cone.scale.y)
	check(shortest<.99,"the lighthouse beam is cut short where something blocks it (%.2f)"%shortest)
	wall.queue_free()
	# --- A world that changes: tide, seasons, migration, the hold
	var probe2:=Vector3(140,0,-330)
	Waves.tide=0.;var h0:=Waves.height_at(probe2);Waves.tide=.35;var h1:=Waves.height_at(probe2)
	check(absf(h1-h0-.35)<.01,"the tide lifts the whole sea surface")
	var ocean=world.ocean;var announced:=[]
	ocean.season_changed.connect(func(n: String) -> void:announced.append(n))
	ocean.cycle_enabled=true;ocean.day=2;ocean.hour=23.9995
	await frames(30)
	check(ocean.day==3 and ocean.season()==1 and announced.size()==1,"a new day can bring a new season (%s)"%str(announced))
	var tuna: Node3D=null
	for sc in game.marine.fish_schools:
		if str(sc.species)=="atum_rei":tuna=sc;break
	if tuna!=null:
		ocean.hour=6.;game.marine._migrate();var home_a: Vector3=tuna.home
		ocean.hour=18.;game.marine._migrate();var home_b: Vector3=tuna.home
		check(home_a.distance_to(home_b)>200.,"tuna migrate through the day (%.0f m)"%home_a.distance_to(home_b))
	game.inventory.catches.clear();game.inventory.hold_limit=2
	var f1: Dictionary=game.gear.make_catch("caranguejo")
	game.inventory.add_catch(f1);game.inventory.add_catch(f1)
	check(not game.inventory.add_catch(f1) and game.inventory.catches.size()==2,"a full hold takes no more fish")
	print("SEA_HAZARDS %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
