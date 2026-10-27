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
## The fish on the line, in the water, then lifted out or put back (hooked_fish.gd).
var hooked: Node3D
## Rod holders on the boat's rail (rod_holders.gd): set a line, do something else, come back for the fish.
var holders: Node3D
## Hired sailors aboard (crew_manager.gd).
var crew: Node
var pending_catch: Dictionary={}
var stowing: bool=false
var stow_tween: Tween
var stow_origin:=Vector3.ZERO
var service_id: String=""
## The boatyard shop opens once each time the boat comes to rest in its berth.
var berth_opened: bool=false
var aiming: bool=false
var aim_manual: bool=false
var cast_charge: float=0.
var cast_distance: float=14.
var cast_marker: MeshInstance3D
var graphics: RefCounted
var marine: Node3D
## Developer mode (F6): test tools, put-aside inventory, no saving. See scripts/dev/developer_mode.gd.
var dev: CanvasLayer
## Feed, cast net and crab traps (C, N, B).
var gear: Node3D
## Monster territories in the deep ocean (kraken, sea serpent, leviathan).
var lairs: Node3D
## Story objectives and the market's order board.
var missions: Node
## Dynamic monster encounters at sea, the diving system (air, depth, wrecks, chests) and the boat sonar.
var encounters: Node3D
var diving: Node3D
var sonar: Control
const Economy=preload("res://scripts/inventory/harbor_economy.gd")
const SaveGame=preload("res://scripts/inventory/save_game.gd")
## Progress is saved to user:// in normal play; tests and tools (run with --script) never touch it.
var saving_enabled: bool=not ("--script" in OS.get_cmdline_args())
var autosave_clock: float=0.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
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
	boat.anchor.floor_sampler=world.get_node("VidaNoFundo").floor_at
	boat.anchor.changed.connect(func(state: String) -> void:
		if hud==null:return
		if state=="down":hud.notify("Âncora firme no fundo · %.0f m de corrente."%boat.anchor.rode_length);audio.cue("splash")
		elif state=="up":hud.notify("Âncora a bordo. Pode navegar."))
	boat.sank.connect(_on_boat_sank)
	boat.warning.connect(func(text: String) -> void:hud.notify(text))
	world.traffic.set_player_boat(boat)
	world.sea_events.set_player_boat(boat)
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
	fishing.nibble.connect(func(strength: float) -> void:
		fishing_visual.nibble(strength)
		if hud.fight_gauge!=null:hud.fight_gauge.nibble())
	fishing.state_changed.connect(_on_fishing_state)
	fishing_visual = FishingVisual.new()
	_add_system(fishing_visual)
	cast_marker=MeshInstance3D.new()
	# Discreet aim: a thin, faint ring lying on the water where the float will land (no floating ball).
	var ring:=TorusMesh.new();ring.inner_radius=.34;ring.outer_radius=.37;ring.rings=40;ring.ring_segments=4;cast_marker.mesh=ring
	var aim_material:=StandardMaterial3D.new();aim_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;aim_material.albedo_color=Color(.9,.97,.95,.38)
	aim_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;aim_material.no_depth_test=false
	cast_marker.material_override=aim_material;cast_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;cast_marker.scale=Vector3(1,.15,1);add_child(cast_marker);cast_marker.hide()
	audio = OceanAudio.new()
	_add_system(audio)
	audio.configure(world.ocean,boat)
	surface_fish=preload("res://scripts/fishing/surface_fish.gd").new()
	_add_system(surface_fish); surface_fish.effects=world.ocean.effects
	hooked=preload("res://scripts/fishing/hooked_fish.gd").new();hooked.name="PeixeFisgado";_add_system(hooked)
	hooked.thrash.connect(func(at: Vector3,strength: float) -> void:world.ocean.effects.splash(at,strength,true))
	fishing_visual.hooked=hooked
	holders=preload("res://scripts/fishing/rod_holders.gd").new();holders.name="SuportesDeVara";holders.game=self;holders.boat=boat;_add_system(holders)
	holders.rebuild.call_deferred()
	boat.hull_changed.connect(func() -> void:holders.rebuild())
	holders.strike.connect(_on_holder_strike)
	crew=preload("res://scripts/boats/crew_manager.gd").new();crew.name="Tripulacao";crew.game=self;crew.boat=boat;_add_system(crew)
	boat.hull_changed.connect(func() -> void:crew.sync())
	marine=preload("res://scripts/creatures/marine_ecosystem.gd").new();marine.game=self;marine.name="VidaMarinha";_add_system(marine)
	gear=preload("res://scripts/fishing/sea_gear.gd").new();gear.game=self;gear.name="Apetrechos";_add_system(gear)
	lairs=preload("res://scripts/world/monster_lairs.gd").new();lairs.game=self;lairs.name="TerritoriosDosMonstros";_add_system(lairs)
	missions=preload("res://scripts/inventory/missions.gd").new();missions.game=self;missions.name="Missoes";_add_system(missions)
	encounters=preload("res://scripts/world/encounters.gd").new();encounters.game=self;encounters.name="Encontros";_add_system(encounters)
	diving=preload("res://scripts/fishing/diving.gd").new();diving.game=self;diving.name="Mergulho";_add_system(diving)
	hud = HUD.new()
	world.sea_events.event_started.connect(func(text: String) -> void: hud.notify(text))
	world.ocean.season_changed.connect(func(season_name: String) -> void:
		hud.notify({"Estação Calma":"Começa a Estação Calma: mar manso e poucas tempestades.","Estação da Migração":"Começa a Estação da Migração: cardumes viajam longe e as baleias passam mais.","Estação das Tempestades":"Começa a Estação das Tempestades: frentes escuras se formam com frequência."}.get(season_name,season_name)))
	add_child(hud)
	hud.start_requested.connect(begin_play)
	hud.resume_requested.connect(resume_play)
	hud.return_requested.connect(return_to_harbor)
	hud.quit_requested.connect(func() -> void: save_progress();get_tree().quit())
	hud.new_game_requested.connect(func() -> void: SaveGame.erase();hud.set_has_save(false))
	hud.set_has_save(saving_enabled and SaveGame.exists())
	hud.weather_selected.connect(func(index: int) -> void: world.ocean.weather.choose(index))
	hud.service_action.connect(_service_action)
	hud.service_closed.connect(func() -> void: service_id="";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
	hud.time_selected.connect(func(hour_value: float) -> void: world.ocean.hour=hour_value)
	hud.map_view.game=self
	hud.missions=missions
	sonar=preload("res://scripts/fishing/sonar.gd").new();sonar.game=self;sonar.name="Sonar";hud.add_child(sonar)
	dev=preload("res://scripts/dev/developer_mode.gd").new();dev.game=self;dev.name="ModoDesenvolvedor";add_child(dev)
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

## Writes the save file (no-op in tests). Returns true when written.
func save_progress() -> bool:
	if not saving_enabled or not started or (dev!=null and dev.active):return false
	return SaveGame.save(self)

func begin_play() -> void:
	if saving_enabled and SaveGame.load_into(self):
		hud.call_deferred("notify","Progresso carregado. Bem-vindo de volta!")
	if crew!=null:crew.sync.call_deferred()
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
			hud.show_pause();save_progress()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if not started or get_tree().paused:
		return
	if event.is_action_pressed("dev_toggle") and not event.is_echo():
		dev.toggle()
		get_viewport().set_input_as_handled()
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
	if event.is_action_pressed("sails") and player.in_boat and boat.has_sails():hud.notify(boat.cycle_sails())
	if event.is_action_pressed("anchor") and player.in_boat:toggle_anchor()
	if event.is_action_pressed("feed") and not event.is_echo():hud.notify(gear.throw_feed())
	if event.is_action_pressed("cast_net") and not event.is_echo():hud.notify(gear.gillnet_action() if Input.is_key_pressed(KEY_SHIFT) else gear.begin_net_throw())
	if event.is_action_released("cast_net"):
		var thrown: String=gear.release_net_throw()
		if not thrown.is_empty():hud.notify(thrown)
	if event.is_action_pressed("trap") and not event.is_echo():hud.notify(gear.trap_action())
	if event.is_action_pressed("harpoon") and not event.is_echo():hud.notify(lairs.fire_harpoon())
	if event.is_action_pressed("flare") and not event.is_echo():
		var flare_text: String=lairs.fire_flare()
		if encounters.scare() and not flare_text.begins_with("Sem"):flare_text="O clarão vermelho afasta a criatura que seguia o barco!"
		hud.notify(flare_text)
	if event.is_action_pressed("sonar") and not event.is_echo():hud.notify(sonar.ping())
	if event.is_action_pressed("boat_lights"):
		boat.toggle_lights();hud.notify("Luzes do barco acesas." if boat.lights_enabled else "Luzes do barco apagadas.")
	if event.is_action_pressed("observe_wildlife"):
		hud.notify("Vigia Abissal · +40 moedas" if marine.observe_guardian() else "Aproxime-se devagar para observar.")
	if event.is_action_pressed("keep_catch"): finish_catch(false)
	if event.is_action_pressed("release_catch"):
		if pending_catch.is_empty() and gear.can_release():hud.notify(gear.release_haul())
		else:finish_catch(true)
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
	_check_berth()
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
			var held_at: Vector3=hand.origin+Vector3(0,-.32,0)
			# Big fish are held in both hands, across the chest; small ones hang from one hand.
			if float(pending_catch.get("weight",1.))>6. and player.visual.has_method("two_hand_point"):held_at=player.visual.two_hand_point()
			catch_display.global_transform=Transform3D(Basis(Vector3.FORWARD,-PI*.5),held_at)
			catch_display.visible=not hooked.landing()
	if not player.in_boat:
		player.global_position=preload("res://scripts/world/archipelago_layout.gd").wrapped(player.global_position)

func _process(delta: float) -> void:
	if started and not get_tree().paused:
		autosave_clock+=delta
		if autosave_clock>60. and not boat.sinking:autosave_clock=0.;save_progress()
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
		cast_distance=lerpf(5.,42.+fishing.cast_range_bonus,cast_charge)*_wind_factor()
	if "cast_hold" in player.visual:player.visual.cast_hold=cast_charge if aiming else -1.
	var aim_target:=_cast_target() if aiming else {}
	cast_marker.visible=not aim_target.is_empty()
	if cast_marker.visible:
		cast_marker.global_position=aim_target.position
		cast_marker.position.y=preload("res://scripts/world/wave_field.gd").height_at(cast_marker.position)+.05
		var pulse: float=1.+.12*sin(Time.get_ticks_msec()*.006)
		cast_marker.scale=Vector3(pulse,.15,pulse)*(.8+cast_charge*.6)
	if fishing.active():
		var line_distance: float=player.global_position.distance_to(fishing_visual.target)
		fishing.line_stretch=clampf((line_distance-42.-fishing.cast_range_bonus)/14.,0.,1.)
		if player.swimming or line_distance>56.+fishing.cast_range_bonus:
			fishing.cancel();hud.notify("Linha fora de alcance.")
	fishing.set_reeling(Input.is_action_pressed("fish"))
	if fishing.state==Fishing.State.REELING:
		hooked.fight(delta,player.global_position,fishing.tension,fishing.progress,fishing.surging,fishing.fight_phase)
	fishing_visual.tension=fishing.tension
	if fishing.state in [Fishing.State.CASTING,Fishing.State.WAITING]:fishing.conditions=_fishing_conditions()
	# Signs on the water while waiting: over a school small fish now and then jump near the float.
	if fishing.state==Fishing.State.WAITING and not surface_fish.visible and randf()<delta*.12:
		var school: String=marine.school_at(fishing_visual.target)
		if school!="":
			for sp: Resource in Fishing.SPECIES:
				if sp.id==school:
					var off:=Vector2.from_angle(randf()*TAU)*randf_range(3.,8.)
					surface_fish.breach(fishing_visual.target+Vector3(off.x,0,off.y),sp,.3);break
	if hud.throw_meter!=null:hud.throw_meter.show_value(gear.net_charge,gear.NET_SWEET,gear.NET_BAND)
	if hud.fight_gauge!=null:
		hud.fight_gauge.update_from(fishing,int(inventory.equipment.get("rod",0)),int(inventory.equipment.get("line",0)))
		hud.fight_gauge.visible=hud.fight_gauge.visible and started
	if "rod_bend" in player.visual:player.visual.rod_bend=_rod_load()
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
		hud.objective.text = missions.objective_text()

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
		# Longer casts fly longer: rod throw plus the float's flight time.
		var flight: float=.35+player.global_position.distance_to(target)*.016
		fishing.cast_duration=fishing_visual.RELEASE_AT+flight;fishing_visual.cast_time=fishing.cast_duration
		fishing.bait_bonus=.25 if inventory.bait>0 else 0.
		if inventory.bait>0:inventory.bait-=1
		var fed:=false
		for f: Vector3 in marine.feed_targets():
			if Vector2(f.x-target.x,f.z-target.z).length()<14.:fed=true
		fishing.feed_bonus=.55 if fed else 0.
		fishing.start_cast(marine.region_at(target),marine.school_at(target))
	else:
		fishing.strike()

func interact() -> void:
	aiming=false
	if diving!=null and diving.try_open():return
	if player.in_boat and player.on_deck:
		# Whoever is closer, a crewmate or a rod holder, is what E talks to.
		var mate: Node3D=crew.near(player.global_position) if crew!=null else null
		var holder: int=holders.nearest(player.global_position)
		var mate_d: float=mate.global_position.distance_to(player.global_position) if mate!=null else 99.
		var holder_d: float=(holders.holders[holder].node as Node3D).global_position.distance_to(player.global_position) if holder>=0 else 99.
		if mate!=null and mate_d<holder_d:hud.notify(crew.cycle_task(mate));return
		if _holder_action():return
		# Water on deck: E bails a bucket over the side.
		if boat.water_fraction()>.03 and not fishing.active():
			boat.bail();player.visual.play_action("ual/PickUp",.7)
			world.ocean.effects.splash(boat.global_position+boat.global_basis.x*(float(boat.hull_spec.beam)*.5*boat.size_factor+.4),.25,false)
			hud.notify("Esgotando… %d%% de água a bordo."%int(boat.water_fraction()*100.));return
	if fishing.active():
		fishing.cancel()
	if player.in_boat:
		var ship=world.traffic.hailable(boat.global_position)
		if ship!=null:
			hail_vessel(ship);return
		disembark()
	elif player.global_position.distance_to(boat.global_position + Vector3(0, 1, 0)) < boat.board_radius():
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
		player.deck_local=boat.deck_layout().start;player.deck_level=-1
		player.deck_velocity=Vector3.ZERO;player.deck_sway=Vector3.ZERO;player.prev_boat_speed=boat.speed
	boat.set_occupied(not player.on_deck)
	hud.notify("R · Assumir o leme" if player.on_deck else "Você assumiu o leme.")

func disembark() -> void:
	var target: Vector3=boat.exit_point()
	if near_dock() and absf(boat.speed)<2.:
		boat.reset_to_dock();target=Vector3(0,1.55,-23)
	else:
		for side: float in [-1.,1.]:
			var p: Vector3=boat.global_position+boat.global_basis*Vector3(side*(float(boat.hull_spec.beam)*.5*boat.size_factor+2.),0,2.)
			var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*3.,p-Vector3.UP*3.,1))
			if not hit.is_empty() and hit.position.y>.15 and hit.position.y<2.7 and hit.normal.y>.65:
				target=hit.position+Vector3.UP*.1;break
	boat.set_occupied(false);player.set_boating(false);player.global_position=target;player.velocity=Vector3.ZERO
	hud.notify("Desembarcou.")

