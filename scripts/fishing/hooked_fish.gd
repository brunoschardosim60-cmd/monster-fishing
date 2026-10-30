extends Node3D
## The fish on the end of the line, as a real body in the water. It is presentation only: the fight's
## numbers live in fishing_system.gd (tension, progress, surging) and this node acts them out.
##   fight   — runs left and right, dives when it surges, comes closer as the angler gains line,
##             thrashes at the surface near the end (splashes via `thrash`).
##   landing — lifted out of the water on an arc to the angler's hand; then the held trophy takes over.
##   escape  — the line broke or went slack: it bolts away and sinks out of sight.
##   release — let go beside the boat or shore: lowered into the water, then swims off and down.
## Only one body exists at a time, so a fish is never duplicated between water, hand and hold.
signal thrash(at: Vector3,strength: float)
const Waves=preload("res://scripts/world/wave_field.gd")
const Forms=preload("res://scripts/creatures/fish_forms.gd")
var mode: String=""
var body: Node3D
var length_m: float=.6
var clock: float=0.
var phase: float=0.
var _player: Vector3
var _dir:=Vector3.FORWARD
var _start_dist: float=10.
var _depth: float=.6
var _velocity:=Vector3.ZERO
var _from:=Vector3.ZERO
var _to:=Vector3.ZERO
var _thrash_clock: float=0.
## The fish's own tail-beat material (fish_form.gdshader wag/time_speed), driven by the fight.
var _beat: ShaderMaterial
var _roll: float=0.
## Where the line ties on (the fish's mouth), for the line renderer.
var mouth:=Vector3.ZERO
var _last_phase: String=""
var _phase_clock: float=0.
var _run_out: float=0.
var _splashed_down: bool=false

func _ready() -> void:
	visible=false

func _build(species: Resource) -> void:
	if is_instance_valid(body):body.queue_free()
	body=Node3D.new();add_child(body)
	var id: String=str(species.id) if species!=null else "sardine"
	if Forms.has_form(id):
		length_m=Forms.length_of(id)
		var mesh:=MeshInstance3D.new();mesh.mesh=Forms.mesh(id);_beat=Forms.struggle_material(id);mesh.material_override=_beat
		mesh.scale=Vector3.ONE*length_m;body.add_child(mesh)
	elif id in ["mackerel","tuna","lanternfish"]:
		var imported:=preload("res://scripts/creatures/marine_visual.gd").new();imported.species=id;imported.face_forward=false;body.add_child(imported)
		length_m={"mackerel":.45,"tuna":1.4,"lanternfish":.2}[id]
	else:
		var display: Node3D=preload("res://scripts/fishing/catch_display.gd").new();body.add_child(display);display.set_process(false)
		display.show_catch({"species_id":id,"color":species.color.to_html() if species!=null else "83c6cf"});display.rotation=Vector3.ZERO
		length_m=1.

## The hook is set at `at`: the fish starts where the bobber was.
func hook(at: Vector3,player_pos: Vector3,species: Resource) -> void:
	_build(species)
	mode="fight";clock=0.;phase=randf()*TAU;_player=player_pos
	var flat:=Vector3(at.x-player_pos.x,0.,at.z-player_pos.z)
	_start_dist=maxf(flat.length(),2.);_dir=flat.normalized() if flat.length()>.01 else Vector3.FORWARD
	global_position=at-Vector3.UP*.5;_velocity=Vector3.ZERO;_depth=.5;visible=true

