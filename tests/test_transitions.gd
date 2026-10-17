extends SceneTree
var checks := 0
var failures := 0

class TestGame extends "res://scripts/game.gd":
	func _load_best() -> void:
		muted = false
	func _save_best() -> void:
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
	check(game.starting and game.start_banner.visible, "new game starts with banner")
	check(game.audio.voices.any(func(p): return p.playing and p.stream == game.audio.EFFECTS.start), "whistle starts with banner")
	game._drop()
	game._toggle_pause()
	check(game.coins.is_empty() and not game.suspended, "intro blocks drops and pause")
	var angle: float = game.start_banner.rotation
	await create_timer(0.65).timeout
	check(game.start_banner.rotation > angle and game.start_banner.scale.x > 0.5, "banner spins and zooms")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/coin-garden-start.png")
	await create_timer(1.15).timeout
	check(not game.starting and not game.start_banner.visible, "intro finishes and hides")
	game._drop()
	check(game.coins.size() == 1, "drop unlocks after intro")
	game.score = 468149495
	game.best = 468149495
	game.cleared = 1000
	game.max_chain = 6
	game._game_over()
	check(game.ended and game.overlay.visible and game.coins[0].freeze, "game over freezes board and opens window")
	check(game.audio.music.playing, "result retains music playback")
	check(game.audio.voices.any(func(p): return p.playing and p.stream == game.audio.EFFECTS.game_over), "game over cue plays")
	var music_position: float = game.audio.music.get_playback_position()
	game._game_over()
	await create_timer(0.5).timeout
	check(game.audio.music.get_playback_position() > music_position, "result BGM continues from its position")
	check(is_equal_approx(game.audio.music.volume_db, -13.0), "result BGM fades to slightly quieter level")
	check(game.overlay_shade.color.a < 0.5, "result dims board gently")
	check(game.overlay_title.text == "GAME OVER" and game.overlay_detail.text.contains("CHAIN 6"), "result shows maximum chain")
	check(game.overlay_detail.text.contains("CASH  1,000"), "result shows cash-out total")
	check(not game.retry_button.disabled and not game.resume_button.visible, "result allows retry without resume")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/coin-garden-result.png")
	game._drop()
	check(game.coins.size() == 1, "result blocks new coins")
	game._toggle_sound()
	check(game.audio.music.volume_db <= -80, "result can mute")
	game._toggle_sound()
	check(is_equal_approx(game.audio.music.volume_db, -13.0), "result unmute preserves quieter volume")
	music_position = game.audio.music.get_playback_position()
	game.restart()
	check(game.starting and not game.overlay.visible and game.coins.is_empty(), "retry restarts intro and clears result")
	check(is_equal_approx(game.audio.music.volume_db, -10.0), "retry restores gameplay BGM volume")
	await create_timer(0.4).timeout
	check(game.audio.music.get_playback_position() >= music_position and game.audio.music.get_playback_position() < music_position + 0.7, "result retry keeps BGM position through start animation")
	game.restart()
	await create_timer(1.3).timeout
	check(game.starting, "old intro callback cannot unlock a newer intro")
	await create_timer(0.5).timeout
	check(not game.starting, "replacement intro completes")
	game._toggle_sound()
	game.restart()
	check(game.audio.music.volume_db <= -80 and game.audio.voices.all(func(p): return not p.playing), "muted start has no whistle or music")
	game._game_over()
	game.restart()
	await create_timer(0.5).timeout
	check(game.starting and not game.overlay.visible and game.audio.music_level == -10.0, "retry cancels result animation and ducking")
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	await process_frame
	print("%d transition checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