## First E beside a vessel hails it (it heaves to and the crew answers); a second E takes its offer.
func hail_vessel(ship) -> void:
	if ship.activity!="saudado":
		ship.hail();ship.set_meta("traded",false)
		audio.cue("horn");hud.notify(world.traffic.greeting(ship))
	elif not ship.get_meta("traded",false):
		ship.set_meta("traded",true);hud.notify(world.traffic.trade(ship,self))
		ship.activity_clock=minf(ship.activity_clock,8.)
	else:
		hud.notify("%s acena e segue viagem."%ship.ship_name)

func _check_berth() -> void:
	var yard=world.village.get("shipyard") if world!=null and world.village!=null else null
	if yard==null or boat==null:return
	var inside: bool=yard.in_berth(boat.global_position)
	if not inside:berth_opened=false;return
	if berth_opened or hud==null or hud.service_open or not player.in_boat or absf(boat.speed)>1.5:return
	berth_opened=true;service_id="shipyard"
	hud.open_service("shipyard",inventory,boat,world.village.bridge_district.stock);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	hud.notify("Barco na vaga do estaleiro.")

func toggle_anchor() -> void:
	if absf(boat.speed)>2.5 and boat.anchor.state=="up":
		hud.notify("Reduza a velocidade para lançar a âncora.");return
	var state: String=boat.anchor.toggle()
	match state:
		"dropping":hud.notify("Âncora lançada.");audio.cue("chain")
		"raising":hud.notify("Recolhendo a âncora…");audio.cue("chain")
		"too_deep":hud.notify("Fundo muito profundo: a corrente da âncora não alcança (máx. 45 m).")

