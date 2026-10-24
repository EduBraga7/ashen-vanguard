extends Node3D
class_name MagicDarts
## Dardos Mágicos: a cada recarga dispara uma rajada de dardos retos contra o inimigo mais próximo.

@export var base_cooldown: float = 1.3
@export var damage: int = 12
@export var dart_count: int = 1
@export var projectile_speed: float = 18.0
@export var max_range: float = 22.0
@export var burst_gap: float = 0.09
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/magic_dart.tscn")

var level: int = 1
var cooldown: float = 1.3

var _cooldown_timer: float = 0.0
var _pending_shots: int = 0
var _gap_timer: float = 0.0

func _ready() -> void:
	set_level(1)

## Cada nível: +3 dano, recarga -0.12s (mín. 0.6s) e +1 dardo a cada 2 níveis (1, 2, 2, 3, 3).
func set_level(new_level: int) -> void:
	level = new_level
	damage = 12 + 3 * (level - 1)
	cooldown = maxf(0.6, base_cooldown - 0.12 * float(level - 1))
	dart_count = 1 + int(level * 0.5)

func _physics_process(delta: float) -> void:
	if _pending_shots > 0:
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_pending_shots -= 1
			_gap_timer = burst_gap
			_fire_dart()
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		# Sem alvo no alcance: tenta de novo logo em seguida em vez de gastar a recarga.
		if Combat.nearest_enemy(self, max_range) == null:
			_cooldown_timer = 0.15
			return
		_cooldown_timer = cooldown
		_pending_shots = dart_count
		_gap_timer = 0.0

func _fire_dart() -> void:
	var target: Node3D = Combat.nearest_enemy(self, max_range)
	if target == null:
		return
	var origin: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var dart := projectile_scene.instantiate() as MagicDartProjectile
	Combat.world_root(self).add_child(dart)
	dart.launch(origin, direction.normalized(), damage, projectile_speed)
