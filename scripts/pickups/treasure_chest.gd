extends Area3D
class_name TreasureChest
## Baú de Tesouro dropado pelo mini-chefe. Ao ser tocado pelo herói avisa o jogo (signal) e some.

signal opened

const MODEL: PackedScene = preload("res://assets/models/treasure_chest.glb")

## Tempo até o baú poder ser aberto, para não disparar a tela de recompensa no meio da luta.
@export var arm_delay: float = 0.8

var _opened: bool = false

@onready var _visual: Node3D = $Visual

func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.5
	_visual.add_child(model)
	body_entered.connect(_on_body_entered)
	# Chegada com "pulo" de escala.
	_visual.scale = Vector3.ONE * 0.2
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	monitoring = false
	await get_tree().create_timer(arm_delay).timeout
	monitoring = true

func _process(delta: float) -> void:
	_visual.rotate_y(delta * 0.8)

func _on_body_entered(body: Node3D) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	opened.emit()
	var main := get_tree().current_scene
	if main and main.has_method("on_treasure_chest_opened"):
		main.on_treasure_chest_opened()
	queue_free()
