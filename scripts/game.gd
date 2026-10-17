extends Node2D
## Main scene. All coordinates use the 1280 × 900 logical canvas.

const Rules = preload("res://scripts/exchange_rules.gd")
const Coin = preload("res://scripts/coin.gd")
const Art = preload("res://scripts/coin_art.gd")
const Stage = preload("res://scripts/pig_stage.gd")
const BACKGROUND = preload("res://assets/pixel/background.png")
const PIXEL_FONT = preload("res://assets/pixel/font/pixel_font.fnt")
const INK := Color("fff1c5")
const MUTED := Color("aaa2bc")
const PAPER := Color("24233d")
const ORANGE := Color("f5d478")
const BOARD := Rect2(240, 240, 800, 560)
const DANGER_Y := 350.0
const SPAWN_Y := Stage.SPAWN_Y
const DROP_DELAY := 0.40
const OVERFLOW_GRACE := 2.0

var rng := RandomNumberGenerator.new()
var font: Font
var bold: Font
var coins: Array = []
var score := 0
var best := 0
var cleared := 0
var exchanges := 0
var chain := 0
var current_tier := 0
var upcoming: Array[int] = []
var aim_x := 640.0
var active_touch := -1
var cooldown := 0.0
var danger := 0.0
var ended := false
var suspended := false
var starting := false
var max_chain := 0
var muted := false
var pending_exchange := false
var effects: Array[Dictionary] = []
var score_label: Label
var best_label: Label
var cleared_label: Label
var chain_label: Label
var status_label: Label
var next_label: Label
var pause_button: Button
var sound_button: Button
var overlay: Control
var overlay_title: Label
var overlay_detail: Label
var resume_button: Button
var retry_button: Button
var overlay_shade: ColorRect
var overlay_card: Panel
var start_banner: Node2D
var intro_tween: Tween
var result_tween: Tween
var audio: Node
var active_tween: Tween
var effect_layer: Node2D
var chipmunk: Node2D

func _ready() -> void:
	rng.randomize()
	font = PIXEL_FONT
	bold = PIXEL_FONT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_best()
	_build_walls()
	# Draw behind the buttons, in front of the room background.
	chipmunk = preload("res://scripts/chipmunk.gd").new()
	add_child(chipmunk)
	_build_ui()
	_build_pixel_presentation()
	var coin_layer := Node2D.new()
	coin_layer.set_script(preload("res://scripts/coin_renderer.gd"))
	coin_layer.coins = coins
	coin_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_layer.z_index = 2
	add_child(coin_layer)
	effect_layer = Node2D.new()
	effect_layer.set_script(preload("res://scripts/exchange_effects.gd"))
	effect_layer.font = bold
	effect_layer.z_index = 5
	add_child(effect_layer)
	_build_audio()
	_build_start_banner()
	restart()

func _build_walls() -> void:
	Stage.build_walls(self)

func _label(text: String, at: Vector2, size: Vector2, pixels: int, color: Color = INK, heavy: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at.snapped(Vector2(4, 4))
	label.size = size
	label.add_theme_font_override("font", bold if heavy else font)
	label.add_theme_font_size_override("font_size", maxi(32, roundi(pixels / 32.0) * 32))
	label.add_theme_color_override("font_shadow_color", Color("17152b"))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _style(color: Color, _radius: int = 0, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("c99743") if border.a == 0 else border
	box.set_border_width_all(4)
	box.shadow_color = Color("17152b")
	box.shadow_size = 4
	box.shadow_offset = Vector2(4, 4)
	return box

func _button(text: String, at: Vector2, size: Vector2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at.snapped(Vector2(4, 4))
	button.size = size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", bold)
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("fff0ad"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color("593448") if primary else PAPER))
	button.add_theme_stylebox_override("hover", _style(Color("945069") if primary else Color("454363")))
	button.add_theme_stylebox_override("pressed", _style(Color("593448")))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 0, Color("fff1c5")))
	var pixel_theme := Theme.new()
	pixel_theme.default_font = font
	pixel_theme.default_font_size = 32
	button.theme = pixel_theme
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build_pixel_presentation() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PixelPresentation"
	layer.layer = 100
	add_child(layer)
	var screen := ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pixel_grid.gdshader")
	screen.material = material
	layer.add_child(screen)

