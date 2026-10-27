extends Node3D
## Real diving: limited air, depth limits, and things worth diving for.
##  · Air: without gear you hold your breath ~30 s; the dive mask and tank from the boatyard give 75 s and the
##    deep-diving rig 150 s. An air bar shows while under water; running out forces you up.
##  · Depth: free diving reaches 12 m, the mask 35 m, the deep rig 80 m; going deeper hurts (pressure) and
##    pushes you back.
##  · Sites: wrecks resting on the bottom around the archipelago and the caves under some whirlpools, each
##    with a chest (E while swimming next to it): coins and a treasure for the encyclopedia. Opened chests are
##    remembered in the save. The sonar shows sites as metallic echoes or cavities.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const AIR: Array[float]=[30.,75.,150.]
const DEPTH: Array[float]=[12.,35.,80.]
const TREASURES: Array=[["Moeda de ouro antiga","Rara",120],["Pérola negra","Rara",160],["Bússola de latão","Incomum",80],
	["Ídolo de jade","Lendária",300],["Garrafa com mapa","Incomum",90],["Coroa coberta de coral","Lendária",360]]
var game: Node3D
var sites: Array[Dictionary]=[]
var opened: Dictionary={}
var bar: ProgressBar
var bar_label: Label
var _hurt_clock: float=0.
var _rng:=RandomNumberGenerator.new()
var _painted: ShaderMaterial

func _ready() -> void:
	_rng.seed=2468
	var ui:=CanvasLayer.new();ui.layer=20;add_child(ui)
	bar=ProgressBar.new();bar.custom_minimum_size=Vector2(260,14);bar.show_percentage=false;bar.max_value=1.
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);bar.position=Vector2(-130,-120);bar.visible=false
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("6fe0ff");fill.corner_radius_top_left=6;fill.corner_radius_top_right=6;fill.corner_radius_bottom_left=6;fill.corner_radius_bottom_right=6
	var back:=StyleBoxFlat.new();back.bg_color=Color(0,0,0,.45);back.corner_radius_top_left=6;back.corner_radius_top_right=6;back.corner_radius_bottom_left=6;back.corner_radius_bottom_right=6
	bar.add_theme_stylebox_override("fill",fill);bar.add_theme_stylebox_override("background",back);ui.add_child(bar)
	bar_label=Label.new();bar_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);bar_label.position=Vector2(-130,-142);bar_label.visible=false
	bar_label.add_theme_font_size_override("font_size",13);bar_label.add_theme_constant_override("outline_size",4);bar_label.add_theme_color_override("font_outline_color",Color(0,0,0,.8));ui.add_child(bar_label)
	_place_sites.call_deferred()

func gear() -> int:return clampi(int(game.inventory.equipment.get("diving",0)),0,2)
func air_capacity() -> float:return AIR[gear()]
func max_depth() -> float:return DEPTH[gear()]

func _place_sites() -> void:
	# Wrecks: around the home island first (easy dives), then further out in deeper water.
	var plan: Array=[[Vector2(330,-60),"rowboat"],[Vector2(-260,-120),"rowboat"],[Vector2(420,420),"galleon"],[Vector2(-520,640),"cargo"],
		[Vector2(1347,-773),"galleon"],[Vector2(1650,700),"cargo"],[Vector2(-1300,300),"galleon"],[Vector2(2300,-300),"rowboat"]]
	for item: Array in plan:
		var p:=_bottom_spot(item[0],10.,45.)
		if p!=Vector3.INF:_wreck(p,str(item[1]))
	var wp=game.world.get("whirlpools")
	if wp!=null:
		for site: Dictionary in wp.sites:
			if str(site.secret)=="gruta":
				var at: Vector2=site.pos
				sites.append({"id":"gruta_%d_%d"%[int(at.x),int(at.y)],"kind":"gruta","pos":Vector3(at.x,float(site.floor)+.4,at.y),"node":null})
			elif str(site.secret)=="naufragio":
				var at2: Vector2=site.pos
				_wreck(Vector3(at2.x,-Waves.depth_at(at2),at2.y),"galleon")
	for site: Dictionary in sites:_chest(site)

## Searches around `near` for sea bottom between min and max depth.
func _bottom_spot(near: Vector2,min_d: float,max_d: float) -> Vector3:
	for ring: int in 80:
		var p:=near+Vector2.from_angle(float(ring)*2.4)*float(ring)*12.
		var c:=Layout.coast(p).x
		if c<20.:continue
		var d:=Waves.depth_at(p)
		if d>=min_d and d<=max_d:return Vector3(p.x,-d,p.y)
	return Vector3.INF

