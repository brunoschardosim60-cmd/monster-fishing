extends Node
## Original synthesized ambience; no downloaded audio or external services.
var ambient: AudioStreamPlayer
var fx: AudioStreamPlayer
var ocean: Node3D
var boat: CharacterBody3D
var wind_layer: AudioStreamPlayer
var rain_layer: AudioStreamPlayer
var shore_layer: AudioStreamPlayer3D
var hull_layer: AudioStreamPlayer3D
var splash_layer: AudioStreamPlayer3D
var thunder_layer: AudioStreamPlayer3D
## Boat sounds: engine hum (pitch follows the throttle), wind in the rigging, and one-shot creaks,
## sail flogging and bow slaps triggered by what the hull is doing.
var engine_layer: AudioStreamPlayer3D
var rigging_layer: AudioStreamPlayer
## Water on deck washing about and running out of the scuppers (loop, follows the boat's water aboard).
var wash_layer: AudioStreamPlayer3D
var _creak_clock: float=3.
var _flap_clock: float=0.
var _last_roll: float=0.
## Synthesized one-shots by name, built once. Positional ones play from a small pool of 3D players.
var _cues: Dictionary={}
var _pool: Array[AudioStreamPlayer3D]=[]
var _pool_next: int=0

func _ready() -> void:
	add_to_group("audio")
	for i: int in 6:
		var p:=AudioStreamPlayer3D.new();p.unit_size=6.;p.max_distance=70.;p.volume_db=-12.;add_child(p);_pool.append(p)
	ambient = AudioStreamPlayer.new()
	ambient.stream = _wave_sound()
	ambient.volume_db = -24.0
	add_child(ambient)
	ambient.play()
	fx = AudioStreamPlayer.new()
	fx.volume_db = -15.0
	add_child(fx)
	wind_layer=_layer(_noise_sound(61,.012,6.,true))
	rain_layer=_layer(_noise_sound(62,.7,6.,true))
	shore_layer=_spatial(_wave_sound(),true)
	hull_layer=_spatial(_noise_sound(63,.055,6.,true),true)
	splash_layer=_spatial(_noise_sound(64,.2,.8,false),false)
	thunder_layer=_spatial(_noise_sound(65,.004,5.,false),false)
	thunder_layer.unit_size=250.; thunder_layer.max_distance=1500.
	engine_layer=_spatial(_engine_sound(),true);engine_layer.volume_db=-80.
	rigging_layer=_layer(_noise_sound(66,.5,6.,true))
	wash_layer=_spatial(_noise_sound(67,.09,5.,true),true);wash_layer.volume_db=-80.
	thunder_layer.volume_db=-5.

func _layer(stream: AudioStream) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new(); player.stream=stream; player.volume_db=-60.
	add_child(player); player.play(); return player

func _spatial(stream: AudioStream, loop: bool) -> AudioStreamPlayer3D:
	var player:=AudioStreamPlayer3D.new(); player.stream=stream
	player.volume_db=-26.; player.unit_size=8.; player.max_distance=90.
	add_child(player)
	if loop: player.play()
	return player

func configure(sea: Node3D, vessel: CharacterBody3D) -> void:
	ocean=sea; boat=vessel
	ocean.effects.splashed.connect(func(at: Vector3, strength: float) -> void:
		splash_layer.global_position=at; splash_layer.volume_db=-23.+strength*3.; splash_layer.play())
	ocean.thunder.connect(func(at: Vector3) -> void: thunder_layer.global_position=at; thunder_layer.play())

