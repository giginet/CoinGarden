class_name CoinBody
extends RigidBody2D

signal landed(tier: int)

var tier := 0
var radius := 22.0
var age := 0.0
var overflow_time := 0.0
var merging := false
var face_font: Font
var has_landed := false

func setup(kind: int, font: Font) -> void:
	tier = kind
	radius = ExchangeRules.RADII[tier]
	face_font = font
	mass = 0.7 + float(tier) * 0.3
	gravity_scale = 1.0
	linear_damp = 0.65
	angular_damp = 2.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	var material := PhysicsMaterial.new()
	material.friction = 0.65
	material.bounce = 0.12
	physics_material_override = material
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collider.shape = shape
	add_child(collider)
	add_to_group("coins")

func _physics_process(delta: float) -> void:
	age += delta

func exchange_ready() -> bool:
	# A real collision is ready immediately. Uncontacted/newly exchanged
	# bodies get a short physics warm-up before proximity alone can connect them.
	return not merging and (has_landed or age >= 0.08)

func _on_body_entered(_body: Node) -> void:
	if not has_landed and not merging:
		has_landed = true
		landed.emit(tier)
