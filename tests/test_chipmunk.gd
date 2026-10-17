extends SceneTree
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
	game.set_process(false)
	game.set_physics_process(false)
	var pet = game.chipmunk
	var gameplay_rng: int = game.rng.state
	check(not pet.visible and pet.wait_left >= 8 and pet.wait_left <= 14, "first visit waits after game starts")
	pet.advance(pet.wait_left + 0.01)
	check(pet.visible and pet.visit != pet.Visit.WAITING, "timer starts a visit")
	var first_visit: int = pet.visit
	pet.advance(6.0)
	check(not pet.visible and pet.wait_left >= 18 and pet.wait_left <= 32, "visit finishes with a quiet interval")
	pet.advance(pet.wait_left + 0.01)
	check(pet.visible and pet.visit != first_visit, "both visit types appear in turn")
	for direction in [-1.0, 1.0]:
		pet.begin_visit(pet.Visit.RUN)
		pet.direction = direction
		pet.advance(0)
		check(pet.position.x < 0 if direction > 0 else pet.position.x > 1280, "run starts offscreen")
		pet.advance(pet.RUN_DURATION / 2)
		check(pet.position.x > 500 and pet.position.x < 700 and pet.sprite.frame < 6, "run crosses bottom using running frames")
		check(pet.sprite.flip_h == (direction < 0), "runner faces travel direction")
		pet.advance(pet.RUN_DURATION / 2)
		check(not pet.visible, "runner exits cleanly")
	pet.begin_visit(pet.Visit.DANCE)
	pet.advance(1.2)
	check(pet.position.x == 104 and pet.sprite.frame >= 6, "visitor dances in lower left")
	var time: float = pet.elapsed
	game.suspended = true
	game._process(1)
	check(pet.elapsed == time, "pause freezes visitor")
	game.suspended = false
	game.starting = true
	game._process(1)
	check(pet.elapsed == time, "intro suspends ambient animation")
	game.starting = false
	game.ended = true
	game._process(1)
	check(pet.elapsed == time, "results suspend ambient animation")
	game.ended = false
	game._process(0.1)
	check(pet.elapsed > time, "gameplay resumes visitor")
	check(game.rng.state == gameplay_rng and game.coins.is_empty() and game.score == 0, "decoration leaves gameplay and coin RNG untouched")
	game.restart()
	check(not pet.visible and pet.visit == pet.Visit.WAITING, "retry clears visitor and reschedules")
	if OS.get_cmdline_user_args().has("--capture"):
		game.current_tier = 1
		game.upcoming.assign([2, 0, 4])
		game.score = 1280
		game.best = 2450
		game._refresh_ui()
		for spec in [[5, 640, 720], [4, 490, 698], [3, 810, 680], [2, 440, 580], [1, 570, 580]]:
			var coin = game._spawn_coin(spec[0], Vector2(spec[1], spec[2]))
			coin.freeze = true
		for kind in [pet.Visit.RUN, pet.Visit.DANCE]:
			pet.begin_visit(kind)
			pet.direction = 1
			var duration: float = pet.RUN_DURATION if kind == pet.Visit.RUN else pet.DANCE_DURATION
			for frame in range(ceili(duration * 60)):
				pet.advance(1.0 / 60.0)
				await process_frame
				if kind == pet.Visit.DANCE and frame == 150:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/tmp/chipmunk-game.png")
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	await process_frame
	print("%d chipmunk checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
