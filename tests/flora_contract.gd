extends "res://tests/archipelago_contract.gd"
## Remote islands carry varied, batched vegetation.  --headless --fixed-fps 60 --script res://tests/flora_contract.gd
const Flora=preload("res://scripts/world/biome_flora.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(10)
	var good:=true
	for kind: String in Flora.KINDS:
		var m:=Flora.mesh(kind)
		if m.get_surface_count()!=1 or m.get_faces().size()<60:good=false;push_error("bad flora mesh "+kind)
		var box:=m.get_aabb()
		if box.size.y<.5 or box.size.y>Flora.height_of(kind)*1.6 or box.size.y<Flora.height_of(kind)*.5:good=false;push_error("flora height off %s %.1f"%[kind,box.size.y])
	check(good,"all %d procedural plant meshes are valid and sized sensibly"%Flora.KINDS.size())
	var found:={};var instances:=0;var nodes:=0
	for node: Node in game.world.find_children("flora_*","MultiMeshInstance3D",true,false):
		found[node.name]=true;nodes+=1;instances+=(node as MultiMeshInstance3D).multimesh.instance_count
	check(found.size()>=8,"%d plant kinds appear across the islands"%found.size())
	check(instances>=150,"%d plants planted"%instances)
	check(nodes<=120,"plants are batched (%d multimesh nodes for %d plants)"%[nodes,instances])
	print("FLORA %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
