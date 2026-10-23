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
var surface_fish: Node3D
var pending_catch: Dictionary={}
var stowing: bool=false
var stow_tween: Tween
var stow_origin:=Vector3.ZERO
var service_id: String=""
var aiming: bool=false
var aim_manual: bool=false
var cast_charge: float=0.
var cast_distance: float=14.
var cast_marker: MeshInstance3D
var graphics: RefCounted
var marine: Node3D
const Economy=preload("res://scripts/inventory/harbor_economy.gd")

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
	boat.water_effects=world.ocean.effects
	world.traffic.set_player_boat(boat)
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
	cast_marker=MeshInstance3D.new()
	var ring:=TorusMesh.new();ring.inner_radius=.42;ring.outer_radius=.5;ring.rings=24;ring.ring_segments=6;cast_marker.mesh=ring
	var aim_material:=StandardMaterial3D.new();aim_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;aim_material.albedo_color=Color("8de8dd");cast_marker.material_override=aim_material;cast_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(cast_marker);cast_marker.hide()
	audio = OceanAudio.new()
	_add_system(audio)
	audio.configure(world.ocean,boat)
	surface_fish=preload("res://scripts/fishing/surface_fish.gd").new()
	_add_system(surface_fish); surface_fish.effects=world.ocean.effects
	marine=preload("res://scripts/creatures/marine_ecosystem.gd").new();marine.game=self;marine.name="VidaMarinha";_add_system(marine)
	hud = HUD.new()
	add_child(hud)
	hud.start_requested.connect(begin_play)
	hud.resume_requested.connect(resume_play)
	hud.return_requested.connect(return_to_harbor)
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	hud.weather_selected.connect(func(index: int) -> void: world.ocean.weather.choose(index))
	hud.service_action.connect(_service_action)
	hud.service_closed.connect(func() -> void: service_id="";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
	hud.time_selected.connect(func(hour_value: float) -> void: world.ocean.hour=hour_value)
	hud.map_view.game=self
	graphics=preload("res://scripts/visuals/graphics_settings.gd").new();graphics.configure(self)
	hud.configure_graphics(graphics)
	hud.graphics_changed.connect(func(level: int,scale_value: float,sync: bool) -> void:graphics.apply(level,scale_value,sync))
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
	hud.notify("ESC · Controles e opções")

func resume_play() -> void:
	get_tree().paused = false
	hud.hide_pause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if started and hud.service_open:
		if event.is_action_pressed("pause") or event.is_action_pressed("interact"):hud.close_service()
		return
	if event.is_action_pressed("pause") and started:
		if get_tree().paused:
			resume_play()
		else:
			aiming=false
			get_tree().paused = true
			hud.show_pause()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if not started or get_tree().paused:
		return
	if event.is_action_pressed("fly_toggle") and not event.is_echo():
		aiming = false
		fishing.cancel()
		if not player.flying:
			boat.set_occupied(false)
			boat.speed = 0.; boat.velocity = Vector3.ZERO
			player.set_boating(false)
		player.set_flying(not player.flying)
		hud.notify("Voo · ESPAÇO sobe · CTRL desce · SHIFT acelera" if player.flying else "Voo desligado")
		get_viewport().set_input_as_handled()
		return
	if player.flying:
		if event.is_action_pressed("world_map"): hud.map_view.visible = not hud.map_view.visible
		return
	if event.is_action_pressed("deck"): toggle_deck()
	if event.is_action_pressed("boat_lights"):
		boat.toggle_lights();hud.notify("Luzes do barco acesas." if boat.lights_enabled else "Luzes do barco apagadas.")
	if event.is_action_pressed("observe_wildlife"):
		hud.notify("Vigia Abissal · +40 moedas" if marine.observe_guardian() else "Aproxime-se devagar para observar.")
	if event.is_action_pressed("keep_catch"): finish_catch(false)
	if event.is_action_pressed("release_catch"): finish_catch(true)
	if event.is_action_pressed("world_map"):hud.map_view.visible=not hud.map_view.visible
	if event.is_action_pressed("journal"):hud.show_encyclopedia(inventory.encyclopedia,world.village.discovered)
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("fish"):
		if fishing.state==Fishing.State.IDLE and pending_catch.is_empty():aiming=true;aim_manual=false;cast_charge=0.
		else:fish_action()
	if event.is_action_released("fish") and aiming:
		aiming=false;fish_action()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		cast_distance=clampf(cast_distance+(2. if event.button_index==MOUSE_BUTTON_WHEEL_UP else -2.),5.,42.+fishing.cast_range_bonus)
		if aiming:
			aim_manual=true;cast_charge=(cast_distance-5.)/(37.+fishing.cast_range_bonus)
	if event.is_action_pressed("cancel_fishing"):
		aiming=false
		fishing.cancel()
	if event.is_action_pressed("inventory"):
		hud.toggle_ledger(inventory.catches, inventory.total_value())

func _physics_process(_delta: float) -> void:
	if not started or get_tree().paused:
		return
	if player.in_boat and not player.on_deck:
		player.global_position = boat.seat_position()
		player.visual.rotation.y = boat.rotation.y
		player.keep_camera_above_water()
		if boat.global_position.distance_to(Vector3(3.9, 0, -23)) > 15.0:
			sailed_once = true
	if catch_display != null:
		if not pending_catch.is_empty():
			var hand: Transform3D=player.visual.catch_hand_transform()
			catch_display.global_transform=Transform3D(Basis(Vector3.FORWARD,-PI*.5),hand.origin+Vector3(0,-.32,0))
	if not player.in_boat:
		player.global_position=preload("res://scripts/world/archipelago_layout.gd").wrapped(player.global_position)

func _process(delta: float) -> void:
	if not started or get_tree().paused:
		return
	player.movement_locked = hud.service_open
	player.fishing_active=fishing.active() or aiming
	player.fishing_state=fishing.state
	player.cast_power=cast_charge
	player.holding_fish=not pending_catch.is_empty()
	boat.controls_enabled = not hud.service_open
	if aiming and not aim_manual:
		cast_charge=minf(1.,cast_charge+delta*.65)
		cast_distance=lerpf(5.,42.+fishing.cast_range_bonus,cast_charge)
	var aim_target:=_cast_target() if aiming else {}
	cast_marker.visible=not aim_target.is_empty()
	if cast_marker.visible:
		cast_marker.global_position=aim_target.position
		cast_marker.position.y=preload("res://scripts/world/wave_field.gd").height_at(cast_marker.position)+.22
	if fishing.active():
		var line_distance: float=player.global_position.distance_to(fishing_visual.target)
		fishing.line_stretch=clampf((line_distance-42.-fishing.cast_range_bonus)/14.,0.,1.)
		if player.swimming or line_distance>56.+fishing.cast_range_bonus:
			fishing.cancel();hud.notify("Linha fora de alcance.")
	fishing.set_reeling(Input.is_action_pressed("fish"))
	fishing_visual.update_line(player.rod_tip(), fishing.state, delta)
	hud.stats.text = "%d moedas · %d peixes" % [inventory.money, inventory.count()]
	hud.sea_label.text = "%02d:%02d  /  %s"%[int(world.ocean.hour),int(fposmod(world.ocean.hour,1.)*60.),world.ocean.weather.LABELS[world.ocean.weather.state]]
	var heading := wrapf(rad_to_deg(-player.yaw), 0, 360)
	var directions := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
	hud.compass.text = "%s  ·  %03d°" % [directions[int((heading + 22.5) / 45.0) % 8], int(heading)]
	hud.prompt.text = _interaction_hint()
	hud.update_fishing(fishing.state, fishing.tension, fishing.progress, fishing.bite_time_remaining)
	if fishing.state==Fishing.State.REELING and fishing.surging:hud.fishing_hint.text="Arrancada · solte!"
	if not boarded_once:
		hud.objective.text = "PRIMEIRA VIAGEM\nCaminhe até o barco e pressione E."
	elif not sailed_once:
		hud.objective.text = "SOLTE AS AMARRAS\nW acelera · S freia · A / D viram."
	elif not caught_once:
		hud.objective.text = "ESCOLHA SEU LANÇAMENTO\nSegure o clique para mirar e solte para lançar."
	elif not sold_once:
		hud.objective.text = "O FRUTO DA VIAGEM\nVolte ao cais. O mercado fica na ilha."
	else:
		hud.objective.text = "SEU TEMPO, SEU MAR\nExplore a baía. Tente uma captura maior."

func can_cast() -> bool:
	if not pending_catch.is_empty() or stowing or player.swimming or hud.service_open: return false
	if player.in_boat and absf(boat.speed)>=6.: return false
	return not _cast_target().is_empty()

func _cast_target() -> Dictionary:
	var source: Vector3=player.global_position
	var forward:=Vector3(-sin(player.yaw),0,-cos(player.yaw))
	for distance: float in [cast_distance,maxf(5.,cast_distance*.7),8.,5.]:
		var target:=source+forward*distance;target.y=.1
		if world.is_land(target):continue
		# Validate the same ballistic arc used by the bobber, not a straight ray
		# through the pier beneath the angler's feet.
		var start:=source+Vector3.UP*1.6;var previous:=start;var clear:=true
		for step: int in range(1,9):
			var t:=float(step)/8.;var point:=start.lerp(target,t)+Vector3.UP*sin(t*PI)*maxf(2.,distance*.2)
			var query:=PhysicsRayQueryParameters3D.create(previous,point,1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():clear=false;break
			previous=point
		if clear:return {"position":target}
	return {}

func fish_action() -> void:
	if fishing.state == Fishing.State.IDLE:
		if not can_cast():
			hud.notify("Guarde ou devolva a captura primeiro." if not pending_catch.is_empty() else ("Reduza para menos de 12 nós para lançar." if player.in_boat and absf(boat.speed)>=6. else "Mire na água livre."))
			return
		var target: Vector3=_cast_target().position
		fishing_visual.target = target
		fishing_visual.cast_start=player.rod_tip();fishing_visual.cast_elapsed=0.
		fishing.bait_bonus=.25 if inventory.bait>0 else 0.
		if inventory.bait>0:inventory.bait-=1
		fishing.start_cast(marine.region_at(target),marine.school_at(target))
	else:
		fishing.strike()

func interact() -> void:
	aiming=false
	if fishing.active():
		fishing.cancel()
	if player.in_boat:
		disembark()
	elif player.global_position.distance_to(boat.global_position + Vector3(0, 1, 0)) < 6.0:
		boat.set_occupied(true)
		player.set_boating(true)
		player.yaw = boat.rotation.y
		boarded_once = true
		hud.notify("R · Convés    E · Sair")
	elif near_market():
		var earned: int = inventory.sell_all()
		if earned > 0:
			sold_once = true
			audio.cue("catch")
			hud.notify("+%d moedas" % earned)
		else:
			hud.notify("Sem capturas para vender.")
	else:
		if world.village.guardian!=null and not inventory.encyclopedia.has("island_guardian") and player.global_position.distance_to(world.village.guardian.global_position)<12.:
			world.village.guardian.observe()
			if not inventory.encyclopedia.has("island_guardian"):
				inventory.record({"id":"island_guardian","name":"Guardião da Vigia","rarity":"Lendária","weight":0.,"observation":true})
			hud.notify("Guardião registrado.");return
		var service: String=world.village.nearby_service(player.global_position)
		if not service.is_empty():
			service_id=service;hud.open_service(service,inventory,boat,world.village.bridge_district.stock);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;return
		var discovery: Dictionary=world.village.nearby_discovery(player.global_position)
		if not discovery.is_empty():
			world.village.discovered[discovery.id]=discovery.title
			inventory.money+=int(discovery.reward);inventory.materials+=2;inventory.changed.emit()
			hud.notify("%s descoberto! Baú: %d moedas e 2 materiais."%[discovery.title,discovery.reward])

func toggle_deck() -> void:
	if not player.in_boat:return
	fishing.cancel()
	player.on_deck=not player.on_deck;player.deck_boat=boat
	player.visual.seated=not player.on_deck
	if player.on_deck:
		player.deck_local=Vector3(0,1.12,2.4)
		player.deck_velocity=Vector3.ZERO;player.deck_sway=Vector3.ZERO;player.prev_boat_speed=boat.speed
	boat.set_occupied(not player.on_deck)
	hud.notify("R · Assumir o leme" if player.on_deck else "Você assumiu o leme.")

func disembark() -> void:
	var target: Vector3=boat._hull.to_global(Vector3(-3.1,.2,2.2))
	if near_dock() and absf(boat.speed)<2.:
		boat.reset_to_dock();target=Vector3(0,1.55,-23)
	else:
		for side: float in [-1.,1.]:
			var p: Vector3=boat.global_position+boat.global_basis*Vector3(side*3.8,0,2.)
			var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*3.,p-Vector3.UP*3.,1))
			if not hit.is_empty() and hit.position.y>.15 and hit.position.y<2.7 and hit.normal.y>.65:
				target=hit.position+Vector3.UP*.1;break
	boat.set_occupied(false);player.set_boating(false);player.global_position=target;player.velocity=Vector3.ZERO
	hud.notify("Desembarcou.")

