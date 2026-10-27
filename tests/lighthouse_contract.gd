extends SceneTree
## Lighthouse light contract: night-only beams, distinct characters, visible flare that flashes toward the viewer.
## --headless --fixed-fps 60 --script res://tests/lighthouse_contract.gd
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
	for i: int in n: await process_frame

func _run() -> void:
	var world := preload("res://scripts/world/coastal_world.gd").new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	await frames(4)
	# One home lighthouse and two distant ones (27/10: fewer towers, fewer flashes at night).
	var harbor: Node3D = world.remote_lighthouses.lighthouses[0]
	var aurora: Node3D = world.lighthouse
	world.ocean.cycle_enabled = false
	world.ocean.hour = 23.
	await frames(10)
	check(harbor.rotor.visible and aurora.rotor.visible, "home and distant lighthouses burn at night")
	check(world.harbor_lighthouse == aurora and aurora.arms.size() == 1 and world.remote_lighthouses.lighthouses.size() == 2, "a single lighthouse on the home island, two on distant islands, one beam each at home")
	check(harbor.spots.size() == harbor.arms.size() and harbor.spots[0].light_energy > 8., "every beam carries a real spotlight")
	check(not is_equal_approx(harbor.period, aurora.period) and harbor.tint != aurora.tint, "each lighthouse has its own period and colour")
	check(absf(harbor.elapsed - aurora.elapsed) > 1., "the two lighthouses do not sweep in sync")
	check(harbor.glow.visible and harbor.glow.visibility_range_end >= 4000., "a distance flare is visible for kilometres")
	var before: float = harbor.rotor.rotation.y
	await frames(30)
	check(absf(angle_difference(before, harbor.rotor.rotation.y)) > .05, "the beam sweeps")
	# The flare surges when the beam points at the viewer and calms when it points away.
	var top: Vector3 = harbor.rotor.global_position
	camera.global_position = top + Vector3(600, 0, 0)
	var dir: Vector3 = (camera.global_position - top).normalized()
	var toward: float = fposmod(atan2(-dir.x, -dir.z) - harbor.global_rotation.y, TAU) * harbor.period / TAU
	harbor.elapsed = toward
	await frames(1)
	var aligned: float = harbor.glow_material.get_shader_parameter("intensity")
	harbor.elapsed = toward + harbor.period * .5
	await frames(1)
	var opposite: float = harbor.glow_material.get_shader_parameter("intensity")
	check(aligned > opposite * 3. and opposite > .05, "flare flashes toward the viewer (%.2f vs %.2f) and keeps a faint glow otherwise" % [aligned, opposite])
	world.ocean.hour = 12.
	await frames(10)
	check(not harbor.rotor.visible and not harbor.glow.visible and harbor.spots[0].light_energy < .01, "lamps are off in daylight")
	print("LIGHTHOUSE %d checks / %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
