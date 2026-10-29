extends "res://tests/archipelago_contract.gd"
## The yard's sales pier: every boat for sale floats moored bow-in beside the pier with a priced board.
## E at a board buys the boat (or switches to one you own) and the yard brings it to the berth.
## --headless --fixed-fps 60 --script res://tests/showroom_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var inv: RefCounted=game.inventory;var yard=game.world.village.shipyard;var room: Node3D=yard.showroom
	game.start_career();await frames(4)
	check(room.displays.size()==Economy.BOATS.size(),"every boat the yard sells is moored at the sales pier (%d)"%room.displays.size())
	var dry: Array[String]=[];var clash: Array[String]=[]
	for id: String in room.displays:
		var node: Node3D=room.displays[id].node
		var p:=node.global_position
		var spec: Dictionary=preload("res://scripts/boats/hull_classes.gd").spec(str(Economy.BOATS[id].get("model","tripo")))
		var L: float=float(spec.get("model_length",spec.length))*float(Economy.BOATS[id].scale)
		for t: float in [-.5,0.,.5]:
			var q:=p-node.global_basis.z*L*t
			if Layout.ground(Vector2(q.x,q.z))>-float(spec.get("immersion",.5))-.3:dry.append("%s(%.1f)"%[id,Layout.ground(Vector2(q.x,q.z))]);break
		if Vector2(p.x,p.z).distance_to(Vector2(yard.berth.x,yard.berth.z))<L*.5+9.:clash.append(id)
	check(dry.is_empty(),"each display boat lies in enough water along its whole length %s"%str(dry))
	check(clash.is_empty(),"…and none blocks the berth %s"%str(clash))
	check(not room.displays.canoa.node.visible and room.displays.aurora.node.visible,"the boat you use is not on show; the rest are")
	check("240" in room.displays.aurora.board.text and "EM USO" in room.displays.canoa.board.text,"boards show the price, and which one is yours (%s)"%room.displays.aurora.board.text.replace("\n"," / "))
	await frames(30)
	var d: Dictionary=room.displays.veleiro
	check(absf(d.node.global_position.y-(Waves.height_at(d.node.global_position)-float(d.draft)))<.25,"display boats float at the waterline")
	# Walk to the lancha's board.
	game.player.global_position=room.displays.aurora.at+Vector3(.4,0,.3);await frames(3)
	check(game._interaction_hint().begins_with("E · Comprar Lancha Aurora"),"at its board, E offers the lancha (%s)"%game._interaction_hint())
	game.interact();await frames(3)
	check(inv.money==Economy.START_MONEY and inv.boat_id=="canoa","with too few coins nothing is sold")
	inv.money=300;inv.changed.emit();game.interact();await frames(5)
	check(inv.boat_id=="aurora" and inv.money==60 and "canoa" in inv.owned_boats,"buying at the pier: 240 coins, the lancha is yours and the canoe kept")
	check(Vector2(game.boat.global_position.x,game.boat.global_position.z).distance_to(Vector2(yard.berth.x,yard.berth.z))<1. and yard.in_berth(game.boat.global_position),"the yard brings the new boat round to its berth")
	check(not room.displays.aurora.node.visible and room.displays.canoa.node.visible and "SEU" in room.displays.canoa.board.text,"the canoe now waits at the pier, marked as yours")
	game.player.global_position=room.displays.canoa.at;await frames(3)
	check(game._interaction_hint().begins_with("E · Usar Canoa"),"at the canoe's board, E offers to switch back (%s)"%game._interaction_hint())
	game.interact();await frames(5)
	check(inv.boat_id=="canoa" and inv.money==60,"switching to an owned boat is free")
	print("SHOWROOM %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