func near_market() -> bool:
	return Vector2(player.global_position.x - 6, player.global_position.z + 6).length() < 3.3

func near_dock() -> bool:
	return Vector2(boat.global_position.x - 3.9, boat.global_position.z + 23).length() < 9.5

func _interaction_hint() -> String:
	if player.flying:return "T · Encerrar voo"
	if marine!=null and marine.guardian_in_range() and pending_catch.is_empty() and not fishing.active():return "V · Observar"
	if aiming:return "%.0f m · Solte para lançar"%cast_distance
	if not pending_catch.is_empty():return "G · Guardar    X · Devolver"
	if fishing.active():return ""
	if player.in_boat:
		if player.on_deck:return "R · Leme    E · Sair"
		return "%.0f nós · %d%% casco    R · Convés"%[absf(boat.speed)*1.94,int(boat.integrity*100.)]
	if player.global_position.distance_to(boat.global_position+Vector3(0,1,0))<5.:return "E · Embarcar"
	if near_market():return "E · Vender capturas"
	var service: String=world.village.nearby_service(player.global_position)
	if not service.is_empty():return "E · %s"%hud.SERVICE_NAMES.get(service.replace("_oldport","").replace("_bridge",""),service)
	var discovery: Dictionary=world.village.nearby_discovery(player.global_position)
	if not discovery.is_empty():return "E · "+str(discovery.title)
	if world.village.guardian!=null and not inventory.encyclopedia.has("island_guardian") and player.global_position.distance_to(world.village.guardian.global_position)<12.:return "E · Observar"
	return ""

