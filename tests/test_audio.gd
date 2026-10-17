extends SceneTree
## Tests actual players with the headless audio driver, without changing saves.
var checks := 0
var failures := 0

class TestGame extends "res://scripts/game.gd":
	func _load_best() -> void:
		muted = true
	func _save_best() -> void:
		pass
	func _begin_start() -> void:
		pass

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var game := TestGame.new()
	root.add_child(game)
	game.set_physics_process(false)
	var audio = game.audio
	check(audio.music.stream != null, "packaged music loads")
	if audio.music.stream:
		check(audio.music.stream.loop and audio.music.stream.get_length() > 100, "music includes the original song opening before the loop")
		check(is_equal_approx(audio.music.stream.loop_offset, 85.21), "repeats use the matched phrase rather than replaying the intro")
	check(audio.music.playing and audio.music.volume_db <= -80, "saved mute starts music silently")
	check(audio.music.get_playback_position() < 1.0, "first playback starts at the beginning of the song")
	audio.music.seek(audio.music.stream.get_length() - 0.1)
	await create_timer(0.35).timeout
	var loop_start: float = audio.music.stream.loop_offset
	check(audio.music.playing and audio.music.get_playback_position() >= loop_start and audio.music.get_playback_position() < loop_start + 1.0, "BGM wraps to its loop point after the original opening (position %.3f)" % audio.music.get_playback_position())
	audio.music.seek(12.0)
	await create_timer(0.1).timeout
	var running_position: float = audio.music.get_playback_position()
	game.restart()
	await create_timer(0.1).timeout
	check(audio.music.get_playback_position() >= running_position and audio.music.get_playback_position() < running_position + 0.3, "gameplay retry preserves BGM timeline")
	game._toggle_sound()
	check(not audio.muted and audio.music.volume_db > -80, "unmute restores music")
	audio.stop_effects()
	game._drop()
	check(_is_playing(audio, "drop"), "dropping triggers Zappu effect")
	await create_timer(1.4).timeout
	check(game.coins[0].has_landed, "real collision triggers first-landing signal")
	for event in audio.EFFECTS:
		check(audio.EFFECTS[event].get_length() > 0, "%s effect loads" % event)
	check(audio.EFFECTS.game_over.get_length() > 1.3 and audio.EFFECTS.game_over.get_length() < 1.8, "game-over sting has a long final decay")
	audio.exchange(2, 1)
	check(_is_playing(audio, "exchange"), "ordinary exchange cue")
	audio.exchange(2, 4)
	check(_is_playing(audio, "chain"), "chain cue")
	var last_pitch := 0.0
	# Alternate denominations, including cash-out, to catch pitches resetting
	# when the exchange type changes during a cascade.
	for chain in range(1, 11):
		audio.stop_effects()
		audio.exchange(5 if chain % 3 == 0 else 4 - chain % 5, chain)
		var active = audio.voices.filter(func(p): return p.playing)
		check(active.size() == 1 and active[0].pitch_scale > last_pitch, "chain %d rises across denominations" % chain)
		last_pitch = active[0].pitch_scale
	audio.stop_effects()
	audio.exchange(4, 1)
	var reset_voice = audio.voices.filter(func(p): return p.playing)[0]
	check(is_equal_approx(reset_voice.pitch_scale, 1.0), "new chain resets to the root note")
	audio.exchange(5, 5)
	for i in 15:
		audio.play_effect("land")
	check(_is_playing(audio, "cashout"), "cash-out survives a burst of impacts")
	game._toggle_pause()
	check(audio.music.stream_paused, "pause suspends music")
	# Let the audio mixer acknowledge the pause before sampling its position.
	await create_timer(0.06).timeout
	var paused_position: float = audio.music.get_playback_position()
	await create_timer(0.15).timeout
	check(is_equal_approx(audio.music.get_playback_position(), paused_position), "paused music keeps its position")
	check(audio.voices.all(func(p): return p.stream_paused), "pause suspends effects")
	game._toggle_sound()
	game._toggle_sound()
	check(audio.music.stream_paused, "mute toggles do not resume a paused game")
	game._toggle_pause()
	check(not audio.music.stream_paused, "resume continues music")
	game._toggle_pause()
	await create_timer(0.06).timeout
	paused_position = audio.music.get_playback_position()
	game.restart()
	check(not audio.music.stream_paused and audio.music.playing, "retry while paused resumes music")
	check(audio.voices.all(func(p): return not p.stream_paused and not p.playing), "retry clears paused effects")
	await create_timer(0.1).timeout
	check(audio.music.get_playback_position() >= paused_position and audio.music.get_playback_position() < paused_position + 0.3, "paused retry preserves BGM position")
	var before_result: float = audio.music.get_playback_position()
	var continuous_playback: AudioStreamPlayback = audio.music.get_stream_playback()
	game._game_over()
	check(audio.music.playing and _is_playing(audio, "game_over"), "game over keeps BGM and plays result cue")
	await create_timer(0.5).timeout
	check(audio.music.get_playback_position() >= before_result and audio.music.get_playback_position() < before_result + 0.8, "game over continues from the same position while lowering volume")
	check(audio.music.get_stream_playback() == continuous_playback, "game over retains the same BGM playback")
	check(is_equal_approx(audio.music.volume_db, -13.0), "result BGM fades down gently by 3 dB")
	check(_is_playing(audio, "game_over"), "long game-over cue continues through result animation")
	game._toggle_sound()
	check(audio.voices.all(func(p): return not p.playing), "mute immediately silences effects")
	var muted_position: float = audio.music.get_playback_position()
	game.restart()
	check(audio.music.playing and audio.music.volume_db <= -80, "retry preserves mute")
	await create_timer(0.1).timeout
	check(audio.music.get_playback_position() >= muted_position and audio.music.get_playback_position() < muted_position + 0.3, "muted result retry preserves BGM timeline")
	check(audio.music.get_stream_playback() == continuous_playback, "result retry retains the same BGM playback")
	# Repeat the transitions inside the looping section as well as the intro.
	audio.music.seek(95.0)
	await create_timer(0.1).timeout
	var loop_position: float = audio.music.get_playback_position()
	continuous_playback = audio.music.get_stream_playback()
	for i in 3:
		game._game_over()
		await create_timer(0.15).timeout
		game.restart()
		await create_timer(0.1).timeout
	check(audio.music.get_playback_position() >= loop_position and audio.music.get_playback_position() < loop_position + 1.2, "repeated game overs and retries do not jump within the loop section")
	check(audio.music.get_stream_playback() == continuous_playback, "repeated transitions do not replace the loop playback")
	audio.music.stop()
	audio.stop_effects()
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	await process_frame
	print("%d audio checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _is_playing(audio: Node, event: String) -> bool:
	return audio.voices.any(func(p): return p.playing and p.stream == audio.EFFECTS[event])