func _build_ui() -> void:
	# Compact scores and a coin guide keep the full drop opening unobstructed.
	score_label = _label("0", Vector2(96, 52), Vector2(280, 56), 38, INK, true)
	chain_label = _label("", Vector2(96, 96), Vector2(200, 30), 20, ORANGE, true)
	_label("BEST", Vector2(400, 44), Vector2(224, 32), 32, ORANGE)
	best_label = _label("0", Vector2(400, 88), Vector2(224, 32), 32)
	# Additional statistics remain available in the pause / result sheet.
	cleared_label = _label("", Vector2.ZERO, Vector2.ZERO, 13)
	status_label = _label("", Vector2.ZERO, Vector2.ZERO, 13)
	next_label = _label("NEXT", Vector2(680, 24), Vector2(120, 32), 32, ORANGE)
	_label("2", Vector2(880, 52), Vector2(32, 32), 32, MUTED)
	_label("3", Vector2(1024, 52), Vector2(32, 32), 32, MUTED)
	for label in [cleared_label, status_label]:
		label.hide()
	_build_coin_guide()
	sound_button = _button("♪", Vector2(1138, 48), Vector2(48, 48), _toggle_sound)
	sound_button.tooltip_text = "SOUND"
	pause_button = _button("Ⅱ", Vector2(1198, 48), Vector2(48, 48), _toggle_pause)
	pause_button.tooltip_text = "PAUSE / ESC"
	var retry := _button("↺", Vector2(40, 844), Vector2(48, 48), _request_restart)
	retry.tooltip_text = "RETRY"
	_build_overlay()

func _build_coin_guide() -> void:
	var panel := Panel.new()
	panel.name = "CoinGuide"
	panel.position = Vector2(1120, 112)
	panel.size = Vector2(144, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(PAPER))
	add_child(panel)
	for tier in Rules.VALUES.size():
		var icon := TextureRect.new()
		icon.texture = Art.GUIDE_TEXTURES[tier]
		icon.position = Vector2(8, 4 + tier * 60)
		icon.size = Vector2(52, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		_label("× %d" % Rules.REQUIRED[tier], Vector2(1192, 124 + tier * 60), Vector2(64, 32), 32)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	overlay_shade = ColorRect.new()
	overlay_shade.color = Color(0.09, 0.08, 0.17, 0.38)
	overlay_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_shade)
	overlay_card = Panel.new()
	overlay_card.position = Vector2(380, 252)
	overlay_card.size = Vector2(520, 400)
	overlay_card.pivot_offset = overlay_card.size / 2
	overlay_card.add_theme_stylebox_override("panel", _style(PAPER, 26))
	overlay.add_child(overlay_card)
	overlay_title = _label("PAUSED", Vector2(412, 276), Vector2(456, 48), 32, INK, true)
	overlay_title.reparent(overlay_card)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_detail = _label("", Vector2(412, 344), Vector2(456, 160), 32, MUTED)
	overlay_detail.reparent(overlay_card)
	overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume_button = _button("CONTINUE", Vector2(460, 516), Vector2(360, 48), _toggle_pause, true)
	resume_button.reparent(overlay_card)
	retry_button = _button("PLAY AGAIN", Vector2(460, 584), Vector2(360, 44), restart)
	retry_button.reparent(overlay_card)
	overlay.hide()

func _build_start_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	start_banner = preload("res://scripts/start_banner.gd").new()
	start_banner.font = bold
	start_banner.position = Vector2(640, 430)
	layer.add_child(start_banner)
	start_banner.hide()

