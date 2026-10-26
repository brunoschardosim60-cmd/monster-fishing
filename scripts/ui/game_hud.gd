extends CanvasLayer
signal start_requested
signal resume_requested
signal return_requested
signal quit_requested
signal weather_selected(index: int)
signal time_selected(hour: float)
signal service_action(id: String)
signal service_closed
signal graphics_changed(level: int,scale_value: float,sync: bool)
const SERVICE_NAMES: Dictionary={"shipyard":"estaleiro","gear":"loja de pesca","workshop":"oficina naval","cabin":"sua cabana","inn":"pousada","storage":"armazém","market":"mercado de peixes"}
var service_open: bool=false
var service_panel: PanelContainer
var service_message: Label
var map_view: Control
var sea_label: Label
var weather_picker: OptionButton
var graphics_panel: PanelContainer
var quality_picker: OptionButton
var resolution_slider: HSlider
var resolution_label: Label
var vsync_button: CheckButton

const INK := Color("071d2b")
const CREAM := Color("e4edf1")
const GOLD := Color("d4b17b")
const SEA := Color("73c4e0")
var root: Control
var stats: Label
var prompt: Label
var toast: Label
var objective: Label
var compass: Label
var fishing_box: PanelContainer
var fishing_title: Label
var fishing_hint: Label
var tension_bar: ProgressBar
var progress_bar: ProgressBar
var tension_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var play_button: Button
var return_button: Button
var quit_button: Button
var ledger: PanelContainer
var ledger_text: Label
var started: bool = false
var toast_time: float = 0.0
var hud_controls: Array[Control] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	sea_label=_label(root, "", 13, CREAM)
	sea_label.position=Vector2(30,28)
	hud_controls.append(sea_label)
	stats = _label(root, "", 13, CREAM)
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stats.offset_left = -400
	stats.offset_top = 28
	stats.offset_right = -40
	stats.offset_bottom = 96
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_controls.append(stats)
	objective = _label(root, "", 15, CREAM)
	objective.position = Vector2(48, 151)
	objective.hide()
	compass = _label(root, "N  ·  000°", 15, CREAM)
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.offset_left = -90
	compass.offset_top = 35
	compass.offset_right = 90
	compass.offset_bottom = 65
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_controls.append(compass)
	prompt = _label(root, "", 16, CREAM)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -450
	prompt.offset_top = -62
	prompt.offset_right = 450
	prompt.offset_bottom = -28
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_controls.append(prompt)
	toast = _label(root, "", 16, GOLD)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -460
	toast.offset_top = 106
	toast.offset_right = 460
	toast.offset_bottom = 158
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud_controls.append(toast)
	fishing_box = _panel(root, Vector2.ZERO, Vector2(320, 120))
	fishing_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fishing_box.offset_left = -160
	fishing_box.offset_top = -220
	fishing_box.offset_right = 160
	fishing_box.offset_bottom = -85
	var fishing_content := _vbox(fishing_box)
	fishing_title = _label(fishing_content, "", 16, GOLD)
	fishing_hint = _label(fishing_content, "Observe a boia.", 14, CREAM)
	progress_bar = _bar(fishing_content, SEA)
	tension_label = _label(fishing_content, "TENSÃO DA LINHA", 12, CREAM)
	tension_bar = _bar(fishing_content, GOLD)
	fishing_box.hide()
	ledger = _panel(root, Vector2.ZERO, Vector2(470, 340))
	ledger.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	ledger.offset_left = -505
	ledger.offset_top = -155
	ledger.offset_right = -35
	ledger.offset_bottom = 185
	var ledger_content := _vbox(ledger)
	_label(ledger_content, "Caderno de bordo", 28, GOLD)
	ledger_text = _label(ledger_content, "", 17, CREAM)
	ledger_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger_text.custom_minimum_size.x = 410
	_label(ledger_content, "Venda suas capturas no mercado da ilha.\nTAB  fechar", 14, SEA)
	ledger.hide()
	_make_overlay()
	map_view=preload("res://scripts/ui/world_map.gd").new();root.add_child(map_view)
	_set_hud(false)

