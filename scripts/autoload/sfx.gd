extends Node
## Procedurally synthesised sound bank. Every sound is generated at startup from
## code, so the game ships no third-party audio and has no licensing concerns.

const RATE := 22050

var streams := {}
var world: Node3D
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	streams["ar_fire"] = _gunshot(rng, 0.3, 5200.0, 95.0, 0.09)
	streams["sniper_fire"] = _gunshot(rng, 1.2, 3600.0, 58.0, 0.34)
	streams["bot_fire"] = _gunshot(rng, 0.32, 3000.0, 80.0, 0.1)
	streams["reload"] = _reload(rng)
	streams["bolt"] = _bolt(rng)
	streams["switch"] = _switch(rng)
	streams["dry"] = _click(rng, 0.05, 0.0)
	for i in 3:
		streams["step%d" % i] = _footstep(rng)
	streams["impact"] = _impact(rng)
	streams["hit"] = _tone([1900.0], 0.06, 0.5, 45.0)
	streams["headshot"] = _tone([2400.0, 3300.0], 0.14, 0.45, 22.0)
	streams["kill"] = _tone([880.0, 1320.0], 0.26, 0.4, 9.0)
	streams["hurt"] = _hurt(rng)
	streams["death"] = _death()
	streams["ui_hover"] = _tone([1150.0], 0.05, 0.22, 60.0)
	streams["ui_click"] = _tone([700.0, 1400.0], 0.1, 0.35, 30.0)
	streams["ambient_wind"] = _wind(rng, 6.0, 500.0)
	streams["ambient_indoor"] = _indoor(rng, 6.0)
	streams["music"] = _music_loop()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "SFX"
	_ambient.volume_db = -12.0
	add_child(_ambient)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, max_distance := 90.0) -> void:
	if not streams.has(sound):
		return
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		play(sound, volume_db - 6.0, pitch)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.unit_size = 7.0
	world.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func music(on: bool) -> void:
	if on and not _music.playing:
		_music.stream = streams["music"]
		_music.play()
	elif not on:
		_music.stop()


func ambient(sound: String) -> void:
	if sound == "" or not streams.has(sound):
		_ambient.stop()
		return
	if _ambient.stream != streams[sound] or not _ambient.playing:
		_ambient.stream = streams[sound]
		_ambient.play()


# ---------------------------------------------------------------- synthesis

