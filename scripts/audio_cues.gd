extends Node
## Audio autoload: maps gameplay events to SFX ids and (when enabled) plays them. The recorded
## last_id IS the behavioral contract (design section juice, acceptance #2 "each gameplay event
## logs its mapped SFX id"); real synthesized playback (AudioStreamGenerator) is the deferred
## manual-audio tier (acceptance #4: done is not gated on art/music quality). Music deferred.

const CUES := {
	"place": "sfx_place",
	"invalid": "sfx_invalid",
	"go": "sfx_go",
	"clear": "sfx_clear",
	"leak": "sfx_leak",
	"bomb": "sfx_bomb",
}

var last_id: String = ""


func play(event: String) -> void:
	if not CUES.has(event):
		return
	last_id = CUES[event]  # always recorded (gate is deterministic regardless of the audio toggle)
	# Real playback would synthesize CUES[event] here, gated by Settings.audio_enabled (deferred).
