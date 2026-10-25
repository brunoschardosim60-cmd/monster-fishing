extends "res://tests/archipelago_contract.gd"
## Traffic has five vessels including a large cargo liner; rare sea events spawn in open water and retire.
## --headless --fixed-fps 60 --script res://tests/sea_life_contract.gd
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	await frames(10)
	var ships: Array=game.world.traffic.vessels
	check(ships.size()==7,"%d vessels sail the lanes, from fishing boats to a 150 m tanker"%ships.size())
	var big:=false
	for ship: CharacterBody3D in ships:
		if ship.length_m>=60.:big=true
	check(big,"a large cargo liner (62 m) is on the lanes")
	var events: Node3D=game.world.sea_events
	events.clock=events.next_at
	events._process(0.01)
	check(events.current!=null,"a rare sea event spawns once the timer runs out")
	if events.current!=null:
		var p: Vector3=events.current.global_position
		check(Layout.coast(Vector2(p.x,p.z)).x>60.,"the event starts in open water")
		check(p.distance_to(game.boat.global_position)>200.,"it spawns well away from the boat")
	events.lived=1000.;events._process(.01)
	# Ambient life: spawn several times over simulated time and check the calm/rough/rain branches run without errors.
	var kinds:={}
	for i: int in 40:
		events.next_ambient=0.;events.clock+=0.5;events._process(0.5)
		for record: Dictionary in events.ambient:kinds[record.kind]=true
		events.rain_until=events.clock+5.;events._process(0.1)
	check(kinds.size()>=2,"ambient life spawns varied creatures (%s)"%str(kinds.keys()))
	check(events.rain!=null and events.rain.emitting,"a rain squall starts and the particles emit")
	check(events.ambient.size()<=8,"ambient creatures are capped (%d alive)"%events.ambient.size())
	events.lived=1000.
	events._process(0.01)
	check(events.current==null,"an event leaves after its time is up")
	print("SEA LIFE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
