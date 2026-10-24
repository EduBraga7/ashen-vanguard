extends Camera3D
class_name TopDownCamera

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 16.0, 9.0)
@export var follow_speed: float = 14.0
@export var pitch_degrees: float = -60.0

func _ready() -> void:
	# Fixed top-down perspective: strict pitch, zero yaw, zero roll
	rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)
	_snap_to_target()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as Node3D
		else:
			return

	var target_pos: Vector3 = target.global_position + offset
	global_position.x = lerp(global_position.x, target_pos.x, follow_speed * delta)
	global_position.z = lerp(global_position.z, target_pos.z, follow_speed * delta)
	global_position.y = target_pos.y
	
	# Strictly maintain fixed top-down angle without any yaw distortion
	rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

func _snap_to_target() -> void:
	if not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as Node3D
	if is_instance_valid(target):
		global_position = target.global_position + offset
		rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)
