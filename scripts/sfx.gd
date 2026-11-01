extends Node
## All sound effects and music are synthesized here at startup (no external audio files, no license risk).
## Autoload "Sfx". Sfx.play("splash", world_pos)

const RATE := 22050
var sounds := {}  # name -> Array[AudioStreamWAV] (variants)
var pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var pitch_scale := 1.0  # global (slow-mo replay lowers it)
var enabled := true
var _thread: Thread
var _music_stream: AudioStreamWAV
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	for i in 20:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -6.0
	add_child(music_player)
	build_all()
	_thread = Thread.new()
	_thread.start(_build_music_thread)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func play(name: String, pos = null, vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled or not sounds.has(name):
		return
	var att := 0.0
	if pos is Vector3:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var d: float = cam.global_position.distance_to(pos)
			att = -clampf((d - 10.0) * 0.9, 0.0, 30.0)
	var p: AudioStreamPlayer = null
	for cand in pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = pool[_rng.randi() % pool.size()]
	var variants: Array = sounds[name]
	p.stream = variants[_rng.randi() % variants.size()]
	p.volume_db = vol_db + att
	p.pitch_scale = maxf(0.05, pitch * pitch_scale * _rng.randf_range(0.94, 1.06))
	p.play()


func play_music() -> void:
	if not enabled or music_player == null:
		return
	if _music_stream == null:
		if _thread and _thread.is_started() and not _thread.is_alive():
			_thread.wait_to_finish()
		if _music_stream == null:
			get_tree().create_timer(0.5).timeout.connect(play_music)
			return
	if not music_player.playing:
		music_player.stream = _music_stream
		music_player.play()


func stop_music() -> void:
	if music_player:
		music_player.stop()


# ---------------------------------------------------------------- synthesis

func build_all() -> void:
	_rng.seed = 1234
	sounds["slip"] = [_slip(0), _slip(1)]
	sounds["thud"] = [_thud()]
	sounds["splash"] = [_splash()]
	sounds["paint"] = [_splat()]
	sounds["pop"] = [_pop()]
	sounds["flour"] = [_poof()]
	sounds["fart"] = [_fart(0), _fart(1), _fart(2)]
	sounds["punch"] = [_punch()]
	sounds["boing"] = [_boing()]
	sounds["marbles"] = [_marbles()]
	sounds["confetti"] = [_confetti()]
	sounds["alarm"] = [_alarm()]
	sounds["yell"] = [_yell(1.0), _yell(1.25), _yell(0.8), _yell(1.5)]
	sounds["task"] = [_ding()]
	sounds["chain"] = [_arp([523.0, 659.0, 784.0, 1047.0], 0.07)]
	sounds["win"] = [_arp([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0], 0.13)]
	sounds["place"] = [_plop()]
	sounds["click"] = [_tick(1400.0, 0.03)]
	sounds["tick"] = [_tick(1000.0, 0.06)]
	sounds["go"] = [_horn()]
	sounds["uhoh"] = [_uhoh()]
	sounds["whoosh"] = [_whoosh()]
	sounds["tape"] = [_squelch()]
	sounds["disarm"] = [_arp([784.0, 523.0], 0.08)]
	sounds["meow"] = [_meow(1.0), _meow(1.2)]
	sounds["doorbell"] = [_doorbell()]
	sounds["ding_pu"] = [_arp([1047.0, 1319.0, 1568.0], 0.05)]


func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


func _to_wav(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	var peak := 0.001
	for v in b:
		peak = maxf(peak, absf(v))
	var g := 0.9 / peak if peak > 0.9 else 1.0
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = b.size()
	return w


func _wave(phase: float, kind: int) -> float:
	# 0 sine, 1 square, 2 saw, 3 triangle
	var p := fposmod(phase, 1.0)
	match kind:
		1: return 1.0 if p < 0.5 else -1.0
		2: return 2.0 * p - 1.0
		3: return 4.0 * absf(p - 0.5) - 1.0
	return sin(p * TAU)


## Adds an oscillator sweeping f0->f1 with exponential decay.
func _osc(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, kind: int, vol: float, decay := 4.0, vib_hz := 0.0, vib_amt := 0.0) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if vib_hz > 0.0:
			f *= 1.0 + vib_amt * sin(TAU * vib_hz * i / RATE)
		phase += f / RATE
		var env := minf(1.0, i / (0.004 * RATE)) * exp(-decay * t)
		b[idx] += _wave(phase, kind) * vol * env


func _noise(b: PackedFloat32Array, start: float, dur: float, vol: float, lp0 := 0.5, lp1 := 0.5, decay := 4.0) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var a := lerpf(lp0, lp1, t)
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		var env := minf(1.0, i / (0.003 * RATE)) * exp(-decay * t)
		b[idx] += y * vol * env


func _slip(v: int) -> AudioStreamWAV:
	var b := _buf(0.55)
	_osc(b, 0.0, 0.3, 1300.0 - v * 200, 250.0, 0, 0.5, 1.5)
	_noise(b, 0.0, 0.3, 0.25, 0.3, 0.1, 2.0)
	_osc(b, 0.3, 0.2, 110.0, 50.0, 0, 0.9, 5.0)
	_noise(b, 0.3, 0.15, 0.4, 0.2, 0.05, 6.0)
	return _to_wav(b)


func _thud() -> AudioStreamWAV:
	var b := _buf(0.25)
	_osc(b, 0.0, 0.25, 120.0, 45.0, 0, 1.0, 6.0)
	_noise(b, 0.0, 0.1, 0.4, 0.15, 0.05, 8.0)
	return _to_wav(b)


func _splash() -> AudioStreamWAV:
	var b := _buf(0.9)
	_noise(b, 0.0, 0.9, 0.9, 0.9, 0.2, 3.5)
	for i in 10:
		var st := _rng.randf_range(0.05, 0.6)
		var f := _rng.randf_range(500.0, 1400.0)
		_osc(b, st, 0.06, f, f * 1.6, 0, 0.2, 3.0)
	return _to_wav(b)


func _splat() -> AudioStreamWAV:
	var b := _buf(0.45)
	_osc(b, 0.0, 0.12, 220.0, 70.0, 0, 0.9, 4.0)
	_noise(b, 0.0, 0.4, 0.8, 0.6, 0.08, 5.0)
	return _to_wav(b)


func _pop() -> AudioStreamWAV:
	var b := _buf(0.12)
	_osc(b, 0.0, 0.12, 700.0, 150.0, 0, 1.0, 6.0)
	return _to_wav(b)


func _poof() -> AudioStreamWAV:
	var b := _buf(0.7)
	_noise(b, 0.0, 0.7, 1.0, 0.25, 0.03, 3.0)
	_osc(b, 0.0, 0.15, 160.0, 60.0, 0, 0.6, 5.0)
	return _to_wav(b)


func _fart(v: int) -> AudioStreamWAV:
	var dur := 0.7 + v * 0.25
	var b := _buf(dur)
	var phase := 0.0
	var f := 95.0 + v * 12.0
	var y := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		f = clampf(f + _rng.randf_range(-3.0, 3.0), 55.0, 150.0)
		var flutter := 0.6 + 0.4 * sin(TAU * (18.0 + v * 5.0) * i / RATE)
		phase += f * (1.0 - 0.35 * t) / RATE
		var raw := _wave(phase, 1) * 0.6 + _wave(phase * 2.0, 2) * 0.3 + _rng.randf_range(-0.3, 0.3)
		y += 0.35 * (raw - y)
		var env := minf(1.0, i / (0.02 * RATE)) * (1.0 - pow(t, 3.0))
		b[i] = y * flutter * env
	return _to_wav(b)


func _punch() -> AudioStreamWAV:
	var b := _buf(0.5)
	_noise(b, 0.0, 0.12, 1.0, 0.7, 0.2, 6.0)
	_osc(b, 0.0, 0.2, 160.0, 50.0, 0, 1.0, 5.0)
	_osc(b, 0.08, 0.4, 300.0, 600.0, 0, 0.3, 3.0, 14.0, 0.2)
	return _to_wav(b)


func _boing() -> AudioStreamWAV:
	var b := _buf(0.8)
	_osc(b, 0.0, 0.8, 180.0, 520.0, 0, 0.9, 2.5, 13.0, 0.35)
	_osc(b, 0.0, 0.8, 360.0, 1040.0, 3, 0.2, 3.0, 13.0, 0.35)
	return _to_wav(b)


func _marbles() -> AudioStreamWAV:
	var b := _buf(1.3)
	for i in 45:
		var st := pow(_rng.randf(), 1.6) * 1.2
		var f := _rng.randf_range(2500.0, 5000.0)
		_osc(b, st, 0.025, f, f * 0.9, 0, _rng.randf_range(0.2, 0.5), 8.0)
	return _to_wav(b)


func _confetti() -> AudioStreamWAV:
	var b := _buf(1.0)
	_noise(b, 0.0, 0.08, 1.0, 0.9, 0.5, 5.0)
	_osc(b, 0.0, 0.1, 400.0, 120.0, 0, 0.8, 5.0)
	for i in 30:
		var st := _rng.randf_range(0.05, 0.9)
		_noise(b, st, 0.01, 0.4, 0.9, 0.9, 1.0)
	_osc(b, 0.1, 0.6, 520.0, 470.0, 1, 0.12, 1.0, 9.0, 0.05)
	return _to_wav(b)


func _alarm() -> AudioStreamWAV:
	var b := _buf(1.0)
	var phase := 0.0
	for i in b.size():
		phase += 1250.0 / RATE
		var gate := 1.0 if fmod(float(i) / RATE, 0.1) < 0.05 else 0.0
		b[i] = _wave(phase, 1) * 0.35 * gate
	return _to_wav(b, true)


## Cartoon "aaah" with two vowel formants.
func _yell(pitch: float) -> AudioStreamWAV:
	var dur := 0.75
	var b := _buf(dur)
	var phase := 0.0
	var bp1 := _bp_coef(800.0 * sqrt(pitch), 6.0)
	var bp2 := _bp_coef(1250.0 * sqrt(pitch), 7.0)
	var s1 := [0.0, 0.0, 0.0, 0.0]
	var s2 := [0.0, 0.0, 0.0, 0.0]
	for i in b.size():
		var t := float(i) / b.size()
		var f := lerpf(330.0, 200.0, t) * pitch * (1.0 + 0.04 * sin(TAU * 6.5 * i / RATE))
		phase += f / RATE
		var x := _wave(phase, 2)
		var y1 := _biquad(bp1, s1, x)
		var y2 := _biquad(bp2, s2, x)
		var env := minf(1.0, i / (0.03 * RATE)) * (1.0 - pow(t, 2.0))
		b[i] = (y1 + 0.7 * y2) * env
	return _to_wav(b)


func _bp_coef(f: float, q: float) -> Array:
	var w := TAU * f / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	return [alpha / a0, 0.0, -alpha / a0, -2.0 * cos(w) / a0, (1.0 - alpha) / a0]


func _biquad(c: Array, s: Array, x: float) -> float:
	# s = [x1, x2, y1, y2]
	var y: float = c[0] * x + c[1] * s[0] + c[2] * s[1] - c[3] * s[2] - c[4] * s[3]
	s[1] = s[0]
	s[0] = x
	s[3] = s[2]
	s[2] = y
	return y


func _ding() -> AudioStreamWAV:
	var b := _buf(0.6)
	_osc(b, 0.0, 0.5, 880.0, 880.0, 0, 0.6, 4.0)
	_osc(b, 0.1, 0.5, 1320.0, 1320.0, 0, 0.6, 4.0)
	return _to_wav(b)


func _arp(notes: Array, step: float) -> AudioStreamWAV:
	var b := _buf(step * notes.size() + 0.35)
	for i in notes.size():
		_osc(b, i * step, 0.35, notes[i], notes[i], 1, 0.25, 4.0)
		_osc(b, i * step, 0.35, notes[i] * 2.0, notes[i] * 2.0, 0, 0.15, 5.0)
	return _to_wav(b)


func _plop() -> AudioStreamWAV:
	var b := _buf(0.15)
	_osc(b, 0.0, 0.15, 260.0, 620.0, 0, 0.8, 5.0)
	return _to_wav(b)


func _tick(f: float, d: float) -> AudioStreamWAV:
	var b := _buf(d)
	_osc(b, 0.0, d, f, f, 1, 0.3, 6.0)
	return _to_wav(b)


func _horn() -> AudioStreamWAV:
	var b := _buf(0.7)
	_osc(b, 0.0, 0.25, 523.0, 523.0, 2, 0.35, 1.0)
	_osc(b, 0.25, 0.45, 784.0, 784.0, 2, 0.35, 2.0)
	return _to_wav(b)


func _uhoh() -> AudioStreamWAV:
	var b := _buf(0.55)
	_osc(b, 0.0, 0.2, 520.0, 500.0, 3, 0.6, 1.0)
	_osc(b, 0.24, 0.3, 400.0, 360.0, 3, 0.6, 2.0)
	return _to_wav(b)


func _whoosh() -> AudioStreamWAV:
	var b := _buf(0.4)
	_noise(b, 0.0, 0.4, 0.8, 0.05, 0.5, 2.0)
	return _to_wav(b)


func _squelch() -> AudioStreamWAV:
	var b := _buf(0.5)
	_noise(b, 0.0, 0.5, 0.8, 0.1, 0.3, 3.0)
	_osc(b, 0.0, 0.5, 90.0, 140.0, 2, 0.4, 2.0, 20.0, 0.3)
	return _to_wav(b)


func _meow(pitch: float) -> AudioStreamWAV:
	var b := _buf(0.6)
	var phase := 0.0
	var bp := _bp_coef(1400.0 * pitch, 3.0)
	var st := [0.0, 0.0, 0.0, 0.0]
	for i in b.size():
		var t := float(i) / b.size()
		var f := (520.0 + 380.0 * sin(t * PI)) * pitch
		phase += f / RATE
		var x := _wave(phase, 2)
		var env := minf(1.0, i / (0.03 * RATE)) * (1.0 - t)
		b[i] = (_biquad(bp, st, x) * 1.5 + x * 0.15) * env
	return _to_wav(b)


func _doorbell() -> AudioStreamWAV:
	var b := _buf(1.3)
	_osc(b, 0.0, 0.7, 659.0, 659.0, 0, 0.6, 2.5)
	_osc(b, 0.45, 0.85, 523.0, 523.0, 0, 0.6, 2.5)
	return _to_wav(b)


# ---------------------------------------------------------------- music

func _build_music_thread() -> void:
	_music_stream = build_music()


## 8-bar bouncy loop (I-vi-IV-V), 124 BPM. Deterministic.
func build_music() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bpm := 124.0
	var beat := 60.0 / bpm
	var bars := 8
	var b := _buf(beat * 4.0 * bars)
	var chords := [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
	var scale := [60, 62, 64, 67, 69, 72, 74, 76]
	for bar in bars:
		var ch: Array = chords[bar % 4]
		var t0 := bar * 4.0 * beat
		for q in 4:
			var tb := t0 + q * beat
			# bass: root on beats, octave bounce on off-beats
			_osc(b, tb, beat * 0.45, _midi(ch[0] - 24), _midi(ch[0] - 24), 3, 0.32, 3.0)
			_osc(b, tb + beat * 0.5, beat * 0.4, _midi(ch[0] - 12), _midi(ch[0] - 12), 3, 0.22, 3.0)
			# kick / snare / hats
			if q % 2 == 0:
				_osc(b, tb, 0.12, 140.0, 45.0, 0, 0.5, 5.0)
			else:
				_noise(b, tb, 0.12, 0.18, 0.6, 0.4, 6.0)
			_noise(b, tb + beat * 0.5, 0.03, 0.06, 0.95, 0.95, 5.0)
			# chord stab on off-beat
			for n in ch:
				_osc(b, tb + beat * 0.5, beat * 0.3, _midi(n), _midi(n), 1, 0.035, 5.0)
		# melody: 8 eighth notes per bar, some rests
		for e in 8:
			if rng.randf() < 0.3:
				continue
			var note: int = scale[rng.randi() % scale.size()]
			if e == 0:
				note = ch[0] + 12
			_osc(b, t0 + e * beat * 0.5, beat * 0.42, _midi(note), _midi(note), 1, 0.07, 3.5)
			_osc(b, t0 + e * beat * 0.5, beat * 0.42, _midi(note + 12), _midi(note + 12), 0, 0.04, 4.0)
	return _to_wav(b, true)


func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)
