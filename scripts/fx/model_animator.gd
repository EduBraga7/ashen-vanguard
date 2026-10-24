extends Node
class_name ModelAnimator
## Animação procedural para os modelos .glb: balanço de pernas/braços, bater de asas e leve quicar.
## Procura os nós "LegL", "LegR", "ArmL", "ArmR", "WingL", "WingR" dentro do pai (Visuals).

@export var swing_speed: float = 9.0
@export var swing_degrees: float = 32.0
@export var bob_height: float = 0.05
@export var wing_flap_speed: float = 24.0
@export var wing_flap_degrees: float = 38.0
## Quando false os membros voltam à pose de repouso (asas continuam batendo).
@export var moving: bool = true

var _body: Node3D
var _body_rest_y: float = 0.0
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _rest_rotation: Dictionary = {}
var _phase: float = 0.0
var _wing_phase: float = 0.0
var _blend: float = 0.0

func _ready() -> void:
	_body = get_parent() as Node3D
	_body_rest_y = _body.position.y
	_phase = randf() * TAU
	_wing_phase = randf() * TAU
	for limb_name in ["LegL", "LegR"]:
		_register(limb_name, _legs)
	for limb_name in ["ArmL", "ArmR"]:
		_register(limb_name, _arms)
	for limb_name in ["WingL", "WingR"]:
		_register(limb_name, _wings)

func _register(limb_name: String, bucket: Array[Node3D]) -> void:
	var limb := _body.find_child(limb_name, true, false) as Node3D
	if limb:
		bucket.append(limb)
		_rest_rotation[limb] = limb.rotation

func _process(delta: float) -> void:
	_blend = move_toward(_blend, 1.0 if moving else 0.0, delta * 8.0)
	if moving:
		_phase += delta * swing_speed
	var swing: float = sin(_phase) * deg_to_rad(swing_degrees) * _blend
	# Perna esquerda e braço direito vão juntos (marcha cruzada).
	if _legs.size() == 2:
		_set_pitch(_legs[0], swing)
		_set_pitch(_legs[1], -swing)
	if _arms.size() == 2:
		_set_pitch(_arms[0], -swing)
		_set_pitch(_arms[1], swing)
	if _wings.size() == 2:
		_wing_phase += delta * wing_flap_speed
		var flap: float = sin(_wing_phase) * deg_to_rad(wing_flap_degrees)
		_set_roll(_wings[0], flap)
		_set_roll(_wings[1], -flap)
	_body.position.y = _body_rest_y + absf(sin(_phase)) * bob_height * _blend

func _set_pitch(limb: Node3D, angle: float) -> void:
	var rest: Vector3 = _rest_rotation[limb]
	limb.rotation = Vector3(rest.x + angle, rest.y, rest.z)

func _set_roll(limb: Node3D, angle: float) -> void:
	var rest: Vector3 = _rest_rotation[limb]
	limb.rotation = Vector3(rest.x, rest.y, rest.z + angle)