func near_market() -> bool:
	return Vector2(player.global_position.x - 6, player.global_position.z + 6).length() < 3.3

func near_dock() -> bool:
	return Vector2(boat.global_position.x - 3.9, boat.global_position.z + 23).length() < 9.5

func _interaction_hint() -> String:
	if player.flying:return "T · Encerrar voo"
	if diving!=null and not diving.hint().is_empty():return diving.hint()
	if marine!=null and marine.guardian_in_range() and pending_catch.is_empty() and not fishing.active():return "V · Observar"
	if aiming:return "%.0f m · Solte para lançar"%cast_distance
	if not pending_catch.is_empty():return "G · Guardar    X · Devolver"
	if player.in_boat and player.on_deck and holders!=null:
		var i: int=holders.nearest(player.global_position)
		if i>=0:
			match str(holders.holders[i].state):
				"empty":
					if fishing.state==Fishing.State.WAITING:return "E · Pôr a vara no suporte"
				"biting":return "E · Pegar a vara · PEIXE!"
				_:return "E · Recolher a vara do suporte"
		var mate: Node3D=crew.near(player.global_position) if crew!=null else null
		if mate!=null:return "E · %s (tarefa: %s)"%[mate.sailor_name,str(mate.get_meta("task","convés"))]
		if boat.water_fraction()>.03 and not fishing.active():return "E · Esgotar a água (%d%%)"%int(boat.water_fraction()*100.)
	if fishing.active():return ""
	if player.in_boat:
		if lairs!=null and lairs.encounter():return "SHIFT · Turbo    Y · Sinalizador (%d)    H · Arpão (%d)"%[inventory.flares,inventory.harpoons if inventory.equipment.get("harpoon",0)>0 else 0]
		var near_ship=world.traffic.hailable(boat.global_position)
		if near_ship!=null:return ("E · Trocar com " if near_ship.activity=="saudado" and not near_ship.get_meta("traded",false) else "E · Saudar ")+near_ship.ship_name
		var anchor_hint: String={"up":"Z · Âncora","dropping":"Âncora descendo…","down":"Ancorado · Z recolher","raising":"Recolhendo âncora…"}[boat.anchor.state]
		var trap: Dictionary=gear.nearest_trap(boat.global_position)
		if not trap.is_empty():return "B · Recolher covo" if float(trap.soak)>=gear.TRAP_SOAK else "Covo na água · %d s"%int(gear.TRAP_SOAK-float(trap.soak))
		if player.on_deck:
			var ladder: String=player.ladder_hint()
			var trap_hint: String=("    B · Covo (%d)"%inventory.traps) if inventory.traps>0 else ""
			return ("%s    "%ladder if ladder!="" else "")+"R · Leme    E · Sair    C · Ração    N · Tarrafa (segure)"+trap_hint+"    "+anchor_hint
		var turbo:="TURBO!" if boat.boost>0. else ("SHIFT turbo" if boat.boost_cooldown<=0. else "turbo %ds"%int(ceil(boat.boost_cooldown)))
		var sails:=("    P · Velas: %s"%boat.point_of_sail()) if boat.has_sails() else ""
		var water:=("    ÁGUA %d%%"%int(boat.water_fraction()*100.)) if boat.water_fraction()>.03 else ""
		return "%.0f nós · %d%% casco%s · %s    R · Convés    %s%s"%[absf(boat.speed)*1.94,int(boat.integrity*100.),water,turbo,anchor_hint,sails]
	if player.global_position.distance_to(boat.global_position+Vector3(0,1,0))<boat.board_radius()-1.:return "E · Embarcar"
	if near_market():return "E · Vender capturas"
	var service: String=world.village.nearby_service(player.global_position)
	if not service.is_empty():return "E · %s"%hud.SERVICE_NAMES.get(service.get_slice("_",0),service)
	var discovery: Dictionary=world.village.nearby_discovery(player.global_position)
	if not discovery.is_empty():return "E · "+str(discovery.title)
	return ""

