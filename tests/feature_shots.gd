extends SceneTree
## In-game captures of specific features, for reviewing art changes.
## godot --path . --script res://tests/feature_shots.gd -- <out_dir> [scenario ...]
## Scenarios: fleet, rowboat, serpent, creatures, trap, whale, squid, town
var view: SubViewport
var camera: Camera3D
var game: Node3D
var out_dir:="/tmp"
func _initialize() -> void:call_deferred("run")

func shot(id: String,eye: Vector3,target: Vector3,frames: int=3) -> void:
	camera.global_position=eye;camera.look_at(target)
	for i: int in frames:await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out_dir+"/"+id+".png");print("SHOT ",id)

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	out_dir=args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	view=SubViewport.new();view.size=Vector2i(960,560);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.hide();game.set_process_input(false);game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;camera=Camera3D.new();camera.far=6000.;camera.fov=60.;view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=15.5
	for i: int in 30:await process_frame
	var wanted:=args.slice(1)
	for id: String in ["fleet","rowboat","serpent","creatures","trap","whale","squid","night","clouds","kraken","storm","whirl","home","marks","helm","classes","escuna","fight","reef","reefdbg","poses","farois"]:
		if wanted.is_empty() or id in wanted:await call("_"+id)
	quit(0)

func _sea_point() -> Vector3:
	return Vector3(140,0,-330)

func _ships(kind: String) -> Array:
	var out:=[]
	for ship in game.world.traffic.vessels:
		if ship.kind==kind:out.append(ship)
	return out

func _park(ship: Node3D,at: Vector3,yaw: float) -> void:
	ship.set_physics_process(false);ship.global_position=at;ship.rotation=Vector3(0,yaw,0)
	ship.hull.position=Vector3.ZERO;ship.hull.rotation=Vector3.ZERO

func _fleet() -> void:
	var p:=_sea_point()
	var g: Node3D=_ships("gigante")[0];_park(g,p+Vector3(0,0,-260),.6)
	await shot("fleet_container",p+Vector3(150,30,-120),p+Vector3(0,15,-260))
	await shot("fleet_container_close",g.global_position+g.global_basis.x*90.+g.global_basis.z*40.+Vector3(0,30,0),g.global_position+Vector3(0,20,0))
	var c: Node3D=_ships("cargueiro")[0];_park(c,p+Vector3(-120,0,-80),-1.)
	await shot("fleet_cargo",p+Vector3(-40,14,-10),p+Vector3(-120,6,-80))
	var s: Node3D=_ships("galeao")[0];_park(s,p+Vector3(60,0,-40),2.2)
	await shot("fleet_galleon",p+Vector3(110,8,10),p+Vector3(60,12,-40))
	await shot("fleet_galleon_deck",s.global_position+s.global_basis.x*18.+s.global_basis.z*12.+Vector3(0,9,0),s.global_position+Vector3(0,4,0))
	await shot("fleet_galleon_side",s.global_position+s.global_basis.x*70.+Vector3(0,3,0),s.global_position+Vector3(0,10,0))

func _rowboat() -> void:
	var p:=_sea_point()
	var list:=_ships("bote_remo")
	for i: int in list.size():_park(list[i],p+Vector3(10+float(i)*7.,0,20),.8+float(i))
	await shot("rowboat",p+Vector3(14,3.5,30),p+Vector3(12,0,20))
	await shot("rowboat_top",p+Vector3(12,9,24),p+Vector3(11,0,20))
	var b: Node3D=list[0]
	for person in b.crew:
		var body: MeshInstance3D=person.visual.model.find_children("*","MeshInstance3D",true,false)[0]
		print("crew ",person.role," pack ",person.visual.backpack.visible," mesh ",body.mesh.resource_path)
	for k: int in 3:
		for i: int in 26:await process_frame
		await shot("rowboat_side_%d"%k,b.global_position+b.global_basis.x*3.2+Vector3(0,1.4,0),b.global_position+Vector3(0,.6,0),1)

func _serpent() -> void:
	var lairs: Node3D=game.lairs
	for lair: Dictionary in lairs.lairs:
		if lair.kind!="serpente":continue
		var c: Vector3=lair.center
		game.boat.global_position=c+Vector3(40,0,0)
		var node: Node3D=lair.node;node.visible=true
		lair.state="caca";lair.clock=6.;lair.pos=c+Vector3(5,0,0)
		for i: int in 40:await physics_frame
		var at: Vector3=node.global_position
		await shot("serpent",game.boat.global_position+Vector3(10,6,18),at+Vector3(0,8,0),3)
		await shot("serpent_far",game.boat.global_position+Vector3(70,25,60),at+Vector3(0,6,0),3)