func _boat_sounds(delta: float,muffled: float) -> void:
	if boat==null or not "engine_rpm" in boat:return
	var rpm: float=absf(float(boat.engine_rpm))
	var aboard: bool=boat.occupied or (boat.global_position.distance_to(ocean.get_viewport().get_camera_3d().global_position)<25.)
	var outboard: bool=str(boat.hull_model)=="canoa"
	engine_layer.global_position=boat.global_position+boat.global_basis.z*float(boat.hull_spec.length)*.4
	engine_layer.volume_db=(-80. if rpm<.02 else -30.+rpm*12.+(4. if outboard else 0.))-muffled
	engine_layer.pitch_scale=(.55+rpm*.75)*(1.7 if outboard else 1.)+(.25 if boat.boost>0. else 0.)
	var sails: bool=boat.has_method("has_sails") and boat.has_sails()
	var hoisted: float=float(boat.sail_rig.hoist) if sails else 0.
	rigging_layer.volume_db=(-70. if not (sails and aboard) else -52.+ocean.weather.wind*26.+hoisted*4.)-muffled
	rigging_layer.pitch_scale=.8+ocean.weather.wind*.6
	var wf: float=float(boat.water_fraction()) if boat.has_method("water_fraction") else 0.
	wash_layer.global_position=boat.global_position+Vector3.UP
	wash_layer.volume_db=(-80. if wf<.01 else -30.+sqrt(wf)*18.)-muffled
	wash_layer.pitch_scale=.75+.25*sin(Time.get_ticks_msec()*.0013)+absf(float(boat.roll_rate))*.3
	if not aboard:return
	# Wooden hulls creak as they roll; more in a seaway.
	var hull: Node3D=boat._hull
	var roll: float=hull.rotation.z if is_instance_valid(hull) else 0.
	var roll_rate: float=absf(roll-_last_roll)/maxf(delta,.001);_last_roll=roll
	_creak_clock-=delta*(.4+roll_rate*6.+ocean.weather.energy)
	if _creak_clock<=0.:
		_creak_clock=randf_range(2.5,6.)
		cue_at("creak",boat.global_position+Vector3.UP,-4. if str(boat.hull_model)=="tripo" else 0.)
	# Sails flogging when pointed into the wind.
	if sails and hoisted>.3:
		_flap_clock-=delta
		if boat.sail_speed<.25 and float(boat.sail_rig.fill)<.45 and _flap_clock<=0.:
			_flap_clock=.7;cue_at("flap",boat.global_position+Vector3.UP*4.,-2.)

func _process(_delta: float) -> void:
	if ocean==null: return
	var camera:=ocean.get_viewport().get_camera_3d()
	if camera==null: return
	var p:=camera.global_position
	var waves=preload("res://scripts/world/wave_field.gd")
	var c: Vector4=waves.coast(Vector2(p.x,p.z))
	var muffled: float=10. if ocean.underwater else ocean.cold*3.
	ambient.volume_db=-29.+ocean.weather.energy*7.-muffled
	wind_layer.volume_db=-48.+ocean.weather.wind*29.-muffled
	rain_layer.volume_db=-62.+ocean.weather.rain*42.-muffled
	shore_layer.global_position=Vector3(p.x-c.y*c.x,0,p.z-c.z*c.x)
	shore_layer.volume_db=-25.+ocean.weather.energy*9.-muffled
	hull_layer.global_position=boat.global_position
	hull_layer.volume_db=-34.+ocean.weather.energy*8.+boat.wake_strength*13.-muffled
	hull_layer.pitch_scale=.8+boat.wake_strength*.35
	_boat_sounds(_delta,muffled)
	for player: AudioStreamPlayer3D in [shore_layer,hull_layer,splash_layer,thunder_layer,engine_layer]:
		player.attenuation_filter_cutoff_hz=1200. if ocean.underwater else 8000.

func stop_all() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D: child.stop()

func _noise_sound(seed_value: int, filter: float, duration: float, loop: bool) -> AudioStreamWAV:
	var stream:=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050
	var count:=int(22050.*duration); var data:=PackedByteArray(); data.resize(count*2)
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value; var low:=0.
	for i: int in count:
		var t:=float(i)/22050.; low=lerpf(low,rng.randf_range(-1,1),filter)
		var envelope:=minf(1.,minf(t,duration-t)*8.)
		if not loop: envelope*=exp(-t*2./duration)*(1.+.35*sin(t*27.))
		var gain:=minf(5.,1./sqrt(filter))
		data.encode_s16(i*2,int(clampf(low*gain*envelope*.28,-1.,1.)*32767))
	stream.data=data
	if loop: stream.loop_mode=AudioStreamWAV.LOOP_FORWARD; stream.loop_end=count
	return stream