func _make(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _buf(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


func _gunshot(rng: RandomNumberGenerator, length: float, bright: float, thump_hz: float, tail: float) -> AudioStreamWAV:
	var out := _buf(length)
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var cutoff := bright * exp(-t * 16.0) + 250.0
		var a := clampf(cutoff / RATE * TAU, 0.0, 1.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		lp2 += (lp - lp2) * a
		phase += TAU * thump_hz * (1.0 + 2.5 * exp(-t * 40.0)) / RATE
		var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.7
		var body := lp2 * 2.2 * (exp(-t * 9.0) * 0.7 + exp(-t / tail) * 0.3)
		var thump := sin(phase) * exp(-t * 22.0) * 0.9
		out[i] = (crack + body + thump) * 0.8
	return _make(out)


func _click(rng: RandomNumberGenerator, length: float, offset: float) -> AudioStreamWAV:
	var out := _buf(length + offset)
	_add_click(out, rng, offset, 0.6)
	return _make(out)


func _add_click(out: PackedFloat32Array, rng: RandomNumberGenerator, at: float, vol: float) -> void:
	var start := int(at * RATE)
	var n := int(0.03 * RATE)
	var hp := 0.0
	var prev := 0.0
	for j in n:
		var i := start + j
		if i >= out.size():
			break
		var t := float(j) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + x - prev)
		prev = x
		out[i] += (hp * 0.8 + sin(t * TAU * 3200.0) * 0.4) * exp(-t * 260.0) * vol


func _add_slide(out: PackedFloat32Array, rng: RandomNumberGenerator, at: float, dur: float, vol: float) -> void:
	var start := int(at * RATE)
	var lp := 0.0
	for j in int(dur * RATE):
		var i := start + j
		if i >= out.size():
			break
		var t := float(j) / (dur * RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		out[i] += lp * sin(t * PI) * vol


func _reload(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(1.1)
	_add_slide(out, rng, 0.05, 0.15, 0.25)
	_add_click(out, rng, 0.22, 0.7)
	_add_slide(out, rng, 0.45, 0.12, 0.2)
	_add_click(out, rng, 0.62, 0.9)
	_add_click(out, rng, 0.9, 0.8)
	return _make(out)


func _bolt(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(0.55)
	_add_click(out, rng, 0.0, 0.7)
	_add_slide(out, rng, 0.05, 0.14, 0.3)
	_add_slide(out, rng, 0.25, 0.14, 0.3)
	_add_click(out, rng, 0.42, 0.9)
	return _make(out)


func _switch(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(0.35)
	_add_slide(out, rng, 0.0, 0.2, 0.3)
	_add_click(out, rng, 0.22, 0.6)
	return _make(out)


func _footstep(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(0.16)
	var lp := 0.0
	var f := rng.randf_range(0.08, 0.14)
	for i in out.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * f
		out[i] = (lp * 3.0 + sin(t * TAU * 70.0) * 0.4) * exp(-t * 30.0)
	return _make(out)


func _impact(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(0.12)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.6
	return _make(out)


func _tone(freqs: Array, length: float, vol: float, decay: float) -> AudioStreamWAV:
	var out := _buf(length)
	var seg := out.size() / freqs.size()
	var phase := 0.0
	for i in out.size():
		var k := mini(i / maxi(seg, 1), freqs.size() - 1)
		var t := float(i - k * seg) / RATE
		phase += TAU * float(freqs[k]) / RATE
		out[i] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.15) * exp(-t * decay) * vol
	return _make(out)


func _hurt(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var out := _buf(0.25)
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.1
		out[i] = (sin(t * TAU * 90.0) * 0.6 + lp * 1.5) * exp(-t * 14.0)
	return _make(out)


func _death() -> AudioStreamWAV:
	var out := _buf(0.6)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (420.0 - t * 500.0) / RATE
		out[i] = sin(phase) * exp(-t * 5.0) * 0.4
	return _make(out)


func _loopify(raw: PackedFloat32Array, fade_samples: int) -> PackedFloat32Array:
	# raw has fade_samples extra at the end; crossfade them into the start.
	var n := raw.size() - fade_samples
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade_samples:
		var w := float(i) / fade_samples
		out[i] = raw[i] * w + raw[n + i] * (1.0 - w)
	return out


func _wind(rng: RandomNumberGenerator, seconds: float, cutoff: float) -> AudioStreamWAV:
	var fade := int(0.5 * RATE)
	var raw := _buf(seconds + 0.5)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * sin(t * TAU / seconds) * sin(t * TAU * 2.0 / seconds + 1.0)
		var a := (cutoff * (0.6 + gust * 0.6)) / RATE * TAU
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		lp2 += (lp - lp2) * a
		raw[i] = lp2 * 3.0 * gust
	return _make(_loopify(raw, fade), true)


func _indoor(rng: RandomNumberGenerator, seconds: float) -> AudioStreamWAV:
	var fade := int(0.5 * RATE)
	var raw := _buf(seconds + 0.5)
	var lp := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		var hum := sin(t * TAU * 60.0) * 0.12 + sin(t * TAU * 120.0) * 0.05
		raw[i] = lp * 4.0 + hum
	return _make(_loopify(raw, fade), true)


func _music_loop() -> AudioStreamWAV:
	# 120 BPM, 16 beats: Am - F - C - G with kick, snare, hats, bass and a soft pad.
	var beat := 0.5
	var out := _buf(beat * 16.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var roots := [110.0, 87.31, 130.81, 98.0]
	var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
	var bass_phase := 0.0
	var pad_phase := [0.0, 0.0, 0.0]
	for i in out.size():
		var t := float(i) / RATE
		var bar := mini(int(t / (beat * 4.0)), 3)
		var bt := fmod(t, beat)
		var beat_idx := int(t / beat)
		var kick := sin(TAU * (50.0 + 90.0 * exp(-bt * 30.0)) * bt) * exp(-bt * 9.0)
		var snare := 0.0
		if beat_idx % 2 == 1:
			snare = rng.randf_range(-1.0, 1.0) * exp(-bt * 18.0) * 0.35
		var et := fmod(t, beat * 0.5)
		var hat := rng.randf_range(-1.0, 1.0) * exp(-et * 90.0) * 0.08
		bass_phase += TAU * float(roots[bar]) / RATE
		var bass := (sin(bass_phase) + 0.3 * sin(bass_phase * 2.0)) * (0.6 + 0.4 * exp(-et * 8.0)) * 0.35
		var pad := 0.0
		var chord: Array = chords[bar]
		for k in 3:
			pad_phase[k] = float(pad_phase[k]) + TAU * float(chord[k]) / RATE
			pad += sin(float(pad_phase[k])) * 0.06
		out[i] = (kick * 0.55 + snare + hat + bass + pad) * 0.6
	return _make(out, true)