func _creatures() -> void:
	var sea: Node3D=game.marine.creatures
	var t: Dictionary=sea.turtles[0];var tn: Node3D=t.node
	for i: int in 20:await physics_frame
	var at:=tn.global_position
	await shot("turtle",at+Vector3(2.2,.6,1.6),at,2)
	await shot("turtle_top",at+Vector3(.5,4.,.5),at,2)
	var j: Dictionary=sea.jellies[0];var jn: Node3D=j.node
	var m: Node3D=j.members[0]
	await shot("jelly",m.global_position+Vector3(1.6,.4,1.6),m.global_position+Vector3(0,-.3,0),2)
	game.world.ocean.hour=22.
	for i: int in 10:await process_frame
	await shot("jelly_night",m.global_position+Vector3(2.5,.8,2.5),m.global_position+Vector3(0,-.3,0),2)
	game.world.ocean.hour=15.5
	for school in game.marine.fish_schools:
		if str(school.species).begins_with("tubarao"):
			var f: Node3D=school
			var c: Vector3=school.center
			await shot("shark",c+Vector3(6,1,6),c,4)
			break

func _trap() -> void:
	var gear: Node3D=game.gear
	var at:=Vector3(0,0,0)
	# find a 6-12 m deep spot near the start
	for k: int in 400:
		var q:=Vector2(cos(float(k)*.7)*float(40+k),sin(float(k)*.7)*float(40+k))
		var b: float=game.marine._seabed(q)
		if b<-6. and b>-12.:at=Vector3(q.x,0,q.y);break
	game.boat.global_position=at+Vector3(-3,0,0)
	game.inventory.traps=1;game.player.in_boat=false
	game.player.global_position=at+Vector3(-3,0,0)
	var r: String=gear.trap_action();print(r)
	var t: Dictionary=gear.traps[0];t.soak=gear.TRAP_SOAK+1.
	for i: int in 3:await physics_frame
	var cage: Node3D=(t.node as Node3D).get_node("Gaiola")
	await shot("trap_full",cage.global_position+Vector3(1.4,.8,1.4),cage.global_position,2)
	print(gear.trap_action())
	for i: int in 200:await physics_frame
	await shot("trap_hauled",cage.global_position+Vector3(2.,1.,2.),cage.global_position,2)

func _whale() -> void:
	var p:=_sea_point()
	var w: Node3D=game.world.sea_events._build_whale();game.world.add_child(w);w.global_position=p+Vector3(0,-.6,-30);w.rotation.y=.9
	for i: int in 30:await process_frame
	await shot("whale",w.global_position+Vector3(12,4,8),w.global_position,2)
	await shot("whale_under",w.global_position+Vector3(14,-4,6),w.global_position,2)
	w.queue_free()
	for lair: Dictionary in game.lairs.lairs:
		if lair.kind!="leviata":continue
		var node: Node3D=lair.node;node.visible=true;node.global_position=p+Vector3(0,-4,-90);node.rotation.y=.6
		for i: int in 10:await process_frame
		await shot("leviathan",node.global_position+Vector3(40,14,30),node.global_position,2)
		await shot("leviathan_under",p+Vector3(30,-6,-70),node.global_position,2)
		node.visible=false

func _squid() -> void:
	var p:=_sea_point()
	var sq: Node3D=preload("res://scripts/creatures/big_animals.gd").squid(2.6);game.world.add_child(sq);sq.global_position=p+Vector3(0,-2,-8);sq.rotation.y=1.2
	for i: int in 20:await process_frame
	await shot("squid",p+Vector3(3,-1.5,-4),sq.global_position,2)
	var am: Node3D=game.world.sea_events._build_ambient("agua_viva");game.world.add_child(am);am.global_position=p+Vector3(10,-.5,-6)
	await shot("ambient_jelly",p+Vector3(14,-1,0),am.global_position,2)

func _night() -> void:
	game.world.ocean.hour=21.
	for i: int in 20:await process_frame
	var p:=_sea_point()
	await shot("night_fleet",p+Vector3(150,30,-120),p+Vector3(0,15,-260))

