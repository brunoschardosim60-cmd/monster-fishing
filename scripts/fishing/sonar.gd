extends Control
## Boat sonar (O, needs the sonar from the boatyard). A ping spreads a ring over the water and, for a few
## seconds, a round screen shows what came back: the depth under the keel, schools of fish, wrecks and
## caves, turbulence, and big shapes. Echoes are honest but not complete: far contacts come back blurred,
## a guardian asleep in its abyss is only "a sinal desconhecido", and at night the deep sometimes answers
## with something that is not there at all. The level-2 sonar reaches twice as far and reads more.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const SHOW_TIME: float=12.
var game: Node3D
var contacts: Array=[]
var show_clock: float=0.
var cooldown: float=0.
var depth_line: String=""
var heading: float=0.
var _ring: MeshInstance3D
var _ring_clock: float=-1.
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(250,280);size=custom_minimum_size
	set_anchors_preset(Control.PRESET_TOP_RIGHT);position=Vector2(-270,110);visible=false
	_rng.seed=4040

func level() -> int:
	return int(game.inventory.equipment.get("sonar",0))

func ping() -> String:
	if not game.player.in_boat:return "O sonar fica no barco."
	if level()<1:return "Sem sonar. O estaleiro instala um por 120 moedas."
	if cooldown>0.:return "O sonar ainda está recarregando (%d s)."%int(ceil(cooldown))
	cooldown=5.
	var boat: Node3D=game.boat
	var at: Vector3=boat.global_position
	var reach:=600. if level()<2 else 1200.
	heading=boat.rotation.y
	contacts.clear()
	var depth:=Waves.depth_at(Vector2(at.x,at.z))
	depth_line="Fundo: %d m"%int(round(depth))
	if depth>140.:depth_line+=" · profundidade anormal"
	var marine=game.get("marine")
	if marine!=null:
		for school in marine.fish_schools:
			var c: Vector3=school.center
			var d:=Vector2(c.x-at.x,c.z-at.z).length()
			if d<reach*.8:
				var big:=str(school.species) in ["atum_rei","peixe_lua","peixe_serra","tubarao_branco","tubarao_recife"]
				_add(c,("cardume grande" if big else "cardume")+" a %d m de fundo"%int(maxf(1.,-c.y)),Color("7dffb0") if not big else Color("e9ff7d"),d,reach)
	var diving=game.get("diving")
	if diving!=null:
		for site: Dictionary in diving.sites:
			var p: Vector3=site.pos
			var d:=Vector2(p.x-at.x,p.z-at.z).length()
			if d<reach:_add(p,"eco metálico no fundo" if site.kind=="naufragio" else "cavidade no fundo",Color("ffd27d"),d,reach)
	var wp=game.world.get("whirlpools")
	if wp!=null:
		for site: Dictionary in wp.sites:
			var p:=Vector3((site.pos as Vector2).x,0,(site.pos as Vector2).y)
			var d:=Vector2(p.x-at.x,p.z-at.z).length()
			if d<reach*1.5 and float(site.strength)>.2:_add(p,"turbulência forte",Color("7dd8ff"),d,reach*1.5)
			elif d<reach and str(site.secret)=="gruta":_add(p+Vector3(0,site.floor,0),"cavidade no fundo",Color("ffd27d"),d,reach)
	var lairs=game.get("lairs")
	if lairs!=null:
		for lair: Dictionary in lairs.lairs:
			var c: Vector3=lair.center
			var d:=Vector2(c.x-at.x,c.z-at.z).length()
			if d>reach*2.5:continue
			var awake: bool=str(lair.state)!="dormindo"
			var p:=(lair.pos as Vector3) if awake else c+Vector3(_rng.randf_range(-80.,80.),-60.,_rng.randf_range(-80.,80.))
			_add(p,"forma enorme" if awake else "sinal desconhecido",Color("ff6d6d"),d,reach*2.5)
	var enc=game.get("encounters")
	if enc!=null:
		for c: Array in enc.contacts(at,reach*1.5):_add(c[0],c[1],Color("ff9d6d"),Vector2((c[0] as Vector3).x-at.x,(c[0] as Vector3).z-at.z).length(),reach*1.5)
	# The deep at night sometimes answers with nothing at all.
	var h: float=game.world.ocean.hour
	if (h>20. or h<5.) and depth>100. and _rng.randf()<.35:
		var a:=_rng.randf()*TAU
		_add(at+Vector3(cos(a),0,sin(a))*_rng.randf_range(150.,reach)+Vector3(0,-80,0),"sinal desconhecido",Color("ff6d6d"),300.,reach)
	contacts.sort_custom(func(a: Array,b: Array) -> bool:return float(a[3])<float(b[3]))
	show_clock=SHOW_TIME;visible=true;queue_redraw()
	_ring_fx(at)
	game.audio.cue("ping")
	var summary:=depth_line
	if contacts.is_empty():summary+=" · nenhum eco"
	else:summary+=" · %d ecos: %s"%[contacts.size(),str(contacts[0][2])]
	return summary

