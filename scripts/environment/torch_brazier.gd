extends StaticBody3D
class_name TorchBrazier

@export var base_energy: float = 2.2
@export var flame_color: Color = Color(1.0, 0.52, 0.15, 1.0)

var _time: float = 0.0

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var flame_mesh: MeshInstance3D = $FlameMesh

func _ready() -> void:
	# Random phase offset so braziers don't flicker in exact unison
	_time = randf() * 100.0
	if omni_light:
		omni_light.light_color = flame_color
		omni_light.light_energy = base_energy

func _process(delta: float) -> void:
	_time += delta
	if omni_light:
		# Realistic subtle flame flicker
		var flicker: float = sin(_time * 9.0) * 0.12 + sin(_time * 17.0) * 0.08 + (randf() - 0.5) * 0.06
		omni_light.light_energy = base_energy + flicker
	if flame_mesh:
		flame_mesh.scale.y = 1.0 + sin(_time * 11.0) * 0.1
