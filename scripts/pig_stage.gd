extends RefCounted
## Shared geometry for the pig's belly, collision wall, and drop opening.
const CENTER := Vector2(640, 520)
const RADII := Vector2(400, 280)
const OPENING_Y := 275.0
const WALL_THICKNESS := 18.0
const SEGMENTS := 96
# Leave room below the HUD for the enlarged 500-yen preview and its marker.
const SPAWN_Y := 260.0

static func point(angle: float) -> Vector2:
	return CENTER + Vector2(cos(angle), sin(angle)) * RADII

static func mouth_left() -> float:
	return CENTER.x - RADII.x

static func mouth_right() -> float:
	return CENTER.x + RADII.x

static func mouth_y() -> float:
	return OPENING_Y

static func wall_path() -> PackedVector2Array:
	# Full-width vertical entry, with an elliptical lower half. Upper
	# shoulders must not funnel edge drops back toward the center.
	var points := PackedVector2Array([Vector2(mouth_right(), OPENING_Y)])
	for i in SEGMENTS + 1:
		points.append(point(PI * float(i) / SEGMENTS))
	points.append(Vector2(mouth_left(), OPENING_Y))
	return points

static func body_polygon(padding: float = 0.0) -> PackedVector2Array:
	var radii := RADII + Vector2.ONE * padding
	var points := PackedVector2Array([Vector2(CENTER.x + radii.x, OPENING_Y)])
	for i in SEGMENTS + 1:
		points.append(CENTER + Vector2.from_angle(PI * float(i) / SEGMENTS) * radii)
	points.append(Vector2(CENTER.x - radii.x, OPENING_Y))
	return points

static func build_walls(parent: Node) -> void:
	var wall := StaticBody2D.new()
	wall.name = "PigBellyWall"
	var path := wall_path()
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var outward := Vector2((b - a).y, -(b - a).x).normalized() * WALL_THICKNESS
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([a, b, b + outward, a + outward])
		var collider := CollisionShape2D.new()
		collider.shape = shape
		wall.add_child(collider)
	# Short vertical guides keep every denomination inside the open slot.
	for x in [mouth_left() - WALL_THICKNESS / 2, mouth_right() + WALL_THICKNESS / 2]:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(WALL_THICKNESS, mouth_y() - 145)
		collider.shape = shape
		collider.position = Vector2(x, (mouth_y() + 145) / 2)
		wall.add_child(collider)
	parent.add_child(wall)

static func confine(center: Vector2, radius: float) -> Vector2:
	# Inward half-planes of the convex belly keep a newly merged coin clear
	# of curved walls, including near the narrow bottom of the ellipse.
	var result := center
	var path := wall_path()
	for iteration in 4:
		for i in path.size() - 1:
			var edge := path[i + 1] - path[i]
			var inward := Vector2(-edge.y, edge.x).normalized()
			var distance := (result - path[i]).dot(inward)
			if distance < radius + 1:
				result += inward * (radius + 1 - distance)
	return result
