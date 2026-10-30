extends CanvasLayer
## Developer mode (F6), for testing the world quickly. While it is on, progress is not saved and the real
## inventory is put aside (restored when it is switched off). Keys:
##   F7 next weather · F8 +3 h · F9 boat to the next region · F10 boat to the next monster territory
##   F11 whirlpool ahead · F12 storm cell over the boat · I invulnerable hull · T flight (as usual)
## A panel shows FPS, draw calls, position, region, depth, weather and the active key list.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Economy=preload("res://scripts/inventory/harbor_economy.gd")
var game: Node
var active: bool=false
var invulnerable: bool=true
var snapshot: Dictionary={}
var panel: Label
var _region: int=-1
var _lair: int=-1

func _ready() -> void:
	layer=60;process_mode=Node.PROCESS_MODE_ALWAYS
	panel=Label.new();panel.position=Vector2(18,96);panel.add_theme_font_size_override("font_size",13)
	panel.add_theme_color_override("font_color",Color("d8fff4"));panel.add_theme_color_override("font_outline_color",Color(0,0,0,.85));panel.add_theme_constant_override("outline_size",5)
	add_child(panel);panel.hide()

func toggle() -> void:
	set_active(not active)

func set_active(on: bool) -> void:
	if on==active:return
	active=on;panel.visible=on
	var inv=game.inventory
	if on:
		snapshot={"money":inv.money,"bait":inv.bait,"materials":inv.materials,"equipment":inv.equipment.duplicate(true),"goods":inv.goods.duplicate(true),
			"integrity":game.boat.integrity,"flares":inv.flares,"harpoons":inv.harpoons,"feed":inv.feed,"traps":inv.traps}
		inv.money=99999;inv.bait=99;inv.materials=99;inv.flares=99;inv.harpoons=99;inv.feed=99;inv.traps=9
		inv.goods={"repair_kit":9,"tackle":9,"canvas":9}
		inv.equipment={"rod":3,"line":3,"hook":3,"engine":3,"reel":3,"searchlight":1,"hull":1,"harpoon":1,"net":1,"sonar":1,"diving":2}
		Economy.apply(inv,game.boat,game.fishing);inv.changed.emit()
		game.hud.notify("MODO DESENVOLVEDOR · F7 clima · F8 hora · F9 região · F10 monstro · F11 redemoinho · F12 tempestade · I casco invulnerável · F6 sai")
	else:
		for key: String in snapshot:
			if key=="integrity":game.boat.integrity=float(snapshot[key])
			else:inv.set(key,snapshot[key])
		snapshot.clear();Economy.apply(inv,game.boat,game.fishing);inv.changed.emit()
		game.hud.notify("Modo desenvolvedor desligado · inventário normal restaurado")

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:return
	match (event as InputEventKey).keycode:
		KEY_F7:
			var w=game.world.ocean.weather;var next:int=(int(w.state)+1)%6;w.settle(next)
			game.hud.notify("Clima: "+str(w.LABELS[next]))
		KEY_F8:
			game.world.ocean.hour=fmod(float(game.world.ocean.hour)+3.,24.);game.hud.notify("Hora: %02d:00"%int(game.world.ocean.hour))
		KEY_F9:_next_region()
		KEY_F10:_next_lair()
		KEY_F11:
			var sea=game.world.get("whirlpools")
			if sea!=null:game.hud.notify(sea.spawn_near(game.boat.global_position-game.boat.global_basis.z*90.))
		KEY_F12:
			var storms=game.world.get("storms")
			if storms!=null:game.hud.notify(storms.spawn_at(game.boat.global_position))
		KEY_I:
			invulnerable=not invulnerable;game.hud.notify("Casco invulnerável" if invulnerable else "Casco normal")
		_:return
	get_viewport().set_input_as_handled()

func _water_near(lobe: int,off: float) -> Vector3:
	var l: Vector4=Layout.LOBES[lobe];var p:=Vector2(l.x,l.y)
	for step: int in 900:
		p+=Vector2(.8,.6)*2.
		if Layout.coast(p).x>=off:return Vector3(p.x,0,p.y)
	return Vector3(l.x,0,l.y)

func _put_boat(at: Vector3) -> void:
	var boat: CharacterBody3D=game.boat
	boat.global_position=Vector3(at.x,0,at.z);boat.speed=0.;boat.velocity=Vector3.ZERO
	if not game.player.in_boat:game.player.set_flying(false);game.player.global_position=at+Vector3(0,2,0)

func _next_region() -> void:
	_region=(_region+1)%Layout.LOBES.size()
	var r: Dictionary=Layout.region_for_lobe(_region)
	_put_boat(_water_near(_region,60.))
	game.hud.notify("Região %d: %s"%[_region,str(r.get("name","?"))])

func _next_lair() -> void:
	var lairs: Array=game.lairs.lairs
	_lair=(_lair+1)%lairs.size()
	var lair: Dictionary=lairs[_lair]
	_put_boat((lair.center as Vector3)+Vector3(float(lair.radius)*.7,0,0))
	game.hud.notify("Território: "+str(lair.name))

func _process(_delta: float) -> void:
	if not active or game==null:return
	if invulnerable and not game.boat.sinking:game.boat.integrity=1.
	var at: Vector3=game.boat.global_position if game.player.in_boat else game.player.global_position
	var region: Dictionary=Layout.region_at(Vector2(at.x,at.z))
	var w=game.world.ocean.weather
	var depth:=Waves.depth_at(Vector2(at.x,at.z))
	panel.text="DEV · %d FPS · %d draw calls · %d objetos\n(%.0f, %.1f, %.0f) · %s · fundo %.0f m\n%s · vento %.2f · ondas %.2f · %02d:%02d\nF7 clima F8 hora F9 região F10 monstro F11 redemoinho F12 tempestade I casco %s"%[
		Engine.get_frames_per_second(),int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
		at.x,at.y,at.z,str(region.get("name","mar aberto")),depth,str(w.LABELS[w.state]),Waves.wind,Waves.energy,
		int(game.world.ocean.hour),int(fmod(float(game.world.ocean.hour),1.)*60.),"ON" if invulnerable else "off"]
