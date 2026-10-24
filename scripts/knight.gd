extends CharacterBody3D
class_name Knight

signal health_changed(current: int, max_health: int)
signal xp_changed(current: int, next_level_xp: int, level: int)
signal level_up(new_level: int)
signal player_died()

@export var max_health: int = 120
@export var move_speed: float = 5.2
@export var acceleration: float = 45.0
@export var friction: float = 35.0
## Armadura base: cada golpe recebido é reduzido por este valor (mínimo de 1 de dano).
@export var armor: int = 2
## Raio base do ímã de XP em metros.
@export var magnet_radius: float = 2.5
## Regeneração passiva de HP por segundo (acumulada e aplicada em HP inteiros).
@export var hp_regen_per_second: float = 0.0

var current_health: int = 120
var current_xp: int = 0
var xp_to_next_level: int = 10
var current_level: int = 1
var is_dead: bool = false

# Bônus vindos dos itens passivos (aplicados pelo WeaponManager).
var bonus_armor: int = 0
var speed_multiplier: float = 1.0
var magnet_multiplier: float = 1.0

var _input_direction: Vector3 = Vector3.ZERO
var _damage_cooldown: float = 0.0
var _regen_accumulator: float = 0.0

@onready var magnet_area: Area3D = $MagnetArea:
	get:
		if magnet_area == null:
			magnet_area = get_node_or_null("MagnetArea") as Area3D
		return magnet_area

@onready var magnet_shape: CollisionShape3D = $MagnetArea/CollisionShape3D:
	get:
		if magnet_shape == null:
			magnet_shape = get_node_or_null("MagnetArea/CollisionShape3D") as CollisionShape3D
		return magnet_shape

@onready var visuals: Node3D = $Visuals:
	get:
		if visuals == null:
			visuals = get_node_or_null("Visuals") as Node3D
		return visuals

@onready var animator: ModelAnimator = $Visuals/ModelAnimator:
	get:
		if animator == null:
			animator = get_node_or_null("Visuals/ModelAnimator") as ModelAnimator
		return animator

@onready var weapon_manager: WeaponManager = $WeaponManager:
	get:
		if weapon_manager == null:
			weapon_manager = get_node_or_null("WeaponManager") as WeaponManager
		if weapon_manager and weapon_manager.starting_weapon != "" and weapon_manager.get_level(weapon_manager.starting_weapon) == 0:
			weapon_manager.add_upgrade(weapon_manager.starting_weapon)
		return weapon_manager

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	# A forma do ímã vem de um sub_resource compartilhado pela cena; cada herói usa a sua cópia.
	if magnet_shape and magnet_shape.shape:
		magnet_shape.shape = magnet_shape.shape.duplicate()
	_update_magnet_radius()
	if magnet_area:
		magnet_area.area_entered.connect(_on_magnet_area_entered)

	health_changed.emit(current_health, max_health)
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _process(delta: float) -> void:
	if is_dead:
		return

	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta

	animator.moving = _input_direction.length_squared() > 0.01
	if _input_direction.length_squared() > 0.01:
		var target_yaw: float = atan2(_input_direction.x, _input_direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_yaw, 15.0 * delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.lerp(Vector3.ZERO, friction * delta)
		velocity.y = 0.0
		move_and_slide()
		global_position.y = 0.0
		return

	_apply_regeneration(delta)

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_input_direction = Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	if _input_direction.length_squared() > 0.01:
		velocity = velocity.move_toward(_input_direction * get_move_speed(), acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, friction * delta)

	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0

func get_armor() -> int:
	return armor + bonus_armor

func get_move_speed() -> float:
	return move_speed * speed_multiplier

func get_magnet_radius() -> float:
	return magnet_radius * magnet_multiplier

func take_damage(amount: int, force: bool = false) -> void:
	if is_dead or (_damage_cooldown > 0.0 and not force):
		return

	var net_damage: int = maxi(amount - get_armor(), 1)
	current_health = maxi(current_health - net_damage, 0)
	_damage_cooldown = 0.4 # Janela curta de invulnerabilidade para a horda não derreter o herói
	health_changed.emit(current_health, max_health)

	_flash_hit()

	if current_health <= 0:
		_die()

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func collect_xp(amount: int) -> void:
	if is_dead:
		return

	current_xp += amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		current_level += 1
		xp_to_next_level = int(xp_to_next_level * 1.4) + 6
		level_up.emit(current_level)

	xp_changed.emit(current_xp, xp_to_next_level, current_level)

## Chamado pelo WeaponManager sempre que o nível de um passivo muda.
func set_passive_bonuses(magnet_mult: float, speed_mult: float, armor_bonus: int, regen_per_second: float) -> void:
	magnet_multiplier = magnet_mult
	speed_multiplier = speed_mult
	bonus_armor = armor_bonus
	hp_regen_per_second = regen_per_second
	_update_magnet_radius()

func _apply_regeneration(delta: float) -> void:
	if hp_regen_per_second <= 0.0 or current_health >= max_health:
		return
	_regen_accumulator += hp_regen_per_second * delta
	if _regen_accumulator >= 1.0:
		var whole_hp: int = int(_regen_accumulator)
		_regen_accumulator -= float(whole_hp)
		heal(whole_hp)

func _on_magnet_area_entered(area: Area3D) -> void:
	if area.has_method("attract"):
		area.attract(self)

func _update_magnet_radius() -> void:
	if magnet_shape and magnet_shape.shape is SphereShape3D:
		(magnet_shape.shape as SphereShape3D).radius = get_magnet_radius()

func _flash_hit() -> void:
	if visuals == null:
		return
	var tween := create_tween()
	if tween:
		tween.tween_property(visuals, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
		tween.tween_property(visuals, "scale", Vector3.ONE, 0.08)

func _die() -> void:
	is_dead = true
	if animator:
		animator.moving = false
	if visuals:
		var tween := create_tween()
		if tween:
			tween.tween_property(visuals, "rotation:x", deg_to_rad(90.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	player_died.emit()