func _begin_start() -> void:
	starting = true
	start_banner.show()
	start_banner.modulate = Color.WHITE
	start_banner.rotation = -TAU * 3
	start_banner.scale = Vector2.ONE * 0.06
	audio.play_effect("start")
	intro_tween = create_tween().set_parallel(true)
	intro_tween.tween_property(start_banner, "rotation", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(start_banner, "scale", Vector2.ONE * 1.25, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tween.chain().tween_property(start_banner, "scale", Vector2.ONE * 0.96, 0.12)
	intro_tween.chain().tween_property(start_banner, "scale", Vector2.ONE * 1.08, 0.12)
	intro_tween.chain().tween_interval(0.25)
	intro_tween.chain().tween_property(start_banner, "modulate:a", 0.0, 0.18)
	intro_tween.chain().tween_callback(_finish_start)

func _finish_start() -> void:
	starting = false
	start_banner.hide()
	queue_redraw()

func restart() -> void:
	active_touch = -1
	for tween in [intro_tween, result_tween]:
		if tween and tween.is_valid():
			tween.kill()
	starting = false
	start_banner.hide()
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	for coin in coins:
		coin.free()
	coins.clear()
	effects.clear()
	chipmunk.reset()
	audio.restart()
	score = 0
	cleared = 0
	exchanges = 0
	chain = 0
	max_chain = 0
	cooldown = 0
	danger = 0
	ended = false
	suspended = false
	pending_exchange = false
	aim_x = 640
	current_tier = 0
	upcoming.clear()
	for i in 3:
		upcoming.append(Rules.roll_tier(rng))
	overlay.hide()
	overlay_card.scale = Vector2.ONE
	overlay_card.modulate = Color.WHITE
	overlay_shade.modulate = Color.WHITE
	retry_button.disabled = false
	pause_button.text = "Ⅱ"
	_refresh_ui()
	_begin_start()
	queue_redraw()

func _request_restart() -> void:
	# The pause sheet prevents an accidental click from erasing a run.
	if not ended and not suspended:
		_toggle_pause()

func _toggle_pause() -> void:
	if ended or starting:
		return
	suspended = not suspended
	active_touch = -1
	for coin in coins:
		coin.freeze = suspended or coin.merging
		coin.set_physics_process(not suspended)
	if active_tween and active_tween.is_valid():
		if suspended:
			active_tween.pause()
		else:
			active_tween.play()
	audio.set_suspended(suspended)
	if not suspended:
		audio.play_effect("ui")
	overlay.visible = suspended
	overlay_shade.color.a = 0.55
	overlay_title.text = "PAUSED"
	overlay_detail.text = "SCORE %s\nBEST  %s" % [_score_text(score), _score_text(best)]
	overlay_detail.tooltip_text = "SCORE %s\nBEST %s" % [_number(score), _number(best)]
	overlay_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	resume_button.show()
	pause_button.text = "▶" if suspended else "Ⅱ"
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Capture an existing gesture even if the finger leaves the jar or crosses UI.
	if active_touch >= 0:
		if event is InputEventScreenDrag and event.index == active_touch:
			_set_aim(event.position.x)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch and event.index == active_touch and not event.pressed:
			active_touch = -1
			if not event.canceled:
				_set_aim(event.position.x)
				_drop()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and not suspended:
			_drop()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if ended or suspended or starting:
		return
	if event is InputEventScreenTouch:
		# A tap and a drag both commit on release, never on touch-down.
		if event.pressed and not event.canceled and active_touch < 0 and _inside_drop_area(event.position):
			active_touch = event.index
			_set_aim(event.position.x)
			get_viewport().set_input_as_handled()
		return
	if active_touch >= 0:
		return
	if event is InputEventMouseMotion:
		_set_aim(event.position.x)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _inside_drop_area(event.position):
			_set_aim(event.position.x)
			_drop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		active_touch = -1

func _set_aim(x: float) -> void:
	var radius: float = Rules.RADII[current_tier]
	aim_x = clampf(x, Stage.mouth_left() + radius + 2, Stage.mouth_right() - radius - 2)
	queue_redraw()

func _inside_drop_area(at: Vector2) -> bool:
	var in_belly := at.y >= Stage.CENTER.y and ((at - Stage.CENTER) / Stage.RADII).length_squared() <= 1
	var in_upper_body := Rect2(Stage.mouth_left(), Stage.mouth_y(), Stage.RADII.x * 2, Stage.CENTER.y - Stage.mouth_y()).has_point(at)
	var in_opening := Rect2(Stage.mouth_left(), 140, Stage.mouth_right() - Stage.mouth_left(), Stage.mouth_y() - 140).has_point(at)
	return in_belly or in_upper_body or in_opening

func _drop() -> void:
	if ended or suspended or starting or cooldown > 0 or pending_exchange:
		return
	_set_aim(aim_x)
	# Never spawn overlapping an existing coin near the mouth of the jar.
	var spawn := Vector2(aim_x, SPAWN_Y)
	for coin in coins:
		if coin.position.distance_to(spawn) < coin.radius + Rules.RADII[current_tier] + 1:
			status_label.text = "少し横へ動かしてみよう"
			return
	# A successful drop starts a new turn; blocked inputs never break a chain.
	chain = 0
	var coin := _spawn_coin(current_tier, spawn)
	coin.linear_velocity = Vector2(0, 65)
	coin.angular_velocity = rng.randf_range(-0.45, 0.45)
	current_tier = upcoming.pop_front()
	upcoming.append(Rules.roll_tier(rng))
	cooldown = DROP_DELAY
	_set_aim(aim_x)
	audio.play_effect("drop")
	_refresh_ui()

func _spawn_coin(tier: int, at: Vector2) -> CoinBody:
	var coin := Coin.new()
	coin.setup(tier, bold)
	coin.landed.connect(audio.landing)
	coin.position = at
	coin.z_index = 2
	add_child(coin)
	coins.append(coin)
	return coin

func _physics_process(delta: float) -> void:
	if ended or suspended or starting:
		return
	var direction := float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	if direction != 0:
		_set_aim(aim_x + direction * 430 * delta)
	cooldown = maxf(0, cooldown - delta)
	# Check each physics step so brief contact during a bounce is not missed.
	if not pending_exchange:
		var batch := Rules.connected_batch(coins)
		if not batch.is_empty():
			_begin_exchange(batch)
	_check_overflow(delta)
	queue_redraw()

func _process(delta: float) -> void:
	if suspended:
		return
	if not starting and not ended:
		chipmunk.advance(delta)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	effect_layer.effects = effects
	effect_layer.queue_redraw()
	queue_redraw()

func _begin_exchange(batch: Array) -> void:
	pending_exchange = true
	var center := Vector2.ZERO
	var tier: int = batch[0].tier
	for coin in batch:
		center += coin.position
		coin.merging = true
		coin.freeze = true
	center /= batch.size()
	active_tween = create_tween().set_parallel(true)
	for coin in batch:
		active_tween.tween_property(coin, "modulate", Color(1.6, 1.5, 1.2, 0), 0.18)
	# Keep collision shapes stable during the flash, then replace atomically.
	active_tween.chain().tween_callback(_finish_exchange.bind(batch, tier, center))

func _finish_exchange(batch: Array, tier: int, center: Vector2) -> void:
	for coin in batch:
		coins.erase(coin)
		coin.free()
	chain += 1
	max_chain = maxi(max_chain, chain)
	exchanges += 1
	var earned := Rules.exchange_score(tier, chain)
	score = Rules.add_score(score, earned)
	if tier == 5:
		cleared += 1000
	else:
		var radius: float = Rules.RADII[tier + 1]
		center = Stage.confine(center, radius)
		var result := _spawn_coin(tier + 1, center)
		result.linear_velocity = Vector2(0, -80)
		result.angular_velocity = rng.randf_range(-0.7, 0.7)
	var text := "+%s" % _score_text(earned)
	if tier == 5:
		text = "1,000 CLEAR!\n" + text
	if chain > 1:
		text += "\n%d CHAIN  ×%s" % [chain, _score_text(Rules.chain_multiplier(chain))]
	# A fast cascade replaces nearby labels so its newest award stays readable.
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.position.distance_to(center) > 160)
	effects.append({"position": center, "life": 1.1, "text": text, "color": Art.GLOWS[tier], "clear": tier == 5})
	audio.exchange(tier, chain)
	if score > best:
		best = score
		_save_best()
	pending_exchange = false
	_refresh_ui()
	queue_redraw()

func _check_overflow(delta: float) -> void:
	danger = 0
	for coin in coins:
		if coin.merging:
			continue
		var over: bool = coin.position.y - coin.radius < DANGER_Y
		# A freshly dropped or fast falling coin can cross the line safely.
		if over and coin.age > 1.2 and coin.linear_velocity.length() < 65:
			coin.overflow_time += delta
		else:
			coin.overflow_time = maxf(0, coin.overflow_time - delta * 2)
		danger = maxf(danger, coin.overflow_time / OVERFLOW_GRACE)
	if danger >= 1 and not pending_exchange:
		_game_over()

func _game_over() -> void:
	active_touch = -1
	if ended:
		return
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	starting = false
	start_banner.hide()
	ended = true
	suspended = false
	pending_exchange = false
	audio.game_over()
	for coin in coins:
		coin.freeze = true
		coin.set_physics_process(false)
	overlay_title.text = "GAME OVER"
	overlay_detail.text = "SCORE %s\nBEST  %s\nCASH  %s\nCHAIN %d" % [_score_text(score), _score_text(best), _score_text(cleared), max_chain]
	overlay_detail.tooltip_text = "SCORE %s\nBEST %s" % [_number(score), _number(best)]
	overlay_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	resume_button.hide()
	overlay_shade.color.a = 0.38
	overlay_shade.modulate.a = 0
	overlay_card.modulate.a = 0
	overlay_card.scale = Vector2.ONE * 0.84
	retry_button.disabled = true
	overlay.show()
	result_tween = create_tween().set_parallel(true)
	result_tween.tween_property(overlay_shade, "modulate:a", 1.0, 0.3)
	result_tween.tween_property(overlay_card, "modulate:a", 1.0, 0.2)
	result_tween.tween_property(overlay_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	result_tween.chain().tween_callback(func(): retry_button.disabled = false)
	status_label.text = "GARDEN FULL"
	_save_best()
	queue_redraw()

func _refresh_ui() -> void:
	score_label.text = _score_text(score)
	score_label.tooltip_text = _number(score)
	score_label.mouse_filter = Control.MOUSE_FILTER_PASS
	best_label.text = _score_text(best)
	best_label.tooltip_text = "BEST  %s" % _number(best)
	best_label.mouse_filter = Control.MOUSE_FILTER_PASS
	cleared_label.text = "¥ %s" % _number(cleared)
	chain_label.text = "%d CHAIN" % chain if chain > 1 else ""
	chain_label.tooltip_text = "×%s" % _number(Rules.chain_multiplier(chain)) if chain > 1 else ""
	chain_label.mouse_filter = Control.MOUSE_FILTER_PASS
	chain_label.add_theme_color_override("font_color", ORANGE if chain > 1 else INK)
	next_label.tooltip_text = "NEXT  %d円" % Rules.VALUES[upcoming[0]]
	status_label.text = "クリック / Space で落とす"

func _score_text(value: int) -> String:
	if value < 1000000:
		return _number(value)
	# Keep the pixel HUD readable; exact integers remain in save data/tooltips.
	var units := [1000000, 1000000000, 1000000000000, 1000000000000000, 1000000000000000000]
	var suffixes := ["M", "B", "T", "Q", "E18"]
	for index in range(units.size() - 1, -1, -1):
		if value >= units[index]:
			return "%.2f%s" % [float(value) / units[index], suffixes[index]]
	return _number(value)

func _number(value: int) -> String:
	var raw := str(value)
	var output := ""
	for i in raw.length():
		if i > 0 and (raw.length() - i) % 3 == 0:
			output += ","
		output += raw[i]
	return output

func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load("user://coin_garden.cfg") == OK:
		best = int(config.get_value("game", "best", 0))
		muted = bool(config.get_value("game", "muted", false))

func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "best", best)
	config.set_value("game", "muted", muted)
	config.save("user://coin_garden.cfg")

func _build_audio() -> void:
	audio = preload("res://scripts/game_audio.gd").new()
	audio.muted = muted
	add_child(audio)
	sound_button.text = "♪" if not muted else "×♪"

func _toggle_sound() -> void:
	muted = not muted
	audio.set_muted(muted)
	if not muted:
		audio.play_effect("ui")
	sound_button.text = "♪" if not muted else "×♪"
	_save_best()

func _draw() -> void:
	if not font:
		return
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 1280, 900), false)
	var warning := Color("efa1a2") if danger > 0 else Color("575377")
	for x in range(256, 1024, 20):
		draw_rect(Rect2(x, 348, 8, 4), warning)
	if danger > 0:
		draw_rect(Rect2(256, 356, floorf(768 * clampf(danger, 0, 1) / 4) * 4, 4), Color("c8768a"))
	Art.paint(self, 1, Vector2(60, 80), 20, bold)
	if not upcoming.is_empty():
		var slots := [Rect2(656, 16, 152, 136), Rect2(840, 48, 112, 104), Rect2(984, 48, 112, 104)]
		for i in slots.size():
			var slot: Rect2 = slots[i]
			draw_rect(Rect2(slot.position + Vector2(4, 4), slot.size), Color("17152b"))
			draw_rect(slot, ORANGE if i == 0 else Color("575377"))
			draw_rect(slot.grow(-4), PAPER)
			Art.paint(self, upcoming[i], Vector2(slot.get_center().x, 108 if i == 0 else 116), 36 if i == 0 else 28, bold)
		# Left-to-right order, with the immediate next coin emphasized in gold.
		for x in [816, 960]:
			for point in [Vector2(0, 0), Vector2(4, 4), Vector2(8, 8), Vector2(4, 12), Vector2(0, 16)]:
				draw_rect(Rect2(Vector2(x, 96) + point, Vector2(4, 4)), MUTED)
	if not ended and not suspended and not starting:
		_draw_aim()

