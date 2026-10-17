extends Node2D
## Keep sprites on the pixel grid while following each physics body's rotation.
var coins: Array = []

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for coin in coins:
		draw_set_transform(coin.position.snapped(Vector2(4, 4)), coin.rotation)
		CoinArt.paint(self, coin.tier, Vector2.ZERO, coin.radius, coin.face_font, coin.modulate.a)
	draw_set_transform(Vector2.ZERO)
