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


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	for id in _TONE:
		_streams[id] = _bake(_TONE[id])


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