func open_service(id: String,inventory: RefCounted,boat: CharacterBody3D,stock: Array[Dictionary]=[]) -> void:
	id=id.get_slice("_",0)
	if service_panel!=null:service_panel.free()
	service_open=true
	service_panel=_panel(root,Vector2.ZERO,Vector2(580,570));service_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	service_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	service_panel.offset_left=-290;service_panel.offset_right=290;service_panel.offset_top=-285;service_panel.offset_bottom=285
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(540,530);service_panel.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",10);scroll.add_child(box)
	_label(box,str(SERVICE_NAMES.get(id,id)).to_upper(),25,GOLD)
	_label(box,"%d moedas · %d iscas · %d ração · %d covos · %d materiais\nCasco: %d%% · Capturas no armazém: %d"%[inventory.money,inventory.bait,inventory.feed,inventory.traps,inventory.materials,int(boat.integrity*100.),inventory.stored_catches.size()],16,CREAM)
	var catalog: Dictionary=preload("res://scripts/inventory/harbor_economy.gd").CATALOG
	for key: String in catalog:
		var item: Dictionary=catalog[key]
		if item.service!=id and not (id=="shipyard" and item.service=="workshop" and not item.has("craft")):continue
		var label_text:="%s  —  %d moedas"%[item.title,item.price]
		if item.has("craft"):label_text=str(item.title)
		if item.get("tiered",false):
			var level:int=int(inventory.equipment.get(key,0))
			label_text="%s  —  nível %d/3 · próximo: %d moedas"%[item.title,level,preload("res://scripts/inventory/harbor_economy.gd").next_cost(key,inventory)] if level<3 else "%s  —  nível máximo"%item.title
		var button:=_button(box,label_text);button.custom_minimum_size.x=500.;button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func() -> void: service_action.emit(key))
	var actions: Dictionary={}
	if id=="shipyard":
		_label(box,"BARCOS À VENDA",19,GOLD)
		var boats: Dictionary=preload("res://scripts/inventory/harbor_economy.gd").BOATS
		for key: String in boats:
			var data: Dictionary=boats[key]
			var state:="em uso" if inventory.boat_id==key else ("seu · usar" if key in inventory.owned_boats else "%d moedas"%int(data.price))
			var boat_button:=_button(box,"%s  —  %s"%[data.title,state]);boat_button.custom_minimum_size.x=500.;boat_button.add_theme_font_size_override("font_size",14)
			boat_button.disabled=inventory.boat_id==key
			boat_button.pressed.connect(func() -> void: service_action.emit("boat:"+key))
	if id=="market":actions={"sell":"Vender todas as capturas · %d moedas"%inventory.total_value()}
	if id=="market":
		for key: String in preload("res://scripts/inventory/harbor_economy.gd").GOODS:
			var item: Dictionary=preload("res://scripts/inventory/harbor_economy.gd").GOODS[key]
			var row:=HBoxContainer.new();box.add_child(row)
			var label:=_label(row,"%s ×%d"%[item.title,inventory.goods.get(key,0)],15,CREAM);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var buy_button:=_button(row,"Comprar %d"%item.buy);buy_button.custom_minimum_size=Vector2(110,38);buy_button.add_theme_font_size_override("font_size",14);buy_button.pressed.connect(func() -> void:service_action.emit("buy_goods:"+key))
			var sell_button:=_button(row,"Vender %d"%item.sell);sell_button.custom_minimum_size=Vector2(110,38);sell_button.add_theme_font_size_override("font_size",14);sell_button.disabled=inventory.goods.get(key,0)<=0;sell_button.pressed.connect(func() -> void:service_action.emit("sell_goods:"+key))
		if inventory.goods.get("tackle",0)>0:actions["use_tackle"]="Preparar 6 iscas artificiais"
		if inventory.goods.get("canvas",0)>0 and inventory.materials>=2:actions["craft_kit"]="Montar kit · 1 lona + 2 materiais"
		for index: int in mini(stock.size(),3):actions["buy_stock:"+str(index)]="Comprar %s · %.1f kg · %d"%[stock[index].name,stock[index].weight,ceili(float(stock[index].value)*1.25)]
		if inventory.goods.get("repair_kit",0)>0:actions["use_kit"]="Usar kit de reparo · casco +35%"
		if inventory.bait>0:actions["sell_bait"]="Vender uma isca · 1 moeda"
		if inventory.materials>0:actions["sell_material"]="Vender um material · 3 moedas"
		for index: int in mini(inventory.catches.size(),6):
			var fish: Dictionary=inventory.catches[index]
			actions["sell_fish:"+str(index)]="Vender %s · %.1f kg · %d"%[fish.name,fish.weight,fish.value]
	if id in ["cabin","inn"]:actions={"rest":"Descansar até 08:00"}
	if id in ["cabin","storage"]:actions.merge({"store":"Guardar capturas no armazém","withdraw":"Retirar capturas do armazém"})
	for key: String in actions:
		var button:=_button(box,actions[key]);button.pressed.connect(func() -> void:service_action.emit(key))
	service_message=_label(box,"",15,SEA);service_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;service_message.custom_minimum_size.x=500.
	_button(box,"Fechar  ·  E / ESC").pressed.connect(close_service)

