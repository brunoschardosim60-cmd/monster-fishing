extends RefCounted
## Working sails for a hull built by vessel_models.gd. Each sail is hung on a pivot at its tack (the
## mast or forestay foot) so it can swing about the vertical axis; its boom swings with it. The rig trims
## itself to the wind (sheeted at about half the angle to the true wind, always to leeward), bellies out
## to leeward when drawing, flogs when the boat points too high, and hoists/reefs by scaling the cloth
## up from the boom. drive() is the share of the wind's push turned into forward thrust (a simple polar).
const NO_GO_DEG: float=38.
var pivots: Array[Node3D]=[]
## Visible hoist, 0 furled … 1 full sail.
var hoist: float=1.
var trim: float=0.
var fill: float=1.
var _clock: float=0.

static func rig(model: Node3D) -> RefCounted:
	var out=load("res://scripts/boats/sail_rig.gd").new()
	var booms: Array=model.get_meta("booms",[])
	for sail: MeshInstance3D in model.get_meta("sails",[]):
		if not sail.has_meta("tack"):continue
		var tack: Vector3=sail.get_meta("tack")
		var pivot:=Node3D.new();pivot.name="Escota";pivot.position=tack
		sail.get_parent().add_child(pivot)
		sail.reparent(pivot,false);sail.position=-tack
		for boom: Node3D in booms:
			if boom.get_parent()!=pivot and _flat(boom.get_meta("from",Vector3.ZERO)).distance_to(_flat(tack))<.6:
				boom.reparent(pivot,false);boom.position-=tack
		if sail.has_meta("square"):pivot.set_meta("square",true)
		out.pivots.append(pivot)
	return out

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

## Angle (radians) between the bow and the direction the wind comes FROM, and which side it comes from
## (+1 starboard, -1 port), given the wind's travel direction in boat space.
static func wind_angle(local_wind: Vector3) -> Vector2:
	var w:=Vector3(local_wind.x,0.,local_wind.z).normalized()
	if w.length()<.01:return Vector2.ZERO
	return Vector2(acos(clampf(w.z,-1.,1.)),-signf(w.x) if absf(w.x)>.001 else 1.)

## Thrust share for a sail at `angle` from the wind: nothing inside the no-go zone, best on a beam reach,
## a little less running dead downwind.
static func drive(angle: float) -> float:
	var deg:=rad_to_deg(angle)
	return smoothstep(NO_GO_DEG,NO_GO_DEG+27.,deg)*(1.-.3*smoothstep(110.,180.,deg))

func update(delta: float,local_wind: Vector3,strength: float,target_hoist: float) -> void:
	_clock+=delta
	hoist=move_toward(hoist,target_hoist,delta*.45)
	var aw:=wind_angle(local_wind)
	var angle: float=aw.x;var from_side: float=aw.y
	# Sheeted to leeward at about half the wind angle; a gybe swings the boom across, not instantly.
	var want:=-from_side*clampf(angle*.5,deg_to_rad(8.),deg_to_rad(80.))
	trim=move_toward(trim,want,delta*(.9+strength))
	var drawing:=drive(angle)
	fill=lerpf(fill,.25+.75*drawing,1.-exp(-delta*3.))
	for pivot: Node3D in pivots:
		if pivot.has_meta("square"):
			# Square sail: the yard is braced round (never more than ~35°), the cloth bellies forward when
			# drawing and hangs slack and shivering when not; it hoists from the yard down.
			var brace: float=clampf(trim*.7,-.6,.6)
			var full: float=lerpf(.35,1.,fill) if drawing>=.15 else .3+sin(_clock*15.+pivot.position.y)*.08
			pivot.basis=Basis(Vector3.UP,brace)*Basis.from_scale(Vector3(1.,maxf(hoist,.04),full))
			pivot.visible=true
			continue
		var belly: float=-from_side*fill
		if drawing<.15:belly=sin(_clock*17.+pivot.position.z)*.25*(.3+strength)
		pivot.basis=Basis(Vector3.UP,trim)*Basis.from_scale(Vector3(belly if absf(belly)>.04 else .04,maxf(hoist,.04),1.))
		pivot.visible=hoist>.03