func _draw_aim() -> void:
	var radius: float = Rules.RADII[current_tier]
	# Cast the real circular shape against both the curved wall and the pile.
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, Vector2(aim_x, SPAWN_Y))
	query.motion = Vector2(0, BOARD.end.y - SPAWN_Y)
	var collision := get_world_2d().direct_space_state.cast_motion(query)
	var landing_y := SPAWN_Y + query.motion.y * collision[0]
	var snapped_x := snappedf(aim_x, 4)
	for y in range(int(SPAWN_Y + radius + 8), int(landing_y - radius), 20):
		draw_rect(Rect2(snapped_x, snappedf(y, 4), 4, 4), Color("667e96"))
	for i in 32:
		var point := Vector2(aim_x, landing_y) + Vector2.from_angle(TAU * i / 32.0) * radius
		draw_rect(Rect2(point.snapped(Vector2(4, 4)), Vector2(4, 4)), Color("575377"))
	Art.paint(self, current_tier, Vector2(aim_x, SPAWN_Y), radius, bold, 0.5 if cooldown > 0 else 1.0)
	var marker_y := snappedf(SPAWN_Y - radius - 20, 4)
	draw_rect(Rect2(snapped_x - 8, marker_y, 20, 4), Color("f5d478"))
	draw_rect(Rect2(snapped_x - 4, marker_y + 4, 12, 4), Color("f5d478"))
	draw_rect(Rect2(snapped_x, marker_y + 8, 4, 4), Color("f5d478"))