func _on_caught(data: Dictionary) -> void:
	if stow_tween!=null: stow_tween.kill()
	stowing=false;catch_display.scale=Vector3.ONE
	pending_catch=data.duplicate(true)
	if "hold_clip" in player.visual:player.visual.hold_clip="Hold" if float(data.get("weight",1.))>6. else "ual/FishHold"
	caught_once = true
	audio.cue("catch")
	if hooked.visible:hooked.land(player.visual.catch_hand_transform().origin)
	else:world.ocean.effects.splash(fishing_visual.target,clampf(.5+float(data.get("weight",1.))*.08,.5,2.5),true)
	if catch_display != null:
		catch_display.show_catch(data)
		catch_display.held=true
		catch_display.visible=not hooked.landing()
	hud.notify("Captura!")

func finish_catch(release: bool) -> void:
	if pending_catch.is_empty():return
	inventory.record(pending_catch,release)
	if release:
		# Lowered back into the water beside the angler; it rests a moment and swims off.
		var ahead: Vector3=Vector3(sin(player.yaw),0.,cos(player.yaw))*-1.
		var reach: float=(float(boat.hull_spec.beam)*.5*boat.size_factor+1.2) if player.in_boat else 1.6
		var water: Vector3=(boat.global_position if player.in_boat else player.global_position)+(boat.global_basis.x*-reach if player.in_boat else ahead*reach)
		water.y=preload("res://scripts/world/wave_field.gd").height_at(water)-.15
		hooked.release(fishing.species_current,catch_display.global_position,water)
		if player.visual.has_method("play_action") and not player.swimming:player.visual.play_action("ual/PickUp",1.2)
		hud.notify("Peixe devolvido.")
	else:
		if inventory.add_catch(pending_catch):
			hud.notify("Captura guardada %s · porão %d/%d."%["no balde do barco" if player.in_boat else "na mochila",inventory.catches.size(),inventory.hold_limit])
		else:hud.notify("Porão cheio (%d)! Venda no mercado ou devolva o peixe (X)."%inventory.hold_limit)
	pending_catch.clear();player.holding_fish=false
	if release:
		catch_display.held=false;catch_display.remaining=0.;catch_display.hide()
	else:
		stowing=true;stow_origin=catch_display.global_position
		if player.visual.has_method("play_action"):player.visual.play_action("ual/Interact",.8)
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
	elif action.begins_with("boat:"):message=Economy.buy_boat(action.get_slice(":",1),inventory,boat,fishing)
	elif action.begins_with("buy_stock:"):
		var index:=int(action.get_slice(":",1));var stock: Array=world.village.bridge_district.stock
		if index>=0 and index<stock.size():
			var price:=ceili(float(stock[index].value)*1.25)
			if inventory.money>=price:
				inventory.money-=price;inventory.add_catch(stock[index]);stock.remove_at(index);message="Peixe comprado."
			else:message="Moedas insuficientes."
	elif action.begins_with("contract:"):message=missions.deliver(int(action.get_slice(":",1)))
	elif action.contains(":") or action in ["use_kit","use_tackle","craft_kit","sell_bait","sell_material"]:message=Economy.trade(action,inventory,boat)
	elif action=="sell":
		var amount: int=inventory.sell_all();sold_once=sold_once or amount>0;message="Venda: +%d moedas."%amount
		if amount>0:audio.cue("coins");save_progress()
	elif action=="store":
		inventory.stored_catches.append_array(inventory.catches);inventory.catches.clear();inventory.changed.emit();message="Capturas guardadas no armazém."
	elif action=="withdraw":
		inventory.catches.append_array(inventory.stored_catches);inventory.stored_catches.clear();inventory.changed.emit();message="Capturas retiradas do armazém."
	elif action=="rest":world.ocean.hour=8.;message="Você descansou até a manhã."
	elif action=="hire":message=crew.hire()
	elif action=="dismiss":message=crew.dismiss()
	hud.open_service(service_id,inventory,boat,world.village.bridge_district.stock);hud.service_message.text=message

