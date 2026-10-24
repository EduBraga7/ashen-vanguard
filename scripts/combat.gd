class_name Combat
## Funções estáticas compartilhadas pelas armas (4 armas usam as mesmas regras de dano/mira).

const CRIT_CHANCE: float = 0.1
const CRIT_MULTIPLIER: int = 2

## Aplica dano de arma a um inimigo, rolando crítico. Ignora qualquer alvo que não seja inimigo.
static func hit(target: Node, base_damage: int) -> void:
	if not is_instance_valid(target) or not target.is_in_group("enemies"):
		return
	var is_crit: bool = randf() < CRIT_CHANCE
	var amount: int = base_damage * CRIT_MULTIPLIER if is_crit else base_damage
	target.take_damage(amount, is_crit)

## Nó onde projéteis, poças e números flutuantes são adicionados (cena atual ou root em testes headless).
static func world_root(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	var tree: SceneTree = from.get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene else tree.root

## Inimigo vivo mais próximo no plano XZ dentro de max_range (null se nenhum).
static func nearest_enemy(from: Node3D, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_sq: float = max_range * max_range
	var origin: Vector3 = from.global_position
	for node in from.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		var offset: Vector3 = enemy.global_position - origin
		offset.y = 0.0
		var dist_sq: float = offset.length_squared()
		if dist_sq < best_sq:
			best_sq = dist_sq
			best = enemy
	return best

## Inimigos vivos a até max_range no plano XZ.
static func enemies_in_range(from: Node3D, max_range: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var origin: Vector3 = from.global_position
	var range_sq: float = max_range * max_range
	for node in from.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		var offset: Vector3 = enemy.global_position - origin
		offset.y = 0.0
		if offset.length_squared() <= range_sq:
			result.append(enemy)
	return result

## Velocidade inicial de um arremesso parabólico que sai de `start` e chega em `target` após `flight_time`.
static func ballistic_velocity(start: Vector3, target: Vector3, flight_time: float, gravity: float) -> Vector3:
	var velocity: Vector3 = (target - start) / flight_time
	velocity.y = (target.y - start.y + 0.5 * gravity * flight_time * flight_time) / flight_time
	return velocity
