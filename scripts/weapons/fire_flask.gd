extends Node3D
class_name FireFlask
## Frasco de Fogo: lança frascos na direção de maior aglomeração (ou numa distância média aleatória).
## Ao cair, cada frasco cria uma poça de chamas de 3s com dano contínuo.

@export var base_cooldown: float = 3.2
@export var tick_damage: int = 5
@export var pool_radius: float = 1.5
@export var flask_count: int = 1
@export var target_range: float = 12.0
@export var cluster_radius: float = 3.0
@export var throw_gap: float = 0.3
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/flask_projectile.tscn")

var level: int = 1
var cooldown: float = 3.2

var _cooldown_timer: float = 0.0
var _pending_throws: int = 0
var _gap_timer: float = 0.0

func _ready() -> void:
	set_level(1)

## Cada nível: +2 dano por tique, +0.2m de raio, recarga -0.2s (mín. 1.8s) e +1 frasco a cada 2 níveis (1, 1, 2, 2, 3).
func set_level(new_level: int) -> void:
	level = new_level
	tick_damage = 5 + 2 * (level - 1)
	pool_radius = 1.5 + 0.2 * float(level - 1)
	cooldown = maxf(1.8, base_cooldown - 0.2 * float(level - 1))
	flask_count = 1 + int((level - 1) * 0.5)

func _physics_process(delta: float) -> void:
	if _pending_throws > 0:
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_pending_throws -= 1
			_gap_timer = throw_gap
			_throw_flask()
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_cooldown_timer = cooldown
		_pending_throws = flask_count
		_gap_timer = 0.0

func _throw_flask() -> void:
	var start: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	var flask := projectile_scene.instantiate() as FlaskProjectile
	Combat.world_root(self).add_child(flask)
	flask.launch(start, _pick_landing_point(), tick_damage, pool_radius)

## Entre até 10 inimigos sorteados, escolhe o que tem mais vizinhos num raio curto (aglomeração).
## Sem inimigos por perto, cai a 5-8m numa direção aleatória.
func _pick_landing_point() -> Vector3:
	var candidates: Array[Node3D] = Combat.enemies_in_range(self, target_range)
	if candidates.size() > 0:
		candidates.shuffle()
		var sample: Array[Node3D] = candidates.slice(0, 10)
		var best_position: Vector3 = sample[0].global_position
		var best_neighbors: int = -1
		for enemy in sample:
			var neighbors: int = 0
			for other in candidates:
				if enemy.global_position.distance_to(other.global_position) <= cluster_radius:
					neighbors += 1
			if neighbors > best_neighbors:
				best_neighbors = neighbors
				best_position = enemy.global_position
		return best_position
	var angle: float = randf() * TAU
	var distance: float = randf_range(5.0, 8.0)
	return global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