func _on_fishing_message(_message: String) -> void:
	if is_instance_valid(hud) and fishing.state==Fishing.State.ESCAPED:
		hud.notify(fishing.last_message if fishing.last_message!="" else "O peixe escapou.")

func _on_fishing_state(state: int) -> void:
	if state in [Fishing.State.IDLE,Fishing.State.ESCAPED] and is_instance_valid(surface_fish): surface_fish.hide()
	if state==Fishing.State.REELING and is_instance_valid(hooked):
		surface_fish.hide()
		hooked.hook(fishing_visual.target,player.global_position,fishing.species_current)
		world.ocean.effects.splash(fishing_visual.target,.9,true)
	if state==Fishing.State.ESCAPED and is_instance_valid(hooked):hooked.escape()
	if state==Fishing.State.IDLE and is_instance_valid(hooked) and hooked.mode=="fight":hooked.escape()
	if is_instance_valid(fishing_visual) and state in [Fishing.State.WAITING,Fishing.State.BITE]:
		world.ocean.effects.splash(fishing_visual.target,.5 if state==Fishing.State.WAITING else .85,state==Fishing.State.BITE)
	if state == Fishing.State.BITE and is_instance_valid(audio):
		audio.cue("bite")

func _recover_player() -> void:
	fishing.cancel()
	player.global_position = world.safe_spawn()
	player.velocity = Vector3.ZERO
	hud.notify("De volta ao cais.")

