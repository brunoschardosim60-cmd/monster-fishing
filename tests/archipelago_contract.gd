extends SceneTree
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Economy=preload("res://scripts/inventory/harbor_economy.gd")
var game: Node3D
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;print("FAIL ",message)
	else:print("PASS ",message)
func frames(count: int) -> void:
	for i: int in count:await physics_frame
func walk_to(target: Vector3,budget: int=1200) -> bool:
	var previous: float=10000.;var stuck: int=0
	Input.action_press("move_forward")
	for i: int in budget:
		var diff: Vector3=target-game.player.global_position;diff.y=0.
		if diff.length()<.65:Input.action_release("move_forward");return true
		game.player.yaw=atan2(-diff.x,-diff.z)
		if absf(previous-diff.length())<.002:stuck+=1
		else:stuck=0
		previous=diff.length()
		if stuck>120:break
		await physics_frame
	Input.action_release("move_forward");print("WALK END target=",target," player=",game.player.global_position)
	for i: int in game.player.get_slide_collision_count():
		var hit: KinematicCollision3D=game.player.get_slide_collision(i)
		print("BLOCKER ",hit.get_collider().get_path()," at ",hit.get_collider().global_position," normal ",hit.get_normal())
	return false
func run() -> void:
	Engine.time_scale=6.;Engine.physics_ticks_per_second=120
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.set_process(false);game.set_process_input(false)
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(10)
	check(game.world.region.chunks.size()>40,"Modular large island terrain")
	check(game.world.region.foliage_count>500,"Terrain-aware forest instances")
	check(game.world.village.buildings.size()>=12,"Organized inhabited village")
	check(game.world.village.services.size()==8,"Eight connected service locations including the full harbor")
	check(await walk_to(Vector3(0,1.25,0)),"Walk from preserved pier to village")
	var accessible:=0
	for b: Node3D in game.world.village.buildings:
		game.player.global_position=b.entry.global_position+Vector3(0,.2,-1.5);game.player.velocity=Vector3.ZERO;await frames(8)
		if await walk_to(b.service.global_position,180):accessible+=1
	check(accessible==game.world.village.buildings.size(),"Physically enter every house/shop: %d/%d"%[accessible,game.world.village.buildings.size()])
	game.player.global_position=Vector3(0,1.55,32);game.player.velocity=Vector3.ZERO;await frames(8)
	var reached:=0
	for p: Vector3 in Layout.TRAIL.slice(2):
		if await walk_to(p):reached+=1
		else:break
	check(reached==Layout.TRAIL.size()-2,"Walk full village-to-lighthouse trail: %d waypoints"%reached)
	check(game.player.global_position.y>75.,"Panoramic summit reached on foot")
	game.player.global_position=Layout.WEST_TRAIL[0]+Vector3.UP*.3;game.player.velocity=Vector3.ZERO;await frames(8)
	reached=0
	for p: Vector3 in Layout.WEST_TRAIL.slice(1):
		if await walk_to(p):reached+=1
		else:break
	check(reached==Layout.WEST_TRAIL.size()-1,"Walk western grotto/ruins loop: %d waypoints"%reached)
	game.player.global_position=Vector3(-110,38.3,310);game.interact()
	check(game.inventory.encyclopedia.has("island_guardian"),"Guardian observation records real encyclopedia")
	var coins: int=game.inventory.money;game.interact();game.interact()
	check(game.world.village.discovered.has("ruins") and game.inventory.money==coins+20,"Observation allows ruin chest discovery and cannot duplicate its reward")
	game.inventory.money=0
	Economy.buy("rod",game.inventory,game.boat,game.fishing)
	check(game.inventory.money==0 and game.fishing.rod_bonus==0.,"Shop rejects insufficient funds")
	game.inventory.money=250;Economy.buy("rod",game.inventory,game.boat,game.fishing)
	check(game.inventory.money==185 and game.fishing.rod_bonus>.1,"Rod purchase changes real fishing and money")
	Economy.buy("rod",game.inventory,game.boat,game.fishing);check(game.inventory.money==185,"Unique upgrade cannot double-charge")
	Economy.buy("engine",game.inventory,game.boat,game.fishing);check(game.boat.max_speed>12.,"Engine upgrade changes navigation")
	game.boat.integrity=.4;Economy.buy("repair",game.inventory,game.boat,game.fishing);check(game.boat.integrity==1.,"Workshop repairs actual hull integrity")
	game.player.global_position=Vector3(0,1.55,-23);game.boat.reset_to_dock();game.interact();await frames(4)
	check(game.player.in_boat,"Board imported vessel at original pier")
	game.toggle_deck();await frames(4);var start: Vector3=game.player.global_position
	game.player.yaw=game.boat.rotation.y;Input.action_press("move_right");await frames(10);Input.action_release("move_right")
	check(game.player.on_deck and game.player.global_position.distance_to(start)>.3,"Walk on wave-following deck")
	game.boat.global_position=Vector3(300,0,-400);await frames(8);game.disembark();await frames(60)
	check(not game.player.in_boat and game.player.swimming,"Disembark in open sea and swim")
	game.player.global_position=game.boat.global_position+Vector3(2.5,-.5,1.);game.interact();await frames(4)
	check(game.player.in_boat,"Reboard vessel from swimming")
	game.toggle_deck();game.boat.speed=0.;game.player.yaw=PI*.5;await frames(8)
	check(game.can_cast(),"Cast from deck anywhere in open sea")
	var data:={"id":"sardine","species_id":"sardine","name":"Sardinha","weight":.8,"value":12,"rarity":"Comum","color":"83c6cf"}
	game._on_caught(data);await frames(4)
	check(game.inventory.count()==0 and not game.pending_catch.is_empty(),"Catch remains in hand until disposition")
	check(game.catch_display.global_position.y<game.player.global_position.y+1.8,"Fish is below head at hand attachment")
	game.finish_catch(false);game.finish_catch(false);check(game.inventory.count()==1,"Keeping catch adds once to inventory")
	game.fishing.species_current=game.fishing.SPECIES[0];game._on_caught(data);game.finish_catch(true)
	check(game.inventory.count()==1 and game.inventory.encyclopedia.sardine.released==1,"Release preserves inventory and records encyclopedia")
	game.boat.global_position=Vector3(2201,0,-400);await frames(3);check(game.boat.global_position.x< -2190.,"World can be crossed without radius wall")
	game.audio.stop_all();game.queue_free();await process_frame;OS.delay_msec(100)
	print("ARCHIPELAGO ",checks," checks / ",failures," failures")
	quit(1 if failures>0 else 0)