func close_service() -> void:
	service_open=false
	if service_panel!=null:service_panel.queue_free();service_panel=null
	service_closed.emit()

func show_encyclopedia(entries: Dictionary,discoveries: Dictionary) -> void:
	ledger.visible=not ledger.visible
	var content:="ENCICLOPÉDIA\n"
	for data: Dictionary in entries.values():
		if data.get("observation",false):content+="%s · %s\nCriatura observada · não capturável\n"%[data.name,data.rarity]
		else:content+="%s · %s\n%d registros · recorde %.2f kg · %d devolvidos\n"%[data.name,data.rarity,data.count,data.record,data.released]
	if entries.is_empty():content+="Pesque e guarde ou devolva um peixe para registrá-lo.\n"
	content+="\nLOCAIS DESCOBERTOS\n"
	for place: String in discoveries.values():content+=place+"\n"
	ledger_text.text=content

func _make_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.09, 0.115, 0.68)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var content := VBoxContainer.new()
	content.position = Vector2(100, 150)
	content.size = Vector2(620, 550)
	content.add_theme_constant_override("separation", 20)
	overlay.add_child(content)
	_label(content, "VILA DA AURORA. UM OCEANO DE HISTÓRIAS.", 14, SEA)
	overlay_title = _label(content, "Monster\nFishing", 76, CREAM)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "DejaVu Serif"])
	overlay_title.add_theme_font_override("font", serif)
	overlay_body = _label(content, "O dia ainda tem algumas horas de luz.\nPegue sua vara, solte as amarras e encontre seu lugar no mar.\n\nPesque no cais ou embarque. Venda a captura no mercado.\nNa disputa, segure para recolher e solte antes de romper a linha.", 18, CREAM)
	play_button = _button(content, "COMEÇAR A EXPLORAR  →")
	play_button.pressed.connect(func() -> void:
		if started: resume_requested.emit()
		else: start_requested.emit())
	return_button = _button(content, "Voltar em segurança ao cais")
	return_button.pressed.connect(func() -> void: return_requested.emit())
	return_button.hide()
	quit_button = _button(content, "Sair do jogo")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	var build_label := _label(overlay, "ARQUIPÉLAGO DA AURORA  /  EXPLORAÇÃO, PESCA E VIDA NO PORTO", 13, SEA)
	build_label.position = Vector2(100, 820)
	var weather_panel:=_panel(overlay,Vector2.ZERO,Vector2(395,530))
	graphics_panel=weather_panel
	weather_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	weather_panel.offset_left=-425;weather_panel.offset_right=-30;weather_panel.offset_top=90;weather_panel.offset_bottom=660
	var weather_box:=_vbox(weather_panel)
	_label(weather_box,"CONDIÇÕES DO MAR",18,GOLD)
	weather_picker=OptionButton.new()
	for text: String in ["Clima dinâmico","Mar calmo","Brisa","Mar agitado","Tempestade","Após a tempestade"]: weather_picker.add_item(text)
	weather_picker.custom_minimum_size=Vector2(325,44)
	weather_box.add_child(weather_picker)
	weather_picker.item_selected.connect(func(index: int) -> void: weather_selected.emit(index-1))
	_label(weather_box,"Vento e ondas mudam gradualmente.",14,CREAM)
	_label(weather_box,"HORÁRIO",16,GOLD)
	var time_picker:=OptionButton.new()
	for text: String in ["Fim de tarde","Amanhecer","Manhã","Meio-dia","Noite"]:time_picker.add_item(text)
	time_picker.custom_minimum_size=Vector2(325,40);weather_box.add_child(time_picker)
	time_picker.item_selected.connect(func(index: int) -> void:time_selected.emit([16.6,6.5,9.,12.,23.][index]))
	_label(weather_box,"QUALIDADE GRÁFICA",18,GOLD)
	quality_picker=OptionButton.new()
	for label: String in ["Baixa","Equilibrada","Alta","Ultra"]:quality_picker.add_item(label)
	quality_picker.custom_minimum_size=Vector2(325,40);weather_box.add_child(quality_picker);quality_picker.select(2)
	quality_picker.item_selected.connect(func(_i: int) -> void:_graphics_changed())
	resolution_label=_label(weather_box,"Resolução 3D: 100%",15,CREAM)
	resolution_slider=HSlider.new();resolution_slider.min_value=50;resolution_slider.max_value=150;resolution_slider.step=5;resolution_slider.value=100;resolution_slider.custom_minimum_size=Vector2(325,30);weather_box.add_child(resolution_slider)
	resolution_slider.value_changed.connect(func(_v: float) -> void:_graphics_changed())
	vsync_button=CheckButton.new();vsync_button.text="Sincronização vertical";vsync_button.button_pressed=true;weather_box.add_child(vsync_button)
	vsync_button.toggled.connect(func(_v: bool) -> void:_graphics_changed())
	_label(weather_box,"Alta/Ultra: vegetação mais distante,\nsombras completas e luz indireta.\nAjustes aplicados e salvos na hora.",14,CREAM)