func _wreck(at: Vector3,model: String) -> void:
	if _painted==null:_painted=ShaderMaterial.new();_painted.shader=preload("res://assets/shaders/imported_model.gdshader")
	var file: String={"rowboat":"rowboat","galleon":"sailing_ship","cargo":"cargo_ship"}[model]
	var length: float={"rowboat":5.,"galleon":26.,"cargo":46.}[model]
	var node:=MeshInstance3D.new();node.name="Naufragio";node.mesh=load("res://assets/models/imported/%s.res"%file);node.material_override=_painted
	node.scale=Vector3.ONE*length;node.set_instance_shader_parameter("model_scale",length)
	node.set_instance_shader_parameter("hull_paint",Color("3a3a2a"));node.set_instance_shader_parameter("wreck",1.)
	node.position=at+Vector3(0,length*.02,0);node.rotation=Vector3(_rng.randf_range(-.12,.12),_rng.randf()*TAU,_rng.randf_range(.25,.55)*(1. if _rng.randf()<.5 else -1.))
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	var chest_at:=at+node.global_basis.x*length*.08+Vector3(0,.35,0) if node.is_inside_tree() else at+Vector3(length*.1,.35,0)
	sites.append({"id":"naufragio_%d_%d"%[int(at.x),int(at.z)],"kind":"naufragio","pos":chest_at,"node":node})

func _chest(site: Dictionary) -> void:
	var root:=Node3D.new();root.name="Bau";root.position=site.pos;add_child(root)
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color("5a3b22");wood.roughness=.8
	var brass:=StandardMaterial3D.new();brass.albedo_color=Color("c9a043");brass.metallic=.8;brass.roughness=.35
	var box:=MeshInstance3D.new();var bm:=BoxMesh.new();bm.size=Vector3(1.,.55,.65);box.mesh=bm;box.material_override=wood;root.add_child(box)
	var lid:=MeshInstance3D.new();var lm:=CylinderMesh.new();lm.top_radius=.33;lm.bottom_radius=.33;lm.height=1.;lid.mesh=lm;lid.material_override=wood
	lid.rotation.z=PI*.5;lid.position.y=.28;lid.scale=Vector3(1.,1.,.98);root.add_child(lid)
	for x: float in [-.35,.35]:
		var band:=MeshInstance3D.new();var b2:=BoxMesh.new();b2.size=Vector3(.06,.62,.7);band.mesh=b2;band.material_override=brass;band.position=Vector3(x,.12,0);root.add_child(band)
	var glow:=OmniLight3D.new();glow.light_color=Color("ffd27d");glow.omni_range=6.;glow.light_energy=1.2;glow.position.y=.8;root.add_child(glow)
	site.chest=root;site.lid=lid;site.glow=glow
	if opened.has(site.id):_show_opened(site)

func _show_opened(site: Dictionary) -> void:
	(site.lid as Node3D).rotation=Vector3(-1.1,0,PI*.5);(site.lid as Node3D).position=Vector3(0,.5,-.3);(site.glow as OmniLight3D).visible=false

## Chests already opened in a saved game.
func restore_opened(ids: Dictionary) -> void:
	opened.merge(ids,true)
	for site: Dictionary in sites:
		if opened.has(site.id) and site.has("lid"):_show_opened(site)

## The chest the swimming player can reach, or {}.
func reachable() -> Dictionary:
	if not game.player.swimming:return {}
	var p: Vector3=game.player.global_position
	for site: Dictionary in sites:
		if not opened.has(site.id) and (site.pos as Vector3).distance_to(p)<3.:return site
	return {}

func try_open() -> bool:
	var site:=reachable()
	if site.is_empty():return false
	opened[site.id]=true;_show_opened(site)
	var t: Array=TREASURES[_rng.randi()%TREASURES.size()]
	var coins:=_rng.randi_range(40,140)+int(t[2])
	game.inventory.money+=coins
	game.inventory.record({"id":"tesouro_"+str(t[0]).to_lower().replace(" ","_"),"name":str(t[0]),"rarity":str(t[1]),"weight":0.,"observation":true})
	game.inventory.stats["treasures"]=int(game.inventory.stats.get("treasures",0))+1
	game.inventory.changed.emit()
	game.audio.cue("coins")
	game.hud.notify("Baú aberto: %s · +%d moedas"%[t[0],coins])
	return true

func hint() -> String:
	return "" if reachable().is_empty() else "E · Abrir baú"

func _process(delta: float) -> void:
	if game==null:return
	var player: CharacterBody3D=game.player
	player.breath=air_capacity()
	var under: bool=player.swimming and player.diving
	bar.visible=under;bar_label.visible=under
	if not under:_hurt_clock=0.;return
	var left:=clampf(1.-player.dive_time/air_capacity(),0.,1.)
	bar.value=left
	var depth:=Waves.height_at(player.global_position)-player.global_position.y
	bar_label.text="Ar %d s · %d m de profundidade (limite %d m)"%[int(ceil(left*air_capacity())),int(depth),int(max_depth())]
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color=Color("6fe0ff") if left>.3 else Color("ff6f5a")
	if depth>max_depth():
		_hurt_clock+=delta
		player.velocity.y=maxf(player.velocity.y,2.5)
		if _hurt_clock>.1 and fmod(_hurt_clock,3.)<delta:
			game.hud.notify("A pressão aperta os ouvidos: fundo demais sem equipamento (limite %d m). O estaleiro vende equipamento de mergulho."%int(max_depth()))
	else:_hurt_clock=0.
