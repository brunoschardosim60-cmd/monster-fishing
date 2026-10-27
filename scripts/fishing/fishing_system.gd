class_name MonsterFishingSystem
extends Node
## Input-free fishing state machine; presentation and inventory subscribe to signals.

signal status_changed(message: String)
signal state_changed(state: int)
signal caught(catch_data: Dictionary)
## A fish mouths the bait without taking it: the float twitches (strength 0..1).
signal nibble(strength: float)

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
	preload("res://data/fish/manjuba.tres"),
	preload("res://data/fish/donzela.tres"),
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
## How long the cast lasts, rod throw plus the flight of the float (set by the game from the distance).
var cast_duration: float=CAST_DURATION
## Fishing conditions under the float, refreshed by the game every frame (see main._fishing_conditions):
## rate multiplier (time of day, weather, boat noise, nearby fish...), water depth and hour.
var conditions: Dictionary={"rate":1.,"depth":20.,"hour":12.}
## Expected bites per second at rate 1 with no bait: about one every nine seconds.
const BASE_BITE_RATE: float=.11
## No fish takes the bait in the first moments after the float lands.
const QUIET_AFTER_LANDING: float=1.4
## Fight: each species has a style; the fish's weight against the tackle's capacity decides how hard it is.
const STYLES: Dictionary={"tuna":"runner","atum_rei":"runner","mackerel":"runner","tubarao_branco":"shaker","tubarao_recife":"shaker",
	"peixe_serra":"shaker","pargo":"diver","sargo":"diver","cirurgiao":"diver","lanternfish":"diver","seabass":"jumper","baiacu":"steady","peixe_lua":"steady"}
var fight_phase: String="calm"
var stamina: float=1.
var fish_weight: float=1.
## Fish weight over tackle capacity: above 1 the gear is too light (tension climbs faster, the line breaks).
var overload: float=0.
var gear_warning: bool=false
var _phase_left: float=0.
var _slack_jump: float=0.
var _school: String=""

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
	if _available(region).is_empty():
		_message("Ainda não há espécies registradas nestas águas.")
		return false
	region_current = region
	_school=school_species
	species_current = null
	tension = 0.0
	progress = 0.0
	bite_time_remaining = 0.0
	_reeling = false
	_slack_time = 0.0
	_fight_phase = rng.randf_range(0.0, TAU)
	_change_state(State.CASTING)
	_message("Lançando a linha…")
	return true

func _available(region: String) -> Array[Resource]:
	var out: Array[Resource]=[]
	for item: Resource in SPECIES:
		if item.capture_allowed and region in item.regions:out.append(item)
	return out

## Which fish takes the bait: species of these waters, weighted by abundance, the school under the float
## and how well the water depth suits each one.
func _pick_species() -> Resource:
	var available:=_available(region_current)
	var depth: float=float(conditions.get("depth",20.))
	var weights: Array[float]=[];var total:=0.
	for item: Resource in available:
		var w: float=float(item.encounter_weight)*(3. if item.id==_school else 1.)
		var pref: Vector2=item.preferred_depth
		if depth<pref.x or depth>pref.y:w*=.35
		weights.append(w);total+=w
	var pick:=rng.randf_range(0.,total)
	for k: int in available.size():
		pick-=weights[k]
		if pick<=0.:return available[k]
	return available.back()

## Bites per second right now.
func bite_rate() -> float:
	return BASE_BITE_RATE*float(conditions.get("rate",1.))*(1.+bait_bonus*1.6)*(1.+feed_bonus*2.)

func strike() -> void:
	if state == State.BITE:
		tension = 0.2
		progress = 0.06
		_slack_time = 0.0
		stamina=1.;fight_phase="calm";_phase_left=rng.randf_range(.6,1.4);_slack_jump=0.
		overload=fish_weight/tackle_capacity()
		gear_warning=overload>1.
		_change_state(State.REELING)
		_message("Fisgou! Segure para recolher. Solte para aliviar a tensão.")
	elif state == State.WAITING or state == State.CASTING:
		_message("Espere a boia afundar antes de fisgar.")

## A fish already hooked on a rod left in a holder: the angler takes the rod and the fight begins.
func hook_external(species: Resource,weight: float,region: String) -> void:
	_reeling=false;tension=0.;progress=0.
	species_current=species;fish_weight=weight;region_current=region
	_change_state(State.BITE)
	strike()

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
			if state_time >= cast_duration:
				_change_state(State.WAITING)
				_message("Observe a boia. Algo pode estar se aproximando…")
		State.WAITING:
			# Not a timer: every moment there is a chance a fish takes the bait, set by the conditions.
			# Before a real bite fish often nibble, so the float tells the angler something is there.
			if state_time >= QUIET_AFTER_LANDING:
				var rate: float=bite_rate()
				if rng.randf() < rate*1.6*delta:nibble.emit(rng.randf_range(.25,.7))
				if rng.randf() < 1.-exp(-rate*delta):
					species_current=_pick_species()
					fish_weight=snappedf(rng.randf_range(float(species_current.min_weight), float(species_current.max_weight)), 0.01)
					bite_time_remaining = BITE_WINDOW
					_change_state(State.BITE)
					_message("Mordida! Fisgue agora.")
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

