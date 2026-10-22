extends Node3D
## Composition root. Systems communicate through signals; content lives in Resources.
const World = preload("res://scripts/world/coastal_world.gd")
const Player = preload("res://scripts/player/player_controller.gd")
const Boat = preload("res://scripts/boats/fishing_boat.gd")
const Fishing = preload("res://scripts/fishing/fishing_system.gd")
const Inventory = preload("res://scripts/inventory/catch_inventory.gd")
const HUD = preload("res://scripts/ui/game_hud.gd")
const FishingVisual = preload("res://scripts/fishing/fishing_visual.gd")
const OceanAudio = preload("res://scripts/audio/ocean_audio.gd")
var world: Node3D
var player: CharacterBody3D
var boat: CharacterBody3D
var fishing: Node
var inventory = Inventory.new()
var hud: CanvasLayer
var fishing_visual: Node3D
var audio: Node
var started: bool = false
var boarded_once: bool = false
var sailed_once: bool = false
var caught_once: bool = false
var sold_once: bool = false
var last_toast: String = ""
var catch_display: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10
	_configure_input()
	world = World.new()
	world.name = "Coast"
	_add_system(world)
	boat = Boat.new()
	boat.name = "FishingBoat"
	boat.position = Vector3(3.9, 0, -23)
	_add_system(boat)
	player = Player.new()
	player.name = "Player"
	player.position = world.safe_spawn()
	_add_system(player)
	player.fell_into_water.connect(_recover_player)
	fishing = Fishing.new()
	fishing.name = "Fishing"
	_add_system(fishing)
	fishing.caught.connect(_on_caught)
	fishing.status_changed.connect(_on_fishing_message)
	fishing.state_changed.connect(_on_fishing_state)
	fishing_visual = FishingVisual.new()
	_add_system(fishing_visual)
	audio = OceanAudio.new()
	_add_system(audio)
	hud = HUD.new()
	add_child(hud)
	hud.start_requested.connect(begin_play)
	hud.resume_requested.connect(resume_play)
	hud.return_requested.connect(return_to_harbor)
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	player.controls_enabled = false
	boat.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists("res://scripts/fishing/catch_display.gd"):
		catch_display = load("res://scripts/fishing/catch_display.gd").new()
		_add_system(catch_display)
	if "--test-mode" in OS.get_cmdline_user_args():
		begin_play()

func _add_system(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)

func begin_play() -> void:
	started = true
	player.controls_enabled = true
	boat.controls_enabled = true
	hud.begin_play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.notify("Bem-vindo à Costa do Farol. O barco está à direita da ponta do cais.")

func resume_play() -> void:
	get_tree().paused = false
	hud.hide_pause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and started:
		if get_tree().paused:
			resume_play()
		else:
			get_tree().paused = true
			hud.show_pause()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if not started or get_tree().paused:
		return
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("fish"):
		fish_action()
	if event.is_action_pressed("cancel_fishing"):
		fishing.cancel()
	if event.is_action_pressed("inventory"):
		hud.toggle_ledger(inventory.catches, inventory.total_value())

func _physics_process(_delta: float) -> void:
	if not started or get_tree().paused:
		return
	if player.in_boat:
		player.global_position = boat.seat_position()
		player.visual.rotation.y = boat.rotation.y
		if boat.global_position.distance_to(Vector3(3.9, 0, -23)) > 15.0:
			sailed_once = true
	if catch_display != null:
		catch_display.global_position = player.global_position + Vector3(0, 2.25, 0)

func _process(delta: float) -> void:
	if not started or get_tree().paused:
		return
	player.movement_locked = fishing.active()
	boat.controls_enabled = not fishing.active()
	fishing.set_reeling(Input.is_action_pressed("fish"))
	fishing_visual.update_line(player.rod_tip(), fishing.state, delta)
	hud.stats.text = "%d  MOEDAS     /     %d  CAPTURAS" % [inventory.money, inventory.count()]
	var heading := wrapf(rad_to_deg(-player.yaw), 0, 360)
	var directions := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
	hud.compass.text = "%s  ·  %03d°" % [directions[int((heading + 22.5) / 45.0) % 8], int(heading)]
	hud.prompt.text = _interaction_hint()
	hud.update_fishing(fishing.state, fishing.tension, fishing.progress, fishing.bite_time_remaining)
	if not boarded_once:
		hud.objective.text = "PRIMEIRA VIAGEM\nCaminhe até o barco e pressione E."
	elif not sailed_once:
		hud.objective.text = "SOLTE AS AMARRAS\nW acelera · S freia · A / D viram."
	elif not caught_once:
		hud.objective.text = "UM BOM LUGAR PARA FICAR\nPare o barco e lance a linha com ESPAÇO."
	elif not sold_once:
		hud.objective.text = "O FRUTO DA VIAGEM\nVolte ao cais. O mercado fica na ilha."
	else:
		hud.objective.text = "SEU TEMPO, SEU MAR\nExplore a baía. Tente uma captura maior."

