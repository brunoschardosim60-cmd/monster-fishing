extends "res://tests/archipelago_contract.gd"
## People at work: dock porters carry fish crates to the market, woodcutters bring logs to the boatyard,
## carpenters raise house frames, and canoes and rowboats carry fish, timber or nets.
## --headless --fixed-fps 60 --script res://tests/working_life_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var village=game.world.village
	var porters: Array=village.porters
	check(porters.size()==2,"two dock porters work the fishing pier")
	var cutters:=0;var carriers:=0
	for w in village.shipyard.workers:
		if w.get("cargo")!=null and w.cargo!=null:
			if w.cargo.name=="Tora":cutters+=1
			elif w.cargo.name=="Tabuas":carriers+=1
	check(cutters==2 and carriers==3,"boatyard: %d woodcutters with logs, %d shipwrights with planks"%[cutters,carriers])
	var town=village.town
	check(town.sites.size()>=2,"%d houses under construction in the districts"%town.sites.size())
	var site_carriers:=0
	for w in town.workers:
		if w.get("cargo")!=null and w.cargo!=null:site_carriers+=1
	check(site_carriers>=4,"%d carpenters carry planks to the frames"%site_carriers)
	# Watch the porters: they carry while heading for the market and walk back empty, on the planks.
	var seen_loaded:=false;var seen_empty:=false;var floating:=0;var sinking:=0
	for i: int in 2700:
		await physics_frame
		if i%30!=0:continue
		for p in porters:
			if p.cargo.visible:seen_loaded=true
			else:seen_empty=true
			var ground:=Layout.height(Vector2(p.position.x,p.position.z))
			if p.position.y<maxf(ground,1.2)-.1:sinking+=1
			if p.position.y>maxf(ground,1.45)+.5:floating+=1
	var delivered:=0
	for p in porters:delivered+=p.deliveries
	check(seen_loaded and seen_empty,"porters carry a crate one way and walk back empty")
	check(delivered>=1,"crates reach the fish stall on the quay (%d deliveries)"%delivered)
	check(sinking==0 and floating==0,"porters walk on the pier and the ground (%d under, %d above)"%[sinking,floating])
	var logs:=0
	for w in village.shipyard.workers:
		if w.get("deliveries")!=null:logs+=w.deliveries
	check(logs>=2,"logs and planks are delivered at the boatyard (%d)"%logs)
	# Small boats with cargo, and someone paddling every canoe.
	var loads:={};var paddled:=0;var canoes:=0
	for v in game.world.traffic.vessels:
		if v.kind in ["canoa","bote_remo"]:
			if v.model.has_meta("cargo"):loads[v.model.get_meta("cargo")]=true
			if v.kind=="canoa":
				canoes+=1
				for c in v.crew:
					if c.role=="rower":paddled+=1;break
	check(loads.size()>=2,"small boats carry %s"%", ".join(loads.keys()))
	check(paddled==canoes and canoes>0,"every canoe has a paddler (%d/%d)"%[paddled,canoes])
	print("WORKING LIFE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
