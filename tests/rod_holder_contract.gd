extends "res://tests/archipelago_contract.gd"
## Rod holders: each hull has its own number of holders on the rail; with a line out the angler puts the
## rod in a holder (E) and it keeps fishing; on a bite the rod bends and shakes and the bell rings; the
## angler takes the rod (E) and fights the fish; left alone the fish gets away. Nothing is caught by itself.
## --headless --fixed-fps 60 --script res://tests/rod_holder_contract.gd
const Fishing=preload("res://scripts/fishing/fishing_system.gd")

func _to_holder(i: int) -> void:
	var p: Vector3=(game.holders.holders[i].node as Node3D).position
	var deck: Dictionary=game.boat.deck_layout()
	game.player.deck_local=Vector3(clampf(p.x,-float(deck.x),float(deck.x)),float(deck.y),clampf(p.z,float(deck.z0),float(deck.z1)))
	await frames(3)

func _cast_line() -> void:
	var f=game.fishing
	game.fishing_visual.target=game.boat.global_position+game.boat.global_basis.x*9.
	f.start_cast("coast");f.advance(2.)

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var boat: CharacterBody3D=game.boat
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	game.toggle_deck();await frames(3)
	var holders: Node3D=game.holders
	check(holders.holders.size()==2,"the launch has two rod holders on its stern rails (%d)"%holders.holders.size())
	# Put a rod in a holder.
	await _cast_line()
	check(game.fishing.state==Fishing.State.WAITING,"line out and waiting")
	await _to_holder(0)
	check(game._interaction_hint()=="E · Pôr a vara no suporte","beside the holder the prompt offers to set the rod")
	game.interact();await frames(3)
	var h: Dictionary=holders.holders[0]
	check(h.state=="set" and (h.rod as Node3D).visible and game.fishing.state==Fishing.State.IDLE and game.player.in_boat,"E sets the rod in the holder; the angler's hands are free (still aboard)")
	await frames(20)
	check((h.bob as Node3D).visible and absf((h.bob as Node3D).global_position.y-preload("res://scripts/world/wave_field.gd").height_at((h.bob as Node3D).global_position))<.4,"its float rides the water off the side")
	check(game._holder_rate(h.water)>0.,"a set line has its own chance of a bite at that spot")
	# A bite on the set rod, with the bell fitted.
	game.inventory.equipment["bell"]=1
	holders._bite(0);await frames(20)
	var bent: float=absf(((h.joints as Array).back() as Node3D).rotation.x)
	check(h.state=="biting" and bent>.1,"the rod tip bends and shakes when a fish takes it (%.2f rad)"%bent)
	check(game.hud.toast.text.contains("sino"),"the bell rings and the skipper is told (%s)"%game.hud.toast.text)
	check(game.inventory.count()==0,"nothing is caught by itself")
	check(game._interaction_hint().contains("PEIXE"),"the prompt calls the angler to the rod")
	game.interact();await frames(5)
	check(game.fishing.state==Fishing.State.REELING and game.hooked.visible and h.state=="empty","E takes the rod and the fight begins with the fish in the water")
	game.fishing.cancel();await frames(150)
	# Left alone, the fish shakes the hook and the bait is gone.
	await _cast_line();game.interact();await frames(3)
	check(h.state=="set","rod set again")
	holders._bite(0);h.weight=2.
	for k: int in 60*20:
		await physics_frame
		if h.state!="biting":break
	check(h.state=="spent" and game.inventory.count()==0,"an unattended fish gets away and nothing enters the hold")
	game.interact();await frames(3)
	check(h.state=="empty","E reels the empty rod in")
	# Other hulls carry a different number of holders.
	var counts:={}
	for id: String in ["canoa","veleiro","escuna"]:
		game.inventory.owned_boats.append(id);game.inventory.boat_id=id;Economy.apply(game.inventory,boat,game.fishing);await frames(3)
		counts[id]=holders.holders.size()
	check(counts.canoa==1 and counts.veleiro==3 and counts.escuna==4,"holders by hull: canoe 1, sloop 3, schooner 4 (%s)"%str(counts))
	print("ROD_HOLDERS %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