func _clouds() -> void:
	game.world.ocean.weather.cloud=.42
	for i: int in 30:await process_frame
	await shot("clouds_village",Vector3(-160,27,-76),Vector3(-110,5,-17),4)
	await shot("clouds_town",Vector3(0,14,-30),Vector3(30,2,40),4)

func _kraken() -> void:
	var p:=_sea_point()
	for lair: Dictionary in game.lairs.lairs:
		if lair.kind!="kraken":continue
		var node: Node3D=lair.node;node.visible=true;node.global_position=p+Vector3(0,-1.5,-60)
		for i: int in 10:await process_frame
		await shot("kraken_near",node.global_position+Vector3(18,6,22),node.global_position+Vector3(0,3,0),2)
		await shot("kraken_far",node.global_position+Vector3(80,15,110),node.global_position+Vector3(0,3,0),2)

func _storm() -> void:
	var p:=_sea_point()
	await shot("storm_anchored",Vector3(60,22,-80),Vector3(14,300,2340),3)
	var st: Node3D=game.world.storms
	st.spawn_at(p+Vector3(900,0,-900))
	for i: int in 20:await process_frame
	await shot("storm_far",p+Vector3(0,6,0),p+Vector3(900,120,-900),2)
	st.spawn_at(p)
	for i: int in 40:await physics_frame
	await shot("storm_inside",p+Vector3(0,5,0),p+Vector3(40,0,-60),2)
	await shot("storm_waves",p+Vector3(0,14,30),p+Vector3(0,0,-40),2)

func _whirl() -> void:
	var p:=_sea_point()+Vector3(0,0,-150)
	for c in game.world.storms.cells.duplicate():
		if not c.anchored:(c.node as Node3D).queue_free();game.world.storms.cells.erase(c)
	game.world.ocean.weather.settle(1)
	var wp: Node3D=game.world.whirlpools
	wp.spawn_near(p)
	wp.sites[-1].strength=1.
	for i: int in 30:await physics_frame
	await shot("whirl_top",p+Vector3(0,90,70),p,2)
	await shot("whirl_side",p+Vector3(120,14,40),p,2)

func _home() -> void:
	game.world.ocean.weather.settle(1)
	for c in game.world.storms.cells.duplicate():
		if not c.anchored:(c.node as Node3D).queue_free();game.world.storms.cells.erase(c)
	for i: int in 20:await process_frame
	await shot("home_port",Vector3(60,22,-80),Vector3(0,4,10),3)
	await shot("home_hill",Vector3(-60,30,110),Vector3(20,15,250),3)
	await shot("home_forest",Vector3(-120,40,300),Vector3(-40,50,450),3)
	await shot("home_aerial",Vector3(300,260,-200),Vector3(0,30,300),3)
	await shot("home_walk",Vector3(5,3,40),Vector3(-20,6,90),3)
	await shot("home_meadow",Vector3(-30,22,180),Vector3(-60,18,230),3)
	var nf: Node3D=game.world.get_node("PescadoresDeTarrafa").get_child(0)
	nf.clock=1.8
	await shot("home_netfisher",nf.global_position+nf.global_basis.x*6.+Vector3(0,2.,3.),nf.global_position+(-nf.global_basis.z)*3.+Vector3(0,1,0),2)

func _marks() -> void:
	game.world.ocean.weather.settle(1)
	for i: int in 20:await process_frame
	var nf: Node3D=game.world.get_node("PescadoresDeTarrafa").get_child(0)
	nf.clock=1.8
	for i: int in 4:await process_frame
	await shot("mark_netfisher",nf.global_position-nf.global_basis.z*12.+nf.global_basis.x*4.+Vector3(0,3.,0),nf.global_position+Vector3(0,1.2,0),2)
	nf.clock=6.5
	for i: int in 3:await process_frame
	await shot("mark_netfisher2",nf.global_position-nf.global_basis.z*12.+nf.global_basis.x*4.+Vector3(0,3.,0),nf.global_position+Vector3(0,1.2,0),2)
	for m: Dictionary in game.world.get_node("Marcos").marks:
		var at: Vector3=m.pos
		var eye:=at+Vector3(70,35,70)
		await shot("mark_"+str(m.kind),eye,at+Vector3(0,8,0),3)

func _helm() -> void:
	var b: CharacterBody3D=game.boat
	b.global_position=_sea_point();b.rotation=Vector3.ZERO;b.rudder=.6
	b.helm_wheel.rotation.y=-.6*PI*1.5
	var w: Vector3=b.helm_wheel.global_position
	await shot("helm_wheel",w+b.global_basis.z*1.6+Vector3(.6,.5,0),w,6)
	await shot("helm_boat",b.global_position+Vector3(9,5,11),b.global_position+Vector3(0,1.5,0),4)

