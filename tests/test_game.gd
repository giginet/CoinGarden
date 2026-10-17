extends SceneTree
## Run: godot --headless --path . --script tests/test_game.gd

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

class StubCoin extends RefCounted:
	var tier: int
	var radius: float
	var position: Vector2
	var merging := false
	func _init(kind: int, at: Vector2) -> void:
		tier = kind
		radius = Rules.RADII[kind]
		position = at
	func exchange_ready() -> bool:
		return not merging

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	_test_rules()
	var game := TestGame.new()
	root.add_child(game)
	game.set_physics_process(false)
	var fresh = game._spawn_coin(1, Vector2(640, 500))
	check(not fresh.exchange_ready(), "uncontacted new coin waits for physics warm-up")
	fresh.has_landed = true
	check(fresh.exchange_ready(), "contact immediately enables a newly placed coin")
	fresh.merging = true
	check(not fresh.exchange_ready(), "contact cannot reactivate an exchanging coin")
	fresh.merging = false
	fresh.has_landed = false
	fresh.age = 0.08
	check(fresh.exchange_ready(), "new exchange result can join nearby coins after a short warm-up")
	game.restart()
	# Real first contact before the old 0.24s gate: no extra scan timer delay.
	var support = game._spawn_coin(1, Vector2(640, 500))
	support.freeze = true
	support.age = 1.0
	var incoming = game._spawn_coin(1, Vector2(640, 420))
	incoming.linear_velocity = Vector2(0, 65)
	game.set_physics_process(true)
	for step in 6:
		await physics_frame
		if game.pending_exchange:
			break
	check(game.pending_exchange and incoming.has_landed and incoming.age < 0.08, "first physical contact exchanges without waiting for age or scan timer")
	game.set_physics_process(false)
	# Every denomination exchanges at the exact requested threshold.
	for tier in 6:
		game.restart()
		var batch: Array = []
		for i in Rules.REQUIRED[tier]:
			var coin = game._spawn_coin(tier, Vector2(440 + i * Rules.RADII[tier] * 2, 700))
			coin.freeze = true
			coin.age = 2
			batch.append(coin)
		game._begin_exchange(batch)
		check(game.pending_exchange, "exchange locks before animation")
		check(Rules.connected_batch(game.coins).is_empty(), "merging coins cannot be consumed twice")
		await create_timer(0.25).timeout
		if tier == 5:
			check(game.coins.is_empty(), "two 500-yen coins disappear")
			check(game.cleared == 1000, "cash-out records 1000 yen")
		else:
			check(game.coins.size() == 1 and game.coins[0].tier == tier + 1, "tier %d upgrades" % tier)
		check(game.score == Rules.BASE_SCORES[tier], "exchange awards correct base score including cash-out bonus")
		check(not game.pending_exchange, "exchange unlocks after animation")
	# Real physics: five one-yen coins settle and automatically exchange.
	game.restart()
	game.set_physics_process(true)
	for i in 5:
		game._spawn_coin(0, Vector2(640 + (i - 2) * Rules.RADII[0] * 2, 735))
	await create_timer(1.0).timeout
	check(game.coins.size() == 1 and game.coins[0].tier == 1, "physical contact triggers five-coin exchange")
	check(game.score == 5, "automatic exchange score")
	# Natural cascade: new 5 yen falls beside an existing 5 yen.
	game.restart()
	game._spawn_coin(1, Vector2(640, 640))
	for i in 5:
		game._spawn_coin(0, Vector2(640 + (i - 2) * Rules.RADII[0] * 2, 735))
	await create_timer(2.0).timeout
	check(game.exchanges >= 2, "newly exchanged coin can trigger a cascade")
	check(game.score >= 25, "cascade multiplies the second exchange score")
	game.set_physics_process(false)
	check(game.Stage.mouth_right() - game.Stage.mouth_left() >= game.BOARD.size.x * 0.98, "opening spans the full playfield width")
	check(game._inside_drop_area(Vector2(265, 330)), "left upper corner accepts drop input")
	check(game._inside_drop_area(Vector2(1015, 330)), "right upper corner accepts drop input")
	# Every coin size enters through either end of the slot and remains
	# inside the curved wall after falling and rolling down the belly.
	for tier in 6:
		for side in [-1, 1]:
			game.restart()
			game.current_tier = tier
			game._set_aim(side * 10000.0)
			var falling = game._spawn_coin(tier, Vector2(game.aim_x, game.SPAWN_Y))
			var drop_x: float = falling.position.x
			await create_timer(0.5).timeout
			check(absf(falling.position.x - drop_x) < 2.0 and falling.position.y > game.Stage.mouth_y(), "tier %d drops straight into side %d without a shoulder deflecting it" % [tier, side])
			await create_timer(1.1).timeout
			check(_fits_belly(game, falling.position, falling.radius), "tier %d stays inside curved wall from side %d" % [tier, side])
	for tier in 6:
		var radius: float = Rules.RADII[tier]
		var position: Vector2 = game.Stage.confine(Vector2(995, 775), radius)
		check(_fits_belly(game, position, radius), "merged tier %d is placed inside ellipse" % tier)
	# Cooldown, wall clamp, no-input while paused, and reset during a tween.
	game.restart()
	game._set_aim(-1000)
	check(game.aim_x >= game.Stage.mouth_left() + Rules.RADII[0], "aim clamps inside drop opening")
	game._drop()
	game._drop()
	check(game.coins.size() == 1, "drop cooldown prevents duplicate input")
	game._toggle_pause()
	var age: float = game.coins[0].age
	await create_timer(0.15).timeout
	check(game.coins[0].age == age, "pause freezes coin timers")
	game._drop()
	check(game.coins.size() == 1, "cannot drop while paused")
	game._toggle_pause()
	game.restart()
	var pair: Array = [game._spawn_coin(1, Vector2(600, 700)), game._spawn_coin(1, Vector2(656, 700))]
	game._begin_exchange(pair)
	game._toggle_pause()
	await create_timer(0.25).timeout
	check(game.pending_exchange and game.coins.size() == 2, "pause suspends exchange animation")
	game.restart()
	await create_timer(0.3).timeout
	check(game.coins.is_empty() and game.score == 0 and not game.pending_exchange, "restart cancels in-flight exchange")
	# Overflow ignores freshly falling coins, warns, then ends the run.
	var high = game._spawn_coin(0, Vector2(600, 290))
	high.freeze = true
	high.age = 0
	game._check_overflow(3.0)
	check(not game.ended, "fresh drop is exempt from overflow")
	high.age = 2
	high.linear_velocity = Vector2(0, 200)
	game._check_overflow(3.0)
	check(not game.ended, "fast falling coin is exempt from overflow")
	high.linear_velocity = Vector2.ZERO
	game._check_overflow(1.0)
	check(not game.ended and game.danger > 0, "overflow gives warning grace time")
	game._check_overflow(1.1)
	check(game.ended and game.overlay.visible, "overflow ends run and shows retry")
	game.restart()
	check(not game.ended and not game.overlay.visible and game.coins.is_empty(), "restart resets game over")
	# Dispatch real engine input, including Space with a UI button focused.
	game.sound_button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(game.coins.size() == 1 and game.muted, "Space drops even when sound button has focus")
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(game.suspended and game.overlay.visible, "Escape dispatch opens pause overlay")
	game.restart()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 450)
	root.push_input(click, true)
	await process_frame
	check(game.coins.size() == 1, "click dispatch drops inside the board")
	# Release streaming audio on its mixer thread before exiting the test tree.
	game.audio.music.stop()
	game.audio.stop_effects()
	await create_timer(0.1).timeout
	game.free()
	await process_frame
	await process_frame
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fits_belly(game: Node, at: Vector2, radius: float) -> bool:
	var path: PackedVector2Array = game.Stage.wall_path()
	for i in path.size() - 1:
		var edge := path[i + 1] - path[i]
		var inward := Vector2(-edge.y, edge.x).normalized()
		if (at - path[i]).dot(inward) < radius - 2.0:
			return false
	return true

