extends CharacterBody3D
class_name Enemy
## Inimigo corpo-a-corpo genérico (esqueleto, morcego e chefe usam este mesmo script com valores diferentes).

signal health_changed(current: int, max_health: int)
signal died(enemy: Enemy)

@export var display_name: String = "Esqueleto"
@export var max_health: int = 20
@export var move_speed: float = 2.4
@export var touch_damage: int = 8
## Variação aleatória de velocidade (±) para a horda não andar em bloco perfeito.
@export_range(0.0, 0.5) var speed_variance: float = 0.1
## Tier do cristal: 0 = azul (+1 XP), 1 = verde (+5 XP), 2 = rubi (+25 XP).
@export_range(0, 2) var xp_tier: int = 0
@export_range(0.0, 1.0) var roast_chance: float = 0.03
@export var knockback_strength: float = 5.0
## Altura (m, já considerando escala do visual) onde nasce o número de dano.
@export var head_height: float = 1.9
## Oscilação lateral do voo (morcegos). 0 = linha reta.
@export var weave_amount: float = 0.0
@export var is_boss: bool = false
@export var xp_gem_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
@export var roast_meat_scene: PackedScene = preload("res://scenes/pickups/roast_meat.tscn")
@export var chest_drop_scene: PackedScene = null

var current_health: int = 20
var is_dead: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO

var _player: Node3D = null
var _speed: float = 2.4
var _time: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _flash_material: StandardMaterial3D = null
var _flash_timer: float = 0.0

@onready var _visuals: Node3D = $Visuals

func _ready() -> void:
	current_health = max_health
	_speed = move_speed * randf_range(1.0 - speed_variance, 1.0 + speed_variance)
	_time = randf() * TAU
	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
		_create_boss_health_bar()

	for node in _visuals.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)

	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 0.75)

	_find_player()

func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node3D

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_flash(false)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_instance_valid(_player):
		_find_player()
		if not is_instance_valid(_player):
			return

	_time += delta
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0

	var move_dir: Vector3 = Vector3.ZERO
	if to_player.length() > 0.1:
		move_dir = to_player.normalized()
		if weave_amount > 0.0:
			var side: Vector3 = Vector3(-move_dir.z, 0.0, move_dir.x)
			move_dir = (move_dir + side * sin(_time * 4.5) * weave_amount).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(move_dir.x, move_dir.z), 10.0 * delta)

	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 10.0 * delta)
	velocity = move_dir * _speed + knockback_velocity
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

	# Dano de contato: o corpo do jogador está na máscara do inimigo, então ele "esbarra" nele.
	for i in range(get_slide_collision_count()):
		var collider: Object = get_slide_collision(i).get_collider()
		if collider is Node3D and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(touch_damage)

func take_damage(amount: int, is_crit: bool = false) -> void:
	if is_dead:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	var wroot := Combat.world_root(self)
	if wroot:
		var jitter: Vector3 = Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.2, 0.2))
		DamageNumber.spawn(wroot, global_position + Vector3(0.0, head_height, 0.0) + jitter, amount, is_crit)

	_set_flash(true)
	_flash_timer = 0.1

	if is_instance_valid(_player):
		var push_dir: Vector3 = global_position - _player.global_position
		push_dir.y = 0.0
		knockback_velocity = push_dir.normalized() * knockback_strength

	if current_health <= 0:
		_die()

func _set_flash(enabled: bool) -> void:
	for mesh in _meshes:
		mesh.material_overlay = _flash_material if enabled else null

func _die() -> void:
	is_dead = true
	remove_from_group("enemies")
	if is_boss:
		remove_from_group("bosses")
	_spawn_drops()
	died.emit(self)
	queue_free()

func _spawn_drops() -> void:
	var drop_parent: Node = get_parent()
	if chest_drop_scene:
		var chest := chest_drop_scene.instantiate() as Node3D
		drop_parent.add_child(chest)
		chest.global_position = global_position
	if xp_gem_scene:
		var gem := xp_gem_scene.instantiate() as XPGem
		gem.tier = xp_tier
		drop_parent.add_child(gem)
		gem.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	if roast_meat_scene and randf() < roast_chance:
		var meat := roast_meat_scene.instantiate() as Node3D
		drop_parent.add_child(meat)
		meat.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))

var _boss_bar_fill: MeshInstance3D = null

func _create_boss_health_bar() -> void:
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0.0, head_height + 0.5, 0.0)
	add_child(bar_root)

	# Fundo escuro da barra
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(2.4, 0.22, 0.06)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.1, 0.9)
	var bg_inst := MeshInstance3D.new()
	bg_inst.mesh = bg_mesh
	bg_inst.material_override = bg_mat
	bar_root.add_child(bg_inst)

	# Barra vermelha de vida
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(2.32, 0.16, 0.07)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.9, 0.15, 0.15, 1.0)
	_boss_bar_fill = MeshInstance3D.new()
	_boss_bar_fill.mesh = fill_mesh
	_boss_bar_fill.material_override = fill_mat
	bar_root.add_child(_boss_bar_fill)

	health_changed.connect(_on_health_changed_update_bar)

func _on_health_changed_update_bar(cur: int, max_hp: int) -> void:
	if _boss_bar_fill:
		var ratio: float = clampf(float(cur) / float(max_hp), 0.0, 1.0)
		_boss_bar_fill.scale.x = ratio
		_boss_bar_fill.position.x = -(1.0 - ratio) * 1.16
