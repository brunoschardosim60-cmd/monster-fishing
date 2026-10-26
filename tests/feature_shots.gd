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
	for id: String in ["fleet","rowboat","serpent","creatures","trap","whale","squid","night"]:
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
	pass

func _squid() -> void:
	pass

func _night() -> void:
	game.world.ocean.hour=21.
	for i: int in 20:await process_frame
	var p:=_sea_point()
	await shot("night_fleet",p+Vector3(150,30,-120),p+Vector3(0,15,-260))