func cue(kind: String) -> void:
	fx.stream=_stream(kind)
	fx.volume_db=-15.+float(LOUD.get(kind,0.))
	fx.play()

## A one-shot heard from a place in the world (axe blows, hammering, a monster's roar, a harpoon hit).
func cue_at(kind: String,at: Vector3,volume_db: float=0.) -> void:
	var p:=_pool[_pool_next];_pool_next=(_pool_next+1)%_pool.size()
	p.stream=_stream(kind);p.global_position=at;p.volume_db=-12.+float(LOUD.get(kind,0.))+volume_db
	p.max_distance=600. if kind in ["roar","slam","breach"] else 70.
	p.unit_size=40. if kind in ["roar","slam","breach"] else 6.
	p.pitch_scale=randf_range(.93,1.07)
	p.play()

const LOUD: Dictionary={"slap":-1.,"pour":3.,"roar":6.,"slam":5.,"breach":6.,"axe":-2.,"hammer":-4.,"knock":-6.,"net":-3.,"harpoon":0.,"flare":-2.,"boost":-4.,"sink":0.,"mission":-6.,"coins":-8.,"ping":-4.}

func _stream(kind: String) -> AudioStreamWAV:
	if _cues.has(kind):return _cues[kind]
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var seconds: Dictionary={"slap":.55,"pour":1.5,"catch":.41,"chain":1.36,"splash":.64,"horn":1.36,"bite":.18,"roar":2.6,"slam":1.6,"breach":2.4,"axe":.5,"hammer":.25,
		"knock":.3,"creak":.9,"flap":.6,"bell":1.,"net":1.5,"harpoon":.9,"flare":2.2,"boost":1.4,"sink":3.,"mission":1.1,"coins":.5,"ping":1.6}
	var length: int=int(22050.*float(seconds.get(kind,.2)))
	var samples := PackedByteArray()
	samples.resize(length * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77+kind.hash()%1000
	var low := 0.0
	var low2 := 0.0
	var phase := 0.0
	for i in length:
		var t := float(i) / 22050.0
		var value: float
		match kind:
			"chain":
				# Metal links running over the bow roller: a burst of short, bright, slightly detuned clicks.
				var link := fposmod(t, 0.055)
				var ring := sin(t * (2300.0 + sin(t * 3.0) * 400.0) * TAU) * 0.6 + sin(t * 3400.0 * TAU) * 0.4
				value = ring * exp(-link * 120.0) * 0.28 * (1.0 - smoothstep(1.1, 1.36, t))
			"horn":
				# A ship's horn: two detuned low saw-ish tones with a soft attack and release.
				var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(1.05, 1.35, t))
				var a := fposmod(t * 98.0, 1.0) * 2.0 - 1.0
				var b := fposmod(t * 147.5, 1.0) * 2.0 - 1.0
				low = lerpf(low, (a * 0.6 + b * 0.4), 0.2)
				value = low * env * 0.45
			"splash":
				low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.25)
				value = low * exp(-t * 4.5) * 0.55
			"slap":
				# A wave slapping the hull: a hollow wooden thunk with the water's smack and a short hiss.
				var body:=sin(t*TAU*(132.-t*60.))*exp(-t*16.)+sin(t*TAU*263.)*exp(-t*28.)*.35
				low=lerpf(low,rng.randf_range(-1.,1.),.42)
				var smack:=low*exp(-t*22.)
				low2=lerpf(low2,rng.randf_range(-1.,1.),.18)
				value=(body*.75+smack*.6+low2*exp(-t*6.)*.25)*.85
			"pour":
				# Green water coming over the rail: a heavy rush that sloshes and gurgles away.
				low=lerpf(low,rng.randf_range(-1.,1.),.16)
				low2=lerpf(low2,rng.randf_range(-1.,1.),.05)
				var rush:=smoothstep(0.,.06,t)*exp(-t*1.6)
				var gurgle:=sin(t*TAU*(95.+60.*sin(t*17.)))*pow(maxf(0.,sin(t*TAU*6.)),6.)*smoothstep(.2,.5,t)*(1.-smoothstep(1.,1.5,t))
				value=(low*rush*.8+low2*rush*.9+gurgle*.25)*.9
			"roar":
				# A sea monster: a falling, gravelly growl (low saw through noise modulation) with a wet tail.
				var f := lerpf(70.,38.,t/2.6)+sin(t*9.)*6.
				phase+=f/22050.
				var saw:=fposmod(phase,1.)*2.-1.
				low=lerpf(low,rng.randf_range(-1.,1.),.08)
				var grit:=.6+.4*sin(t*31.+sin(t*7.)*3.)
				var env:=smoothstep(0.,.35,t)*(1.-smoothstep(1.9,2.6,t))
				low2=lerpf(low2,saw*grit+low*.7,.18)
				value=low2*env*.75
			"slam","breach":
				# A huge body hitting the water: a deep thump, then rushing spray.
				var thump:=sin(t*TAU*(48.-t*12.))*exp(-t*5.)
				low=lerpf(low,rng.randf_range(-1.,1.),.35 if kind=="slam" else .2)
				var spray:=low*smoothstep(0.,.08,t)*exp(-t*(1.8 if kind=="slam" else 1.2))
				value=(thump*.7+spray*.6)*.8
			"axe":
				# Steel into wood: a sharp crack and a short hollow body resonance.
				low=lerpf(low,rng.randf_range(-1.,1.),.6)
				value=(low*exp(-t*90.)*.9+sin(t*TAU*180.)*exp(-t*22.)*.5+sin(t*TAU*410.)*exp(-t*30.)*.2)*.7
			"hammer","knock":
				var f2:=1250. if kind=="hammer" else 520.
				low=lerpf(low,rng.randf_range(-1.,1.),.5)
				value=(sin(t*TAU*f2)*exp(-t*38.)*.6+low*exp(-t*120.)*.6+sin(t*TAU*f2*1.52)*exp(-t*50.)*.2)*.7
			"net":
				# The cast net: a swoosh through the air, then the lead line patters onto the water.
				low=lerpf(low,rng.randf_range(-1.,1.),.12+.5*smoothstep(0.,.5,t))
				var swoosh:=sin(PI*clampf(t/.55,0.,1.))
				var patter:=float(rng.randf()<.04)*smoothstep(.6,.7,t)*(1.-smoothstep(1.,1.5,t))
				low2=lerpf(low2,rng.randf_range(-1.,1.)*patter,.5)
				value=low*swoosh*.45+low2*.9
			"harpoon":
				# Gas-spring launcher: a thunk, the line paying out with a whir.
				var thunk:=sin(t*TAU*95.)*exp(-t*18.)
				low=lerpf(low,rng.randf_range(-1.,1.),.3)
				var whir:=sin(t*TAU*(600.-t*300.))*.25*smoothstep(.05,.15,t)*(1.-smoothstep(.5,.9,t))
				value=thunk*.8+low*exp(-t*14.)*.4+whir*low*.8
			"flare":
				# Pop, then the hiss of the burning flare fading out.
				low=lerpf(low,rng.randf_range(-1.,1.),.85)
				value=sin(t*TAU*140.)*exp(-t*40.)*.8+low*.35*smoothstep(.03,.15,t)*(1.-smoothstep(1.4,2.2,t))
			"boost":
				# Engine pushed hard: rising pulses.
				var rate:=lerpf(18.,46.,smoothstep(0.,1.,t))
				phase+=rate/22050.
				var pulse:=pow(.5+.5*sin(phase*TAU),3.)
				low=lerpf(low,rng.randf_range(-1.,1.),.25)
				value=(pulse*.6+low*.25)*sin(t*TAU*(70.+rate))*smoothstep(0.,.1,t)*(1.-smoothstep(1.,1.4,t))
			"sink":
				# Water pouring in and big bubbles gurgling up.
				low=lerpf(low,rng.randf_range(-1.,1.),.1)
				var bubble:=sin(t*TAU*(180.+90.*sin(t*13.)))*pow(maxf(0.,sin(t*TAU*3.3)),8.)
				value=(low*.6+bubble*.5)*smoothstep(0.,.3,t)*(1.-smoothstep(2.4,3.,t))
			"mission":
				# Objective done: three rising bell notes.
				var n:=floorf(t/.22);var tt:=t-n*.22
				var fq: float=[523.25,659.25,783.99,1046.5][int(minf(n,3.))]
				value=(sin(tt*TAU*fq)+.3*sin(tt*TAU*fq*2.))*exp(-tt*5.)*.3*(1.-smoothstep(.95,1.1,t))
			"ping":
				# Sonar: a clean high ping with a long underwater echo.
				var e1:=sin(t*TAU*1480.)*exp(-t*9.)
				var e2: float=sin((t-.45)*TAU*1480.)*exp(-maxf(t-.45,0.)*7.)*.35*(1. if t>.45 else 0.)
				value=(e1+e2)*.32
			"bell":
				# A small brass rod bell, shaken by the bending rod: a few bright, ringing strikes.
				var n:=floorf(t/.12);var tt:=t-n*.12
				value=(sin(tt*TAU*2350.)*.6+sin(tt*TAU*3510.)*.3+sin(tt*TAU*5120.)*.1)*exp(-tt*9.)*.32*(1.-smoothstep(.8,1.,t))
			"creak":
				# Wood working against wood: a slow, rubbing, pitch-gliding groan.
				var f:=lerpf(110.,70.,t/.9)+sin(t*21.)*8.
				phase+=f/22050.
				var stick:=pow(.5+.5*sin(t*TAU*23.),6.)
				low=lerpf(low,(fposmod(phase,1.)*2.-1.)*(.4+stick),.12)
				value=low*sin(PI*clampf(t/.9,0.,1.))*.5
			"flap":
				# Loose canvas cracking in the wind: noise bursts at a flutter rate.
				low=lerpf(low,rng.randf_range(-1.,1.),.45)
				value=low*pow(maxf(0.,sin(t*TAU*11.)),4.)*exp(-t*3.)*.9
			"coins":
				var n2:=floorf(t/.07);var tt2:=t-n2*.07
				value=sin(tt2*TAU*(2600.+n2*180.))*exp(-tt2*60.)*.25
			_:
				var freq: float = 660.0 if kind == "bite" else (440.0 + floorf(t * 8.0) * 110.0)
				value = sin(t * freq * TAU) * exp(-t * 6.0) * 0.3
		samples.encode_s16(i * 2, int(clampf(value,-1.,1.) * 32767))
	stream.data = samples
	_cues[kind]=stream
	return stream

