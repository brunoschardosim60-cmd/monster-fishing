extends Node3D
## Monster encounters out at sea, beyond the guarded territories (monster_lairs.gd):
##  · "a sombra" (nocturnal): at night over deep water a huge dark shape may come up under the boat and follow
##    it for a couple of minutes without attacking. Only the sonar shows it clearly. Lights on and full speed
##    make it nervous: it can breach beside the hull. A flare (Y) sends it down.
##  · the migrating serpent (daytime): a long sea serpent travelling across open water, its back breaking the
##    surface now and then. It is shy: a boat closing in under power makes it dive and leave.
## Each encounter is an event with a beginning and an end, chosen from the time, the depth and the weather.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Big=preload("res://scripts/creatures/big_animals.gd")
var game: Node3D
var shadow: Node3D
var shadow_state: String=""
var shadow_clock: float=0.
var shadow_offset: Vector3=Vector3(0,-22,40)
var serpent: Node3D
var serpent_clock: float=0.
var serpent_dir: Vector3
var _roll_clock: float=60.
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=1313

func _night() -> bool:
	var h: float=game.world.ocean.hour
	return h>19.8 or h<5.2

func _physics_process(delta: float) -> void:
	if game==null or not game.started:return
	var boat: CharacterBody3D=game.boat
	var b:=boat.global_position
	var depth:=Layout.coast(Vector2(b.x,b.z)).x
	_roll_clock-=delta
	if _roll_clock<=0.:
		_roll_clock=60.
		if shadow==null and _night() and depth>250. and game.player.in_boat and _rng.randf()<.14:start_shadow()
		elif serpent==null and not _night() and depth>300. and _rng.randf()<.1:start_serpent()
	if shadow!=null:_update_shadow(delta,boat)
	if serpent!=null:_update_serpent(delta,boat)

# --- The shadow ----------------------------------------------------------------------------------------

func start_shadow() -> void:
	shadow=Big.whale(30.,true);shadow.name="Sombra"
	var body: MeshInstance3D=shadow.get_node("Corpo")
	(body.material_override as ShaderMaterial).set_shader_parameter("glow",.25)
	add_child(shadow)
	shadow_state="subindo";shadow_clock=0.
	shadow.global_position=game.boat.global_position+Vector3(0,-60,90)
	game.hud.notify("A água fica mais escura sob o barco… algo enorme está logo abaixo.")
	game.audio.cue_at("roar",shadow.global_position,-14.)

func _update_shadow(delta: float,boat: CharacterBody3D) -> void:
	shadow_clock+=delta
	var behind:=boat.global_basis*shadow_offset
	var want:=boat.global_position+behind
	want.y=-22.+sin(shadow_clock*.2)*4.
	var nervous: bool=bool(boat.lights_enabled) and absf(float(boat.speed))>5.
	match shadow_state:
		"subindo","seguindo":
			if shadow_clock>6.:shadow_state="seguindo"
			if shadow_state=="seguindo" and nervous and fmod(shadow_clock,20.)<delta and _rng.randf()<.45:shadow_state="saltando";shadow_clock=0.
			if shadow_clock>150.:shadow_state="indo";shadow_clock=0.
		"saltando":
			want=boat.global_position+boat.global_basis.x*18.;want.y=lerpf(-20.,2.,sin(clampf(shadow_clock/3.,0.,1.)*PI))
			if shadow_clock>1.4 and not shadow.get_meta("hit",false):
				shadow.set_meta("hit",true)
				boat.take_hit(.08,.45);game.world.ocean.effects.splash(boat.global_position+boat.global_basis.x*8.,3.,true)
				game.audio.cue_at("breach",boat.global_position+boat.global_basis.x*10.)
				game.hud.notify("A sombra salta ao lado do casco! Apague as luzes e vá devagar.")
			if shadow_clock>3.:shadow_state="seguindo";shadow_clock=20.;shadow.set_meta("hit",false)
		"indo":
			want=shadow.global_position+Vector3(0,-10,0)-shadow.global_basis.z*20.
			if shadow_clock>12.:shadow.queue_free();shadow=null;game.hud.notify("A sombra desce e some no escuro.");return
	shadow.global_position=shadow.global_position.lerp(want,1.-exp(-delta*.6))
	var heading:=boat.global_position-shadow.global_position;heading.y=0.
	if heading.length()>1.:shadow.rotation.y=lerp_angle(shadow.rotation.y,atan2(-heading.x,-heading.z),1.-exp(-delta*.5))
	Big.beat_fluke(shadow)

## Flare: the shadow dives away at once.
func scare() -> bool:
	if shadow!=null and shadow_state!="indo":shadow_state="indo";shadow_clock=0.;return true
	if serpent!=null:serpent_clock=999.;return true
	return false

# --- The migrating serpent -----------------------------------------------------------------------------

func start_serpent() -> void:
	var boat: CharacterBody3D=game.boat
	var a:=_rng.randf()*TAU;var side:=Vector3(cos(a),0,sin(a))
	var start:=boat.global_position+side*700.
	if Layout.coast(Vector2(start.x,start.z)).x<200.:return
	serpent_dir=(boat.global_position-start).normalized().rotated(Vector3.UP,_rng.randf_range(-.6,.6))
	serpent=Node3D.new();serpent.name="SerpenteMigratoria";add_child(serpent)
	# The same 60 m serpent breed as the lair's (tools/blender/leviathan.py), swimming with its head low.
	preload("res://scripts/world/monster_lairs.gd").serpent_model(serpent,"res://assets/monsters/serpente/serpente.glb",60.)
	serpent.global_position=start;serpent.rotation.y=atan2(-serpent_dir.x,-serpent_dir.z)
	serpent_clock=0.
	game.hud.notify("Ao longe, um dorso longo corta a água… uma serpente marinha em migração.")

func _update_serpent(delta: float,boat: CharacterBody3D) -> void:
	serpent_clock+=delta
	var near:=serpent.global_position.distance_to(boat.global_position)
	var spooked:=serpent_clock>900. or (near<90. and absf(float(boat.speed))>3.)
	serpent.global_position+=serpent_dir*(9. if spooked else 4.)*delta
	# Surfaces in long arcs; spooked, it goes down and does not come back.
	var surfacing:=.5+.5*sin(serpent_clock*.18)
	var y:=lerpf(-16.,-1.,surfacing) if not spooked else serpent.global_position.y-delta*4.
	serpent.global_position.y=lerpf(serpent.global_position.y,y,1.-exp(-delta*.8))
	if spooked and not serpent.get_meta("fled",false):
		serpent.set_meta("fled",true);game.hud.notify("A serpente sente o motor, mergulha e foge.")
	if serpent.global_position.y<-30. or serpent_clock>1100. or near>2200.:
		serpent.queue_free();serpent=null

## For the sonar: [Vector3 position, String label] of encounter creatures in range.
func contacts(at: Vector3,reach: float) -> Array:
	var out:=[]
	if shadow!=null and shadow.global_position.distance_to(at)<reach:out.append([shadow.global_position,"forma enorme seguindo o barco"])
	if serpent!=null and serpent.global_position.distance_to(at)<reach:out.append([serpent.global_position,"corpo longo em movimento"])
	return out
