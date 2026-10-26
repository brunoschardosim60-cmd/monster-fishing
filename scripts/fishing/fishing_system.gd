class_name MonsterFishingSystem
extends Node
## Input-free fishing state machine; presentation and inventory subscribe to signals.

signal status_changed(message: String)
signal state_changed(state: int)
signal caught(catch_data: Dictionary)

enum State { IDLE, CASTING, WAITING, BITE, REELING, CAUGHT, ESCAPED }

const SpeciesData = preload("res://scripts/fishing/fish_species.gd")
const SPECIES: Array[Resource] = [
	preload("res://data/fish/sardine.tres"),
	preload("res://data/fish/mackerel.tres"),
	preload("res://data/fish/seabass.tres"),
	preload("res://data/fish/tuna.tres"),
	preload("res://data/fish/lanternfish.tres"),
	preload("res://data/fish/sargo.tres"),
	preload("res://data/fish/cirurgiao.tres"),
	preload("res://data/fish/pargo.tres"),
	preload("res://data/fish/baiacu.tres"),
	preload("res://data/fish/tubarao_recife.tres"),
	preload("res://data/fish/peixe_serra.tres"),
	preload("res://data/fish/atum_rei.tres"),
	preload("res://data/fish/tubarao_branco.tres"),
	preload("res://data/fish/peixe_lua.tres"),
]
const BITE_WINDOW: float = 3.2
const CAST_DURATION: float = 0.85

var state: int = State.IDLE
var species_current: Resource
var tension: float = 0.0
var progress: float = 0.0
var bite_time_remaining: float = 0.0
var state_time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_catch: Dictionary = {}
var last_message: String = "A baía está tranquila. Escolha um lugar para pescar."
var region_current: String = "coast"
var rod_bonus: float=0.
var line_bonus: float=0.
var bait_bonus: float=0.
var hook_bonus: float=0.
var line_stretch: float=0.
var cast_range_bonus: float=0.
var surging: bool=false
## Set by the game when the line lands where feed was thrown: fish bite sooner.
var feed_bonus: float=0.

var _wait_duration: float = 4.0
var _reeling: bool = false
var _slack_time: float = 0.0
var _fight_phase: float = 0.0

func _init() -> void:
	rng.randomize()

func active() -> bool:
	return state >= State.CASTING and state <= State.REELING

func start_cast(region: String = "coast", school_species: String = "") -> bool:
	if state != State.IDLE:
		return false
	var available: Array[Resource] = []
	var weight_sum: float = 0.0
	for item: Resource in SPECIES:
		if item.capture_allowed and region in item.regions:
			available.append(item)
			weight_sum += float(item.encounter_weight)*(3. if item.id==school_species else 1.)
	if available.is_empty():
		_message("Ainda não há espécies registradas nestas águas.")
		return false
	var selection: float = rng.randf_range(0.0, weight_sum)
	species_current = available.back()
	for item: Resource in available:
		selection -= float(item.encounter_weight)*(3. if item.id==school_species else 1.)
		if selection <= 0.0:
			species_current = item
			break
	region_current = region
	tension = 0.0
	progress = 0.0
	bite_time_remaining = 0.0
	_reeling = false
	_slack_time = 0.0
	_wait_duration = rng.randf_range(3.0, 5.8)*(1.-bait_bonus)*(1.-feed_bonus)
	_fight_phase = rng.randf_range(0.0, TAU)
	_change_state(State.CASTING)
	_message("Lançando a linha…")
	return true

func strike() -> void:
	if state == State.BITE:
		tension = 0.2
		progress = 0.06
		_slack_time = 0.0
		_change_state(State.REELING)
		_message("Fisgou! Segure para recolher. Solte para aliviar a tensão.")
	elif state == State.WAITING or state == State.CASTING:
		_message("Espere a boia afundar antes de fisgar.")

func cancel() -> void:
	if active():
		_reeling = false
		tension = 0.0
		progress = 0.0
		_change_state(State.IDLE)
		_message("Linha recolhida. O mar pode esperar.")

func set_reeling(value: bool) -> void:
	_reeling = value

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	## Public tick allows deterministic regression tests without real-time waits.
	if delta <= 0.0:
		return
	state_time += delta
	match state:
		State.CASTING:
			if state_time >= CAST_DURATION:
				_change_state(State.WAITING)
				_message("Observe a boia. Algo pode estar se aproximando…")
		State.WAITING:
			if state_time >= _wait_duration:
				bite_time_remaining = BITE_WINDOW
				_change_state(State.BITE)
				_message("MORDIDA! Clique ou pressione Q para fisgar!")
		State.BITE:
			bite_time_remaining = maxf(0.0, BITE_WINDOW - state_time)
			if bite_time_remaining <= 0.0:
				_escape("O peixe levou a isca. Na próxima, reaja à mordida!")
		State.REELING:
			_update_fight(delta)
		State.CAUGHT, State.ESCAPED:
			if state_time >= 2.8:
				_change_state(State.IDLE)
				_message("Pronto para outro lançamento.")

func _update_fight(delta: float) -> void:
	var difficulty: float = float(species_current.difficulty)
	surging=difficulty>=.8 and sin(state_time*1.35+_fight_phase)>.72
	var tug: float = 0.5 + 0.5 * sin(state_time * 2.2 + _fight_phase)
	tension+=delta*line_stretch*.12
	if _reeling:
		_slack_time = 0.0
		tension += delta * (0.19 + difficulty * 0.09 + tug * 0.06)*(1.-line_bonus)
		progress += delta * (0.155 - difficulty * 0.045)*(1.+rod_bonus+hook_bonus)
		if surging:tension+=delta*.16*(1.-line_bonus);progress-=delta*.045
	else:
		_slack_time += delta
		tension -= delta * 0.37
		progress -= delta * 0.018
	tension = clampf(tension, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	if tension >= 1.0:
		_escape("A linha rompeu! Solte o botão antes da tensão chegar ao limite.")
	elif _slack_time >= 5.5:
		_escape("A linha ficou frouxa por tempo demais. O peixe escapou.")
	elif progress >= 1.0:
		_land_catch()

func _land_catch() -> void:
	var weight: float = snappedf(rng.randf_range(float(species_current.min_weight), float(species_current.max_weight)), 0.01)
	var value: int = maxi(1, int(round(weight * float(species_current.value_per_kg))))
	last_catch = {
		"id": str(species_current.id),
		"species_id": str(species_current.id),
		"name": str(species_current.display_name),
		"species_name": str(species_current.display_name),
		"weight": weight,
		"value": value,
		"rarity": str(species_current.rarity),
		"region": region_current,
		"caught_at": Time.get_datetime_string_from_system(true),
		"timestamp": int(Time.get_unix_time_from_system()),
		"color": species_current.color.to_html(),
	}
	_reeling = false
	_change_state(State.CAUGHT)
	_message("%s • %.2f kg • %d moedas" % [species_current.display_name, weight, value])
	caught.emit(last_catch.duplicate(true))

func _escape(reason: String) -> void:
	_reeling = false
	_change_state(State.ESCAPED)
	_message(reason)

func _change_state(next_state: int) -> void:
	state = next_state
	state_time = 0.0
	state_changed.emit(state)

func _message(message: String) -> void:
	last_message = message
	status_changed.emit(message)
