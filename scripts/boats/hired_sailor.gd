extends Node3D
## A sailor hired at the port, aboard the player's boat. Lives in hull space (child of the wave-following
## hull) and walks the real deck: the same walkable box and cabin blocks the player uses, going round a
## cabin by the side deck. Jobs are given by crew_manager.gd; each job is "walk to the spot, then work":
## a sailor never hauls a trap or aims the light from the other end of the boat.
##   haul    — at the rail nearest the gear, pulls the line hand over hand until the manager says done
##   alert   — goes to a rod holder with a fish on and calls out (waves)
##   light   — stands by the searchlight and aims it (the manager drives the aim)
##   secure  — storm duty: works along the side deck lashing gear (reduces wave damage)
##   fish    — at the rail with a rod: waits on the float, fights and lands what bites (crew_manager runs the odds)
##   helm    — at the wheel, holding the course and speed the skipper left (the boat's autopilot)
##   idle    — rests at its station, looks out to sea
const HullClasses=preload("res://scripts/boats/hull_classes.gd")
const WALK_SPEED: float=1.35
signal arrived(sailor: Node3D)
var sailor_name: String="Marujo"
var look_id: int=70
var boat: CharacterBody3D
var visual: Node3D
## Deck position in hull space and the current target.
var deck_local:=Vector3.ZERO
var target:=Vector3.ZERO
var job: String="idle"
var station:=Vector3.ZERO
var facing: float=0.
var _waypoints: Array[Vector3]=[]
var _arrived_sent: bool=true
var _secure_clock: float=0.
## Fishing at the rail: the rod is out, where the float lies (world space) and how hard a fish pulls (0..1).
var rod_out: bool=false
var bob_point:=Vector3.ZERO
var pull: float=0.
var _bob: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh

func _ready() -> void:
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	visual.apply_look(preload("res://scripts/world/npc_look.gd").for_id(look_id))
	if visual.backpack!=null:visual.backpack.visible=false
	_bob=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.07;ball.height=.14;_bob.mesh=ball
	var red:=StandardMaterial3D.new();red.albedo_color=Color("e0603a");_bob.material_override=red;_bob.top_level=true;_bob.visible=false;add_child(_bob)
	_line_mesh=ImmediateMesh.new();_line=MeshInstance3D.new();_line.mesh=_line_mesh;_line.top_level=true
	var lm:=StandardMaterial3D.new();lm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;lm.albedo_color=Color(.92,.95,.9,.8);lm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override=lm;_line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(_line)

func at_target() -> bool:
	return _waypoints.is_empty() and Vector2(deck_local.x-target.x,deck_local.z-target.z).length()<.15

## Walk to `point` (hull space, on deck), then do `new_job` there facing `face` (radians, hull space).
func assign(new_job: String,point: Vector3,face: float=0.) -> void:
	job=new_job;facing=face
	var deck: Dictionary=boat.deck_layout()
	point.x=clampf(point.x,-float(deck.x)+.05,float(deck.x)-.05);point.z=clampf(point.z,float(deck.z0),float(deck.z1));point.y=float(deck.y)
	point=HullClasses.resolve_blocks(point,deck.blocks,.1)
	target=point;_waypoints=_route(deck_local,point,deck);_arrived_sent=false

## Straight line if clear; otherwise round the obstacle: out to the side deck, along it past the end of the
## cabin nearest the way, across, and back along the other side to the spot.
func _route(from: Vector3,to: Vector3,deck: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3]=[]
	for b: Rect2 in deck.blocks:
		var r:=b.grow(.2)
		if not _segment_hits(Vector2(from.x,from.z),Vector2(to.x,to.z),r):continue
		var lane: float=float(deck.x)-.15
		var x_from: float=lane*(1. if from.x>=0. else -1.);var x_to: float=lane*(1. if to.x>=0. else -1.)
		var mid_z: float=(from.z+to.z)*.5
		var cross_z: float=r.position.y-.25 if absf(mid_z-r.position.y)<absf(mid_z-r.end.y) else r.end.y+.25
		cross_z=clampf(cross_z,float(deck.z0)+.1,float(deck.z1)-.1)
		out.append(Vector3(x_from,from.y,from.z))
		if absf(x_from-x_to)>.1:
			out.append(Vector3(x_from,from.y,cross_z));out.append(Vector3(x_to,from.y,cross_z))
		out.append(Vector3(x_to,from.y,to.z))
		break
	out.append(to)
	return out

static func _segment_hits(a: Vector2,b: Vector2,r: Rect2) -> bool:
	for k: int in 21:
		if r.has_point(a.lerp(b,float(k)/20.)):return true
	return false

func _process(delta: float) -> void:
	if boat==null or not is_instance_valid(boat._hull):return
	var deck: Dictionary=boat.deck_layout()
	var moving:=0.
	if not _waypoints.is_empty():
		var next: Vector3=_waypoints[0]
		var to:=Vector3(next.x-deck_local.x,0,next.z-deck_local.z)
		if to.length()<.08:_waypoints.pop_front()
		else:
			var step:=minf(WALK_SPEED*delta,to.length())
			deck_local+=to.normalized()*step;moving=WALK_SPEED
			deck_local=HullClasses.resolve_blocks(deck_local,deck.blocks,.05)
			rotation.y=lerp_angle(rotation.y,atan2(-to.x,-to.z),1.-exp(-delta*8.))
	elif not _arrived_sent:
		_arrived_sent=true;arrived.emit(self)
	else:
		rotation.y=lerp_angle(rotation.y,facing,1.-exp(-delta*4.))
	if job=="secure" and at_target():
		# Storm duty: move along the side deck from one lashing to the next.
		_secure_clock-=delta
		if _secure_clock<=0.:
			_secure_clock=randf_range(3.,6.)
			var side: float=signf(deck_local.x) if absf(deck_local.x)>.1 else 1.
			assign("secure",Vector3(side*(float(deck.x)-.2),0.,randf_range(float(deck.z0)+.5,float(deck.z1)-.5)),PI*.5*side)
	deck_local.y=float(deck.y)
	position=deck_local
	var working: bool=at_target() and moving==0.
	# Hauling is hand over hand at the rail (procedural, see imported_angler.haul); the rest are clips.
	visual.haul=1. if working and job=="haul" else 0.
	visual.work_clip={"alert":"ual/Wave","light":"ual/IdleLook","secure":"ual/Fix","helm":"ual/Rail","helm_wait":"ual/FoldArms"}.get(job,"") if working else ""
	visual.idle_clip="ual/Rail" if job=="idle" else "ual/Idle"
	var fishing: bool=rod_out and working and job=="fish"
	visual.fishing_state=4 if pull>0. else 0
	visual.rod_bend=pull
	visual.update_animation(moving,fishing,delta)
	_draw_line(fishing)

## Line from the rod tip to the float, sagging when slack, straight and under water when a fish pulls.
func _draw_line(on: bool) -> void:
	_line_mesh.clear_surfaces();_bob.visible=on
	if not on:return
	var tip: Vector3=visual.rod_tip()
	var end: Vector3=bob_point
	_bob.global_position=end+Vector3(0,.04,0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag: float=lerpf(.6,.05,clampf(pull*1.4,0.,1.))
	for i: int in 13:
		var t: float=float(i)/12.
		_line_mesh.surface_add_vertex(tip.lerp(end,t)-Vector3(0,sin(t*PI)*sag,0))
	_line_mesh.surface_end()
