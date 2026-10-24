extends SceneTree
## Regressions for manual mooring, offshore islands and camera water clearance.
## --headless --fixed-fps 60 --script res://tests/docking_regression.gd
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var game: Node3D
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame

func tap_logical_key(code: Key) -> void:
	# Native/synthetic inputs can expose only a logical keycode. Exercise the
	# real input dispatch with physical_keycode deliberately left unset.
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func run() -> void:
	game = preload("res://scripts/main.gd").new()
	root.add_child(game)
	game.begin_play()
	await frames(10)
	# Reach the side of the docking area through real acceleration and braking.
	game.boat.set_occupied(true)
	game.player.set_boating(true)
	game.boat.position.z=-28.5 # Clear the longer imported hull from the finger before turning.
	game.boat.rotation.y = -PI / 2
	Input.action_press("move_forward")
	for frame: int in range(240):
		if game.boat.position.x >= 8.2:
			break
		await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_back")
	for frame: int in range(180):
		if game.boat.speed <= 0.1:
			break
		await physics_frame
	Input.action_release("move_back")
	await frames(30)
	check(game.boat.position.x > 9.0 and game.near_dock(), "pilot can return within the outer docking radius")
	game.interact()
	await frames(12)
	check(not game.player.in_boat, "E disembarks after a manual approach")
	check(game.boat.position.distance_to(game.boat.DOCK_POSITION) < 0.01, "manual disembarkation moors the launch in its reachable berth")
	check(absf(game.boat.speed) < 0.01 and game.boat.velocity.length() < 0.01, "mooring clears residual motion")
	game.interact()
	await frames(12)
	check(game.player.in_boat, "the launch can be boarded again immediately after mooring")
	# A legal water position near a distant island, with the normal cast aimed
	# at its emerged sloping beach. Test the real main-scene cast validation.
	# Search the real layout for water just south of Ilhas Adversas whose beach lies within cast range
	# (the boat faces -Z; the cast lands about 7 m ahead and 4 m to port of the boat).
	var adverse: Vector4 = Layout.LOBES[4]
	var berth := Vector3(adverse.x, 0, adverse.y + adverse.w * 1.4)
	for step: int in range(0, 2400):
		var z: float = adverse.y + adverse.w * 1.4 - float(step) * .25
		var here := Layout.coast(Vector2(adverse.x, z))
		var ahead := Layout.coast(Vector2(adverse.x - 4., z - 6.5))
		var short_cast := Layout.coast(Vector2(adverse.x, z - 3.7))
		if here.x > .5 and ahead.x < -2.5 and short_cast.x < -2.:
			berth = Vector3(adverse.x, 0, z)
			break
	check(berth.z < adverse.y + adverse.w * 1.4, "found legal water beside a distant island beach")
	game.boat.position = berth
	game.boat.rotation.y = 0
	game.boat.speed = 0
	await frames(8)
	var target: Vector3 = game.player.global_position + game.boat.global_basis * Vector3(-4,0,-8)
	var query := PhysicsRayQueryParameters3D.create(target + Vector3(0,10,0),target - Vector3(0,4,0),1)
	var hit: Dictionary = game.world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and (hit.position as Vector3).y > 0.0, "test cast would actually hit the emerged distant beach")
	check(game.world.is_land(target), "distant island beach is recognised as land")
	game.fish_action()
	check(game.fishing.state == 0, "a cast onto the distant island cannot start fishing")
	for lobe: int in Layout.LOBES.size():
		var l: Vector4 = Layout.LOBES[lobe]
		var center := Vector3(l.x, 0, l.y)
		check(game.world.is_land(center), "is_land includes island " + str(Layout.region_for_lobe(lobe).get("id", lobe)))
	# Maximum upward mouse angle must not put the third-person camera beneath
	# the ocean; first-person sky observation should remain available.
	game.boat.position = Vector3(0,0,-70)
	game.player.pitch = 0.45
	await frames(90)
	check(game.player.camera.global_position.y >= 0.15, "third-person orbit stays above the ocean")
	game.player.first_person = true
	game.player.pitch = 0.45
	await frames(90)
	check(game.player.pitch > 0.35 and game.player.camera.global_position.y > 0.15, "first-person can still look upward safely")
	await tap_logical_key(KEY_F)
	check(not game.player.first_person, "logical-only F switches back to third person")
	await tap_logical_key(KEY_F)
	check(game.player.first_person, "logical-only F switches into first person")
	await tap_logical_key(KEY_ESCAPE)
	check(paused, "logical-only Escape pauses the game")
	await tap_logical_key(KEY_ESCAPE)
	check(not paused, "logical-only Escape resumes the game")
	game.audio.stop_all()
	game.audio.fx.stop()
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	print("DOCKING REGRESSIONS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
