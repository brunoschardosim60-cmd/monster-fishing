extends Control
## Cast-net swing meter (bottom centre): a bar with the sweet spot in green; the needle rides up and down
## with the swing; let go of N while it is in the green.
const NAVY:=Color("ecdfbf",.95)
const BRASS:=Color("9a3a1c")
const CREAM:=Color("3b2614")
var value: float=-1.
var sweet: float=.82
var band: float=.07

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left=-140;offset_right=140;offset_top=-178;offset_bottom=-118

func show_value(v: float,sweet_at: float,band_w: float) -> void:
	value=v;sweet=sweet_at;band=band_w;visible=v>=0.;queue_redraw()

func _draw() -> void:
	if value<0.:return
	var b:=StyleBoxFlat.new();b.bg_color=NAVY;b.border_color=Color("4a3018");b.set_border_width_all(2);b.set_corner_radius_all(4)
	draw_style_box(b,Rect2(Vector2.ZERO,size))
	var font:=get_theme_default_font()
	draw_string(font,Vector2(14,22),"TARRAFA · solte na faixa verde",HORIZONTAL_ALIGNMENT_LEFT,-1,13,CREAM)
	var bar:=Rect2(14,32,size.x-28,12)
	draw_rect(bar,Color(CREAM,.12))
	var near:=Rect2(bar.position.x+bar.size.x*(sweet-band-.18),bar.position.y,bar.size.x*(band*2.+.36),bar.size.y)
	draw_rect(near.intersection(bar),Color("e0b84a",.45))
	var good:=Rect2(bar.position.x+bar.size.x*(sweet-band),bar.position.y,bar.size.x*band*2.,bar.size.y)
	draw_rect(good.intersection(bar),Color("5cc96b",.85))
	var x: float=bar.position.x+bar.size.x*clampf(value,0.,1.)
	draw_line(Vector2(x,bar.position.y-4),Vector2(x,bar.end.y+4),CREAM,3.)
