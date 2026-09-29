extends Node
## Autoload: sound effects + looping music, synthesized in code (no asset files).
## Mute flags live in Save. To use real assets later, replace streams with load("res://...").

const MIX_RATE := 22050
const MUSIC_VOLUME_DB := -14.0

var _players := {}
var _music := AudioStreamPlayer.new()
var _music_task := -1
var _calm: AudioStreamWAV
var _sad: AudioStreamWAV
var _sad_on := false


func _ready() -> void:
	var streams := {
		"hit": make_hit(), "miss": make_miss(), "new_level": make_new_level(),
		"level_up": make_level_up(), "game_over": make_game_over(), "click": make_click(),
	}
	for sound_name in streams:
		var player := AudioStreamPlayer.new()
		player.stream = streams[sound_name]
		player.max_polyphony = 3
		add_child(player)
		_players[sound_name] = player
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	# Music takes a moment to synthesize; do it off the main thread so startup stays instant.
	_music_task = WorkerThreadPool.add_task(func(): _set_music_streams.call_deferred(make_music(), make_sad_music()))


func _exit_tree() -> void:
	# Godot requires every pool task to be waited on; otherwise it aborts on quit.
	if _music_task != -1:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func play(sound_name: String) -> void:
	if Save.sound_enabled:
		_players[sound_name].play()


## Starts or stops music to match Save.music_enabled.
func update_music() -> void:
	if not Save.music_enabled:
		_music.stop()
	elif _music.stream and not _music.playing:
		_music.play()


## Swaps to the sad loop (after a failed level) or back to the calm one; restarts from the top.
func set_sad(on: bool) -> void:
	_sad_on = on
	var stream := _sad if on else _calm
	if stream == null or _music.stream == stream:
		return
	_music.stop()
	_music.stream = stream
	update_music()


func _set_music_streams(calm: AudioStreamWAV, sad: AudioStreamWAV) -> void:
	_calm = calm
	_sad = sad
	_music.stream = _sad if _sad_on else _calm
	update_music()


# --- Synthesis ---

## Diamond found: bright sparkly arpeggio E6-G#6-B6-E7, ~0.35s.
static func make_hit() -> AudioStreamWAV:
	var notes := [1318.5, 1661.2, 1975.5, 2637.0]
	var step := 0.05
	return _to_wav(_tone(0.35, func(t):
		var v := 0.0
		for k in notes.size():
			var dt: float = t - k * step
			if dt >= 0.0:
				v += sin(TAU * notes[k] * dt) * exp(-dt * 14.0)
		return v * 0.22))


## Miss: dull downward thud, ~0.25s.
static func make_miss() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.25)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(220.0, 90.0, t / 0.25) / MIX_RATE
		samples[i] = (_tri(phase / TAU) * 0.7 + _square(phase / TAU) * 0.2) * minf(t / 0.005, 1.0) * exp(-t * 12.0) * 0.5
	return _to_wav(samples)


## Level start: rising sweep, ~0.3s.
static func make_new_level() -> AudioStreamWAV:
	return _to_wav(_sweep(0.3, 300.0, 1100.0, 0.35))


## Level passed: quick rising fanfare G4-C5-E5-G5, then a ringing C major chord, ~0.9s.
static func make_level_up() -> AudioStreamWAV:
	var run := [392.0, 523.3, 659.3, 784.0]
	var step := 0.08
	var chord := [523.3, 659.3, 784.0, 1046.5]
	var chord_at := run.size() * step
	return _to_wav(_normalized(_tone(0.9, func(t):
		var v := 0.0
		if t < chord_at:
			var k := int(t / step)
			var dt: float = t - k * step
			v = (_tri(run[k] * t) * 0.8 + _square(run[k] * t) * 0.2) * minf(dt / 0.005, 1.0) * exp(-dt * 10.0)
		else:
			var dt: float = t - chord_at
			for f in chord:
				v += (_tri(f * t) * 0.8 + _square(f * t) * 0.12) * exp(-dt * 3.5) * 0.35
		return v), 0.6))