func _on_caught(data: Dictionary) -> void:
	if stow_tween!=null: stow_tween.kill()
	stowing=false;catch_display.scale=Vector3.ONE
	pending_catch=data.duplicate(true)
	caught_once = true
	audio.cue("catch")
	world.ocean.effects.splash(fishing_visual.target,clampf(.5+float(data.get("weight",1.))*.08,.5,2.5),true)
	if catch_display != null:
		catch_display.show_catch(data)
		catch_display.held=true
	hud.notify("Captura!")

func finish_catch(release: bool) -> void:
	if pending_catch.is_empty():return
	inventory.record(pending_catch,release)
	if release:
		world.ocean.effects.splash(fishing_visual.target,.9,true)
		surface_fish.breach(fishing_visual.target,fishing.species_current)
		hud.notify("Peixe devolvido.")
	else:
		inventory.add_catch(pending_catch)
		hud.notify("Captura guardada %s."%["no balde do barco" if player.in_boat else "na mochila"])
	pending_catch.clear();player.holding_fish=false
	if release:
		catch_display.held=false;catch_display.remaining=0.;catch_display.hide()
	else:
		stowing=true;stow_origin=catch_display.global_position
		stow_tween=create_tween()
		stow_tween.tween_method(_stow_frame,0.,1.,.65).set_trans(Tween.TRANS_SINE)
		stow_tween.tween_callback(func() -> void:
			stowing=false;catch_display.held=false;catch_display.remaining=0.;catch_display.hide();catch_display.scale=Vector3.ONE)

