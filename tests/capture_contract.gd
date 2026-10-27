extends "res://tests/archipelago_contract.gd"
## Physical capture: the hooked fish is a body in the water that fights (runs, comes closer as line is
## gained), the line stays tied to it, the rod bends with tension; landing lifts it to the hand without a
## second copy; keeping stows it, releasing puts it back in the water where it swims away; an escaped
## fish bolts and disappears. Every state ends with nothing stuck or invisible-but-active.
## --headless --fixed-fps 60 --script res://tests/capture_contract.gd
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
const Waves=preload("res://scripts/world/wave_field.gd")

func _hook(at: Vector3) -> void:
	var f=game.fishing
	game.fishing_visual.target=at;game.fishing_visual.cast_start=game.player.rod_tip();game.fishing_visual.cast_elapsed=0.
	f.start_cast("coast")
	f.advance(1.);f.advance(8.)
	f.strike()
	await frames(2)

## Plays the fight like a person: reel while the line is safe, ease off when it gets tight.
func _fight(max_frames: int) -> Dictionary:
	var f=game.fishing;var stats:={"closest":1000.,"start":-1.,"max_bend":0.,"tied":true,"under":0,"frames":0}
	for i: int in max_frames:
		if f.state!=Fishing.State.REELING:break
		if f.tension<.62:Input.action_press("fish")
		else:Input.action_release("fish")
		await physics_frame
		var h: Node3D=game.hooked
		var d: float=Vector2(h.global_position.x-game.player.global_position.x,h.global_position.z-game.player.global_position.z).length()
		if stats.start<0.:stats.start=d
		stats.closest=minf(stats.closest,d)
		stats.max_bend=maxf(stats.max_bend,game.player.visual._bend_now)
		if h.global_position.y<Waves.height_at(h.global_position)-.1:stats.under+=1
		if h.mouth.distance_to(h.global_position)>h.length_m+.2:stats.tied=false
		stats.frames+=1
	Input.action_release("fish")
	return stats

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var boat: CharacterBody3D=game.boat
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	check(game.player.in_boat,"angler aboard at open sea")
	var spot: Vector3=boat.global_position+Vector3(0,0,-16)
	# 1) Fight and keep.
	await _hook(spot)
	check(game.fishing.state==Fishing.State.REELING and game.hooked.visible and game.hooked.mode=="fight","the hooked fish appears in the water when the hook is set")
	check(not game.surface_fish.visible,"no second fish breaching at the same time")
	var s: Dictionary=await _fight(60*90)
	check(s.under>s.frames*.4,"the fish fights below the surface most of the time (%d/%d frames)"%[s.under,s.frames])
	check(s.closest<s.start-4.,"line gained brings the fish closer (%.1f → %.1f m)"%[s.start,s.closest])
	check(s.tied,"the line stays tied to the fish's mouth")
	check(s.max_bend>.3,"the rod bends under tension (%.2f)"%s.max_bend)
	check(game.fishing.state==Fishing.State.CAUGHT and not game.pending_catch.is_empty(),"the fish is landed (state %d)"%game.fishing.state)
	check(game.hooked.landing() and not game.catch_display.visible,"landing: lifted out on the line, the trophy in hand not yet shown")
	await frames(45)
	check(not game.hooked.visible and game.catch_display.visible,"after the lift only the fish in hand is visible")
	var count: int=game.inventory.count()
	game.finish_catch(false);await frames(60)
	check(game.inventory.count()==count+1 and not game.catch_display.visible and game.pending_catch.is_empty(),"keeping stows exactly one fish")
	await frames(180)
	# 2) Fight and release.
	await _hook(spot+Vector3(5,0,0))
	s=await _fight(60*90)
	await frames(45)
	if game.fishing.state==Fishing.State.CAUGHT or not game.pending_catch.is_empty():
		count=game.inventory.count()
		game.finish_catch(true);await frames(3)
		check(game.hooked.visible and game.hooked.mode=="release" and not game.catch_display.visible,"releasing puts the same fish back in the water")
		var start: Vector3=game.hooked.global_position
		await frames(150)
		check(game.hooked.global_position.distance_to(start)>1.5 and game.hooked.global_position.y<Waves.height_at(game.hooked.global_position),"the released fish swims away under water")
		await frames(150)
		check(not game.hooked.visible and game.inventory.count()==count,"…and disappears without entering the hold")
	else:
		check(false,"second fish should have been landed (state %d)"%game.fishing.state)
	await frames(180)
	# 3) Escape: hook and never reel → slack line.
	await _hook(spot+Vector3(-5,0,0))
	Input.action_release("fish")
	for i: int in 60*8:
		if game.fishing.state!=Fishing.State.REELING:break
		await physics_frame
	check(game.fishing.state==Fishing.State.ESCAPED and game.hooked.mode=="escape","a slack line lets the fish escape and it bolts")
	await frames(150)
	check(not game.hooked.visible and game.pending_catch.is_empty() and not game.fishing_visual.visible,"the escaped fish leaves nothing behind: no fish, no line")
	print("CAPTURE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
