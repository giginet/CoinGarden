extends Node2D
## Separate drawing layer keeps feedback above every physics coin.
const SPARKLE = preload("res://assets/pixel/fx/sparkle.png")
var effects: Array[Dictionary] = []
var font: Font

func _draw() -> void:
	if not font:
		return
	for effect in effects:
		var elapsed: float = 1.1 - effect.life
		var fade: float = ceilf(minf(effect.life * 2.5, 1) * 4) / 4
		var center: Vector2 = effect.position
		for i in 8:
			var angle := TAU * i / 8.0
			var point := center + Vector2.from_angle(angle) * (20 + elapsed * 115)
			var size := 36.0 if i % 2 == 0 else 20.0
			draw_texture_rect(SPARKLE, Rect2((point - Vector2.ONE * size / 2).snapped(Vector2(4, 4)), Vector2.ONE * size), false, Color(1, 1, 1, fade))
		var at := center + Vector2(0, -38 - elapsed * 65)
		var lines: PackedStringArray = effect.text.split("\n")
		var width := 0.0
		for line in lines:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x)
		at.x = clampf(at.x, 248 + width / 2, 1032 - width / 2)
		at = at.snapped(Vector2(4, 4))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.14, 0.14, 0.24, fade)
		box.border_color = Color("c99743")
		box.set_border_width_all(4)
		var height := 48 + (lines.size() - 1) * 36
		at.y -= (lines.size() - 1) * 36
		draw_style_box(box, Rect2(at - Vector2(width / 2 + 12, 36), Vector2(width + 24, height)))
		for index in lines.size():
			var line_width := font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
			draw_string(font, at + Vector2(-line_width / 2, index * 36), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.94, 0.68, fade))