func _test_rules() -> void:
	for tier in 6:
		var group: Array = []
		for i in Rules.REQUIRED[tier] - 1:
			group.append(StubCoin.new(tier, Vector2(i * Rules.RADII[tier] * 2, 0)))
		check(Rules.connected_batch(group).is_empty(), "tier %d needs full threshold" % tier)
		group.append(StubCoin.new(tier, Vector2(group.size() * Rules.RADII[tier] * 2, 0)))
		check(Rules.connected_batch(group).size() == Rules.REQUIRED[tier], "tier %d threshold recognized" % tier)
		group.append(StubCoin.new(tier, Vector2(group.size() * Rules.RADII[tier] * 2, 0)))
		check(Rules.connected_batch(group).size() == Rules.REQUIRED[tier], "excess coins remain unconsumed")
		group[0].position = Vector2(10000, 0)
		group[1].position = Vector2(-10000, 0)
		check(Rules.connected_batch(group).is_empty(), "disconnected totals do not exchange")
		var near: Array = []
		for i in Rules.REQUIRED[tier]:
			near.append(StubCoin.new(tier, Vector2(i * (Rules.RADII[tier] * 2 + 8.0), 0)))
		check(Rules.connected_batch(near).size() == Rules.REQUIRED[tier], "tier %d tolerates a small visible gap" % tier)
		for i in near.size():
			near[i].position.x = i * (Rules.RADII[tier] * 2 + 9.0)
		check(Rules.connected_batch(near).is_empty(), "tier %d does not bridge gaps beyond tolerance" % tier)
	var mixed := [StubCoin.new(1, Vector2.ZERO), StubCoin.new(3, Vector2(56, 0))]
	check(Rules.connected_batch(mixed).is_empty(), "different denominations cannot merge")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen := {}
	for i in 1000:
		seen[Rules.roll_tier(rng)] = true
	check(seen.size() == 6, "all six denominations can drop")
