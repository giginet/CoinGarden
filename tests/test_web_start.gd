extends SceneTree
## Run the Web-only gate through viewport input without touching user saves.
var checks := 0
var failures := 0

class WebGame extends "res://scripts/game.gd":
	func _requires_start_gesture() -> bool:
		return true
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

func touch(pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = Vector2(640, 440)
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func screen_touch(at: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.index = index
	root.push_input(event, false)

func dispose(game: Node) -> void:
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 900)
	var game := WebGame.new()
	root.add_child(game)
	await process_frame
	check(game.waiting_for_start and game.start_prompt.visible and not game.starting, "Web opens on the in-game start prompt")
	check(not game.audio.music.playing and game.audio.voices.all(func(p): return not p.playing), "no BGM or whistle is scheduled before the gesture")
	game._drop()
	game._toggle_pause()
	check(game.coins.is_empty() and not game.suspended, "waiting blocks gameplay and pause")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/coin-garden-tap-to-start.png")
	await create_timer(1.4).timeout
	check(game.start_prompt_label.modulate.a < 0.4 and game.start_prompt_label.modulate.a >= 0.29, "prompt slowly fades but remains visible")
	await create_timer(1.4).timeout
	check(game.start_prompt_label.modulate.a > 0.9, "prompt returns to full brightness")
	touch(true)
	touch(false, true)
	check(game.waiting_for_start, "canceled touch does not start")
	touch(true)
	check(game.waiting_for_start, "touch-down waits for release")
	touch(false)
	check(not game.waiting_for_start and not game.start_prompt.visible and game.starting, "tap dismisses prompt and starts the banner")
	check(game.audio.music.playing, "tap starts BGM")
	check(game.audio.voices.any(func(p): return p.playing and p.stream == game.audio.EFFECTS.start), "tap starts whistle")
	check(game.coins.is_empty() and game.active_touch == -1, "start tap cannot also drop a coin")
	var intro: Tween = game.intro_tween
	game._accept_start()
	check(game.intro_tween == intro, "duplicate start does not replay intro")
	await create_timer(1.8).timeout
	check(not game.starting, "intro finishes after gesture")
	touch(true)
	touch(false)
	check(game.coins.size() == 1, "a fresh tap drops a coin after the start animation")
	await create_timer(0.5).timeout
	touch(true)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(850, 440)
	root.push_input(drag, true)
	var release := InputEventScreenTouch.new()
	release.position = Vector2(850, 440)
	root.push_input(release, true)
	check(game.coins.size() == 2 and game.coins[1].position.x == 850, "a drag after start drops at the new column")
	var position: float = game.audio.music.get_playback_position()
	game.restart()
	await create_timer(0.1).timeout
	check(not game.waiting_for_start and not game.start_prompt.visible and game.starting, "retry skips the one-time gate")
	check(game.audio.music.get_playback_position() >= position, "retry preserves the music timeline")
	await dispose(game)
	for method in ["mouse", "keyboard"]:
		game = WebGame.new()
		root.add_child(game)
		await process_frame
		if method == "mouse":
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.position = Vector2(640, 440)
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				root.push_input(event, true)
		else:
			game.audio.set_muted(true)
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = true
			root.push_input(event, true)
			check(game.audio.music.volume_db <= -80 and game.audio.voices.all(func(p): return not p.playing), "start respects saved mute")
		check(game.starting and not game.waiting_for_start and game.coins.is_empty(), "%s can start without dropping" % method)
		await create_timer(1.8).timeout
		for pressed in [true, false]:
			var drop_event := InputEventMouseButton.new()
			drop_event.position = Vector2(500, 500)
			drop_event.button_index = MOUSE_BUTTON_LEFT
			drop_event.pressed = pressed
			root.push_input(drop_event, true)
		check(game.coins.size() == 1, "click drops a coin after starting with %s" % method)
		await dispose(game)
	# Use physical screen coordinates and nonzero / negative browser IDs, not
	# just logical 1280x900 events with the default finger index of zero.
	root.size = Vector2i(390, 844)
	game = WebGame.new()
	root.add_child(game)
	await process_frame
	screen_touch(Vector2(195, 422), true, 7)
	screen_touch(Vector2(195, 422), false, 7)
	await create_timer(1.8).timeout
	check(not game.waiting_for_start and not game.starting, "start completes on a portrait phone viewport")
	screen_touch(Vector2(195, 437), true, -2147483647)
	screen_touch(Vector2(195, 437), false, -2147483647)
	check(game.coins.size() == 1, "portrait tap drops with a negative browser touch ID after start")
	await create_timer(0.5).timeout
	screen_touch(Vector2(195, 437), true, -1)
	var phone_drag := InputEventScreenDrag.new()
	phone_drag.index = -1
	phone_drag.position = Vector2(270, 437)
	root.push_input(phone_drag, false)
	check(game.aim_x > 880 and game.aim_x < 890, "portrait drag converts physical screen coordinates into the game field")
	screen_touch(Vector2(270, 437), false, -1)
	check(game.coins.size() == 2 and not game.has_active_touch, "portrait release with ID -1 drops the second coin")
	await dispose(game)
	print("%d web-start checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
