extends "res://tests/archipelago_contract.gd"
## Physical cast: holding the button draws the rod back (more charge, further back) and holding longer
## casts further; releasing throws, the float leaves the rod tip on the forward stroke and flies an arc to
## the water; the aim mark is a faint ring on the water; first person keeps the rod in view.
## --headless --fixed-fps 60 --script res://tests/cast_contract.gd
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
const Waves=preload("res://scripts/world/wave_field.gd")

func _fish(pressed: bool) -> void:
	var e:=InputEventAction.new();e.action="fish";e.pressed=pressed;Input.parse_input_event(e)
	if pressed:Input.action_press("fish")
	else:Input.action_release("fish")

## Holds for `hold` frames, releases, follows the float; returns the cast record.
func _cast(hold: int) -> Dictionary:
	var g=game
	_fish(true)
	await frames(hold)
	var rec:={"charge":g.cast_charge,"hold":g.player.visual.cast_hold,"clip":g.player.visual.current,
		"pose":g.player.visual.animation.current_animation_position,"rod":g.player.visual._rod.visible,"marker":g.cast_marker.visible,"marker_scale":g.cast_marker.scale.x}
	_fish(false)
	await frames(2)
	rec.state=g.fishing.state
	var at_tip: bool=g.fishing_visual.bobber.global_position.distance_to(g.player.rod_tip())<.3
	rec.at_tip=at_tip
	var peak:=-100.;var frames_flying:=0
	while g.fishing.state==Fishing.State.CASTING and frames_flying<300:
		await physics_frame;frames_flying+=1
		peak=maxf(peak,g.fishing_visual.bobber.global_position.y)
	await frames(2)
	rec.peak=peak;rec.flight=frames_flying
	rec.landed=g.fishing_visual.bobber.global_position.distance_to(Vector3(g.fishing_visual.target.x,g.fishing_visual.bobber.global_position.y,g.fishing_visual.target.z))<.6
	rec.distance=Vector2(g.fishing_visual.target.x-g.player.global_position.x,g.fishing_visual.target.z-g.player.global_position.z).length()
	rec.after=g.fishing.state
	g.fishing.cancel();await frames(10)
	return rec

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var boat: CharacterBody3D=game.boat
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	game.player.yaw=0.
	game.world.ocean.process_mode=Node.PROCESS_MODE_DISABLED
	Waves.wind=.2
	var short: Dictionary=await _cast(12)
	var long: Dictionary=await _cast(90)
	check(long.clip=="ual/FishCast" and long.hold>.9 and long.pose>.4,"holding draws the rod back into the wind-up and holds it (clip %s, pose %.2f s)"%[long.clip,long.pose])
	check(short.pose<long.pose,"a short hold is a short wind-up (%.2f vs %.2f s)"%[short.pose,long.pose])
	check(long.rod,"the rod is in the hands during the wind-up")
	check(long.marker and long.marker_scale<1.6,"a faint aim ring lies on the water while charging (scale %.2f)"%long.marker_scale)
	check(long.state==Fishing.State.CASTING and long.at_tip,"on release the float starts at the rod tip")
	check(long.peak>game.player.rod_tip().y+.5,"the float flies an arc above the rod (peak %.1f m)"%long.peak)
	check(long.landed and long.after==Fishing.State.WAITING,"…and lands where it was aimed, then waits")
	check(long.distance>short.distance+10. and long.flight>short.flight,"a longer hold casts further and flies longer (%.0f m in %d frames vs %.0f m in %d)"%[long.distance,long.flight,short.distance,short.flight])
	# Wind: the same hold with the wind behind and in the face.
	Waves.wind=.9;Waves.direction=Vector2(0,-1)
	var tail: Dictionary=await _cast(90)
	Waves.direction=Vector2(0,1)
	var head: Dictionary=await _cast(90)
	check(tail.distance>head.distance+5.,"a following wind carries the cast further than a headwind (%.0f vs %.0f m)"%[tail.distance,head.distance])
	# First person: body hidden, rod visible.
	Waves.wind=.2
	game.player.first_person=true;await frames(3)
	_fish(true);await frames(40)
	check(game.player.visual.visible and not game.player.visual.model.visible and game.player.visual._rod.visible,"first person hides the body but keeps the rod in view")
	_fish(false);await frames(5)
	game.fishing.cancel();game.player.first_person=false;await frames(3)
	check(game.player.visual.model.visible,"third person shows the angler again")
	# Conditions under the float: dawn beats midday, a running engine scares fish, a school brings them.
	game.fishing_visual.target=boat.global_position+Vector3(0,0,-15)
	game.world.ocean.hour=6.5;var dawn: float=game._fishing_conditions().rate
	game.world.ocean.hour=12.5;var noon: float=game._fishing_conditions().rate
	check(dawn>noon*1.5,"dawn bites better than bright midday (%.2f vs %.2f)"%[dawn,noon])
	boat.engine_rpm=1.;var noisy: float=game._fishing_conditions().rate;boat.engine_rpm=0.
	check(noisy<noon*.5,"a running engine puts the fish off (%.2f)"%noisy)
	var school: Node3D=null
	for sc: Node3D in game.marine.fish_schools:
		if not sc.predator:school=sc;break
	if school!=null:
		school.mmi.visible=true;game.fishing_visual.target=Vector3(school.center.x,0,school.center.z)
		check(game._fishing_conditions().rate>noon*2.,"casting over a school multiplies the bites")
	# The new instrument: hidden when idle, shown while fishing, in the lower-right corner.
	var gauge: Control=game.hud.fight_gauge
	check(not gauge.visible,"the fishing instrument is hidden when not fishing")
	_fish(true);await frames(30);_fish(false);await frames(80)
	check(gauge.visible and gauge.state==2,"it appears while the float waits")
	var vp: Vector2=game.get_viewport().get_visible_rect().size
	check(gauge.get_global_rect().position.x>vp.x*.5 and gauge.get_global_rect().position.y>vp.y*.5,"it sits in the lower-right corner, clear of the centre")
	game.fishing.cancel();await frames(5)
	game.world.ocean.process_mode=Node.PROCESS_MODE_INHERIT
	print("CAST %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
