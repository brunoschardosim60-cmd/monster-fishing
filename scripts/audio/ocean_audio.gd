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

func _ready() -> void:
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
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var length: int = 9000 if kind == "catch" else (30000 if kind == "chain" else (14000 if kind == "splash" else (30000 if kind == "horn" else 4000)))
	samples.resize(length * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var low := 0.0
	for i in length:
		var t := float(i) / 22050.0
		var value: float
		if kind == "chain":
			# Metal links running over the bow roller: a burst of short, bright, slightly detuned clicks.
			var link := fposmod(t, 0.055)
			var ring := sin(t * (2300.0 + sin(t * 3.0) * 400.0) * TAU) * 0.6 + sin(t * 3400.0 * TAU) * 0.4
			value = ring * exp(-link * 120.0) * 0.28 * (1.0 - smoothstep(1.1, 1.36, t))
		elif kind == "horn":
			# A ship's horn: two detuned low saw-ish tones with a soft attack and release.
			var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(1.05, 1.35, t))
			var a := fposmod(t * 98.0, 1.0) * 2.0 - 1.0
			var b := fposmod(t * 147.5, 1.0) * 2.0 - 1.0
			low = lerpf(low, (a * 0.6 + b * 0.4), 0.2)
			value = low * env * 0.45
		elif kind == "splash":
			low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.25)
			value = low * exp(-t * 4.5) * 0.55
		else:
			var freq: float = 660.0 if kind == "bite" else (440.0 + floorf(t * 8.0) * 110.0)
			value = sin(t * freq * TAU) * exp(-t * 6.0) * 0.3
		samples.encode_s16(i * 2, int(value * 32767))
	stream.data = samples
	fx.stream = stream
	fx.play()

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
