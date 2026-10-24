extends Node3D
class_name BattleAxe
## Machado de Batalha: arremessa machados para o alto que caem em arco sobre os inimigos (dano em área).

@export var base_cooldown: float = 2.4
@export var damage: int = 25
@export var impact_radius: float = 1.8
@export var axe_count: int = 1
@export var target_range: float = 13.0
@export var throw_gap: float = 0.25
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/battle_axe_projectile.tscn")

var level: int = 1
var cooldown: float = 2.4

var _cooldown_timer: float = 0.0
var _pending_throws: int = 0
var _gap_timer: float = 0.0

func _ready() -> void:
	set_level(1)

## Cada nível: +6 dano, +0.2m de área, recarga -0.15s (mín. 1.2s) e +1 machado a cada 2 níveis (1, 1, 2, 2, 3).
func set_level(new_level: int) -> void:
	level = new_level
	damage = 25 + 6 * (level - 1)
	impact_radius = 1.8 + 0.2 * float(level - 1)
	cooldown = maxf(1.2, base_cooldown - 0.15 * float(level - 1))
	axe_count = 1 + int((level - 1) * 0.5)

func _physics_process(delta: float) -> void:
	if _pending_throws > 0:
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_pending_throws -= 1
			_gap_timer = throw_gap
			_throw_axe()
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_cooldown_timer = cooldown
		_pending_throws = axe_count
		_gap_timer = 0.0

func _throw_axe() -> void:
	var start: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	var target: Vector3 = _pick_landing_point()
	var axe := projectile_scene.instantiate() as BattleAxeProjectile
	Combat.world_root(self).add_child(axe)
	axe.launch(start, target, damage, impact_radius)

## Prefere um inimigo aleatório próximo; sem inimigos, cai a 4-7m numa direção aleatória.
func _pick_landing_point() -> Vector3:
	var candidates: Array[Node3D] = Combat.enemies_in_range(self, target_range)
	if candidates.size() > 0:
		var chosen: Node3D = candidates.pick_random()
		return chosen.global_position + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	var angle: float = randf() * TAU
	var distance: float = randf_range(4.0, 7.0)
	return global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