func _graphics_changed() -> void:
	resolution_label.text="Resolução 3D: %d%%"%int(resolution_slider.value)
	graphics_changed.emit(quality_picker.selected,resolution_slider.value/100.,vsync_button.button_pressed)

func configure_graphics(settings: RefCounted) -> void:
	quality_picker.select(settings.quality);resolution_slider.set_value_no_signal(settings.render_scale*100.);vsync_button.set_pressed_no_signal(settings.vsync)
	resolution_label.text="Resolução 3D: %d%%"%int(resolution_slider.value)

func begin_play() -> void:
	started = true
	overlay.hide()
	_set_hud(true)

func show_pause() -> void:
	ledger.hide()
	overlay_title.text = "O mar\npode esperar."
	overlay_title.add_theme_font_size_override("font_size", 58)
	overlay_body.text = "Seu progresso desta sessão está aqui.\n\nT voo · ESPAÇO sobe · CTRL desce · SHIFT acelera\nWASD mover  ·  Mouse olhar  ·  ESPAÇO pular (e escalar beiradas)\nSHIFT correr  ·  CTRL andar devagar / mergulhar nadando\nE interagir / embarcar / sair  ·  R convés / leme\nCLIQUE / Q pescar  ·  Botão direito cancelar\nG guardar  ·  X devolver  ·  F câmera  ·  L luzes\nV observar criatura  ·  M mapa  ·  J enciclopédia  ·  TAB capturas\nZ âncora  ·  C jogar ração  ·  N tarrafa  ·  B covo (armadilha)"
	play_button.text = "CONTINUAR  →"
	return_button.show()
	overlay.show()

func hide_pause() -> void:
	overlay.hide()

func notify(message: String) -> void:
	toast.text = message
	toast_time = 3.2

func _process(delta: float) -> void:
	if not get_tree().paused:
		toast_time = maxf(0, toast_time - delta)
		toast.modulate.a = minf(1.0, toast_time)

func update_fishing(state: int, tension: float, progress: float, bite_left: float) -> void:
	fishing_box.visible = started and state >= 1 and state <= 4
	progress_bar.value = progress * 100.0
	tension_bar.value = tension * 100.0
	tension_label.text = "TENSÃO  %d%%  %s" % [int(tension*100), "— SOLTE AGORA" if tension > 0.73 else ""]
	tension_label.modulate = Color("ff8b72") if tension > 0.73 else CREAM
	match state:
		1:
			fishing_title.text = "Lançando"
			fishing_hint.text = ""
		2:
			fishing_title.text = "Aguardando…"
			fishing_hint.text = ""
		3:
			fishing_title.text = "Mordida!"
			fishing_hint.text = "Clique para fisgar"
		4:
			fishing_title.text = "Recolhendo"
			fishing_hint.text = "Segure o clique · solte para aliviar"
	fishing_hint.visible=not fishing_hint.text.is_empty()
	progress_bar.visible = state == 4
	tension_bar.visible = state == 4
	tension_label.visible = state == 4

func toggle_ledger(catches: Array[Dictionary], value: int) -> void:
	ledger.visible = not ledger.visible
	var body := "%d capturas  ·  valor total %d moedas\n\n" % [catches.size(), value]
	if catches.is_empty():
		body += "Seu cesto ainda está vazio.\nO primeiro lançamento é um bom começo."
	else:
		for i in mini(catches.size(), 7):
			var item: Dictionary = catches[catches.size() - 1 - i]
			body += "%s   %.2f kg   ·   %d\n" % [item.name, item.weight, item.value]
		if catches.size() > 7:
			body += "… e mais %d capturas.\n" % (catches.size()-7)
	ledger_text.text = body

func _set_hud(value: bool) -> void:
	for control in hud_controls:
		control.visible = value

func _label(parent: Node, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.04, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel(parent: Node, pos: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.12, 0.15, 0.88)
	style.border_color = Color(0.6, 0.8, 0.73, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _vbox(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(420, 12)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("233f45")
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _button(parent: Node, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(390, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", CREAM)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("24655f")
	style.set_corner_radius_all(5)
	style.content_margin_left = 24
	style.content_margin_right = 24
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color("397f71")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	parent.add_child(button)
	return button