## What the rod and line can hold, in kg of fish, before the fight turns against the angler.
func tackle_capacity() -> float:
	return 12.*(1.+rod_bonus/.15*1.4)*(1.+line_bonus/.15*1.1)

## Size class for the HUD and messages: 0 small, 1 medium, 2 large, 3 giant.
func size_class() -> int:
	if fish_weight<2.:return 0
	if fish_weight<15.:return 1
	if fish_weight<80.:return 2
	return 3

func _next_phase() -> void:
	var style: String=STYLES.get(str(species_current.id),"steady")
	var lively: float=.35+.65*stamina
	if fight_phase!="calm" or rng.randf()>lively*.75:
		fight_phase="calm";_phase_left=rng.randf_range(1.,2.4)*(1.4-stamina*.6);return
	var options: Dictionary={"runner":["run","run","dive","shake"],"shaker":["shake","shake","run","dive"],"diver":["dive","dive","shake","run"],
		"jumper":["jump","run","shake","jump"],"steady":["dive","run"]}
	var list: Array=options.get(style,["run"])
	fight_phase=str(list[rng.randi()%list.size()])
	_phase_left={"run":rng.randf_range(1.4,3.2),"dive":rng.randf_range(1.2,2.6),"shake":rng.randf_range(.7,1.5),"jump":rng.randf_range(.55,.8)}[fight_phase]*(.5+lively*.6)

func _update_fight(delta: float) -> void:
	var difficulty: float = float(species_current.difficulty)
	_phase_left-=delta
	if _phase_left<=0.:
		if fight_phase=="jump" and _slack_jump>.45 and rng.randf()<.35:
			_escape("O peixe saltou e soltou o anzol. Mantenha a linha esticada no salto.");return
		_slack_jump=0.;_next_phase()
	surging=fight_phase in ["run","dive"]
	var load: float=maxf(overload,.35)
	# The fish's pull: species temper, how fresh it still is, and its weight against the tackle.
	var pull: float=(.25+difficulty*.5)*(.35+.65*stamina)*(.6+.4*minf(load,2.5))
	# Line gained per second of reeling: better rod and hook help, a tired fish comes easier, a heavy one slower.
	var gain: float=(.17-difficulty*.05)*(1.+rod_bonus+hook_bonus)*(1.25-.55*stamina)/(1.+log(1.+fish_weight)/log(2.)*.32)
	var ease: float=1.-line_bonus
	tension+=delta*line_stretch*.12
	match fight_phase:
		"calm":
			if _reeling:tension+=delta*(.13+pull*.22)*ease*load;progress+=delta*gain
			else:tension-=delta*.37
		"run":
			# Line goes out: reeling against a run is how lines break.
			if _reeling:tension+=delta*(.34+pull*.9)*ease*load;progress-=delta*.03*pull
			else:tension-=delta*.1;progress-=delta*.06*pull
		"dive":
			if _reeling:tension+=delta*(.24+pull*.6)*ease*load;progress+=delta*gain*.25
			else:tension-=delta*.18;progress-=delta*.035*pull
		"shake":
			tension+=delta*(maxf(0.,sin(state_time*15.))*1.1*pull*ease*load-(.05 if _reeling else .3))
			if _reeling:progress+=delta*gain*.4
		"jump":
			tension-=delta*.7
			if _reeling:progress+=delta*gain*1.3
			if tension<.06 and not _reeling:_slack_jump+=delta
	if _reeling:_slack_time=0.
	else:_slack_time+=delta
	# A fish tires faster against a tight line; big fish have more in them.
	stamina=maxf(0.,stamina-delta*(.012+(.045 if _reeling else .015)*(1. if fight_phase!="calm" else .6))/maxf(.6,sqrt(fish_weight/4.)))
	tension = clampf(tension, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	if tension >= 1.0:
		_escape("A linha rompeu!"+(" Equipamento fraco para um peixe deste porte." if overload>1. else " Alivie quando ele arrancar."))
	elif _slack_time >= 5.5:
		_escape("A linha ficou frouxa por tempo demais. O peixe escapou.")
	elif progress >= 1.0:
		_land_catch()

func _land_catch() -> void:
	var weight: float = fish_weight
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