func _stow_frame(t: float) -> void:
	var target: Vector3=boat.bucket.global_position if player.in_boat else player.visual.to_global(Vector3(0,1.15,.22))
	catch_display.global_position=stow_origin.lerp(target,t)+Vector3.UP*sin(t*PI)*.18
	catch_display.scale=Vector3.ONE*lerpf(1.,.18,t*t)

func _service_action(action: String) -> void:
	var message: String=""
	if Economy.CATALOG.has(action):message=Economy.buy(action,inventory,boat,fishing)
	elif action.begins_with("buy_stock:"):
		var index:=int(action.get_slice(":",1));var stock: Array=world.village.bridge_district.stock
		if index>=0 and index<stock.size():
			var price:=ceili(float(stock[index].value)*1.25)
			if inventory.money>=price:
				inventory.money-=price;inventory.add_catch(stock[index]);stock.remove_at(index);message="Peixe comprado."
			else:message="Moedas insuficientes."
	elif action.contains(":") or action in ["use_kit","use_tackle","craft_kit","sell_bait","sell_material"]:message=Economy.trade(action,inventory,boat)
	elif action=="sell":
		var amount: int=inventory.sell_all();sold_once=sold_once or amount>0;message="Venda: +%d moedas."%amount
	elif action=="store":
		inventory.stored_catches.append_array(inventory.catches);inventory.catches.clear();inventory.changed.emit();message="Capturas guardadas no armazém."
	elif action=="withdraw":
		inventory.catches.append_array(inventory.stored_catches);inventory.stored_catches.clear();inventory.changed.emit();message="Capturas retiradas do armazém."
	elif action=="rest":world.ocean.hour=8.;message="Você descansou até a manhã."
	hud.open_service(service_id,inventory,boat,world.village.bridge_district.stock);hud.service_message.text=message

