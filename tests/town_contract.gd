extends "res://tests/archipelago_contract.gd"
## The town spreads over the main island; buildings sit on the ground; the bridge is walkable;
## lighthouses are tall and stand on the distant islands too.  --headless --fixed-fps 60 --script res://tests/town_contract.gd
const House=preload("res://scripts/world/town_house.gd")

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var town=game.world.village.town
	check(town.houses.size()>=45,"%d new buildings across the main island"%town.houses.size())
	var spread:=true
	for d in town.districts:
		if (d.houses as Array).size()<4:spread=false
	check(town.districts.size()==5 and spread,"five districts, each with at least four buildings")
	var styles:={}
	for h: Node3D in town.houses:styles[String(h.name).get_slice("_",1)]=true
	check(styles.size()>=7,"%d building styles (%s)"%[styles.size(),", ".join(styles.keys())])
	var grounded:=0;var bodies:=0
	for h: Node3D in town.houses:
		var ground:=Layout.height(Vector2(h.position.x,h.position.z))
		var stilts: bool=Layout.coast(Vector2(h.position.x,h.position.z)).x>0.  # over the water: stilts or a stone pier
		if (stilts and h.position.y>ground) or (not stilts and h.position.y>=ground and h.position.y<ground+3.):grounded+=1
		if not h.find_children("*","StaticBody3D",true,false).is_empty():bodies+=1
	check(grounded==town.houses.size(),"every building sits on its ground or on stilts (%d/%d)"%[grounded,town.houses.size()])
	check(bodies==town.houses.size(),"every building is solid")
	var overlap:=0
	for i: int in town.footprints.size():
		for j: int in range(i+1,town.footprints.size()):
			var a: Vector3=town.footprints[i];var b: Vector3=town.footprints[j]
			if Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y))<a.z+b.z:overlap+=1
	check(overlap==0,"no two buildings overlap (%d do)"%overlap)
	var streets:=0
	for n: Node in town.get_children():
		if String(n.name).begins_with("Rua"):streets+=1
	check(streets>=40,"%d cobbled streets"%streets)
	var props:=0;var kinds:={}
	for n: Node in town.get_children():
		if String(n.name).begins_with("CC0_"):props+=1;kinds[String(n.name).trim_prefix("CC0_").rstrip("0123456789@")]=true
	check(props>=150 and kinds.size()>=10,"%d CC0 props of %d kinds dress the streets, gardens and beaches"%[props,kinds.size()])
	check(town.residents.size()>=10,"%d townspeople live in the districts"%town.residents.size())
	# Walk over the stone bridge from the village to the west district.
	game.player.global_position=Vector3(-55,2.,-4);game.player.velocity=Vector3.ZERO;await frames(10)
	var crossed:=await walk_to(Vector3(-98,2.,-4))
	check(crossed and not game.player.swimming,"the Ponte do Poente is walkable end to end")
	var starts: Array=[]
	for r in town.residents:starts.append(r.position)
	await frames(400)
	var walking:=0
	for i: int in town.residents.size():
		if town.residents[i].position.distance_to(starts[i])>1.:walking+=1
	check(walking>=town.residents.size()/2,"townspeople walk their streets (%d)"%walking)
	game.world.ocean.hour=23.;await frames(160)
	check(House.windows!=null and House.windows.emission_energy_multiplier>1.,"windows light up at night")
	check(game.world.lighthouse.tower_height>=24. and game.world.lighthouse.scale.x>=2.,"the home lighthouse is a big tower")
	var remote: Array=game.world.remote_lighthouses.lighthouses
	var on_land:=0
	for l: Node3D in remote:
		if Layout.coast(Vector2(l.position.x,l.position.z)).x<0. and l.position.y>-.5:on_land+=1
	check(remote.size()==2 and on_land==remote.size(),"%d lighthouses on the distant islands, all on land"%remote.size())
	var high:=0
	for l: Node3D in remote:
		if l.position.y>15.:high+=1
	check(high==remote.size(),"distant lighthouses stand on high ground (%d of %d)"%[high,remote.size()])
	var periods:={}
	for l: Node3D in remote:periods[l.period]=true
	check(periods.size()>=2,"distant lighthouses each have their own rhythm")
	print("TOWN %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
