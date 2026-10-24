extends Area3D
class_name RoastMeat
## Carne Assada: drop raro que recupera HP instantaneamente ao ser tocada.

const MODEL: PackedScene = preload("res://assets/models/roast_meat.glb")

@export var heal_amount: int = 30

var _bob_timer: float = 0.0

@onready var _visual: Node3D = $Visual

func _ready() -> void:
	_bob_timer = randf() * TAU
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.8
	_visual.add_child(model)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_bob_timer += delta * 2.5
	_visual.position.y = 0.35 + sin(_bob_timer) * 0.07
	_visual.rotate_y(delta * 1.5)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("heal"):
		body.heal(heal_amount)
		queue_free()
