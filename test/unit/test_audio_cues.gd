extends "res://addons/gut/test.gd"
## Music selection and audio-toggle synchronization through the Audio autoload.

var _audio_enabled_before: bool


func before_each() -> void:
	_audio_enabled_before = Settings.audio_enabled
	Settings.audio_enabled = true
	Audio.set_music(Audio.MusicTrack.NONE)
	Audio.sync_audio_enabled()


func after_each() -> void:
	Audio.set_music(Audio.MusicTrack.NONE)
	Settings.audio_enabled = _audio_enabled_before
	Audio.sync_audio_enabled()


func test_selects_build_then_flow_music() -> void:
	Audio.set_music(Audio.MusicTrack.BUILD)
	assert_eq(Audio.current_music, Audio.MusicTrack.BUILD)
	assert_true(Audio.is_music_playing(), "BUILD music starts when selected")

	Audio.set_music(Audio.MusicTrack.FLOW)
	assert_eq(Audio.current_music, Audio.MusicTrack.FLOW)
	assert_true(Audio.is_music_playing(), "FLOW music starts when selected")


func test_music_tracks_are_loop_enabled() -> void:
	for track in [Audio.MusicTrack.BUILD, Audio.MusicTrack.FLOW]:
		var stream: AudioStreamWAV = Audio._music_streams[track]
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD,
			"track %d is loop-enabled" % track)


func test_music_loop_end_is_inside_pcm_frame_range() -> void:
	for track in [Audio.MusicTrack.BUILD, Audio.MusicTrack.FLOW]:
		var stream: AudioStreamWAV = Audio._music_streams[track]
		var frame_count: int = stream.data.size() / 2
		assert_lt(stream.loop_end, frame_count,
			"track %d loop end is inside PCM frame range" % track)


func test_place_sfx_preserves_build_music_and_last_id() -> void:
	Audio.set_music(Audio.MusicTrack.BUILD)
	Audio.play("place")

	assert_eq(Audio.last_id, "sfx_place")
	assert_eq(Audio.current_music, Audio.MusicTrack.BUILD)
	assert_true(Audio.is_music_playing(), "place SFX does not stop build music")


func test_mute_stops_music_but_retains_selected_track() -> void:
	Audio.set_music(Audio.MusicTrack.BUILD)
	Settings.audio_enabled = false
	Audio.sync_audio_enabled()

	assert_false(Audio.is_music_playing(), "muting stops active music")
	assert_eq(Audio.current_music, Audio.MusicTrack.BUILD, "muting retains selected track")


func test_reenable_sync_restarts_selected_track() -> void:
	Audio.set_music(Audio.MusicTrack.FLOW)
	Settings.audio_enabled = false
	Audio.sync_audio_enabled()
	Settings.audio_enabled = true
	Audio.sync_audio_enabled()

	assert_eq(Audio.current_music, Audio.MusicTrack.FLOW)
	assert_true(Audio.is_music_playing(), "re-enabling audio restarts selected music")
