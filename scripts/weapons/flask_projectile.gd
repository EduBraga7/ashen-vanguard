extends Node3D
class_name FlaskProjectile
## Frasco em arco parabólico. Ao tocar o chão se quebra e cria uma FirePool.

const GROUND_HEIGHT: float = 0.1

@export var gravity: float = 22.0
@export var spin_speed: float = 9.0
@export var pool_scene: PackedScene = preload("res://scenes/weapons/fire_pool.tscn")

var _velocity: Vector3 = Vector3.ZERO
var _tick_damage: int = 5
var _pool_radius: float = 1.5

@onready var _model: Node3D = $Model

func launch(start: Vector3, target: Vector3, tick_damage: int, pool_radius: float) -> void:
	global_position = start
	_tick_damage = tick_damage
	_pool_radius = pool_radius
	var flight_time: float = clampf(0.65 + start.distance_to(target) * 0.03, 0.65, 1.0)
	target.y = GROUND_HEIGHT
	_velocity = Combat.ballistic_velocity(start, target, flight_time, gravity)

func _process(delta: float) -> void:
	_model.rotate_x(spin_speed * delta)

func _physics_process(delta: float) -> void:
	_velocity.y -= gravity * delta
	global_position += _velocity * delta
	if _velocity.y < 0.0 and global_position.y <= GROUND_HEIGHT:
		_shatter()

func _shatter() -> void:
	set_physics_process(false)
	var pool := pool_scene.instantiate() as FirePool
	Combat.world_root(self).add_child(pool)
	pool.global_position = Vector3(global_position.x, 0.0, global_position.z)
	pool.setup(_pool_radius, _tick_damage)
	queue_free()
