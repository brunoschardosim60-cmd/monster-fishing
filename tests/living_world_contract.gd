extends SceneTree
var game: Node3D
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",message)
func frames(count: int) -> void:
	for i: int in count:await physics_frame
func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func run() -> void:
	Engine.time_scale=3.;Engine.physics_ticks_per_second=120
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(18)
	var ground: float=game.player.position.y
	key(KEY_SPACE,true);await frames(2);key(KEY_SPACE,false)
	var top:=ground
	for i: int in 40:
		top=maxf(top,game.player.position.y);await frames(1)
	check(top-ground>1.0 and top-ground<1.6,"Space jumps 1–1.6 m using the real CharacterBody controller")
	check(game.fishing.state==0,"Jump does not cast a fishing line")
	check(game.player.is_on_floor() and absf(game.player.position.y-ground)<.1,"Jump lands on the original pier")
	game.player.position=Vector3(0,1.6,-23);game.player.yaw=0.;await frames(8)
	key(KEY_Q,true);await frames(12)
	check(game.aiming and game.cast_distance>5. and game.cast_marker.visible,"Holding Q previews a charged cast on actual water")
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;Input.parse_input_event(wheel);await frames(2)
	var selected_distance: float=game.cast_distance;await frames(8)
	check(game.aim_manual and is_equal_approx(game.cast_distance,selected_distance),"Wheel adjustment holds the chosen cast distance while aiming")
	key(KEY_Q,false);await frames(2)
	check(game.fishing.active() and not game.aiming,"Releasing Q launches the charged cast")
	game.fishing.set_process(false);game.fishing.advance(1.)
	var start: Vector3=game.player.position;Input.action_press("move_back");await frames(18);Input.action_release("move_back")
	check(game.fishing.active() and not game.player.movement_locked and game.player.position.distance_to(start)>.7,"Walk while line is in water without cancelling the fishing loop")
	game.fishing.cancel();game.fishing.set_process(true)
	game.player.position=Vector3(0,1.55,-23);game.boat.reset_to_dock();await frames(5);game.interact();await frames(5);game.toggle_deck()
	key(KEY_SPACE,true);await frames(2);key(KEY_SPACE,false);var deck_top:=0.
	for i: int in 40:deck_top=maxf(deck_top,game.player.deck_jump);await frames(1)
	check(game.player.on_deck and deck_top>1. and game.player.deck_jump==0.,"Jump and land on the wave-following deck")
	game.inventory.money=400
	const Economy=preload("res://scripts/inventory/harbor_economy.gd")
	Economy.buy("searchlight",game.inventory,game.boat,game.fishing)
	check(game.boat.searchlight_upgraded and game.boat.searchlight.visible and game.inventory.money==340,"Naval shop equips real 65 m searchlight")
	game.boat.toggle_lights();check(not game.boat.searchlight.visible,"L lighting toggle hides actual light nodes");game.boat.toggle_lights()
	Economy.buy("reel",game.inventory,game.boat,game.fishing);check(game.fishing.cast_range_bonus==12. and game.inventory.money==295,"Purchased reel extends cast range by 12 m")
	Economy.buy("hull",game.inventory,game.boat,game.fishing);check(game.boat.hull_protection==.6 and game.inventory.money==215,"Purchased hull protection modifies collision damage")
	Economy.buy("hull",game.inventory,game.boat,game.fishing);check(game.inventory.money==215,"Accessories cannot be charged twice")
	check(game.world.village.old_harbor.model.length_m==58. and game.world.village.old_harbor.model.meshes.size()>20,"Complete supplied harbor exists at 58 m scale")
	check(game.world.village.nearby_service(game.world.village.old_harbor.gear.global_position)=="gear_oldport","Full harbor fishing stall is reachable by proximity interaction")
	var skeleton: Skeleton3D=game.player.visual.skeleton
	var animator: AnimationPlayer=game.player.visual.animation
	animator.play("Walk");animator.advance(0.);animator.seek(.1,true)
	var arm_bone:=skeleton.find_bone("RightUpperArm");var chest:=skeleton.find_bone("Chest")
	var a:=skeleton.get_bone_pose_rotation(arm_bone);var b:=skeleton.get_bone_pose_rotation(chest)
	animator.seek(.65,true)
	check(a.angle_to(skeleton.get_bone_pose_rotation(arm_bone))>.3 and b.angle_to(skeleton.get_bone_pose_rotation(chest))>.03,"Walk animates upper arms and chest, not only legs")
	check(animator.has_animation("Jump") and animator.has_animation("Fall") and animator.has_animation("Cast") and animator.has_animation("Reel"),"Distinct jump/fall/cast/reel clips imported from Blender")
	game.player.visual.fishing_state=1;game.player.visual.update_animation(0.,true,.3)
	var cast_basis: Basis=game.player.visual._rod.global_basis
	game.player.visual.fishing_state=4;game.player.visual.update_animation(0.,true,.3)
	check(cast_basis.get_rotation_quaternion().angle_to(game.player.visual._rod.global_basis.get_rotation_quaternion())>.1,"Rod rotates with the animated hand between cast and reel")
	var dock_walkers:=0
	for resident: Node3D in game.world.village.residents.slice(3):
		if is_equal_approx(resident.position.y,1.4) and resident.position.distance_to(resident.route[0])>.2:dock_walkers+=1
	check(dock_walkers==3,"Three waterfront residents walk on the pier surface without sinking")
	const Nature=preload("res://scripts/world/nature_library.gd")
	Nature.wind(10.,1.,Vector2.RIGHT)
	var linked:=0
	for part: Dictionary in Nature.parts(2):
		if part.material is ShaderMaterial and is_equal_approx(part.material.get_shader_parameter("wind_strength"),1.):linked+=1
	check(linked>0,"Palm shader receives the same wind control as the ocean")
	game.audio.stop_all();game.world.life.birdsong.stop();game.queue_free();await process_frame
	print("LIVING WORLD ",checks," checks / ",failures," failures");quit(1 if failures else 0)
