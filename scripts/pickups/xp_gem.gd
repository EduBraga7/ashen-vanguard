extends Area3D
class_name XPGem
## Cristal de XP. Tier 0 = azul (+1), 1 = verde (+5), 2 = rubi (+25). Voa até o herói ao entrar no raio do ímã.

const MODELS: Array[PackedScene] = [
	preload("res://assets/models/gem_blue.glb"),
	preload("res://assets/models/gem_green.glb"),
	preload("res://assets/models/gem_red.glb"),
]
const XP_VALUES: Array[int] = [1, 5, 25]
const VISUAL_SCALES: Array[float] = [1.4, 1.7, 2.1]

@export_range(0, 2) var tier: int = 0:
	set(value):
		tier = clampi(value, 0, XP_VALUES.size() - 1)
		xp_value = XP_VALUES[tier]
		if is_node_ready() and _visual:
			for child in _visual.get_children():
				child.queue_free()
			var model := MODELS[tier].instantiate() as Node3D
			model.scale = Vector3.ONE * VISUAL_SCALES[tier]
			_visual.add_child(model)

@export var base_speed: float = 4.0
@export var acceleration: float = 28.0
@export var max_speed: float = 24.0

var xp_value: int = 1

var _target: Node3D = null
var _current_speed: float = 0.0
var _bob_timer: float = 0.0
var _is_collected: bool = false

@onready var _visual: Node3D = $Visual:
	get:
		if _visual == null:
			_visual = get_node_or_null("Visual") as Node3D
		return _visual

func _ready() -> void:
	xp_value = XP_VALUES[tier]
	_bob_timer = randf() * TAU
	if _visual and _visual.get_child_count() == 0:
		var model := MODELS[tier].instantiate() as Node3D
		model.scale = Vector3.ONE * VISUAL_SCALES[tier]
		_visual.add_child(model)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Apenas o visual flutua/gira; o corpo do Area3D fica no chão para a física.
	_bob_timer += delta * 3.0
	_visual.position.y = 0.55 + sin(_bob_timer) * 0.08
	_visual.rotate_y(delta * (12.0 if _target else 2.5))

func _physics_process(delta: float) -> void:
	if _target == null or _is_collected:
		return
	if not is_instance_valid(_target):
		_target = null
		return
	_current_speed = minf(_current_speed + acceleration * delta, max_speed)
	var target_pos: Vector3 = _target.global_position
	var dir: Vector3 = target_pos - global_position
	dir.y = 0.0
	if dir.length() < 0.6:
		_consume_gem(_target)
		return
	global_position += dir.normalized() * _current_speed * delta

func attract(collector: Node3D) -> void:
	if _target == null:
		_target = collector
		_current_speed = base_speed

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("collect_xp"):
		_consume_gem(body)

func _consume_gem(collector: Node3D) -> void:
	if _is_collected:
		return
	_is_collected = true
	if collector.has_method("collect_xp"):
		collector.collect_xp(xp_value)
	queue_free()
