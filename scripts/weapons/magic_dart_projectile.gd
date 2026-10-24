extends Area3D
class_name MagicDartProjectile
## Dardo arcano: voa reto na direção definida no disparo e some ao acertar o primeiro inimigo.

@export var lifetime: float = 1.8

var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 18.0
var _damage: int = 12
var _age: float = 0.0
var _spent: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(origin: Vector3, direction: Vector3, damage: int, speed: float) -> void:
	global_position = origin
	_direction = direction
	_damage = damage
	_speed = speed
	# look_at aponta o -Z do nó para o alvo; a malha do dardo é modelada ao longo de Z.
	look_at(origin + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	_spent = true
	Combat.hit(body, _damage)
	queue_free()
