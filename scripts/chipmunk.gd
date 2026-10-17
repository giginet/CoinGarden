extends Node2D
## Ambient decoration. Own RNG and no physics/input keep it separate from play.
const SHEET = preload("res://assets/pixel/chipmunk.png")
const FRAME_SIZE := Vector2(32, 28)
const RUN_DURATION := 4.8
const DANCE_DURATION := 5.6
enum Visit { WAITING, RUN, DANCE }

var rng := RandomNumberGenerator.new()
var visit := Visit.WAITING
var elapsed := 0.0
var wait_left := 10.0
var next_visit := Visit.RUN
var direction := 1.0
var sprite: Sprite2D

func _ready() -> void:
	rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 6
	sprite.vframes = 2
	sprite.centered = false
	sprite.scale = Vector2(4, 4)
	add_child(sprite)
	reset()

func reset() -> void:
	visit = Visit.WAITING
	elapsed = 0.0
	wait_left = rng.randf_range(8.0, 14.0)
	next_visit = Visit.RUN if rng.randf() < 0.5 else Visit.DANCE
	hide()

func advance(delta: float) -> void:
	if visit == Visit.WAITING:
		wait_left -= delta
		if wait_left <= 0:
			begin_visit(next_visit)
		return
	elapsed += delta
	var duration := RUN_DURATION if visit == Visit.RUN else DANCE_DURATION
	if elapsed >= duration:
		next_visit = Visit.DANCE if visit == Visit.RUN else Visit.RUN
		visit = Visit.WAITING
		wait_left = rng.randf_range(18.0, 32.0)
		hide()
		return
	_update_pose()

func begin_visit(kind: Visit) -> void:
	visit = kind
	elapsed = 0.0
	direction = 1.0 if rng.randf() < 0.5 else -1.0
	show()
	_update_pose()

func _update_pose() -> void:
	var x: float
	var frame: int
	var facing_left := false
	if visit == Visit.RUN:
		var progress := elapsed / RUN_DURATION
		x = lerpf(-132.0, 1284.0, progress if direction > 0 else 1.0 - progress)
		frame = int(elapsed * 12.0) % 6
		facing_left = direction < 0
	elif elapsed < 0.8:
		x = lerpf(-132.0, 104.0, elapsed / 0.8)
		frame = int(elapsed * 12.0) % 6
	elif elapsed < 4.8:
		x = 104.0
		frame = 6 + int((elapsed - 0.8) * 7.5) % 6
	else:
		x = lerpf(104.0, -132.0, (elapsed - 4.8) / 0.8)
		frame = int(elapsed * 12.0) % 6
		facing_left = true
	position = Vector2(snappedf(x, 4.0), 780.0)
	sprite.frame = frame
	sprite.flip_h = facing_left
	queue_redraw()

func _draw() -> void:
	# Foot shadow is on the floor; music notes stay outside the play field.
	draw_rect(Rect2(32, 108, 72, 4), Color("382735"))
	if visit == Visit.DANCE and elapsed >= 0.8 and elapsed < 4.8:
		var lift := float(int(elapsed * 8.0) % 3) * 4
		for offset in [Vector2(0, 28 - lift), Vector2(112, 16 + lift)]:
			draw_rect(Rect2(offset, Vector2(8, 8)), Color("f5d478"))
			draw_rect(Rect2(offset + Vector2(4, -16), Vector2(4, 20)), Color("f5d478"))
			draw_rect(Rect2(offset + Vector2(8, -16), Vector2(8, 4)), Color("f5d478"))
