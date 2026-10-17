extends SceneTree
const Rules = preload("res://scripts/exchange_rules.gd")
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
	var multipliers := [1, 4, 27, 256, 3125, 46656]
	for i in multipliers.size():
		check(Rules.chain_multiplier(i + 1) == multipliers[i], "exact n^n multiplier %d" % (i + 1))
	check(Rules.exchange_score(5, 1) == 10000, "standalone 1000 yen is worth 10000 points")
	check(Rules.exchange_score(5, 6) == 466560000, "sixth cash-out earns 466560000")
	check(Rules.exchange_score(5, 1000000) == Rules.MAX_SCORE, "extreme chains saturate safely")
	check(Rules.exchange_score(0, 15) == 2189469451904296875, "large scores retain exact integer precision")
	check(Rules.add_score(Rules.MAX_SCORE - 3, 5) == Rules.MAX_SCORE, "score addition never wraps negative")
	var game := TestGame.new()
	root.add_child(game)
	game.set_physics_process(false)
	# Carry each generated coin into the next real exchange animation.
	var expected := [5, 45, 1395, 26995, 1589495, 468149495]
	for tier in 6:
		while game.coins.size() < Rules.REQUIRED[tier]:
			game._spawn_coin(tier, Vector2(500 + game.coins.size() * 10, 650))
		for coin in game.coins:
			coin.freeze = true
			coin.age = 2
		game._begin_exchange(game.coins.duplicate())
		await create_timer(0.24).timeout
		check(game.chain == tier + 1 and game.score == expected[tier], "cascade step %d awards exact total" % (tier + 1))
	check(game.coins.is_empty() and game.cleared == 1000, "six-stage cascade cashes out 1000 yen")
	check(game.best == 468149495, "high score uses exponential points")
	check(game.effects.back().text.contains("466.56M") and game.effects.back().text.contains("46,656"), "cash-out feedback includes award and multiplier")
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/coin-garden-scoring.png")
	game._physics_process(3.0)
	check(game.chain == 6, "same-turn chain survives former timeout")
	game.cooldown = 1
	game._drop()
	check(game.chain == 6, "cooldown-rejected drop preserves chain")
	game.cooldown = 0
	var blocker = game._spawn_coin(0, Vector2(game.aim_x, game.SPAWN_Y))
	blocker.freeze = true
	game._drop()
	check(game.chain == 6, "occupied-slot rejection preserves chain")
	game.coins.erase(blocker)
	blocker.free()
	game._toggle_pause()
	game._drop()
	check(game.chain == 6, "paused input preserves chain")
	game._toggle_pause()
	game._drop()
	check(game.chain == 0 and game.score == 468149495, "successful next drop resets chain only")
	game.restart()
	check(game.chain == 0 and game.score == 0, "retry resets score and turn")
	game.score = Rules.MAX_SCORE
	game._refresh_ui()
	check(game.score_label.tooltip_text == "9,223,372,036,854,775,807", "exact score remains available")
	check(game.font.get_string_size(game.score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x <= game.score_label.size.x, "maximum score fits HUD")
	var config := ConfigFile.new()
	config.set_value("game", "best", Rules.MAX_SCORE)
	var restored := ConfigFile.new()
	check(restored.parse(config.encode_to_text()) == OK and restored.get_value("game", "best") == Rules.MAX_SCORE, "score survives save serialization exactly")
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	await process_frame
	print("%d scoring checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
