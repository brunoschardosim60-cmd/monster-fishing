extends "res://tests/archipelago_contract.gd"
## Reefs, crabs and wrecks sit on the visible sea floor.  --headless --fixed-fps 60 --script res://tests/seabed_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var life=game.world.get_node("VidaNoFundo")
	check(life.reefs.size()>=12,"%d reefs on the sea floor"%life.reefs.size())
	check(life.reefs.size()>0 and Vector2(life.reefs[0].x,life.reefs[0].z).length()<200.,"a reef lies close to the harbour")
	var under:=true
	for c: Vector3 in life.reefs:
		if c.y>-1. or absf(c.y-life.floor_at(Vector2(c.x,c.z)))>.05:under=false
	check(under,"every reef centre is under water and on the visible floor")
	check(life.wrecks.size()>=2,"%d sunken boats"%life.wrecks.size())
	check(life.crabs.size()>=15,"%d crabs on the sand"%life.crabs.size())
	var pieces:=0;var nodes:=0;var kinds:={}
	for child: Node in life.get_children():
		if child is MultiMeshInstance3D:
			nodes+=1;pieces+=(child as MultiMeshInstance3D).multimesh.instance_count
			kinds[String(child.name).get_slice("_",0)]=true
	check(kinds.size()>=6,"%d kinds of sea-floor life (rock, brain and branch coral, kelp, starfish, urchin)"%kinds.size())
	check(pieces>=500,"%d pieces of reef life"%pieces)
	check(kinds.has("fan") and kinds.has("sponge") and kinds.has("anemone"),"sea fans, sponges and anemones grow on the reefs (%s)"%", ".join(kinds.keys()))
	var biomes:={}
	for b: String in life.reef_biomes:biomes[b]=int(biomes.get(b,0))+1
	check(biomes.size()>=3,"reefs differ by sea: %s"%str(biomes))
	# Kelp must stay below the surface (MultiMesh data is not kept by the headless renderer, so use the record).
	var dry:=0
	for top: float in life.kelp_tops:
		if top>0.:dry+=1
	check(life.kelp_tops.size()>=60 and dry==0,"%d kelp clumps, none breaks the surface (%d do)"%[life.kelp_tops.size(),dry])
	print("SEABED %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
