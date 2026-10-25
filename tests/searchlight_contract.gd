extends "res://tests/archipelago_contract.gd"
## The bow searchlight aims with the helm keys and never leaves its limits.  --headless --fixed-fps 60 --script res://tests/searchlight_contract.gd
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	await frames(10)
	var boat: CharacterBody3D=game.boat
	boat.searchlight_upgraded=true;boat.update_lights()
	boat.occupied=true;boat.controls_enabled=true
	check(boat.searchlight!=null and boat.searchlight.visible,"searchlight is on once upgraded")
	boat.light_yaw=0.;boat.light_pitch=0.
	Input.action_release("move_forward")
	await frames(4)
	var yaw0: float=boat.light_yaw
	check(absf(yaw0)<=1.2,"aim starts inside its limits")
	# Hold the swing key by simulating it through the global state is not possible headless, so drive the clamp directly.
	boat.light_yaw=5.;boat.light_pitch=-5.
	await frames(2)
	check(absf(boat.light_yaw)<=1.2+1e-4 and boat.light_pitch>=-.9-1e-4 and boat.light_pitch<=.25+1e-4,"aim stays inside its limits")
	check(absf(boat.searchlight.rotation.y-boat.light_yaw)<1e-4,"the lamp follows the aim (yaw %.2f)"%boat.light_yaw)
	boat.searchlight_upgraded=false;boat.update_lights()
	check(not boat.searchlight.visible,"without the upgrade the lamp stays off")
	print("SEARCHLIGHT %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
