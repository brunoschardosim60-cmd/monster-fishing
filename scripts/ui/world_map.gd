extends Control
## Carta náutica (tecla M). Z alterna: Ilha Aurora → Arquipélago → Mundo inteiro.
## Os contornos vêm de Layout.edge_factor, a mesma fórmula usada pela física, pela
## navegação, pela malha das ilhas e pelo shader do oceano.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const FishingSystem=preload("res://scripts/fishing/fishing_system.gd")
const MODE_ISLAND: int = 0
const MODE_ARCHIPELAGO: int = 1
const MODE_WORLD: int = 2
const ARCHIPELAGO_CENTER: Vector2=Vector2(1650,800)
const ARCHIPELAGO_SPAN: Vector2=Vector2(5000,5600)
const MAP_TOP: float = 58.
const MAP_BOTTOM: float = 566.
var game: Node3D
var zoom_mode: int = MODE_ISLAND
var overview: bool:
	get: return zoom_mode!=MODE_ISLAND
## One polygon per drawn island (Aurora's lobes are merged), plus the lobe that owns it.
var coastlines: Array[PackedVector2Array]=[]
var coast_lobe: Array[int]=[]
var shelf_near: Array[PackedVector2Array]=[]
var shelf_far: Array[PackedVector2Array]=[]

func _ready() -> void:
	custom_minimum_size=Vector2(700,650);size=custom_minimum_size
	clip_contents=true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-350.;offset_top=-325.;offset_right=350.;offset_bottom=325.
	mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
	for i: int in Layout.LOBES.size():
		var l:=Layout.LOBES[i];var polygon:=PackedVector2Array()
		for step: int in 120:
			var a:=float(step)*TAU/120.;var edge:=Layout.edge_factor(i,a)
			polygon.append(Vector2(l.x+cos(a)*l.z*edge,l.y+sin(a)*l.w*edge))
		if (i>0 and i<4) or i==7:
			var merged:=Geometry2D.merge_polygons(coastlines[0],polygon)
			if not merged.is_empty(): coastlines[0]=merged[0]
		else:
			coastlines.append(polygon);coast_lobe.append(i)
	for polygon: PackedVector2Array in coastlines:
		shelf_near.append(_grow(polygon,70.))
		shelf_far.append(_grow(polygon,170.))

func _grow(polygon: PackedVector2Array,meters: float) -> PackedVector2Array:
	var grown:=Geometry2D.offset_polygon(polygon,meters,Geometry2D.JOIN_ROUND)
	return grown[0] if not grown.is_empty() else polygon

func point(p: Vector2) -> Vector2:
	match zoom_mode:
		MODE_WORLD:
			var scale:=minf((size.x-80.)/(Layout.WORLD_HALF*2.),(MAP_BOTTOM-MAP_TOP-8.)/(Layout.WORLD_HALF*2.))
			return p*scale+Vector2(size.x*.5,(MAP_TOP+MAP_BOTTOM)*.5)
		MODE_ARCHIPELAGO:
			var scale:=minf((size.x-60.)/ARCHIPELAGO_SPAN.x,(MAP_BOTTOM-MAP_TOP-8.)/ARCHIPELAGO_SPAN.y)
			return (p-ARCHIPELAGO_CENTER)*scale+Vector2(size.x*.5,(MAP_TOP+MAP_BOTTOM)*.5)
	return (p-Vector2(-40,480))*.47+Vector2(350,340)

func _process(_delta: float) -> void:
	if visible:queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_Z:zoom_mode=(zoom_mode+1)%3

func _title() -> String:
	return ["ILHA AURORA","ARQUIPÉLAGO","MUNDO INTEIRO"][zoom_mode]

