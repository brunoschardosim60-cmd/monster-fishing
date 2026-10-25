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
	for i: int in range(500):
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
	for attempt: int in range(180*Fishing.SPECIES.size()):
		var region: String=["coast","open_water","abyss"][attempt%3]
		fishing.start_cast(region)
		if not fishing.species_current.regions.has(region):
			_check(false,"selected species belongs to the fishing region")
			break
		_wait_for_bite(fishing)
		fishing.strike()
		holding = true
		var duration: float = 0.0
		for i: int in range(1500):
			if fishing.tension > 0.72:
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
			_check(duration >= 6.0 and duration < 30.0, "interactive, bounded fight: %s (%.1f s)" % [species_id, duration])
		fishing.advance(3.0)
		if sampled.size() == Fishing.SPECIES.size():
			break
	_check(sampled.size() == Fishing.SPECIES.size(), "every species can be encountered and caught in their habitats")
	var encounters: Array[int]=[]
	for preference: String in ["","mackerel"]:
		var count:=0;fishing.rng.seed=941
		for i: int in 600:
			fishing.cancel();fishing.start_cast("coast",preference)
			if fishing.species_current.id=="mackerel":count+=1
		encounters.append(count)
	_check(encounters[1]>encounters[0]+90,"Casting into a visible school increases that species' encounter rate")
	fishing.queue_free()
	print("FISHING TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