func _wave_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var count: int = 22050 * 8
	stream.loop_end = count
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8071
	var low: float = 0.0
	for i in count:
		var t := float(i) / 22050.0
		low = lerpf(low, rng.randf_range(-1, 1), 0.08)
		var swell := 0.55 + 0.35 * sin(t * TAU / 4.0)
		var fade := minf(1.0, minf(t, 8.0-t) * 4.0)
		data.encode_s16(i * 2, int(low * swell * fade * 26000))
	stream.data = data
	return stream

## Marine diesel at idle: firing pulses with a low hull resonance and a little exhaust noise. Pitch
## scaling (engine_layer.pitch_scale) turns it into higher revs.
func _engine_sound() -> AudioStreamWAV:
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var count: int=22050*2;var data:=PackedByteArray();data.resize(count*2)
	var rng:=RandomNumberGenerator.new();rng.seed=909;var low:=0.;var body:=0.
	for i: int in count:
		var t:=float(i)/22050.
		var fire:=pow(.5+.5*sin(t*TAU*24.),5.)
		low=lerpf(low,rng.randf_range(-1.,1.),.3)
		body=lerpf(body,sin(t*TAU*48.)*.6+sin(t*TAU*72.)*.3+low*.3,.25)
		data.encode_s16(i*2,int(clampf((body*(.4+fire*.8))*.45,-1.,1.)*32767))
	stream.data=data;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=count
	return stream
