extends Node
## Audio autoload: maps gameplay events to short SYNTHESIZED SFX. Pre-bakes one AudioStreamWAV per
## cue at startup (procedural — no asset files) and plays it via a pooled AudioStreamPlayer, gated by
## Settings.audio_enabled. last_id is still recorded as the cue id (the headless gate asserts it).

const CUES := {
	"place": "sfx_place",
	"invalid": "sfx_invalid",
	"go": "sfx_go",
	"clear": "sfx_clear",
	"leak": "sfx_leak",
	"bomb": "sfx_bomb",
}

enum MusicTrack { NONE, BUILD, FLOW }

const _MUSIC_NOTES := {
	MusicTrack.BUILD: [261.63, 329.63, 392.00, 329.63, 293.66, 349.23, 440.00, 392.00],
	MusicTrack.FLOW: [220.00, 261.63, 311.13, 293.66, 220.00, 261.63, 349.23, 311.13],
}
const _MUSIC_BEATS := {
	MusicTrack.BUILD: 0.42,
	MusicTrack.FLOW: 0.18,
}

# Per-cue synth spec: [base_freq, duration_s, waveform]. Distinct enough to read by ear.
const _TONE := {
	"sfx_place": [660.0, 0.06, "square"],
	"sfx_invalid": [150.0, 0.14, "saw"],
	"sfx_go": [880.0, 0.10, "square"],
	"sfx_clear": [780.0, 0.22, "sine_up"],
	"sfx_leak": [240.0, 0.22, "saw_down"],
	"sfx_bomb": [90.0, 0.32, "noise"],
}
const _RATE := 22050

var last_id: String = ""
var _streams := {}  # cue id -> AudioStreamWAV
var _player: AudioStreamPlayer
var current_music: int = MusicTrack.NONE
var _music_player: AudioStreamPlayer
var _music_streams := {}  # MusicTrack -> looped AudioStreamWAV


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	for id in _TONE:
		_streams[id] = _bake(_TONE[id])
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -12.0  # Keep one-shot gameplay cues above the music bed.
	add_child(_music_player)
	for track in [MusicTrack.BUILD, MusicTrack.FLOW]:
		_music_streams[track] = _bake_music(_MUSIC_NOTES[track], _MUSIC_BEATS[track])


func play(event: String) -> void:
	if not CUES.has(event):
		return
	last_id = CUES[event]  # always recorded (gate is deterministic regardless of the audio toggle)
	if not Settings.audio_enabled:
		return
	var s = _streams.get(last_id)
	if s != null:
		_player.stream = s
		_player.play()


func set_music(track: int) -> void:
	current_music = track
	_music_player.stop()
	if track == MusicTrack.NONE or not Settings.audio_enabled:
		return
	_music_player.stream = _music_streams[track]
	_music_player.play()


func sync_audio_enabled() -> void:
	set_music(current_music)


func is_music_playing() -> bool:
	return _music_player.playing


# Render a short PCM tone with a linear decay envelope into a 16-bit mono AudioStreamWAV.
func _bake(spec) -> AudioStreamWAV:
	var base_freq: float = spec[0]
	var dur: float = spec[1]
	var wave: String = spec[2]
	var n := int(_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var prog := float(i) / n
		var env := 1.0 - prog
		var f := base_freq
		if wave == "sine_up":
			f = base_freq * (1.0 + 0.6 * prog)
		elif wave == "saw_down":
			f = base_freq * (1.0 - 0.4 * prog)
		var phase := (float(i) / _RATE) * f
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw", "saw_down":
				v = 2.0 * fmod(phase, 1.0) - 1.0
			"noise":
				v = randf() * 2.0 - 1.0
			_:
				v = sin(phase * TAU)  # sine, sine_up
		bytes.encode_s16(i * 2, int(clampf(v * env * 0.5, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _RATE
	stream.stereo = false
	stream.data = bytes
	return stream


# Render a short melodic loop. Build uses a slower consonant major phrase; flow uses a faster
# minor phrase with brighter harmonics to make the phase change apparent without extra assets.
func _bake_music(notes: Array, beat_s: float) -> AudioStreamWAV:
	var frames_per_note := int(_RATE * beat_s)
	var frame_count := frames_per_note * notes.size()
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var tense := beat_s < 0.3
	for i in frame_count:
		var note_i := int(i / frames_per_note)
		var note_progress := float(i % frames_per_note) / frames_per_note
		var phase := float(i) / _RATE * float(notes[note_i])
		var v := sin(phase * TAU) * 0.72
		v += sin(phase * TAU * (3.0 if tense else 2.0)) * (0.22 if tense else 0.12)
		var attack := minf(note_progress / 0.08, 1.0)
		var release := minf((1.0 - note_progress) / 0.12, 1.0)
		var env := attack * release
		bytes.encode_s16(i * 2, int(clampf(v * env * 0.38, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frame_count - 1
	return stream
