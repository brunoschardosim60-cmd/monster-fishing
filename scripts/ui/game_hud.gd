extends CanvasLayer
signal start_requested
signal resume_requested
signal return_requested
signal quit_requested

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
	var top := _panel(root, Vector2(34, 28), Vector2(330, 100))
	var box := _vbox(top)
	_label(box, "MONSTER FISHING", 24, CREAM)
	_label(box, "COSTA DO FAROL   /   FIM DE TARDE", 12, SEA)
	hud_controls.append(top)
	stats = _label(root, "", 19, CREAM)
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stats.offset_left = -400
	stats.offset_top = 36
	stats.offset_right = -40
	stats.offset_bottom = 96
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_controls.append(stats)
	objective = _label(root, "", 15, CREAM)
	objective.position = Vector2(48, 151)
	hud_controls.append(objective)
	compass = _label(root, "N  ·  000°", 15, CREAM)
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.offset_left = -90
	compass.offset_top = 35
	compass.offset_right = 90
	compass.offset_bottom = 65
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_controls.append(compass)
	var controls := _label(root, "WASD  mover     SHIFT  correr     E  interagir     ESPAÇO / CLIQUE  pescar     F  câmera     TAB  capturas     ESC  pausa", 14, CREAM)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 30
	controls.offset_right = -30
	controls.offset_top = -39
	controls.offset_bottom = -10
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_controls.append(controls)
	prompt = _label(root, "", 20, CREAM)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -450
	prompt.offset_top = -97
	prompt.offset_right = 450
	prompt.offset_bottom = -57
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_controls.append(prompt)
	toast = _label(root, "", 20, GOLD)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -460
	toast.offset_top = 106
	toast.offset_right = 460
	toast.offset_bottom = 158
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_controls.append(toast)
	fishing_box = _panel(root, Vector2.ZERO, Vector2(480, 184))
	fishing_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fishing_box.offset_left = -240
	fishing_box.offset_top = -300
	fishing_box.offset_right = 240
	fishing_box.offset_bottom = -116
	var fishing_content := _vbox(fishing_box)
	fishing_title = _label(fishing_content, "A LINHA ESTÁ NA ÁGUA", 20, GOLD)
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
	_set_hud(false)

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
	_label(content, "UMA PEQUENA ILHA. UM OCEANO DE HISTÓRIAS.", 14, SEA)
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
	var build_label := _label(overlay, "FASE 1  •  PROTÓTIPO JOGÁVEL     /     COSTA DO FAROL", 13, SEA)
	build_label.position = Vector2(100, 820)

func begin_play() -> void:
	started = true
	overlay.hide()
	_set_hud(true)

func show_pause() -> void:
	ledger.hide()
	overlay_title.text = "O mar\npode esperar."
	overlay_title.add_theme_font_size_override("font_size", 58)
	overlay_body.text = "Seu progresso desta sessão está aqui.\n\nWASD  caminhar / pilotar     •     Mouse  olhar\nE  embarcar / desembarcar / vender     •     F  câmera\nESPAÇO ou clique  lançar / fisgar / recolher\nBotão direito  cancelar a pesca     •     TAB  capturas\n\nDesembarque junto à ponta do cais."
	play_button.text = "CONTINUAR  →"
	return_button.show()
	overlay.show()

func hide_pause() -> void:
	overlay.hide()

func notify(message: String) -> void:
	toast.text = message
	toast_time = 5.0

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
			fishing_title.text = "LANÇANDO A LINHA"
			fishing_hint.text = "A isca encontra a água…"
		2:
			fishing_title.text = "O MAR TEM SEU TEMPO"
			fishing_hint.text = "Aguarde a mordida. Não precisa segurar o botão."
		3:
			fishing_title.text = "MORDIDA!   %.1f s" % bite_left
			fishing_hint.text = "CLIQUE ou ESPAÇO agora para fisgar!"
		4:
			fishing_title.text = "TRAGA O PEIXE ATÉ VOCÊ"
			fishing_hint.text = "Segure CLIQUE / ESPAÇO. Solte para aliviar a tensão."
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
