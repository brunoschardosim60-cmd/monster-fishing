extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func run() -> void:
	var world := preload("res://scripts/world/coastal_world.gd").new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(23, 16, -36)
	camera.look_at(Vector3(0, 2, -1))
	camera.current = true
	for frame: int in range(8):
		await physics_frame
	var physics := world.get_world_3d().direct_space_state
	for pos: Vector3 in [Vector3(0,5,-17),Vector3(0,5,-8),Vector3(0,5,-6),Vector3(6,5,-7)]:
		var query := PhysicsRayQueryParameters3D.create(pos,pos - Vector3(0,8,0),1)
		var hit := physics.intersect_ray(query)
		check(not hit.is_empty(),"Walkable surface at " + str(pos))
		if not hit.is_empty():
			check((hit.normal as Vector3).y > 0.9,"Upward terrain normal at " + str(pos))
			check((hit.position as Vector3).y >= 1.2,"Safe ground height at " + str(pos))
	var water_query := PhysicsRayQueryParameters3D.create(Vector3(4,5,-23),Vector3(4,-5,-23),1)
	var bottom: Dictionary=physics.intersect_ray(water_query)
	check(bottom.is_empty() or bottom.position.y< -1.,"Boat berth has clearance above the underwater shelf")
	var walker := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	walker.add_child(collision)
	world.add_child(walker)
	walker.position = world.safe_spawn()
	for target: Vector3 in [Vector3(0,1.4,-7),Vector3(6,1.4,-7)]:
		for frame: int in range(300):
			var horizontal := Vector3(target.x - walker.position.x,0,target.z - walker.position.z)
			if horizontal.length() < 0.12:
				break
			walker.velocity = horizontal.normalized() * 3.0 + Vector3(0,-3,0)
			walker.move_and_slide()
			await physics_frame
		check(Vector2(walker.position.x-target.x,walker.position.z-target.z).length() < 0.2,"Walk from pier to market waypoint " + str(target))
	if "--visual-world" in OS.get_cmdline_user_args():
		for frame: int in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://tests/output")
		root.get_texture().get_image().save_png("res://tests/output/coastal-world.png")
		camera.position = Vector3(0,4.2,-13)
		camera.look_at(Vector3(0,2,-65))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/output/coast-from-pier.png")
	print("WORLD_SMOKE_FAILURES=" + str(failures))
	world.life.birdsong.stop();world.queue_free();await process_frame;OS.delay_msec(100)
	quit(failures)
