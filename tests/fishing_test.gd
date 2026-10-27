extends SceneTree
## Run: godot --headless --path . --script res://tests/fishing_test.gd

const Fishing = preload("res://scripts/fishing/fishing_system.gd")
const Basket = preload("res://scripts/inventory/catch_inventory.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func _wait_for_bite(fishing: Node) -> void:
	# Bites come at a random moment set by the conditions (about every 9 s here), not after a fixed delay.
	for i: int in range(30000):
		fishing.advance(0.02)
		if fishing.state == Fishing.State.BITE:
			return

func _run() -> void:
	var fishing: Node = Fishing.new()
	root.add_child(fishing)
	fishing.set_process(false)
	fishing.rng.seed = 81347
	var basket: RefCounted = Basket.new()
	fishing.caught.connect(basket.add_catch)
	_check(not fishing.start_cast("unknown"), "unsupported region does not begin a cast")
	_check(fishing.start_cast(), "cast starts from idle")
	_check(not fishing.start_cast(), "a second cast cannot interrupt a live cast")
	fishing.strike()
	_check(fishing.state == Fishing.State.CASTING, "premature strike does not grant a catch")
	_wait_for_bite(fishing)
	_check(fishing.state == Fishing.State.BITE, "cast and wait reach a bite")
	_check(fishing.bite_time_remaining >= 2.5, "beginner gets a readable bite window")
	fishing.strike()
	_check(fishing.state == Fishing.State.REELING, "timely strike starts the fight")
	var holding: bool = true
	for i: int in range(2500):
		if fishing.tension > 0.72:
			holding = false
		elif fishing.tension < 0.25:
			holding = true
		fishing.set_reeling(holding)
		fishing.advance(0.02)
		if fishing.state != Fishing.State.REELING:
			break
	_check(fishing.state == Fishing.State.CAUGHT, "alternating reel and rest catches the fish")
	_check(basket.count() == 1, "capture signal adds exactly one fish to the basket")
	var payout: int = basket.total_value()
	_check(payout > 0, "capture has a positive sale value")
	_check(basket.sell_all() == payout and basket.money == payout and basket.count() == 0, "sale empties basket and credits exact reward")
	_check(basket.sell_all() == 0 and basket.money == payout, "selling twice cannot duplicate reward")
	fishing.advance(3.0)
	fishing.start_cast()
	_wait_for_bite(fishing)
	fishing.advance(3.3)
	_check(fishing.state == Fishing.State.ESCAPED and basket.count() == 0, "missed bite loses the fish without a reward")
	fishing.advance(3.0)
	fishing.start_cast()
	_wait_for_bite(fishing)
	# A heavy fish on starter tackle: cranking non-stop must break the line (a 100 g fish would just come in).
	fishing.fish_weight = 30.0
	fishing.strike()
	fishing.set_reeling(true)
	for i: int in range(500):
		fishing.advance(0.02)
		if fishing.state != Fishing.State.REELING:
			break
	_check(fishing.state == Fishing.State.ESCAPED, "continuous over-tension breaks the line")
	fishing.advance(3.0)
	fishing.start_cast()
	_wait_for_bite(fishing)
	fishing.strike()
	fishing.set_reeling(false)
	fishing.advance(5.6)
	_check(fishing.state == Fishing.State.ESCAPED, "abandoning a fight loses the fish")
	fishing.advance(3.0)
	fishing.start_cast()
	fishing.cancel()
	_check(fishing.state == Fishing.State.IDLE and not fishing.active(), "cancel returns safely to idle")
	_check(not basket.add_catch({"id": "bad", "weight": -2.0, "value": 999}), "invalid catch cannot enter inventory")
	for species: Resource in Fishing.SPECIES:
		_check(species.min_weight > 0.0 and species.max_weight >= species.min_weight and species.value_per_kg > 0.0, "valid species range: " + species.id)
	var sampled: Dictionary = {}
	# Best tackle: every species, giants included, must be catchable with a sensible reel/rest rhythm.
	fishing.rod_bonus=.45;fishing.line_bonus=.45
	for attempt: int in range(180*Fishing.SPECIES.size()):
		var region: String=["coast","open_water","abyss"][attempt%3]
		fishing.start_cast(region)
		_wait_for_bite(fishing)
		if not fishing.species_current.regions.has(region):
			_check(false,"selected species belongs to the fishing region")
			break
		fishing.strike()
		holding = true
		var duration: float = 0.0
		for i: int in range(6000):
			if fishing.tension > 0.72 or fishing.fight_phase == "run":
				holding = false
			elif fishing.tension < 0.25:
				holding = true
			fishing.set_reeling(holding)
			fishing.advance(0.02)
			duration += 0.02
			if fishing.state != Fishing.State.REELING:
				break
		if fishing.state != Fishing.State.CAUGHT:
			_check(false, "reel/rest strategy must work for every selected species")
			break
		var species_id: String = str(fishing.species_current.id)
		if not sampled.has(species_id):
			sampled[species_id] = duration
			_check(duration >= 4.0 and duration < 100.0, "interactive, bounded fight: %s (%.1f s, %.0f kg)" % [species_id, duration, fishing.fish_weight])
		fishing.advance(3.0)
		if sampled.size() == Fishing.SPECIES.size():
			break
	_check(sampled.size() == Fishing.SPECIES.size(), "every species can be encountered and caught in their habitats")
	var encounters: Array[int]=[]
	for preference: String in ["","mackerel"]:
		var count:=0;fishing.rng.seed=941
		for i: int in 600:
			fishing.cancel();fishing.start_cast("coast",preference)
			if fishing._pick_species().id=="mackerel":count+=1
		encounters.append(count)
	_check(encounters[1]>encounters[0]+90,"Casting into a visible school increases that species' encounter rate")
	# Light tackle against a giant: the gear warning is raised and the line goes.
	fishing.rod_bonus=0.;fishing.line_bonus=0.;fishing.cancel();fishing.start_cast("open_water");_wait_for_bite(fishing)
	fishing.fish_weight=250.;fishing.strike()
	_check(fishing.gear_warning and fishing.overload>10.,"starter tackle on a 250 kg fish is flagged as too weak (overload %.0f)"%fishing.overload)
	var broke:=false
	for i: int in 3000:
		fishing.set_reeling(fishing.tension<.5);fishing.advance(.02)
		if fishing.state!=Fishing.State.REELING:broke=fishing.state==Fishing.State.ESCAPED;break
	_check(broke,"…and it cannot be hauled in like a sardine")
	# Bites depend on the conditions: a good spot bites far sooner than a bad one.
	var waits: Array[float]=[]
	for rate: float in [3.,.25]:
		var total:=0.
		fishing.conditions={"rate":rate,"depth":20.,"hour":12.}
		for k: int in 30:
			fishing.cancel();fishing.advance(3.);fishing.start_cast("coast");var t:=0.
			while fishing.state!=Fishing.State.BITE and t<600.:fishing.advance(.05);t+=.05
			total+=t
		waits.append(total/30.)
	_check(waits[0]<6.5 and waits[1]>waits[0]*4.,"bites come quickly in a rich spot and slowly in a poor one (%.1f s vs %.1f s)"%[waits[0],waits[1]])
	fishing.queue_free()
	print("FISHING TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