func _classes() -> void:
	var b: CharacterBody3D=game.boat
	var Econ=load("res://scripts/inventory/harbor_economy.gd")
	for id: String in ["canoa","veleiro","escuna"]:
		game.inventory.owned_boats.append(id);game.inventory.boat_id=id;Econ.apply(game.inventory,b,game.fishing)
		b.global_position=_sea_point();b.rotation=Vector3(0,.4,0);b.set_occupied(true);b.sail_target=1.
		for i: int in 90:await process_frame
		var L: float=float(b.hull_spec.length)
		await shot("class_"+id,b.global_position+b.global_basis*Vector3(L*.9,L*.35+2.,L*.6),b.global_position+Vector3(0,L*.15,0),4)
		var helm: Vector3=b._hull.to_global(b.hull_spec.helm)
		await shot("class_"+id+"_helm",helm+b.global_basis*Vector3(.5,1.7,1.4),helm+b.global_basis*Vector3(0,1.,-3.),4)
	b.set_occupied(false)

func _escuna() -> void:
	var b: CharacterBody3D=game.boat
	var Econ=load("res://scripts/inventory/harbor_economy.gd")
	game.inventory.owned_boats.append("escuna");game.inventory.boat_id="escuna";Econ.apply(game.inventory,b,game.fishing)
	b.global_position=_sea_point();b.rotation=Vector3(0,.4,0);b.set_occupied(true);b.sail_target=1.
	for i: int in 40:await process_frame
	await shot("class_escuna",b.global_position+b.global_basis*Vector3(20.,9.,14.),b.global_position+Vector3(0,4,0),3)
	var helm: Vector3=b._hull.to_global(b.hull_spec.helm)
	await shot("class_escuna_helm",helm+b.global_basis*Vector3(.5,1.7,1.4),helm+b.global_basis*Vector3(0,1.,-3.),3)
	b.set_occupied(false)
	game.inventory.boat_id="aurora";Econ.apply(game.inventory,b,game.fishing)

func _fight() -> void:
	var b: CharacterBody3D=game.boat
	b.global_position=_sea_point();b.rotation=Vector3.ZERO;b.speed=0.
	game.player.global_position=b.global_position+Vector3(0,1.5,0);game.interact()
	for i: int in 5:await process_frame
	var f=game.fishing
	game.fishing_visual.target=b.global_position+Vector3(2,0,-9);game.fishing_visual.cast_start=game.player.rod_tip()
	f.start_cast("coast");f.advance(1.)
	while f.state!=f.State.BITE:f.advance(.25)
	f.strike()
	Input.action_press("fish")
	for i: int in 50:await process_frame
	Input.action_release("fish")
	var p: Vector3=game.player.global_position
	var h: Vector3=game.hooked.global_position
	var log:=FileAccess.open(out_dir+"/fight_log.txt",FileAccess.WRITE)
	log.store_line("player %s fish %s state %d bend %.2f visible %s mode %s"%[p,h,f.state,game.player.visual._bend_now,game.hooked.visible,game.hooked.mode])
	var mid: Vector3=(p+h)*.5
	await shot("fight_side",mid+Vector3(9,6,3),mid,2)
	await shot("fight_fish",Vector3(h.x+2.5,1.6,h.z+2.5),h,2)
	f.progress=.99;f.tension=.3;Input.action_press("fish")
	for i: int in 30:
		await process_frame
		if f.state!=f.State.REELING:break
	Input.action_release("fish")
	log.store_line("after reel: state %d pending %s hooked %s %s"%[f.state,not game.pending_catch.is_empty(),game.hooked.mode,game.hooked.global_position])
	for i: int in 12:await process_frame
	await shot("fight_landing",p+Vector3(6,3,-5),p+Vector3(0,1.,-2),1)
	for i: int in 40:await process_frame
	await shot("fight_held",p+Vector3(1.2,1.8,-2.6),p+Vector3(0,1.2,0),1)
	game.finish_catch(true)
	for i: int in 45:await process_frame
	var r: Vector3=game.hooked.global_position
	log.store_line("release: %s %s %s"%[game.hooked.mode,game.hooked.visible,r]);log.close()
	await shot("fight_release",Vector3(r.x-3.,3.,r.z+3.),r,1)

