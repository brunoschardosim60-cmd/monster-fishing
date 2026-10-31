extends RefCounted
## The game's interface style, after the painted world (Sea of Thieves, Dredge): parchment panels with a
## dark brown edge and brown ink; wooden buttons with cream lettering; text laid straight over the scene in
## cream with a brown outline so it reads on sea, sky or sand. Titles in Pirata One, the rest in EB
## Garamond with lining figures (assets/fonts, SIL OFL).
const PARCHMENT:=Color("ecdfbf")
const PARCHMENT_EDGE:=Color("4a3018")
const INK:=Color("3b2614")
const INK_SOFT:=Color("6a4e34")
const RUST:=Color("9a3a1c")
const SEA_INK:=Color("2f5d62")
const WOOD:=Color("7a5232")
const WOOD_HOVER:=Color("94673f")
const WOOD_DARK:=Color("3a2614")
const CREAM:=Color("f5e9cc")
const GOLD:=Color("e8c27a")
const DANGER:=Color("c0392b")
static var _title: FontFile
static var _body: Font
static var _theme: Theme

static func title_font() -> Font:
	if _title==null:_title=load("res://assets/fonts/pirata_one.woff2")
	return _title

## Body text: EB Garamond with lining figures (numbers all cap height, so "15:30" and prices read at a
## glance). IM FELL's old-style numerals were charming but hard to read in the HUD.
static func body_font() -> Font:
	if _body==null:
		var fv:=FontVariation.new();fv.base_font=load("res://assets/fonts/eb_garamond.woff2")
		var ts:=TextServerManager.get_primary_interface()
		fv.opentype_features={ts.name_to_tag("lnum"):1,ts.name_to_tag("pnum"):1}
		_body=fv
	return _body

## Parchment panel: warm paper, a 2 px brown edge, slightly rounded, a soft drop shadow.
static func parchment(margin: float=18.) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(PARCHMENT,.96);s.border_color=PARCHMENT_EDGE;s.set_border_width_all(2)
	s.set_corner_radius_all(4);s.shadow_color=Color(0,0,0,.35);s.shadow_size=8;s.shadow_offset=Vector2(0,3)
	s.content_margin_left=margin;s.content_margin_right=margin;s.content_margin_top=margin*.85;s.content_margin_bottom=margin*.85
	return s

static func wood(color: Color=WOOD) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color;s.border_color=WOOD_DARK;s.set_border_width_all(2);s.border_width_bottom=4
	s.set_corner_radius_all(3);s.content_margin_left=22;s.content_margin_right=22;s.content_margin_top=6;s.content_margin_bottom=6
	return s

## The theme on the HUD's root: fonts, buttons, drop-down lists, sliders and check buttons in wood and ink.
static func theme() -> Theme:
	if _theme!=null:return _theme
	var t:=Theme.new()
	t.default_font=body_font();t.default_font_size=19
	for cls: String in ["Button","OptionButton"]:
		t.set_stylebox("normal",cls,wood());t.set_stylebox("hover",cls,wood(WOOD_HOVER));t.set_stylebox("focus",cls,wood(WOOD_HOVER))
		t.set_stylebox("pressed",cls,wood(WOOD_DARK));t.set_stylebox("disabled",cls,wood(Color(WOOD,.45)))
		for c: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:t.set_color(c,cls,CREAM)
		t.set_color("font_disabled_color",cls,Color(CREAM,.45))
	t.set_stylebox("panel","PopupMenu",parchment(10.))
	t.set_color("font_color","PopupMenu",INK);t.set_color("font_hover_color","PopupMenu",RUST)
	var hover:=StyleBoxFlat.new();hover.bg_color=Color(WOOD,.25);t.set_stylebox("hover","PopupMenu",hover)
	for st: String in ["normal","hover","pressed","focus","hover_pressed"]:t.set_stylebox(st,"CheckButton",StyleBoxEmpty.new())
	t.set_color("font_color","CheckButton",INK);t.set_color("font_hover_color","CheckButton",RUST);t.set_color("font_pressed_color","CheckButton",INK)
	var track:=StyleBoxFlat.new();track.bg_color=WOOD_DARK;track.set_corner_radius_all(3);track.content_margin_top=3;track.content_margin_bottom=3
	t.set_stylebox("slider","HSlider",track)
	var fill:=StyleBoxFlat.new();fill.bg_color=RUST;fill.set_corner_radius_all(3);fill.content_margin_top=3;fill.content_margin_bottom=3
	t.set_stylebox("grabber_area","HSlider",fill);t.set_stylebox("grabber_area_highlight","HSlider",fill)
	t.set_stylebox("panel","TooltipPanel",parchment(8.));t.set_color("font_color","TooltipLabel",INK)
	_theme=t
	return t

## Whether a control sits on a parchment panel (its text then goes in ink, not cream).
static func on_parchment(node: Node) -> bool:
	var n: Node=node
	while n!=null:
		if n is PanelContainer and n.has_meta("parchment"):return true
		n=n.get_parent()
	return false
