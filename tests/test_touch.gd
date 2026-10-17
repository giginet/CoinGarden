extends SceneTree
## Exercise real viewport dispatch, including GUI consumption and gesture capture.
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

func touch(at: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.index = index
	event.canceled = canceled
	root.push_input(event, true)

func drag(at: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = at
	event.index = index
	root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	var game := TestGame.new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	touch(Vector2(420, 500), true)
	check(game.coins.is_empty(), "touch-down does not drop before a possible drag")
	check(game.aim_x == 420, "touch-down immediately snaps preview to finger")
	touch(Vector2(420, 500), false)
	check(game.coins.size() == 1 and game.coins[0].position.x == 420, "quick tap drops exactly once at tapped column")
	check(game.next_label.visible and game.next_label.text == "NEXT", "next coin has a visible heading")
	game.restart()
	touch(Vector2(400, 500), true)
	drag(Vector2(820, 500))
	check(game.aim_x == 820 and game.coins.is_empty(), "drag follows finger without dropping")
	touch(Vector2(300, 500), true, 1)
	drag(Vector2(300, 500), 1)
	touch(Vector2(300, 500), false, 1)
	check(game.aim_x == 820 and game.coins.is_empty(), "second finger cannot steal or finish a gesture")
	drag(Vector2(1240, 70))
	check(game.aim_x == game.Stage.mouth_right() - game.Rules.RADII[0] - 2, "drag clamps at the far edge outside the jar")
	touch(Vector2(1240, 70), false)
	check(game.coins.size() == 1 and not game.suspended, "release over pause button finishes captured drag instead of pausing")
	game.restart()
	touch(Vector2(600, 500), true)
	touch(Vector2(600, 500), false, 0, true)
	check(game.coins.is_empty() and game.active_touch == -1, "canceled touch never drops")
	drag(Vector2(300, 500))
	touch(Vector2(300, 500), false)
	check(game.coins.is_empty() and game.aim_x == 600, "orphan move and release are ignored")
	touch(Vector2(600, 500), true)
	game._toggle_pause()
	game._toggle_pause()
	touch(Vector2(600, 500), false)
	check(game.coins.is_empty(), "pause cancels an unfinished gesture")
	touch(Vector2(600, 500), true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(Vector2(600, 500), false)
	check(game.coins.is_empty(), "losing app focus cancels gesture")
	# A fresh touch on a GUI control must still activate the control on mobile.
	touch(Vector2(1220, 70), true)
	touch(Vector2(1220, 70), false)
	check(game.suspended and game.active_touch == -1, "pause button responds to a touchscreen tap")
	game._toggle_pause()
	touch(Vector2(600, 500), true)
	game.restart()
	touch(Vector2(600, 500), false)
	check(game.coins.is_empty(), "restart cancels a held touch")
	touch(Vector2(600, 500), true)
	game._game_over()
	check(game.active_touch == -1, "game over cancels gesture capture")
	# Browsers pass opaque touch identifiers; signed values must work too.
	for touch_id in [-2147483647, -1, 2147483647]:
		game.restart()
		touch(Vector2(520, 500), true, touch_id)
		check(game.has_active_touch and game.coins.is_empty(), "capture touch ID %d without dropping early" % touch_id)
		drag(Vector2(700, 500), touch_id)
		check(game.aim_x == 700, "drag follows touch ID %d" % touch_id)
		touch(Vector2(700, 500), false, touch_id)
		check(game.coins.size() == 1 and not game.has_active_touch, "release drops exactly once for touch ID %d" % touch_id)
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	if game.result_tween and game.result_tween.is_valid():
		game.result_tween.kill()
	game.free()
	await process_frame
	await process_frame
	print("%d touch checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