## A contact: [world position, bearing-relative vector (x right, y ahead, 0..1 of reach), label, distance].
## Far ones are blurred: their position wanders and their label becomes vaguer.
func _add(p: Vector3,label: String,color: Color,distance: float,reach: float) -> void:
	var at: Vector3=game.boat.global_position
	var blur:=smoothstep(.45,1.,distance/reach)
	var off:=Vector2(p.x-at.x,p.z-at.z)+Vector2(_rng.randf_range(-1.,1.),_rng.randf_range(-1.,1.))*distance*.18*blur
	var local:=off.rotated(heading)/reach
	if blur>.6 and not label.begins_with("sinal"):label="eco indistinto"
	contacts.append([p,Vector2(local.x,local.y),label,distance,color])

func _ring_fx(at: Vector3) -> void:
	if _ring==null:
		_ring=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.97;torus.outer_radius=1.;torus.rings=96;torus.ring_segments=4;_ring.mesh=torus
		var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color=Color(.5,1.,.85,.6)
		_ring.material_override=m;_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(_ring)
	_ring.global_position=at+Vector3(0,.3,0);_ring_clock=0.;_ring.visible=true

func _process(delta: float) -> void:
	if game==null:return
	cooldown=maxf(0.,cooldown-delta)
	if _ring!=null and _ring_clock>=0.:
		_ring_clock+=delta
		var k:=_ring_clock/2.5
		_ring.scale=Vector3.ONE*(4.+k*160.);(_ring.material_override as StandardMaterial3D).albedo_color.a=.6*(1.-k)
		if k>=1.:_ring.visible=false;_ring_clock=-1.
	if show_clock>0.:
		show_clock-=delta
		if show_clock<=0.:visible=false
		queue_redraw()

func _draw() -> void:
	var c:=Vector2(125,125);var r:=110.
	var fade:=clampf(show_clock/2.,0.,1.)
	draw_circle(c,r,Color(.02,.1,.1,.78*fade))
	for k: int in 3:draw_arc(c,r*float(k+1)/3.,0.,TAU,48,Color(.4,1.,.8,.25*fade),1.)
	draw_line(c+Vector2(0,-r),c+Vector2(0,r),Color(.4,1.,.8,.15*fade));draw_line(c+Vector2(-r,0),c+Vector2(r,0),Color(.4,1.,.8,.15*fade))
	var sweep:=fmod((SHOW_TIME-show_clock)*1.6,TAU)
	draw_line(c,c+Vector2(sin(sweep),-cos(sweep))*r,Color(.5,1.,.85,.5*fade),2.)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-7),c+Vector2(5,5),c+Vector2(-5,5)]),Color(1,1,1,.9*fade))
	var font:=ThemeDB.fallback_font
	var shown:=0
	for contact: Array in contacts:
		var v: Vector2=contact[1]
		if v.length()>1.:v=v.normalized()
		var p:=c+Vector2(v.x,v.y)*r
		var col: Color=contact[4];col.a*=fade
		draw_circle(p,4.5,col)
		if shown<4:
			draw_string(font,Vector2(8,250+shown*15),"• "+str(contact[2])+" (%d m)"%int(round(float(contact[3])/10.)*10.),HORIZONTAL_ALIGNMENT_LEFT,240,12,col)
		shown+=1
	draw_string(font,Vector2(8,238),depth_line,HORIZONTAL_ALIGNMENT_LEFT,240,13,Color(.8,1.,.95,fade))
