extends Node2D
## Intentionally gaudy arcade lettering; the parent spins and zooms this node.
var font: Font

func _draw() -> void:
	if not font:
		return
	var text := "START!"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	var origin := Vector2(-width / 2, 32)
	for depth in range(20, 0, -4):
		draw_string(font, origin + Vector2(depth, depth), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color("593448"))
	for offset in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
		draw_string(font, origin + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color("17152b"))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color("f5d478"))
	for side in [-1, 1]:
		var at := Vector2(side * (width / 2 + 36), -8)
		draw_rect(Rect2(at - Vector2(20, 4), Vector2(40, 8)), Color("fff1c5"))
		draw_rect(Rect2(at - Vector2(4, 20), Vector2(8, 40)), Color("fff1c5"))
