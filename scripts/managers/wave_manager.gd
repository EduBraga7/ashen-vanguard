extends Node
class_name WaveManager
## Gerencia a linha do tempo de 00:00 a 05:00, controle de densidade e surgimento de inimigos e do mini-chefe.

signal time_updated(elapsed: float, formatted_time: String)
signal boss_spawned(boss: Enemy)
signal victory_reached(total_time: float)

@export var skeleton_scene: PackedScene = preload("res://scenes/enemies/skeleton.tscn")
@export var bat_scene: PackedScene = preload("res://scenes/enemies/bat.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/enemies/boss_renegade_knight.tscn")

@export var max_match_time: float = 300.0 # 05:00 minutos
@export var spawn_distance_min: float = 14.0
@export var spawn_distance_max: float = 18.0

var elapsed_time: float = 0.0
var is_active: bool = true
var boss_has_spawned: bool = false
var match_completed: bool = false

var _spawn_timer: float = 0.0
var _player: Node3D = null
var _enemy_container: Node3D = null

func setup(player: Node3D, container: Node3D) -> void:
	_player = player
	_enemy_container = container

func _process(delta: float) -> void:
	if not is_active or match_completed:
		return

	elapsed_time += delta
	var minutes: int = int(elapsed_time) / 60
	var seconds: int = int(elapsed_time) % 60
	var formatted: String = "%02d:%02d" % [minutes, seconds]
	time_updated.emit(elapsed_time, formatted)

	# 03:00 (180s): Surgimento do primeiro Mini-Chefe
	if elapsed_time >= 180.0 and not boss_has_spawned:
		_spawn_boss()

	# 05:00 (300s): Fim da demonstração do MVP com tela de Vitória
	if elapsed_time >= max_match_time:
		match_completed = true
		victory_reached.emit(elapsed_time)
		return

	# Controle de densidade e ritmo por fase do relógio
	_spawn_timer += delta
	var current_interval: float = _get_spawn_interval()
	if _spawn_timer >= current_interval:
		_spawn_timer = 0.0
		_spawn_wave_tick()

func _get_spawn_interval() -> float:
	# 00:00 a 01:00 (0s - 60s): Grupos lentos a cada 1.8s
	if elapsed_time < 60.0:
		return 1.8
	# 01:00 a 02:30 (60s - 150s): Densidade dobra (0.9s)
	elif elapsed_time < 150.0:
		return 0.9
	# 02:30 a 03:00 (150s - 180s): Pressão crescendo antes do chefe (0.75s)
	elif elapsed_time < 180.0:
		return 0.75
	# 03:00 a 05:00 (180s - 300s): Horda máxima (0.65s)
	else:
		return 0.65

func _get_max_active_enemies() -> int:
	if elapsed_time < 60.0:
		return 25
	elif elapsed_time < 150.0:
		return 50
	else:
		return 80

func _spawn_wave_tick() -> void:
	if not is_instance_valid(_player):
		return

	var active_enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if active_enemies.size() >= _get_max_active_enemies():
		return

	# Tamanho do grupo: 1 a 2 nos primeiros 60s; 2 a 4 a partir de 01:00
	var group_size: int = randi_range(1, 2) if elapsed_time < 60.0 else randi_range(2, 4)
	var base_angle: float = randf() * TAU

	for i in range(group_size):
		var enemy_scene: PackedScene = _pick_enemy_type()
		if not enemy_scene:
			continue

		var dist: float = randf_range(spawn_distance_min, spawn_distance_max)
		var angle: float = base_angle + randf_range(-0.35, 0.35)
		var spawn_pos: Vector3 = _player.global_position + Vector3(
			cos(angle) * dist,
			0.0,
			sin(angle) * dist
		)
		_instantiate_enemy(enemy_scene, spawn_pos)

func _pick_enemy_type() -> PackedScene:
	# 00:00 a 01:00: Apenas Esqueletos Lentos
	if elapsed_time < 60.0:
		return skeleton_scene
	# 01:00 a 02:30: 55% Esqueletos, 45% Morcegos Rápidos
	elif elapsed_time < 150.0:
		return bat_scene if randf() < 0.45 else skeleton_scene
	# 02:30 adiante: 50% Esqueletos, 50% Morcegos Rápidos
	else:
		return bat_scene if randf() < 0.50 else skeleton_scene

func _spawn_boss() -> void:
	boss_has_spawned = true
	if not boss_scene or not is_instance_valid(_player):
		return

	# Boss surge a uma distância imponente
	var angle: float = randf() * TAU
	var boss_pos: Vector3 = _player.global_position + Vector3(
		cos(angle) * 15.0,
		0.0,
		sin(angle) * 15.0
	)
	var boss := boss_scene.instantiate() as Enemy
	if boss:
		if _enemy_container:
			_enemy_container.add_child(boss)
		else:
			get_parent().add_child(boss)
		boss.global_position = boss_pos
		boss_spawned.emit(boss)

func _instantiate_enemy(scene: PackedScene, pos: Vector3) -> void:
	var enemy := scene.instantiate() as Node3D
	if enemy:
		if _enemy_container:
			_enemy_container.add_child(enemy)
		else:
			get_parent().add_child(enemy)
		enemy.global_position = pos