func _draw() -> void:
	var font:=ThemeDB.fallback_font
	draw_style_box(_style(),Rect2(Vector2.ZERO,size))
	# Open sea: slightly lighter toward the middle of the chart, like the reference art.
	draw_rect(Rect2(8,MAP_TOP-6,size.x-16,MAP_BOTTOM-MAP_TOP+12),Color(.035,.16,.25,.9))
	draw_rect(Rect2(60,MAP_TOP+30,size.x-120,MAP_BOTTOM-MAP_TOP-60),Color(.04,.22,.32,.35))
	draw_string(font,Vector2(25,38),"CARTA NÁUTICA  /  "+_title(),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("dfc28f"))
	for i: int in coastlines.size():
		if zoom_mode==MODE_ISLAND and i>0:continue
		_fill(shelf_far[i],Color(.12,.52,.62,.16))
		_fill(shelf_near[i],Color(.2,.72,.74,.30))
	for i: int in coastlines.size():
		if zoom_mode==MODE_ISLAND and i>0:continue
		var polygon:=_screen(coastlines[i])
		var biome:=str(Layout.region_for_lobe(coast_lobe[i]).get("biome","harbor"))
		draw_colored_polygon(polygon,_fill_color(biome))
		polygon.append(polygon[0]);draw_polyline(polygon,Color("f2e6bd"),1.6,true)
	if zoom_mode==MODE_ISLAND:
		for route: Array[Vector3] in [Layout.TRAIL,Layout.WEST_TRAIL,Layout.EAST_TRAIL,Layout.NORTH_TRAIL,Layout.OLD_PORT_TRAIL]:
			var line:=PackedVector2Array()
			for p: Vector3 in route:line.append(point(Vector2(p.x,p.z)))
			draw_polyline(line,Color("dfbc80"),2.,true)
	else:
		for zone: Dictionary in Layout.SEA_ZONES:
			var at:=point(zone.position)
			if at.x<20. or at.x>size.x-20. or at.y<MAP_TOP or at.y>MAP_BOTTOM:continue
			var label:=str(zone.name).to_upper();var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
			draw_string(font,at-Vector2(width*.5,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(.62,.82,.9,.55))
		for i: int in Layout.REGIONS.size():
			var region:=Layout.region_for_lobe(i)
			if not bool(region.get("map_visible",false)): continue
			var l:=Layout.LOBES[i]
			var anchor:=Vector2(l.x,l.y) if i==0 else Vector2(l.x,l.y-l.w*1.12)
			_pin(font,point(anchor),str(region.get("map","")),_region_color(str(region.get("biome","harbor"))))
		_compass(Vector2(size.x-58,MAP_TOP+52))
	if game!=null:
		var beacon: Vector3=game.world.harbor_lighthouse.position
		var marker:=point(Vector2(beacon.x,beacon.z));draw_circle(marker,4.,Color(.99,.95,.74))
		if zoom_mode==MODE_ISLAND:draw_string(font,marker+Vector2(7,-5),"Farol da Entrada",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f0e2c0"))
		for item: Dictionary in game.world.village.landmarks:
			var p:=point(Vector2(item.position.x,item.position.z));draw_circle(p,4.,Color("e9cb83"))
			if zoom_mode==MODE_ISLAND:draw_string(font,p+Vector2(7,-5),item.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f0e2c0"))
		var p: Vector3=game.player.global_position;var b: Vector3=game.boat.global_position
		draw_circle(point(Vector2(b.x,b.z)),5.,Color(.47,.8,.93));draw_circle(point(Vector2(p.x,p.z)),4.,Color.WHITE)
		for ship: CharacterBody3D in game.world.traffic.vessels:
			var at:=point(Vector2(ship.position.x,ship.position.z));draw_circle(at,3.,Color(.9,.64,.49))
		# Predators and rare fish are always marked; a kraken or whale is marked only while it is out.
		var rarity_of: Dictionary={}
		for species: Resource in FishingSystem.SPECIES:rarity_of[str(species.id)]=str(species.rarity)
		for school: Node3D in game.marine.fish_schools:
			var rare:=str(rarity_of.get(school.species,"Comum"))!="Comum"
			if not (school.predator or rare):continue
			var at:=point(Vector2(school.center.x,school.center.z))
			var color:=Color("e8584a") if school.predator else Color("b98cff")
			draw_circle(at,4.5,color)
			if zoom_mode==MODE_ISLAND:draw_string(font,at+Vector2(7,-5),str(school.species).replace("_"," ").capitalize(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f0e2c0"))
		# Monster territories: a red ring with the lair's name; the guardian is drawn while it is up.
		if game.get("lairs")!=null:
			for lair: Dictionary in game.lairs.lairs:
				var lc:=point(Vector2(lair.center.x,lair.center.z))
				var edge:=point(Vector2(lair.center.x+float(lair.radius),lair.center.z))
				var rr:=maxf(6.,lc.distance_to(edge))
				draw_circle(lc,rr,Color(.85,.18,.15,.16));draw_arc(lc,rr,0.,TAU,40,Color("e8584a"),2.)
				draw_string(font,lc+Vector2(-40,-rr-6),str(lair.name),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffb3a8"))
				if (lair.node as Node3D).visible:draw_circle(point(Vector2(lair.pos.x,lair.pos.z)),5.,Color("ffd34e"))
		# Storm cells (grey discs, darker when strong) and whirlpools you have seen.
		var storms=game.world.get("storms")
		if storms!=null:
			for c: Dictionary in storms.cells:
				if float(c.intensity)<.1:continue
				var sc:=point(c.pos as Vector2);var se:=point((c.pos as Vector2)+Vector2(float(c.radius),0))
				var sr:=maxf(5.,sc.distance_to(se))
				draw_circle(sc,sr,Color(.35,.4,.48,.25+float(c.intensity)*.25));draw_arc(sc,sr,0.,TAU,32,Color(.75,.82,.9,.6),1.5)
				if zoom_mode!=MODE_ISLAND or sr<60.:draw_string(font,sc+Vector2(-28,4),"tempestade",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(.85,.9,.95))
		var whirls=game.world.get("whirlpools")
		if whirls!=null:
			for w: Array in whirls.seen_sites():
				var wc:=point(w[0] as Vector2)
				draw_arc(wc,6.,0.,TAU*.85,16,Color("7dd8ff") if bool(w[2]) else Color(.5,.7,.8,.5),2.)
				draw_string(font,wc+Vector2(8,4),"redemoinho",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a8e6ff"))
		var marks=game.world.get_node_or_null("Marcos")
		if marks!=null:
			for m: Dictionary in marks.marks:
				if not game.world.village.discovered.has(m.id):continue
				var mc:=point(Vector2((m.pos as Vector3).x,(m.pos as Vector3).z))
				draw_rect(Rect2(mc-Vector2(3,3),Vector2(6,6)),Color("f0d28a"))
		var events: Node3D=game.world.sea_events
		if events.current!=null:
			var ev: Vector3=events.current.global_position
			var ev_at:=point(Vector2(ev.x,ev.z))
			draw_circle(ev_at,6.,Color("ffd34e"))
			draw_string(font,ev_at+Vector2(8,-6),"Baleia",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffd34e"))
	_legend(font)
	draw_string(font,Vector2(25,617),"Branco: você · Azul: barco · Laranja: tráfego · Vermelho: predadores",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8d9d8"))
	draw_string(font,Vector2(25,634),"Roxo: peixes raros · Dourado: monstro ativo · Vermelho: território · Cinza: tempestade · Azul-claro: redemoinho",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8d9d8"))
	draw_string(font,Vector2(25,648),"M fechar   ·   Z mudar escala   ·   Mundo navegável: 10 × 10 km, com travessia contínua",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8cb4bd"))

func _screen(polygon: PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p: Vector2 in polygon:result.append(point(p))
	return result

func _fill(polygon: PackedVector2Array,color: Color) -> void:
	draw_colored_polygon(_screen(polygon),color)

func _pin(font: Font,at: Vector2,text: String,color: Color) -> void:
	if text.is_empty() or at.x<-40. or at.x>size.x+40. or at.y<MAP_TOP-10. or at.y>MAP_BOTTOM+10.:return
	var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	var box:=Rect2(at.x-width*.5-12.,at.y-9.,width+24.,17.)
	box.position.x=clampf(box.position.x,6.,size.x-box.size.x-6.)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.02,.07,.11,.82);style.border_color=color;style.set_border_width_all(1);style.set_corner_radius_all(8)
	draw_style_box(style,box)
	draw_circle(box.position+Vector2(8,8.5),3.,color)
	draw_string(font,box.position+Vector2(15,12.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f0e2c0"))

func _compass(center: Vector2) -> void:
	var font:=ThemeDB.fallback_font;var color:=Color(.88,.82,.66,.9)
	draw_arc(center,24.,0.,TAU,40,Color(.88,.82,.66,.45),1.2,true)
	draw_line(center-Vector2(0,28),center+Vector2(0,28),color,1.4,true);draw_line(center-Vector2(28,0),center+Vector2(28,0),color,1.4,true)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-27),center+Vector2(-5,-8),center+Vector2(5,-8)]),Color("e9cb83"))
	draw_string(font,center+Vector2(-4,-33),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color);draw_string(font,center+Vector2(-4,43),"S",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
	draw_string(font,center+Vector2(32,4),"L",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color);draw_string(font,center+Vector2(-40,4),"O",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)

func _legend(font: Font) -> void:
	var entries:=[["harbor","Porto"],["tropical","Tropical"],["frost","Gelada"],["volcanic","Vulcânica"],["mountain","Montanhosa"],["desert","Deserta"],["mystic","Misteriosa"],["storm","Tempestade"],["shadow","Sombria"]]
	var x:=25.;var y:=MAP_BOTTOM+22.
	for entry: Array in entries:
		var width:=font.get_string_size(str(entry[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+30.
		if x+width>size.x-20.:x=25.;y+=16.
		draw_circle(Vector2(x+4,y-4),4.,_region_color(str(entry[0])))
		draw_string(font,Vector2(x+12,y),str(entry[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("b9cfd0"))
		x+=width

func _fill_color(biome: String) -> Color:
	match biome:
		"tropical": return Color("3f9a5a")
		"frost": return Color("c9e3ea")
		"volcanic": return Color("7a3a2c")
		"mountain": return Color("6f8d6a")
		"desert": return Color("d5ad65")
		"mystic": return Color("3c9d98")
		"storm": return Color("566a86")
		"shadow": return Color("4a3d73")
		_: return Color("5c9a6a")

func _region_color(biome: String) -> Color:
	match biome:
		"tropical": return Color("73d28d")
		"frost": return Color("b9e5f1")
		"volcanic": return Color("ff6e3d")
		"mountain": return Color("9dc6aa")
		"desert": return Color("edbf72")
		"mystic": return Color("62e0d7")
		"storm": return Color("8fa9d9")
		"shadow": return Color("b184f0")
		_: return Color("e9cb83")

func _style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.09,.13,.96);style.border_color=Color("5c8c93");style.set_border_width_all(1);style.set_corner_radius_all(8);return style
