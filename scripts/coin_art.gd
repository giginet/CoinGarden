class_name CoinArt
extends RefCounted

const TEXTURES := [
	preload("res://assets/pixel/coins/1.png"), preload("res://assets/pixel/coins/5.png"),
	preload("res://assets/pixel/coins/10.png"), preload("res://assets/pixel/coins/50.png"),
	preload("res://assets/pixel/coins/100.png"), preload("res://assets/pixel/coins/500.png")]
const GUIDE_TEXTURES := [
	preload("res://assets/pixel/guide/1.png"), preload("res://assets/pixel/guide/5.png"),
	preload("res://assets/pixel/guide/10.png"), preload("res://assets/pixel/guide/50.png"),
	preload("res://assets/pixel/guide/100.png"), preload("res://assets/pixel/guide/500.png")]
const INKS := [Color("526963"), Color("79551e"), Color("794127"),
	Color("526963"), Color("284749"), Color("6c581e")]
const GLOWS := [Color("a9c4bb"), Color("e4bf60"), Color("cc8761"),
	Color("bad0c6"), Color("89bdc7"), Color("eed780")]

static func paint(canvas: CanvasItem, tier: int, center: Vector2, radius: float, _font: Font, alpha: float = 1.0) -> void:
	canvas.draw_texture_rect(TEXTURES[tier], Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, Color(1, 1, 1, alpha))