## The hull gave way: the player ends up in the water, a passing fishing boat picks them up and tows the
## wreck to the boatyard. The catch aboard is lost and the tow costs money; the hull comes back patched.
func _on_boat_sank() -> void:
	var at:=boat.global_position
	aiming=false;fishing.cancel()
	boat.set_occupied(false);player.set_boating(false)
	player.global_position=at+Vector3(2.5,-.5,0)
	hud.notify("O barco afundou! Segure-se… um pesqueiro vem te buscar.")
	audio.cue("horn")
	await get_tree().create_timer(5.).timeout
	var lost: int=inventory.catches.size()
	inventory.catches.clear()
	var fee:=mini(inventory.money,40);inventory.money-=fee
	boat.integrity=.35
	return_to_harbor()
	inventory.changed.emit()
	hud.notify("Resgatado e rebocado ao porto · reboque %d moedas%s. Casco remendado em 35%%."%[fee," · %d capturas perdidas"%lost if lost>0 else ""])

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
		"fly_toggle": KEY_T, "fly_down": KEY_CTRL,"dev_toggle":KEY_F6,
		"deck":KEY_R,"sails":KEY_P,"anchor":KEY_Z,"feed":KEY_C,"cast_net":KEY_N,"trap":KEY_B,"keep_catch":KEY_G,"release_catch":KEY_X,"world_map":KEY_M,"journal":KEY_J,"harpoon":KEY_H,"flare":KEY_Y,"sonar":KEY_O,
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

