extends "res://tests/archipelago_contract.gd"
## Only fishing shops get a furnished interior: counter, rods, bait tank, ice chest and a shopkeeper.
## --headless --fixed-fps 60 --script res://tests/fishing_shop_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var village=game.world.village
	var shops: Array[Node3D]=[]
	var others_furnished:=0
	for b: Node3D in village.buildings:
		if b.use=="shop":shops.append(b)
		elif b.interior!=null:others_furnished+=1
	check(shops.size()==3,"three fishing shops: Casa das Marés and one in each big district (%d)"%shops.size())
	check(others_furnished==0,"no other building gets the shop interior")
	var furnished:=0
	for s: Node3D in shops:
		if s.interior!=null and s.interior.get_child_count()>=120 and s.keeper!=null:furnished+=1
	check(furnished==shops.size(),"every shop has a furnished sales floor and a shopkeeper (%d)"%furnished)
	var labels:={}
	for n: Node in shops[0].interior.find_children("*","Label3D",true,false):labels[(n as Label3D).text]=true
	check(labels.has("ISCA VIVA") and labels.has("PEIXE DO DIA"),"bait tank and ice chest are signed")
	var fish: int=shops[0].interior.find_children("PeixeNoGelo*","Node3D",false,false).size()
	check(fish>=5,"%d fish lie on ice in the chest"%fish)
	# Walk into a district shop, up to the counter, and open the shop.
	var shop: Node3D=village.town.shops[0]
	game.player.global_position=shop.entry.global_position+shop.global_basis*Vector3(0,.3,-2.);game.player.velocity=Vector3.ZERO;await frames(10)
	check(await walk_to(shop.service.global_position,400),"the district shop is walkable from its door to the counter")
	game.interact();await frames(3)
	check(game.hud.service_open and game.service_id.begins_with("gear"),"pressing E at the counter opens the fishing shop (%s)"%game.service_id)
	game.hud.close_service();await frames(3)
	# The counter is solid: the player cannot walk through to the shopkeeper's side.
	var behind:=shop.to_global(Vector3(0,.2,shop.depth*.5-.6))
	await walk_to(behind,240)
	check(shop.to_local(game.player.global_position).z<shop.depth*.5-1.55,"the counter blocks the way behind it")
	var start: Vector3=shop.keeper.position
	await frames(360)
	var k: Vector3=shop.keeper.position
	check(k.distance_to(start)>.5 and k.z>shop.depth*.5-1.2 and absf(k.x)<shop.width*.5,"the shopkeeper paces behind the counter (moved %.1f m)"%k.distance_to(start))
	print("FISHING SHOP %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
