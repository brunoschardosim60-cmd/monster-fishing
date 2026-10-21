extends SceneTree
## Headless scene-level regression. Uses the real player/boat and Godot input path.
## Run with --fixed-fps 60 to advance simulation quickly and deterministically.

const Fishing = preload("res://scripts/fishing/fishing_system.gd")
var game: Node3D
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame

func _tap_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _release_movement() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "sprint", "fish"]:
		Input.action_release(action)

func _walk_to(target: Vector2, max_frames: int = 400) -> bool:
	# Set a camera heading, then drive using the same WASD actions as a person.
	# No position/velocity injection: the real capsule and world handle the path.
	game.player.yaw = 0.0
	for frame: int in range(max_frames):
		var current := Vector2(game.player.global_position.x, game.player.global_position.z)
		var offset := target - current
		_release_movement()
		if offset.length() < 0.16:
			await _frames(12)
			return true
		if absf(offset.x) > 0.08:
			Input.action_press("move_right" if offset.x > 0.0 else "move_left")
		if absf(offset.y) > 0.08:
			Input.action_press("move_back" if offset.y > 0.0 else "move_forward")
		await physics_frame
	_release_movement()
	return false

func _catch_one(seed_value: int) -> bool:
	# Tick this system manually only, with a fixed random seed. The production
	# state transitions, main signal connections and inventory are still used.
	game.fishing.set_process(false)
	game.fishing.rng.seed = seed_value
	var before: int = game.inventory.count()
	game.fish_action()
	_check(game.fishing.state == Fishing.State.CASTING, "fish action casts from the stationary boat or pier")
	for tick: int in range(500):
		game.fishing.advance(0.02)
		if game.fishing.state == Fishing.State.BITE:
			break
	_check(game.fishing.state == Fishing.State.BITE, "line reaches a bite through casting and waiting")
	game.fish_action()
	_check(game.fishing.state == Fishing.State.REELING, "fish action hooks the bite")
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
	var captured: bool = game.fishing.state == Fishing.State.CAUGHT
	_check(captured, "reeling with tension relief lands a fish")
	_check(game.inventory.count() == before + 1, "main scene credits exactly one captured fish")
	game.fishing.advance(3.0)
	game.fishing.set_process(true)
	return captured

func _run() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	game.begin_play()
	await _frames(12)
	_check(game.started and game.player.is_on_floor(), "main scene starts with player on a safe surface")
	var start: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	await _frames(12)
	_check(game.player.global_position.z < start.z - 3.0, "W walks the actual character along the pier")
	_check(game.player.global_position.y > 1.2, "pier collision supports walking without water recovery")
	await _tap_key(KEY_E)
	await _frames(3)
	_check(game.player.in_boat and game.boat.occupied, "E boards when the player reaches the boat")
	var berth: Vector3 = game.boat.global_position
	Input.action_press("move_forward")
	await _frames(120)
	_check(game.boat.speed > 3.0 and game.boat.global_position.distance_to(berth) > 3.0, "W accelerates and moves the boat across the ocean")
	_check(not game.can_cast(), "casting is blocked while the boat is moving fast")
	game.fish_action()
	_check(game.fishing.state == Fishing.State.IDLE and game.inventory.count() == 0, "blocked cast cannot start fishing or grant a fish")
	var angle_before: float = game.boat.rotation.y
	Input.action_press("move_left")
	await _frames(30)
	Input.action_release("move_left")
	_check(game.boat.rotation.y > angle_before + 0.05, "A steers the moving boat left")
	angle_before = game.boat.rotation.y
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(game.boat.rotation.y < angle_before - 0.05, "D steers the moving boat right")
	Input.action_release("move_forward")
	var speed_before: float = game.boat.speed
	Input.action_press("move_back")
	await _frames(45)
	Input.action_release("move_back")
	_check(game.boat.speed < speed_before - 2.0, "S brakes the boat")
	for frame: int in range(600):
		if absf(game.boat.speed) < 0.05:
			break
		await physics_frame
	_check(game.can_cast(), "stationary boat permits casting")
	_check(game.sailed_once, "sailing beyond the harbor updates the travel objective")
	await _catch_one(81347)
	var basket_before: int = game.inventory.count()
	var value_before: int = game.inventory.total_value()
	_check(basket_before == 1 and value_before > 0, "capture has a positive sale value in the live inventory")
	game.return_to_harbor()
	await _frames(12)
	_check(not game.player.in_boat and not game.boat.occupied and game.near_dock(), "safe harbor return resets boat and disembarks")
	_check(game.inventory.count() == basket_before and game.inventory.total_value() == value_before, "return to harbor preserves the catch and its value")
	_check(await _walk_to(Vector2(0.0, -21.5)), "player walks back to the boarding gap")
	await _tap_key(KEY_E)
	await _frames(2)
	_check(game.player.in_boat, "boat remains boardable after harbor return")
	await _tap_key(KEY_E)
	await _frames(12)
	_check(not game.player.in_boat and not game.boat.occupied, "E disembarks at the dock while stopped")
	_check(await _walk_to(Vector2(0.0, -7.0)), "WASD walks from the dock onto the island")
	_check(await _walk_to(Vector2(6.0, -7.0)), "WASD reaches the market without teleporting")
	_check(game.near_market() and game.player.global_position.y > 1.0, "market is reachable on solid ground")
	var money_before: int = game.inventory.money
	await _tap_key(KEY_E)
	_check(game.inventory.count() == 0 and game.inventory.money == money_before + value_before, "E sells the catch and credits its exact value")
	_check(game.sold_once, "successful sale completes the first-trip objective")
	await _tap_key(KEY_E)
	_check(game.inventory.money == money_before + value_before, "a second sale cannot duplicate money")
	await _tap_key(KEY_F)
	await _frames(40)
	_check(game.player.first_person and game.player.arm.spring_length < 0.05, "F switches into first person")
	await _tap_key(KEY_F)
	await _frames(40)
	_check(not game.player.first_person and game.player.arm.spring_length > 6.5, "F restores third person")
	await _tap_key(KEY_ESCAPE)
	_check(paused, "Escape pauses through the actual input event path")
	var paused_position: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	await _frames(45)
	Input.action_release("move_forward")
	_check(game.player.global_position.distance_to(paused_position) < 0.001, "movement remains stopped while paused")
	await _tap_key(KEY_ESCAPE)
	_check(not paused, "Escape resumes through the actual input event path")
	var before_recovery: int = game.inventory.money
	# Walk off the open north end; let the normal falling signal perform recovery.
	game.return_to_harbor()
	_check(await _walk_to(Vector2(0.0, -25.3)), "player can walk to the end of the pier")
	Input.action_press("move_forward")
	await _frames(65)
	Input.action_release("move_forward")
	await _frames(20)
	_check(game.player.global_position.z > -22.0 and game.player.global_position.y > 1.0, "walking into water triggers safe recovery")
	_check(game.inventory.money == before_recovery, "water recovery preserves earned money")
	# Verify recovery also retains an unsold fish, through another real capture.
	await _catch_one(2257)
	var recovered_catches: int = game.inventory.count()
	game.return_to_harbor()
	await _frames(3)
	_check(game.inventory.count() == recovered_catches and recovered_catches > 0, "safe recovery retains unsold fish")
	_release_movement()
	# --fixed-fps advances faster than the real audio thread. Stop voices and
	# allow one audio callback to release playback resources before teardown.
	game.audio.ambient.stop()
	game.audio.fx.stop()
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	print("INTEGRATION TESTS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