## How hard the rod is loaded: nods on a bite, bends with line tension during the fight.
func _rod_load() -> float:
	match fishing.state:
		Fishing.State.BITE:return .22+.18*maxf(0.,sin(Time.get_ticks_msec()*.025))
		Fishing.State.REELING:return clampf(.15+fishing.tension*.95+(.15 if fishing.surging else 0.),0.,1.)
		Fishing.State.WAITING:return .04
	return 0.

## A following wind carries the cast further, a headwind shortens it (up to about a fifth in a gale).
func _wind_factor() -> float:
	var Waves=preload("res://scripts/world/wave_field.gd")
	var forward:=Vector2(-sin(player.yaw),-cos(player.yaw))
	return 1.+forward.dot(Waves.direction)*Waves.wind*.22

## What the fish under the float think of this moment (fishing_system.conditions): time of day, weather,
## the school beneath, the boat's noise and the depth all change how soon something bites.
func _fishing_conditions(at: Vector3=Vector3.INF,trolling: bool=false) -> Dictionary:
	var Waves=preload("res://scripts/world/wave_field.gd")
	if at==Vector3.INF:at=fishing_visual.target
	var depth: float=Waves.depth_at(Vector2(at.x,at.z))
	var hour: float=world.ocean.hour
	var rate:=1.
	if (hour>=5. and hour<8.) or (hour>=17. and hour<20.):rate*=1.6       # dawn and dusk feeding
	elif hour>=11. and hour<14.:rate*=.75                                  # bright midday
	elif hour>=21. or hour<4.:rate*=.85
	var weather=world.ocean.weather
	if weather.rain>.1 and weather.rain<.5:rate*=1.15
	rate*=1.-clampf(Waves.energy-.5,0.,.5)*.8                              # rough water puts fish down
	if marine.school_at(at)!="":rate*=3.
	elif marine.fish_near(at,10.)>5:rate*=1.5
	if player.in_boat:
		# A rod left in a holder can troll slowly behind the boat; a hand line wants the boat still.
		if trolling:rate*=.6 if absf(boat.speed)>1. and absf(boat.speed)<3.5 else (.15 if absf(boat.speed)>=3.5 else 1.)
		else:rate*=.25 if absf(boat.speed)>1. else 1.
		rate*=1.-.6*clampf(absf(float(boat.engine_rpm)),0.,1.)
	if depth<1.5:rate*=.5
	return {"rate":rate,"depth":depth,"hour":hour}