func _on_fishing_message(_message: String) -> void:
	if is_instance_valid(hud) and fishing.state==Fishing.State.ESCAPED:
		hud.notify("O peixe escapou.")

func _on_fishing_state(state: int) -> void:
	if state in [Fishing.State.IDLE,Fishing.State.ESCAPED] and is_instance_valid(surface_fish): surface_fish.hide()
	if state==Fishing.State.REELING and is_instance_valid(surface_fish):
		surface_fish.breach(fishing_visual.target,fishing.species_current)
	if is_instance_valid(fishing_visual) and state in [Fishing.State.WAITING,Fishing.State.BITE]:
		world.ocean.effects.splash(fishing_visual.target,.5 if state==Fishing.State.WAITING else .85,state==Fishing.State.BITE)
	if state == Fishing.State.BITE and is_instance_valid(audio):
		audio.cue("bite")

func _recover_player() -> void:
	fishing.cancel()
	player.global_position = world.safe_spawn()
	player.velocity = Vector3.ZERO
	hud.notify("De volta ao cais.")

func return_to_harbor() -> void:
	player.set_flying(false)
	aiming=false
	fishing.cancel()
	boat.set_occupied(false)
	boat.reset_to_dock()
	player.set_boating(false)
	player.global_position = world.safe_spawn()
	player.yaw = 0.0
	resume_play()
	hud.notify("De volta ao porto.")

func _configure_input() -> void:
	var bindings: Dictionary = {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "interact": KEY_E, "fish": KEY_Q, "jump":KEY_SPACE,"boat_lights":KEY_L,"observe_wildlife":KEY_V,
		"camera_toggle": KEY_F, "pause": KEY_ESCAPE, "inventory": KEY_TAB,
		"look_left": KEY_LEFT, "look_right": KEY_RIGHT,
		"fly_toggle": KEY_T, "fly_down": KEY_CTRL,
		"deck":KEY_R,"keep_catch":KEY_G,"release_catch":KEY_X,"world_map":KEY_M,"journal":KEY_J,
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