## Level failed: three descending sad notes with vibrato, ~1s.
static func make_game_over() -> AudioStreamWAV:
	var notes := [392.0, 329.6, 261.6]
	var note_len := 0.3
	return _to_wav(_tone(0.95, func(t):
		var k := mini(int(t / note_len), notes.size() - 1)
		var dt: float = t - k * note_len
		var f: float = notes[k] * (1.0 + 0.012 * sin(TAU * 6.0 * t))
		var env := minf(dt / 0.01, 1.0) * exp(-dt * (2.0 if k == notes.size() - 1 else 5.0))
		return (_tri(f * t) * 0.7 + _square(f * t) * 0.15) * env * 0.4))


## Button click: very short high tick, ~15ms.
static func make_click() -> AudioStreamWAV:
	return _to_wav(_tone(0.015, func(t): return sin(TAU * 1200.0 * t) * exp(-t * 300.0) * 0.4))


## Background loop: 8 bars C major (C Am F G x2) at 100 bpm, ~19s. Calm, for concentrating.
static func make_music() -> AudioStreamWAV:
	return _make_loop([[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]], 100.0)  # MIDI: C Am F G


## Fail loop: 8 bars A minor (Am Dm E Am x2) at 70 bpm, ~27s. Slow and gloomy.
static func make_sad_music() -> AudioStreamWAV:
	return _make_loop([[57, 60, 64], [50, 53, 57], [52, 56, 59], [57, 60, 64]], 70.0)  # MIDI: Am Dm E Am


## Soft triangle arpeggio in eighths + sine bass on half notes over 4 chords, played twice.
static func _make_loop(chords: Array, bpm: float) -> AudioStreamWAV:
	var eighth := 60.0 / bpm / 2.0
	var pattern := [0, 1, 2, 1, 2, 1, 0, 1]
	var bars := 8
	var slot_n := int(eighth * MIX_RATE)
	var n := slot_n * 8 * bars
	var samples := PackedFloat32Array()
	samples.resize(n)
	for bar in bars:
		var chord: Array = chords[bar % 4]
		var octave := 12 if bar >= 4 else 0  # second pass: arpeggio an octave up
		var bass := _midi_hz(chord[0] - 24)
		for slot in 8:
			var start := (bar * 8 + slot) * slot_n
			var lead := _midi_hz(chord[pattern[slot]] + octave)
			for i in slot_n:
				var t := float(i) / MIX_RATE
				var abs_t := float(start + i) / MIX_RATE
				var bass_t := t + (slot % 4) * eighth  # bass note restarts every half bar
				samples[start + i] = _tri(lead * abs_t) * exp(-t * 5.0) * 0.28 \
					+ sin(TAU * bass * abs_t) * exp(-bass_t * 1.5) * 0.3
	var wav := _to_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


# --- Helpers ---

static func _midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## Triangle / square waves from cycles elapsed (freq * t).
static func _tri(cycles: float) -> float:
	return 4.0 * absf(fposmod(cycles, 1.0) - 0.5) - 1.0


static func _square(cycles: float) -> float:
	return 1.0 if fposmod(cycles, 1.0) < 0.5 else -1.0


## Samples f(t) for `duration` seconds.
static func _tone(duration: float, f: Callable) -> PackedFloat32Array:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		samples[i] = f.call(float(i) / MIX_RATE)
	return samples


## Sine sweep from f0 to f1 with a smooth fade in/out.
static func _sweep(duration: float, f0: float, f1: float, volume: float) -> PackedFloat32Array:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k * k) / MIX_RATE
		samples[i] = sin(phase) * sin(PI * k) * volume
	return samples


static func _normalized(samples: PackedFloat32Array, peak_target: float) -> PackedFloat32Array:
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	for i in samples.size():
		samples[i] *= peak_target / peak
	return samples


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
