extends "res://tests/docking_regression.gd"

func run() -> void:
	game = load("res://scripts/main.gd").new(); root.add_child(game)
	game.begin_play(); await frames(5)
	game.boat.set_occupied(true); game.player.set_boating(true)
	await tap_logical_key(KEY_T)
	check(game.player.flying and not game.player.in_boat and not game.boat.occupied, "T leaves helm and enables free flight")
	check(game.player.collision_mask == 0, "Flight passes over terrain freely")
	var start: Vector3 = game.player.position
	Input.action_press("jump"); await frames(60); Input.action_release("jump")
	check(game.player.position.y > start.y + 20., "Space ascends")
	var height: float = game.player.position.y
	Input.action_press("fly_down"); await frames(30); Input.action_release("fly_down")
	check(game.player.position.y < height - 8., "Ctrl descends")
	start = game.player.position
	Input.action_press("move_forward"); Input.action_press("sprint"); await frames(60)
	Input.action_release("move_forward"); Input.action_release("sprint")
	check(game.player.position.distance_to(start) > 70., "Shift accelerates flight")
	start = game.player.position; await frames(15)
	check(game.player.position.distance_to(start) < .1, "No input hovers without drift")
	await tap_logical_key(KEY_T)
	check(not game.player.flying and game.player.collision_mask == 1, "T restores walking collision and gravity")
	game.player.set_flying(true); game.return_to_harbor()
	check(not game.player.flying, "Return to harbor resets flight")
	check(not game.boat._hull.has_node("SailRig"), "Sail removed from boat")
	print("FLIGHT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
