extends Node3D
class_name Main

@export var initial_enemies_count: int = 4

var kills: int = 0

@onready var player: Knight = $Knight
@onready var hud: HUD = $HUD
@onready var enemy_container: Node3D = $EnemyContainer
@onready var wave_manager: WaveManager = $WaveManager

func _ready() -> void:
	if hud and player:
		hud.setup_player(player)

	if player:
		player.level_up.connect(_on_player_level_up)
		player.player_died.connect(_on_player_died)

	if wave_manager:
		wave_manager.setup(player, enemy_container)
		wave_manager.time_updated.connect(_on_time_updated)
		wave_manager.boss_spawned.connect(_on_boss_spawned)
		wave_manager.victory_reached.connect(_on_victory_reached)

	# Inimigos iniciais para combate imediato
	_spawn_initial_dummies()

func register_kill() -> void:
	kills += 1
	if hud:
		hud.update_kills(kills)

func on_treasure_chest_opened() -> void:
	get_tree().paused = true
	var rewards: Array[String] = []
	if player and player.weapon_manager:
		rewards = player.weapon_manager.grant_random_upgrades(2)
	if hud:
		hud.show_chest_rewards(rewards, _on_chest_rewards_closed)

func _on_chest_rewards_closed() -> void:
	get_tree().paused = false

func _on_time_updated(_elapsed: float, formatted_time: String) -> void:
	if hud:
		hud.update_timer(formatted_time)

func _on_boss_spawned(boss: Enemy) -> void:
	if hud:
		hud.show_boss_bar(boss)

func _on_player_level_up(_new_level: int) -> void:
	if not player or not player.weapon_manager:
		return
	get_tree().paused = true
	var options: Array[Dictionary] = player.weapon_manager.roll_options(3)
	if hud:
		hud.show_level_up(options, _on_level_up_selected)

func _on_level_up_selected(chosen_id: String) -> void:
	if player and player.weapon_manager:
		player.weapon_manager.apply_option(chosen_id)
	get_tree().paused = false

func _on_player_died() -> void:
	await get_tree().create_timer(0.6).timeout
	get_tree().paused = true
	if hud:
		var elapsed: float = wave_manager.elapsed_time if wave_manager else 0.0
		var lvl: int = player.current_level if player else 1
		hud.show_game_over(elapsed, lvl, kills)

func _on_victory_reached(total_time: float) -> void:
	get_tree().paused = true
	if hud:
		var lvl: int = player.current_level if player else 1
		hud.show_victory(total_time, lvl, kills)

func _spawn_initial_dummies() -> void:
	if not player or not wave_manager or not wave_manager.skeleton_scene:
		return
	var initial_offsets: Array[Vector3] = [
		Vector3(0, 0, 4.0),
		Vector3(-3.0, 0, 4.5),
		Vector3(3.0, 0, 4.5),
		Vector3(0, 0, -4.0)
	]
	for offset in initial_offsets:
		var skeleton := wave_manager.skeleton_scene.instantiate() as Node3D
		if skeleton:
			enemy_container.add_child(skeleton)
			skeleton.global_position = player.global_position + offset
