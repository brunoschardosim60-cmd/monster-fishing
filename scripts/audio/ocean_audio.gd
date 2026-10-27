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
	for player: AudioStreamPlayer3D in [shore_layer,hull_layer,splash_layer,thunder_layer]:
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

const LOUD: Dictionary={"roar":6.,"slam":5.,"breach":6.,"axe":-2.,"hammer":-4.,"knock":-6.,"net":-3.,"harpoon":0.,"flare":-2.,"boost":-4.,"sink":0.,"mission":-6.,"coins":-8.,"ping":-4.}

func _stream(kind: String) -> AudioStreamWAV:
	if _cues.has(kind):return _cues[kind]
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var seconds: Dictionary={"catch":.41,"chain":1.36,"splash":.64,"horn":1.36,"bite":.18,"roar":2.6,"slam":1.6,"breach":2.4,"axe":.5,"hammer":.25,
		"knock":.3,"net":1.5,"harpoon":.9,"flare":2.2,"boost":1.4,"sink":3.,"mission":1.1,"coins":.5,"ping":1.6}
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
