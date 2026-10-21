extends Node
## Original synthesized ambience; no downloaded audio or external services.
var ambient: AudioStreamPlayer
var fx: AudioStreamPlayer

func _ready() -> void:
	ambient = AudioStreamPlayer.new()
	ambient.stream = _wave_sound()
	ambient.volume_db = -24.0
	add_child(ambient)
	ambient.play()
	fx = AudioStreamPlayer.new()
	fx.volume_db = -15.0
	add_child(fx)

func cue(kind: String) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var length: int = 9000 if kind == "catch" else 4000
	samples.resize(length * 2)
	for i in length:
		var t := float(i) / 22050.0
		var freq: float = 660.0 if kind == "bite" else (440.0 + floorf(t * 8.0) * 110.0)
		var value := sin(t * freq * TAU) * exp(-t * 6.0) * 0.3
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
