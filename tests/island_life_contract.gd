extends "res://tests/archipelago_contract.gd"
## Remote islands carry lakes, streams, grass, rocks, birds and animals.  --headless --fixed-fps 60 --script res://tests/island_life_contract.gd
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var w: Node=game.world
	var lakes:=get_nodes_in_group("lagoa")
	var streams:=get_nodes_in_group("riacho")
	check(lakes.size()>=6,"%d lakes and oases"%lakes.size())
	check(streams.size()>=2,"%d streams run to the coast"%streams.size())
	var dry:=true
	for lake: Node in lakes:
		var p: Vector3=(lake as Node3D).position
		if Layout.coast(Vector2(p.x,p.z)).x>-8.:dry=false
	check(dry,"every lake sits well inland")
	var tufts:=0;var cells:=0
	for n: Node in get_nodes_in_group("grama"):tufts+=(n as MultiMeshInstance3D).multimesh.instance_count;cells+=1
	check(tufts>=3000,"%d grass tufts in %d cells"%[tufts,cells])
	var birds:=0;var kinds:={}
	for n: Node in get_nodes_in_group("aves"):birds+=(n as MultiMeshInstance3D).multimesh.instance_count;kinds[(n as MultiMeshInstance3D).multimesh.mesh]=true
	check(birds>=60 and kinds.size()>=3,"%d birds of %d kinds orbit the islands"%[birds,kinds.size()])
	var animals:=0;var species:={}
	for n: Node in get_nodes_in_group("fauna"):animals+=(n as MultiMeshInstance3D).multimesh.instance_count;species[(n as MultiMeshInstance3D).multimesh.mesh]=true
	check(animals>=30 and species.size()>=5,"%d animals of %d species live on land"%[animals,species.size()])
	# Animals stand on dry ground.
	var wet:=0
	for n: Node in get_nodes_in_group("fauna"):
		var mm:=(n as MultiMeshInstance3D).multimesh
		for i: int in mm.instance_count:
			var o:=mm.get_instance_transform(i).origin
			if Layout.coast(Vector2(o.x,o.z)).x>0.:wet+=1
	check(wet==0,"no animal stands in the sea")
	await frames(60)
	print("ISLAND LIFE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