## `fight_phase` (fishing_system): calm, run (bolts away, line going out), dive (heads down), shake
## (head-shaking at the surface), jump (clears the water).
func fight(delta: float,player_pos: Vector3,tension: float,progress: float,surging: bool,fight_phase: String="") -> void:
	if mode!="fight":return
	clock+=delta;_player=player_pos
	if fight_phase=="":fight_phase="run" if surging else "calm"
	if fight_phase!=_last_phase:_phase_clock=0.;_last_phase=fight_phase
	_phase_clock+=delta
	var dist: float=lerpf(_start_dist,1.6+length_m*.5,pow(clampf(progress,0.,1.),.85))
	# A run takes the fish out and across; it sweeps wider when fresh, close to the boat it circles.
	_run_out=lerpf(_run_out,(4.+length_m*2.) if fight_phase=="run" else 0.,1.-exp(-delta*(1.2 if fight_phase=="run" else .5)))
	dist+=_run_out*(1.-progress*.7)
	var side:=Vector3(-_dir.z,0.,_dir.x)
	var sweep: float=1.8 if fight_phase=="run" else 1.
	var lateral: float=sin(clock*.75*sweep+phase)*minf(dist*.3,6.)*(1.-.6*progress)*sweep+sin(clock*2.3+phase*2.)*.4
	# Kept high in the water so the angler sees the flash of its flank; a dive takes it down.
	var want_depth: float=.22+length_m*.08+.12*sin(clock*1.6+phase)
	match fight_phase:
		"dive":want_depth+=1.4+length_m*.3
		"run":want_depth+=.4
		"shake":want_depth=.05
	if progress>.82:want_depth=.06
	_depth=lerpf(_depth,want_depth,1.-exp(-delta*1.8))
	var target:=Vector3(player_pos.x,0.,player_pos.z)+_dir*dist+side*lateral
	var surface: float=Waves.height_at(target)
	target.y=surface-_depth
	if fight_phase=="jump":
		# Clears the water in an arc, body bent, and falls back with a splash.
		var t: float=clampf(_phase_clock/.65,0.,1.)
		target.y=surface+sin(t*PI)*(.5+length_m*.35)
		if _phase_clock-delta<=0.:thrash.emit(Vector3(global_position.x,surface,global_position.z),clampf(.5+length_m*.4,.5,1.8))
		if t>=1. and not _splashed_down:_splashed_down=true;thrash.emit(Vector3(global_position.x,surface,global_position.z),clampf(.6+length_m*.5,.6,2.))
	else:_splashed_down=false
	var before:=global_position
	var follow: float=(6. if fight_phase=="jump" else 2.2+tension*2.)
	global_position=global_position.lerp(target,1.-exp(-delta*follow))
	_velocity=_velocity.lerp((global_position-before)/maxf(delta,.001),1.-exp(-delta*6.))
	# Head away from the angler, swung toward where it is swimming; shaking near the surface.
	var heading:=_dir*1.2+Vector3(_velocity.x,0.,_velocity.z).limit_length(1.5)
	if fight_phase=="run":heading+=_dir
	var shaking:=progress>.82 or fight_phase=="shake" or (tension>.75 and sin(clock*3.)>.6)
	_roll=lerpf(_roll,sin(clock*(24. if fight_phase=="shake" else 19.))*(.8 if shaking else .12),1.-exp(-delta*10.))
	var pitch: float=clampf(_velocity.y*.15,-.6,.6)
	if fight_phase=="jump":pitch=lerpf(.7,-.7,clampf(_phase_clock/.65,0.,1.))
	_orient(heading,_roll,pitch)
	# The tail beats hard on a run or while it shakes and jumps, slower as it tires near the boat.
	if _beat!=null:
		var effort: float=1. if fight_phase in ["run","shake","jump"] or shaking else (.55 if fight_phase=="dive" else .3)
		effort*=lerpf(1.,.6,clampf(progress,0.,1.))
		_beat.set_shader_parameter("wag",lerpf(.16,.6,effort));_beat.set_shader_parameter("time_speed",lerpf(7.,22.,effort))
	_thrash_clock-=delta
	if shaking and _depth<.3 and _thrash_clock<=0.:
		_thrash_clock=randf_range(.25,.6) if fight_phase=="shake" else randf_range(.35,.8)
		thrash.emit(Vector3(global_position.x,Waves.height_at(global_position),global_position.z),clampf(.35+length_m*.4,.35,1.6))

## Lift out of the water toward `hand`. Returns true while the lift is still running.
func land(hand: Vector3) -> void:
	if not visible:return
	mode="landing";clock=0.;_from=global_position;_to=hand
	thrash.emit(Vector3(_from.x,Waves.height_at(_from),_from.z),clampf(.5+length_m*.4,.5,1.8))

func landing() -> bool:
	return mode=="landing"

func escape() -> void:
	if mode=="fight":mode="escape";clock=0.

## Put a held fish back: lowered from `from` to the water at `water`, then it swims off.
func release(species: Resource,from: Vector3,water: Vector3) -> void:
	_build(species)
	mode="release";clock=0.;_from=from;_to=water;_dir=Vector3(water.x-from.x,0.,water.z-from.z).normalized()
	if _dir.length()<.1:_dir=Vector3.FORWARD
	global_position=from;visible=true

func _process(delta: float) -> void:
	if not visible:return
	match mode:
		"landing":
			clock+=delta
			var t:=clampf(clock/.6,0.,1.)
			global_position=_from.lerp(_to,t)+Vector3.UP*sin(t*PI)*.9
			_orient((_to-_from)*Vector3(1,0,1)+Vector3(0,.01,0),sin(clock*22.)*.8,-.6+t*.6)
			if t>=1.:visible=false;mode=""
		"escape":
			clock+=delta
			global_position+=(_dir*(3.5+length_m)+Vector3.DOWN*1.2)*delta
			_orient(_dir,sin(clock*14.)*.2,-.3)
			if clock>2.2:visible=false;mode=""
		"release":
			clock+=delta
			if clock<.5:
				var t:=clock/.5
				global_position=_from.lerp(_to,t)+Vector3.UP*sin(t*PI)*.25
				_orient(_dir,sin(clock*16.)*.5,-.4)
				if t>.9 and clock-delta<.45:thrash.emit(_to,.45)
			else:
				# A moment to recover, then a flick of the tail and away, down into the blue.
				var swim: float=clampf((clock-.9)/.6,0.,1.)
				global_position+=(_dir*(.3+swim*(2.+length_m))+Vector3.DOWN*(.2+swim*.6))*delta
				_orient(_dir,sin(clock*(4.+swim*8.))*.15,-.25*swim)
				if clock>4.:visible=false;mode=""
	mouth=to_global(Vector3.ZERO)+global_basis.x*length_m*.48 if is_instance_valid(body) else global_position

func _orient(heading: Vector3,roll: float,pitch: float) -> void:
	var h:=Vector3(heading.x,0.,heading.z)
	if h.length()<.001:h=_dir
	h=h.normalized()
	var b:=Basis(h,Vector3.UP,h.cross(Vector3.UP))  # +X (the head) along the heading
	b=b*Basis(Vector3.RIGHT,roll)*Basis(Vector3.BACK,pitch)
	global_basis=b