func can_cast() -> bool:
	if player.in_boat:
		return absf(boat.speed) < 1.2
	var p: Vector3 = player.global_position
	return absf(p.x) < 2.25 and p.z < -10.0 and p.z > -27.0

func fish_action() -> void:
	if fishing.state == Fishing.State.IDLE:
		if not can_cast():
			hud.notify("Pare o barco para pescar." if player.in_boat else "Lance sua linha na ponta do cais ou a bordo do barco.")
			return
		var source: Vector3 = player.global_position
		var target := source + Vector3(-7, 0, -3)
		if player.in_boat:
			target = source + boat.global_basis * Vector3(-4, 0, -8)
		if world.is_land(target):
			hud.notify("Há terra à frente. Afaste o barco da praia para lançar.")
			return
		target.y = 0.1
		fishing_visual.target = target
		fishing.start_cast("coast")
	else:
		fishing.strike()

func interact() -> void:
	if fishing.active():
		hud.notify("Recolha a linha com o botão direito antes de sair.")
		return
	if player.in_boat:
		if near_dock() and absf(boat.speed) < 2.0:
			boat.set_occupied(false)
			boat.reset_to_dock()
			player.set_boating(false)
			player.global_position = Vector3(0, 1.55, -23)
			player.yaw = PI
			hud.notify("Bem-vindo de volta. O mercado fica além do cais.")
		else:
			hud.notify("Aproxime-se devagar da ponta do cais para desembarcar.")
	elif player.global_position.distance_to(boat.global_position + Vector3(0, 1, 0)) < 5.0:
		boat.set_occupied(true)
		player.set_boating(true)
		player.yaw = boat.rotation.y
		boarded_once = true
		hud.notify("W acelera · S freia / ré · A e D viram. Pare para pescar.")
	elif near_market():
		var earned: int = inventory.sell_all()
		if earned > 0:
			sold_once = true
			audio.cue("catch")
			hud.notify("Capturas vendidas! +%d moedas. Boa próxima viagem." % earned)
		else:
			hud.notify("O cesto está vazio. Traga um peixe e eu compro sua captura.")

func near_market() -> bool:
	return Vector2(player.global_position.x - 6, player.global_position.z + 6).length() < 3.3

func near_dock() -> bool:
	return Vector2(boat.global_position.x - 3.9, boat.global_position.z + 23).length() < 8.0

func _interaction_hint() -> String:
	if fishing.active():
		return "BOTÃO DIREITO  recolher e cancelar"
	if player.in_boat:
		if near_dock() and absf(boat.speed) < 2.0:
			return "E  desembarcar no cais   ·   ESPAÇO  lançar a linha"
		return "%.0f nós   ·   %s" % [absf(boat.speed) * 1.94, "ESPAÇO  lançar a linha" if can_cast() else "S  reduzir a velocidade para pescar"]
	if player.global_position.distance_to(boat.global_position + Vector3(0, 1, 0)) < 5.0:
		return "E  embarcar no Aurora   ·   ESPAÇO  pescar no cais"
	if near_market():
		return "E  vender capturas  /  %d moedas" % inventory.total_value()
	if can_cast():
		return "ESPAÇO  lançar a linha   ·   O barco espera na ponta do cais"
	return "Explore a ilha   ·   Volte ao cais para pescar"

func _on_caught(data: Dictionary) -> void:
	inventory.add_catch(data)
	caught_once = true
	audio.cue("catch")
	if catch_display != null:
		catch_display.show_catch(data)

func _on_fishing_message(message: String) -> void:
	if is_instance_valid(hud):
		hud.notify(message)

func _on_fishing_state(state: int) -> void:
	if state == Fishing.State.BITE and is_instance_valid(audio):
		audio.cue("bite")

func _recover_player() -> void:
	fishing.cancel()
	player.global_position = world.safe_spawn()
	player.velocity = Vector3.ZERO
	hud.notify("Você voltou ao cais em segurança. Nenhuma captura foi perdida.")

func return_to_harbor() -> void:
	fishing.cancel()
	boat.set_occupied(false)
	boat.reset_to_dock()
	player.set_boating(false)
	player.global_position = world.safe_spawn()
	player.yaw = 0.0
	resume_play()
	hud.notify("De volta ao porto. Seu cesto e suas moedas continuam com você.")

func _configure_input() -> void:
	var bindings: Dictionary = {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "interact": KEY_E, "fish": KEY_SPACE,
		"camera_toggle": KEY_F, "pause": KEY_ESCAPE, "inventory": KEY_TAB,
		"look_left": KEY_LEFT, "look_right": KEY_RIGHT,
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = int(bindings[action])
		InputMap.action_add_event(action, key)
		# Some Windows input sources expose a logical key with an unrelated scan
		# code. Accept either representation for keyboard accessibility tools.
		var logical_key := InputEventKey.new()
		logical_key.keycode = int(bindings[action])
		InputMap.action_add_event(action, logical_key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fish", mouse)
	if not InputMap.has_action("cancel_fishing"):
		InputMap.add_action("cancel_fishing")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("cancel_fishing", right)
