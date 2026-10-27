extends Control
## Fishing HUD: a small brass-and-navy instrument in the lower right corner, out of the way of the rod,
## the line and the fish. While waiting it shows a float that dips when a fish nibbles; on a bite it calls
## for the strike; during the fight it shows line tension as a dial (red zone = about to break), how much
## fight the fish still has, how much line is back on the reel, and a one-word cue (recolher / alivie).
const NAVY:=Color(.05,.11,.16,.72)
const BRASS:=Color("d4b17b")
const CREAM:=Color("e4edf1")
const TEAL:=Color("73c4e0")
const DANGER:=Color("ff6b57")
const SIZE_NAMES: Array[String]=["Pequeno","Médio","Grande","Gigante"]
var state: int=0
var tension: float=0.
var progress: float=0.
var stamina: float=1.
var phase: String="calm"
var size_class: int=0
var overload: float=0.
var bite_left: float=0.
var species_name: String=""
var gear_text: String=""
var nibble_flash: float=0.
var _clock: float=0.

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	custom_minimum_size=Vector2(250,150)
	offset_left=-274;offset_top=-250;offset_right=-24;offset_bottom=-100

func nibble() -> void:
	nibble_flash=1.

## Pulls the numbers from the fishing system each frame.
func update_from(fishing: Node,rod_level: int,line_level: int) -> void:
	state=int(fishing.state);tension=float(fishing.tension);progress=float(fishing.progress)
	stamina=float(fishing.stamina);phase=str(fishing.fight_phase);overload=float(fishing.overload)
	bite_left=float(fishing.bite_time_remaining)
	size_class=int(fishing.size_class()) if state==4 else 0
	species_name=str(fishing.species_current.display_name) if state==4 and fishing.species_current!=null else ""
	gear_text="Vara %d · Linha %d"%[rod_level,line_level]
	visible=state>=1 and state<=4
	queue_redraw()

func _process(delta: float) -> void:
	_clock+=delta;nibble_flash=maxf(0.,nibble_flash-delta*2.5)
	if visible:queue_redraw()

func _draw() -> void:
	var r:=Rect2(Vector2.ZERO,size)
	draw_style_box(_box(),r)
	var font:=get_theme_default_font()
	match state:
		1,2:_draw_waiting(font)
		3:_draw_bite(font)
		4:_draw_fight(font)

func _box() -> StyleBoxFlat:
	var b:=StyleBoxFlat.new();b.bg_color=NAVY;b.border_color=Color(BRASS,.65);b.set_border_width_all(1)
	b.set_corner_radius_all(10);b.shadow_color=Color(0,0,0,.25);b.shadow_size=6
	return b

func _float_icon(at: Vector2,dip: float) -> void:
	var y:=at.y+dip*10.
	draw_line(Vector2(at.x,y-22.),Vector2(at.x,y-10.),CREAM,2.)
	draw_circle(Vector2(at.x,y),9.,Color("ed8057"))
	draw_rect(Rect2(at.x-9.,y,18.,9.),Color("f2efe6"))
	draw_arc(Vector2(at.x,y+12.),18.+dip*6.,PI*1.1,PI*1.9,24,Color(TEAL,.6),1.5)

func _draw_waiting(font: Font) -> void:
	var dip:=nibble_flash*sin(_clock*30.)+sin(_clock*2.)*.15
	_float_icon(Vector2(40,78),dip)
	draw_string(font,Vector2(72,62),"Lançando" if state==1 else "Aguardando",HORIZONTAL_ALIGNMENT_LEFT,-1,17,CREAM)
	draw_string(font,Vector2(72,84),"a boia mexeu…" if nibble_flash>.05 else "observe a boia",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(CREAM,.7))
	draw_string(font,Vector2(72,108),gear_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(BRASS,.8))

func _draw_bite(font: Font) -> void:
	var pulse:=.6+.4*absf(sin(_clock*9.))
	_float_icon(Vector2(40,84),1.2)
	draw_string(font,Vector2(72,66),"FISGUE!",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(BRASS,pulse))
	draw_string(font,Vector2(72,90),"clique / Q",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(CREAM,.75))
	var w:=150.*clampf(bite_left/3.2,0.,1.)
	draw_rect(Rect2(72,100,150,4),Color(CREAM,.15));draw_rect(Rect2(72,100,w,4),BRASS)

func _draw_fight(font: Font) -> void:
	# Tension dial: an arc from left to right, the red zone at the end, a needle at the current tension.
	var c:=Vector2(70,92);var rad:=48.
	var from:=PI;var to:=TAU
	draw_arc(c,rad,from,to,48,Color(CREAM,.15),8.)
	draw_arc(c,rad,from,lerpf(from,to,.6),32,Color(TEAL,.55),8.)
	draw_arc(c,rad,lerpf(from,to,.6),lerpf(from,to,.73),12,Color(BRASS,.7),8.)
	draw_arc(c,rad,lerpf(from,to,.73),to,12,Color(DANGER,.8),8.)
	var a:=lerpf(from,to,clampf(tension,0.,1.))
	var hot:=tension>.73
	draw_line(c,c+Vector2(cos(a),sin(a))*(rad+4.),DANGER if hot else CREAM,3.)
	draw_circle(c,5.,BRASS)
	draw_string(font,Vector2(c.x-22,c.y+22),"TENSÃO",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(CREAM,.7))
	# Cue word under the dial.
	var cue:="ALIVIE" if hot or phase=="run" else ("SEGURE" if phase in ["dive","shake"] else ("RECOLHA" if phase!="jump" else "LINHA ESTICADA"))
	var cue_col:=DANGER if cue=="ALIVIE" else (BRASS if cue!="RECOLHA" else TEAL)
	draw_string(font,Vector2(14,140),cue,HORIZONTAL_ALIGNMENT_LEFT,-1,15,cue_col)
	# Right column: fish, its strength left, line recovered, gear.
	var x:=126.
	draw_string(font,Vector2(x,26),species_name if species_name!="" else "Peixe",HORIZONTAL_ALIGNMENT_LEFT,118,13,CREAM)
	draw_string(font,Vector2(x,43),SIZE_NAMES[clampi(size_class,0,3)],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(BRASS,.85))
	draw_string(font,Vector2(x,64),"força",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(CREAM,.6))
	draw_rect(Rect2(x,69,110,6),Color(CREAM,.12));draw_rect(Rect2(x,69,110.*stamina,6),Color("e98a6a"))
	draw_string(font,Vector2(x,92),"linha recolhida",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(CREAM,.6))
	draw_rect(Rect2(x,97,110,6),Color(CREAM,.12));draw_rect(Rect2(x,97,110.*progress,6),TEAL)
	if overload>1.:
		draw_string(font,Vector2(x,124),"equipamento fraco",HORIZONTAL_ALIGNMENT_LEFT,-1,12,DANGER)
	else:
		draw_string(font,Vector2(x,124),gear_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(BRASS,.8))