func _holder_rate(at: Vector3) -> float:
	return float(_fishing_conditions(at,true).rate)

## E on deck by a holder: put the rod you are fishing with in it, take a rod with a fish on, or reel one in.
func _holder_action() -> bool:
	var i: int=holders.nearest(player.global_position)
	if i<0:return false
	var h: Dictionary=holders.holders[i]
	match str(h.state):
		"empty":
			if fishing.state!=Fishing.State.WAITING:hud.notify("Lance a linha e traga a vara até o suporte (E).");return true
			holders.set_rod(i,fishing_visual.target,fishing.region_current,fishing._school)
			fishing._change_state(Fishing.State.IDLE)
			hud.notify("Vara no suporte · a linha continua pescando.")
			return true
		"biting":
			if fishing.active() or not pending_catch.is_empty():hud.notify("Termine a pescaria em curso primeiro.");return true
			var fish: Dictionary=holders.take_rod(i)
			fishing_visual.target=fish.water;fishing_visual.cast_start=player.rod_tip()
			fishing.hook_external(fish.species,float(fish.weight),str(fish.region))
			hud.notify("Você pegou a vara · %s na linha!"%str(fish.species.display_name))
			return true
		_:
			holders.take_rod(i)
			hud.notify("Vara recolhida do suporte.")
			return true

func _on_holder_strike(i: int) -> void:
	if crew!=null:crew.alert_holder(i)
	if int(inventory.equipment.get("bell",0))>0:
		audio.cue_at("bell",(holders.holders[i].node as Node3D).global_position,4.)
		hud.notify("O sino tocou · peixe na vara do suporte!")