func _reef() -> void:
	var life=game.world.get_node("VidaNoFundo")
	for i: int in mini(life.reefs.size(),4):
		var c: Vector3=life.reefs[i]
		# Keep the camera in open water above the slope (a grazing view under the ground shows its edge).
		var eye: Vector3=c+Vector3(7,3.5,7);eye.y=maxf(eye.y,life.floor_at(Vector2(eye.x,eye.z))+1.8)
		await shot("reef_%d_%s"%[i,life.reef_biomes[i]],eye,c+Vector3(0,.6,0),4)

func _reefdbg() -> void:
	var life=game.world.get_node("VidaNoFundo")
	var c: Vector3=life.reefs[0]
	var groups: Array[Node]=[]
	for n: Node in game.get_children():if n!=game.world and n is Node3D:groups.append(n)
	for n: Node in game.world.get_children():if n is Node3D:groups.append(n)
	var k:=0
	for g: Node in groups:
		var n3:=g as Node3D;var was:=n3.visible;n3.visible=false
		await shot("bis_%02d_%s"%[k,String(g.name).left(20)],c+Vector3(7,3.5,7),c+Vector3(0,.6,0),1)
		n3.visible=was;k+=1

func _poses() -> void:
	var b: CharacterBody3D=game.boat
	var Econ=load("res://scripts/inventory/harbor_economy.gd")
	game.inventory.owned_boats.append("veleiro");game.inventory.boat_id="veleiro";Econ.apply(game.inventory,b,game.fishing)
	b.global_position=_sea_point();b.rotation=Vector3.ZERO;b.speed=0.;b.sail_target=0.
	game.player.global_position=b.global_position+Vector3(0,1.5,0);game.interact()
	for i: int in 5:await process_frame
	game.toggle_deck()
	var roof: Dictionary=b.hull_spec.deck.roofs[0]
	game.player.deck_local=roof.ladder;game.player.jump_buffer=.16
	for i: int in 40:await process_frame
	var p: Vector3=game.player.global_position
	await shot("pose_roof",p+b.global_basis*Vector3(4.,2.,4.),p,2)
	game.player.deck_local=Vector3(-1.,1.1,3.);game.player.deck_level=-1
	for i: int in 30:await process_frame
	game.pending_catch={"id":"seabass","species_id":"seabass","name":"Robalo","weight":3.,"value":20,"color":"6e7a52"}
	game.catch_display.show_catch(game.pending_catch);game.catch_display.held=true;game.player.visual.hold_clip="ual/FishHold"
	for i: int in 30:await process_frame
	p=game.player.global_position
	var front: Vector3=game.player.visual.global_basis.z
	await shot("pose_hold",p+front*2.4+Vector3(0,1.4,0)+b.global_basis.x*.8,p+Vector3(0,1.1,0),1)
	game.finish_catch(true)
	for i: int in 25:await process_frame
	await shot("pose_release",p+front*2.6+Vector3(0,1.2,0)+b.global_basis.x*1.5,p+Vector3(0,.6,0),1)

func _farois() -> void:
	var w=game.world
	w.ocean.cycle_enabled=false;w.ocean.hour=22.
	for i: int in 30:await process_frame
	var home: Node3D=w.lighthouse
	await shot("farol_casa",home.position+Vector3(90,30,-110),home.position+Vector3(0,30,0),3)
	await shot("farol_noite_mar",Vector3(140,6,-330),home.position+Vector3(0,40,0),3)
	for l: Node3D in w.remote_lighthouses.lighthouses:
		await shot("farol_"+String(l.name),l.position+Vector3(150,40,150),l.position+Vector3(0,45,0),3)
	w.ocean.hour=11.
	for i: int in 20:await process_frame
	await shot("farol_casa_dia",home.position+Vector3(90,30,-110),home.position+Vector3(0,30,0),3)
	var b: CharacterBody3D=game.boat
	var Econ=load("res://scripts/inventory/harbor_economy.gd")
	game.inventory.owned_boats.append("escuna");game.inventory.boat_id="escuna";Econ.apply(game.inventory,b,game.fishing)
	b.global_position=_sea_point();b.rotation=Vector3(0,.4,0);b.speed=0.
	for i: int in 40:await process_frame
	await shot("escuna_tripulacao",b.global_position+b.global_basis*Vector3(12.,7.,6.),b.global_position+Vector3(0,3,0),2)
