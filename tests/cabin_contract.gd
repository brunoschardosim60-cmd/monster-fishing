extends "res://tests/archipelago_contract.gd"
## Cabins below deck on the sailboat and the schooner: E at the hatch goes down into a furnished room
## (table, berths, galley…), walked in first person, with its own walls and furniture; E at the foot of
## the ladder comes back up. --headless --fixed-fps 60 --script res://tests/cabin_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var boat: CharacterBody3D=game.boat;var inv=game.inventory
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	check(not boat.hull_spec.has("cabin") and boat.cabin_node==null,"the small launch has no cabin below")
	for id: String in ["veleiro","escuna"]:
		inv.owned_boats.append(id);inv.boat_id=id;Economy.apply(inv,boat,game.fishing);await frames(5)
		var c: Dictionary=boat.hull_spec.cabin
		var node: Node3D=boat.cabin_node
		check(node!=null and not node.visible and (node.get_meta("blocks",[]) as Array).size()>=3,"%s: a furnished cabin is built below, hidden until someone goes down (%d pieces of furniture)"%[id,(node.get_meta("blocks",[]) as Array).size()])
		if game.player.on_deck==false:game.toggle_deck();await frames(3)
		game.player.deck_local=c.hatch+Vector3(0,0,.1);await frames(3)
		check(game._interaction_hint()=="E · Descer à cabine","%s: at the hatch, E offers to go below"%id)
		game.interact();await frames(30)
		var local: Vector3=boat._hull.to_local(game.player.global_position)
		check(not game.player.cabin.is_empty() and node.visible and absf(local.y-float(c.floor))<.05,"%s: E takes you down to the cabin floor"%id)
		check(game.player.arm.spring_length<.6 and not game.player.visual.model.visible,"%s: below decks the view is first person"%id)
		# Walk about: the walls and furniture stop you.
		var inside_ok:=true
		for k: int in 240:
			game.player.deck_local+=Vector3(sin(float(k)*.07),0,cos(float(k)*.05))*.08
			await physics_frame
			var l: Vector3=game.player.deck_local
			var r: Rect2=c.rect
			if l.x<r.position.x or l.x>r.end.x or l.z<r.position.y or l.z>r.end.y:inside_ok=false
			for b: Rect2 in node.get_meta("blocks",[]):
				if b.grow(-.15).has_point(Vector2(l.x,l.z)):inside_ok=false
		check(inside_ok,"%s: walking about stays inside the walls and off the furniture"%id)
		check(not game.can_cast(),"%s: no casting from below decks"%id)
		var cam_y: float=game.player.camera.global_position.y
		var ceiling_y: float=boat._hull.to_global(Vector3(0,float(c.ceiling),0)).y
		check(cam_y<ceiling_y,"%s: the eye stays under the deck beams"%id)
		game.player.deck_local=c.foot;await frames(3)
		check(game._interaction_hint()=="E · Subir ao convés","%s: at the foot of the ladder, E offers to go up"%id)
		game.interact();await frames(30)
		check(game.player.cabin.is_empty() and not node.visible and game.player.arm.spring_length>2.,"%s: back on deck, the usual view"%id)
	print("CABIN %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
