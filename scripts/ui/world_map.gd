extends Control
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var game: Node3D
var overview: bool=false
var coastlines: Array[PackedVector2Array]=[]
func _ready() -> void:
	custom_minimum_size=Vector2(700,650);size=custom_minimum_size
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-350.;offset_top=-325.;offset_right=350.;offset_bottom=325.
	mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
	for i: int in Layout.LOBES.size():
		var l:=Layout.LOBES[i];var polygon:=PackedVector2Array()
		for step: int in 96:
			var a:=float(step)*TAU/96.;var edge:=1.+sin(a*3.+float(i)*1.7)*.055+cos(a*7.)*.025
			polygon.append(Vector2(l.x+cos(a)*l.z*edge,l.y+sin(a)*l.w*edge))
		if i>0 and i<4:
			var merged:=Geometry2D.merge_polygons(coastlines[0],polygon)
			coastlines[0]=merged[0]
		else:coastlines.append(polygon)
func point(p: Vector2) -> Vector2:
	return (p-(Vector2.ZERO if overview else Vector2(0,260)))*(.16 if overview else .84)+Vector2(350,340)
func _process(_delta: float) -> void:
	if visible:queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_Z:overview=not overview
func _draw() -> void:
	draw_style_box(_style(),Rect2(Vector2.ZERO,size))
	var font:=ThemeDB.fallback_font
	draw_string(font,Vector2(25,38),"CARTA NÁUTICA  /  "+("ARQUIPÉLAGO" if overview else "ILHA DA AURORA"),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("dfc28f"))
	for i: int in coastlines.size():
		if not overview and i>0:continue
		var polygon:=PackedVector2Array()
		for p: Vector2 in coastlines[i]:polygon.append(point(p))
		draw_colored_polygon(polygon,Color("4e756c"));polygon.append(polygon[0]);draw_polyline(polygon,Color("b5c7a4"),1.5,true)
	if not overview:
		for route: Array[Vector3] in [Layout.TRAIL,Layout.WEST_TRAIL,Layout.EAST_TRAIL]:
			var line:=PackedVector2Array()
			for p: Vector3 in route:line.append(point(Vector2(p.x,p.z)))
			draw_polyline(line,Color("dfbc80"),2.,true)
	if game!=null:
		for item: Dictionary in game.world.village.landmarks:
			var p:=point(Vector2(item.position.x,item.position.z));draw_circle(p,4.,Color("e9cb83"))
			if not overview:draw_string(font,p+Vector2(7,-5),item.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f0e2c0"))
		var p: Vector3=game.player.global_position;var b: Vector3=game.boat.global_position
		draw_circle(point(Vector2(b.x,b.z)),5.,Color("79cced"));draw_circle(point(Vector2(p.x,p.z)),4.,Color.WHITE)
	draw_string(font,Vector2(25,617),"Branco: você   Azul: barco   Dourado: trilhas e descobertas",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8d9d8"))
	draw_string(font,Vector2(25,640),"M fechar   ·   Z mudar escala   ·   Mundo navegável: 4,4 × 4,4 km, com travessia contínua",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8cb4bd"))
func _style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.09,.13,.96);style.border_color=Color("5c8c93");style.set_border_width_all(1);style.set_corner_radius_all(8);return style
