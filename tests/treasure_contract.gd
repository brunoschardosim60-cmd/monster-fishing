extends "res://tests/archipelago_contract.gd"
## Treasure maps mark an X on an island; digging there pays out. Bottles at sea carry maps. The chart
## table in a boat's cabin opens the world map.
## --headless --fixed-fps 60 --script res://tests/treasure_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var tr: Node3D=game.treasure;var inv: RefCounted=game.inventory;var boat: CharacterBody3D=game.boat
	var text: String=tr.give_map()
	check(tr.maps.size()==1 and "MAPA DO TESOURO" in text,"a treasure map is added (%s)"%text)
	var m: Dictionary=tr.maps[0]
	var p: Vector3=m.pos
	check(Layout.ground(Vector2(p.x,p.z))>1.5 and not Layout.in_town(Vector2(p.x,p.z)),"the X is on dry land outside the town (%.0f, %.0f)"%[p.x,p.z])
	check(is_instance_valid(m.node) and (m.node as Node3D).global_position.distance_to(p)<.1,"an X of red planks marks the spot")
	check(tr.open_maps().size()==1,"it is listed for the world map")
	game.player.global_position=p+Vector3(.6,.2,.3);game.player.velocity=Vector3.ZERO;await frames(3)
	check(game._interaction_hint()=="E · Cavar o tesouro","standing on the X, E offers to dig (%s)"%game._interaction_hint())
	var before: int=inv.money
	game.interact();await frames(3)
	check(bool(m.found) and inv.money>=before+160,"digging brings up the chest (+%d coins)"%(inv.money-before))
	check(tr.open_maps().is_empty() and game._interaction_hint()!="E · Cavar o tesouro","a dug treasure is gone from the map")
	# Saved maps come back.
	tr.give_map()
	var saved:={"maps":[{"pos":tr.maps[1].pos,"island":tr.maps[1].island,"found":false},{"pos":m.pos,"island":m.island,"found":true}],"found":1}
	var other=load("res://scripts/world/treasure.gd").new();other.game=game;game.add_child(other);other.restore(saved)
	check(other.maps.size()==2 and other.open_maps().size()==1 and is_instance_valid(other.open_maps()[0].node),"saved maps restore with their X marks")
	other.queue_free()
	# A bottle at sea.
	boat.global_position=Vector3(600,0,-400);game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(4)
	tr.spawn_bottle(boat.global_position+Vector3(30,0,0))
	check(is_instance_valid(tr.bottle),"a bottle drifts at sea")
	boat.global_position=tr.bottle.global_position;await frames(4)
	check(tr.maps.size()==3 and not is_instance_valid(tr.bottle),"sailing over it fishes out a map")
	# Chart table in the sailboat's cabin.
	inv.owned_boats.append("veleiro");inv.boat_id="veleiro";Economy.apply(inv,boat,game.fishing);await frames(6)
	if not game.player.on_deck:game.toggle_deck()
	var c: Dictionary=boat.hull_spec.cabin
	game.player.deck_local=c.hatch;game.interact();await frames(4)
	check(not game.player.cabin.is_empty(),"down in the cabin")
	game.player.deck_local=boat.cabin_node.get_meta("chart");await frames(3)
	check(game._interaction_hint()=="E · Abrir a carta náutica","at the chart table, E opens the chart (%s)"%game._interaction_hint())
	game.interact();await frames(2)
	check(game.hud.map_view.visible,"the world map opens")
	print("TREASURE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
