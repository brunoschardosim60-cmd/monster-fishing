extends SceneTree
## Character locomotion contract: crisp ground control, firm falls, and animation that matches ground speed.
## --headless --fixed-fps 60 --script res://tests/locomotion_contract.gd
const Player=preload("res://scripts/player/player_controller.gd")
const Angler=preload("res://scripts/player/imported_angler.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func frames(n: int) -> void:
	for i: int in n: await physics_frame

func _run() -> void:
	# --- Animation: gait selection and playback speed -------------------------------------------
	var angler: Node3D = Angler.new()
	root.add_child(angler)
	await process_frame
	var dt := 1. / 60.
	for i: int in 30: angler.update_animation(0., false, dt)
	check(angler.current == "Idle", "standing still plays Idle")
	for i: int in 60: angler.update_animation(1.99, false, dt)
	check(angler.current == "Walk" and absf(angler.animation.speed_scale - 1.) < .08, "walking at the Walk clip's own ground speed plays it at 1x (%.2f)" % angler.animation.speed_scale)
	for i: int in 60: angler.update_animation(2.8, false, dt)
	check(angler.current == "Walk", "2.8 m/s stays Walk when speeding up (no flicker at the boundary)")
	for i: int in 60: angler.update_animation(4.4, false, dt)
	check(angler.current == "Run" and angler.animation.speed_scale > 1.2 and angler.animation.speed_scale < 1.45, "jogging speed plays Run slightly faster than 1x (%.2f)" % angler.animation.speed_scale)
	for i: int in 60: angler.update_animation(2.8, false, dt)
	check(angler.current == "Run", "2.8 m/s stays Run when slowing down (hysteresis)")
	for i: int in 60: angler.update_animation(7.3, false, dt)
	check(angler.animation.speed_scale <= 1.9 + .001, "sprint playback is capped so the legs do not blur (%.2f)" % angler.animation.speed_scale)
	for i: int in 90: angler.update_animation(0., false, dt)
	check(angler.current == "Idle", "stopping returns to Idle")
	# Switching Walk -> Run keeps the cycle position, so feet do not pop.
	for i: int in 60: angler.update_animation(2., false, dt)
	angler.update_animation(2., false, dt)
	var before: float = angler.animation.current_animation_position / angler.animation.current_animation_length
	for i: int in 3: angler.update_animation(4.4, false, dt)
	var guard := 0
	while angler.current != "Run" and guard < 120:
		angler.update_animation(4.4, false, dt); guard += 1
	var after: float = angler.animation.current_animation_position / angler.animation.current_animation_length
	check(angler.current == "Run" and absf(fposmod(after - before, 1.) ) < .75, "Walk to Run switch happens without restarting the cycle")
	angler.queue_free()
	# --- Controller: acceleration, braking, jump and fall on a flat floor -------------------------
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump", "look_left", "look_right", "camera_toggle", "fly_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(400, 1, 400)
	floor_shape.shape = box; floor_body.add_child(floor_shape); floor_body.position = Vector3(0, 9.5, 0); floor_body.collision_layer = 1
	root.add_child(floor_body)
	var player: CharacterBody3D = Player.new()
	root.add_child(player)
	player.global_position = Vector3(0, 10.05, 0)
	await frames(30)
	check(player.is_on_floor(), "controller stands on the test floor")
	var planar := func() -> float: return Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_press("move_forward")
	var reach := -1
	for i: int in 60:
		await physics_frame
		if reach < 0 and planar.call() >= player.walk_speed * .98: reach = i + 1
	check(reach > 0 and reach <= 17, "reaches walking speed within 0.28 s (%d frames)" % reach)
	check(absf(planar.call() - player.walk_speed) < .05, "holds a steady walking speed (%.2f m/s)" % planar.call())
	Input.action_release("move_forward")
	var stop := -1
	for i: int in 60:
		await physics_frame
		if stop < 0 and planar.call() < .01: stop = i + 1
	check(stop > 0 and stop <= 14, "stops within 0.23 s of releasing the key, with no sliding tail (%d frames)" % stop)
	Input.action_press("move_forward"); Input.action_press("sprint")
	await frames(40)
	check(planar.call() > player.walk_speed * 1.5, "sprint is clearly faster than walking (%.2f m/s)" % planar.call())
	Input.action_release("move_forward"); Input.action_release("sprint")
	await frames(40)
	# Jump: height contract stays 1.0-1.6 m, and falling is faster than rising.
	var ground: float = player.global_position.y
	var space := InputEventKey.new(); space.physical_keycode = KEY_SPACE; space.keycode = KEY_SPACE
	InputMap.action_add_event("jump", space)
	var press := space.duplicate() as InputEventKey; press.pressed = true
	Input.parse_input_event(press); await frames(2)
	var release := space.duplicate() as InputEventKey; release.pressed = false
	Input.parse_input_event(release)
	var top := ground; var rise := 0; var fall := 0; var seen_top := false
	for i: int in 90:
		await physics_frame
		var y: float = player.global_position.y
		if not seen_top:
			if y > top + .0001: top = y; rise += 1
			else: seen_top = true
		elif not player.is_on_floor(): fall += 1
	check(top - ground > 1.0 and top - ground < 1.6, "jump height stays within 1.0-1.6 m (%.2f)" % (top - ground))
	check(fall > 0 and fall < rise, "falling is firmer than rising (%d frames up, %d down)" % [rise, fall])
	check(player.is_on_floor(), "player lands back on the floor")
	print("LOCOMOTION %d checks / %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
