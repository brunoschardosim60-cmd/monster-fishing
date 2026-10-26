extends Node3D
## Working anchor for the player boat. Z drops it: the anchor falls from the bow roller, splashes,
## sinks to the real sea floor and bites; the boat then stops and swings on its chain, bow into the
## wind. Z again hauls it back aboard (chain rattle), and only then the boat can motor away.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
signal changed(state: String)
const DROP_SPEED: float=3.2
const RAISE_SPEED: float=1.4
## Extra chain paid out beyond the depth (scope), so the boat can swing in a small circle.
const SCOPE: float=1.6
## The chain is this long: deeper water cannot be anchored in.
const MAX_DEPTH: float=45.
var state: String="up"
var boat: CharacterBody3D
## Bow roller, in boat-local space.
var roller: Vector3=Vector3(0,1.05,-3.9)
## Returns the visible sea floor height at a world XZ point; set by main (seabed raycasts).
var floor_sampler: Callable
var anchor: Node3D
var chain: MeshInstance3D
var hold_point: Vector3=Vector3.ZERO
var rode_length: float=0.
var _depth: float=0.
var _bottom: float=-3.
var _was_under: bool=false
var _rattle_clock: float=0.

func _ready() -> void:
	var iron:=StandardMaterial3D.new();iron.albedo_color=Color("2b2f33");iron.metallic=.7;iron.roughness=.45
	anchor=Node3D.new();anchor.name="Ancora";anchor.top_level=true;add_child(anchor)
	G.cylinder(anchor,Vector3(0,-.45,0),.05,.9,iron)
	G.beam(anchor,Vector3(-.32,-.05,0),Vector3(.32,-.05,0),.035,iron)
	G.sphere(anchor,Vector3(0,.04,0),Vector3(.13,.13,.04),iron,10)
	for side: float in [-1.,1.]:
		G.beam(anchor,Vector3(0,-.88,0),Vector3(side*.34,-.62,0),.045,iron)
		var fluke:=G.box(anchor,Vector3(side*.36,-.6,0),Vector3(.16,.2,.05),iron);fluke.rotation.z=side*.6
	chain=MeshInstance3D.new();chain.name="Corrente";chain.top_level=true
	var link:=CylinderMesh.new();link.top_radius=.025;link.bottom_radius=.025;link.height=1.;link.radial_segments=6
	chain.mesh=link;chain.material_override=iron;chain.visible=false;add_child(chain)
	anchor.visible=false

func holding() -> bool:return state=="down"
## True while the anchor is out of its stowed position (the engine is locked out meanwhile).
func deployed() -> bool:return state!="up"

func toggle() -> String:
	match state:
		"up":
			state="dropping";_depth=0.;_was_under=false
			var at:=_roller_world()
			_bottom=_floor(Vector2(at.x,at.z))
			if at.y-_bottom>MAX_DEPTH:
				state="up";changed.emit("too_deep");return "too_deep"
			anchor.visible=true;chain.visible=true
		"down":state="raising"
		_:return state
	changed.emit(state)
	return state

func _roller_world() -> Vector3:
	return boat.global_transform*roller

func _floor(p: Vector2) -> float:
	if floor_sampler.is_valid():return float(floor_sampler.call(p))
	return -maxf(.85,.8+Layout.coast(p).x*.65)

func _physics_process(delta: float) -> void:
	if boat==null or state=="up":return
	var top:=_roller_world()
	match state:
		"dropping":
			_depth+=DROP_SPEED*delta
			var y:=top.y-_depth
			anchor.global_position=Vector3(top.x,maxf(y,_bottom+.15),top.z)
			var under:=anchor.global_position.y<Waves.height_at(anchor.global_position)
			if under and not _was_under and boat.water_effects!=null:boat.water_effects.splash(anchor.global_position,.8,true)
			_was_under=under
			if y<=_bottom+.15:
				state="down";hold_point=Vector3(top.x,_bottom,top.z)
				rode_length=(top.y-_bottom)+SCOPE
				changed.emit(state)
		"down":
			# The anchor stays put on the floor; the chain follows the swinging bow.
			anchor.global_position=hold_point+Vector3(0,.15,0)
		"raising":
			_rattle_clock+=delta
			var target:=top-Vector3(0,.25,0)
			anchor.global_position=anchor.global_position.move_toward(target,RAISE_SPEED*delta)
			if anchor.global_position.distance_to(target)<.05:
				state="up";anchor.visible=false;chain.visible=false
				changed.emit(state)
				return
	anchor.global_rotation=Vector3(0,boat.global_rotation.y,0)
	_update_chain(top,anchor.global_position+Vector3(0,.02,0))

func _update_chain(a: Vector3,b: Vector3) -> void:
	var length:=a.distance_to(b)
	if length<.01:chain.visible=false;return
	chain.visible=true
	var mid:=(a+b)*.5;var dir:=(b-a)/length
	var side:=dir.cross(Vector3.FORWARD if absf(dir.y)<.95 else Vector3.RIGHT).normalized()
	var basis:=Basis(side,dir,side.cross(dir)).orthonormalized()
	chain.global_transform=Transform3D(basis.scaled(Vector3(1.,length,1.)),mid)

## Called by the boat each physics step while anchored: returns the horizontal velocity that keeps the
## boat inside the chain's swing circle and turns the bow into the wind.
func restrain(delta: float) -> Vector3:
	var p:=boat.global_position;var to:=Vector2(hold_point.x-p.x,hold_point.z-p.z)
	var radius:=sqrt(maxf(0.,rode_length*rode_length-pow(_roller_world().y-hold_point.y,2.)))
	var pull:=Vector3.ZERO
	if to.length()>radius:pull=Vector3(to.x,0,to.y).normalized()*(to.length()-radius)*1.5
	# Weathervane: wind pushes the stern downwind, so the bow points up into it, towards the anchor.
	var drift:=Vector3(Waves.direction.x,0,Waves.direction.y)*(.15+Waves.wind*.45)
	var bow_target:=atan2(-to.x,-to.y) if to.length()>.3 else boat.rotation.y
	boat.rotation.y=lerp_angle(boat.rotation.y,bow_target,1.-exp(-delta*.35))
	return pull+drift*(1. if to.length()<radius else 0.)
