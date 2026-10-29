extends "res://tests/archipelago_contract.gd"
## Pirates hunt the boat, fire their cannon, come alongside and either take a tribute, plunder the hold,
## or flee from harpoons leaving a chest; a boat that gets far enough away loses them.
## --headless --fixed-fps 60 --script res://tests/pirates_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var boat: CharacterBody3D=game.boat;var inv: RefCounted=game.inventory;var pir: Node3D=game.pirates
	var sea:=Vector3(700,0,-500)
	boat.global_position=sea;boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	check(game.player.in_boat,"aboard at sea")
	pir.spawn_near(sea+Vector3(140,0,60))
	check(pir.state=="caçando" and is_instance_valid(pir.ship),"a pirate schooner appears and hunts the boat")
	var fired:=false;var t:=0
	while pir.state=="caçando" and t<60*60:
		await physics_frame;t+=1
		if not pir.balls.is_empty():fired=true
	check(fired,"on the way in it fires its cannon")
	check(pir.state=="abordando","it comes alongside within a minute (%.0f s)"%(t/60.))
	check(game._interaction_hint().begins_with("PIRATAS!"),"the hint offers tribute, harpoon or flight (%s)"%game._interaction_hint())
	inv.money=200;game.interact();await frames(3)
	check(pir.state=="fugindo" and inv.money==150,"E pays a quarter of the coins and they sheer off (money %d)"%inv.money)
	# Plunder: wait alongside.
	for k: int in 6:inv.catches.append({"id":"sardine","name":"Sardinha","weight":.2,"value":5})
	pir.spawn_near(boat.global_position+Vector3(12,0,0));pir.state="abordando";pir.clock=0.
	for i: int in 60*9:await physics_frame
	check(pir.state=="fugindo" and inv.catches.size()==3 and inv.money==100,"left alongside, they take half the hold and a third of the coins (%d catches, %d coins)"%[inv.catches.size(),inv.money])
	check(pir.raids==1,"the raid is counted")
	# Harpoons: three hits and they flee, leaving a chest.
	pir.spawn_near(boat.global_position+Vector3(60,0,0))
	for k: int in 3:pir.hit_ship()
	check(pir.state=="fugindo" and pir.chests.size()==1,"three harpoon hits and they flee, leaving a chest")
	var before: int=inv.money
	var chest: Node3D=pir.chests[0].node
	boat.global_position=Vector3(chest.global_position.x,0,chest.global_position.z);await frames(6)
	check(pir.chests.is_empty() and inv.money>before+80,"sailing over the chest picks up its coins (+%d)"%(inv.money-before))
	# Escape.
	pir.spawn_near(boat.global_position+Vector3(120,0,0))
	boat.global_position+=Vector3(-260,0,0)
	for i: int in 60*22:await physics_frame
	check(pir.state=="fugindo" or pir.state=="ausente","a boat that gets well clear loses them")
	# Not near home.
	pir.state="ausente";if is_instance_valid(pir.ship):pir.ship.queue_free()
	boat.global_position=Vector3(30,0,-60);pir.spawn_clock=0.;await frames(3)
	check(pir.state=="ausente","no pirates in the home waters")
	print("PIRATES %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
