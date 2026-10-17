extends SceneTree
## Render the real game with a reproducible sample arrangement, without changing saves.
class PreviewGame extends "res://scripts/game.gd":
	func _load_best() -> void:
		muted = true
	func _save_best() -> void:
		pass
	func _begin_start() -> void:
		pass

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var game := PreviewGame.new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.current_tier = 1
	game.upcoming.assign([2, 0, 4])
	game.aim_x = 650
	var sample := [
		[5, 640, 720], [4, 490, 698], [3, 810, 680],
		[0, 390, 640], [2, 440, 580], [1, 570, 580],
		[4, 700, 560], [1, 860, 550], [0, 960, 490],
		[0, 350, 510], [3, 540, 450], [2, 830, 430], [0, 650, 430]]
	for spec in sample:
		var position: Vector2 = game.Stage.confine(Vector2(spec[1], spec[2]), game.Rules.RADII[spec[0]])
		var coin = game._spawn_coin(spec[0], position)
		coin.rotation = float(spec[1] % 19 - 9) * 0.025
	await create_timer(1.5).timeout
	for coin in game.coins:
		coin.freeze = true
	game.score = 1280
	game.best = 2450
	game.cleared = 1000
	game.chain = 3
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.aim_x = 650
	game._refresh_ui()
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	var path := "/tmp/coin-garden-preview.png"
	root.get_texture().get_image().save_png(path)
	print("Preview saved: " + path)
	game.get_node("PixelPresentation").hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/coin-garden-raw.png")
	game.get_node("PixelPresentation").show()
	game._toggle_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/coin-garden-pause.png")
	game._toggle_pause()
	game.max_chain = 3
	game._game_over()
	await create_timer(0.45).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/coin-garden-game-over.png")
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	await process_frame
	quit()
