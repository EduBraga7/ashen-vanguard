extends Node3D
class_name OrbitBlades

@export var damage: int = 15
@export var rotation_speed: float = 3.8
@export var orbit_radius: float = 2.2
@export var blade_count: int = 2
@export var hit_cooldown: float = 0.35

var level: int = 1

var _current_blades: Array[Area3D] = []
var _enemy_hit_cooldowns: Dictionary = {}

func _ready() -> void:
	_rebuild_blades()

func _process(delta: float) -> void:
	# Rotate the entire blade rig smoothly around the player
	rotate_y(rotation_speed * delta)
	
	# Update cooldown timers for enemies that were recently struck
	var dead_targets: Array = []
	for target in _enemy_hit_cooldowns.keys():
		if not is_instance_valid(target):
			dead_targets.append(target)
			continue
		_enemy_hit_cooldowns[target] -= delta
		if _enemy_hit_cooldowns[target] <= 0.0:
			dead_targets.append(target)
	
	for target in dead_targets:
		_enemy_hit_cooldowns.erase(target)

func _physics_process(_delta: float) -> void:
	# Check for overlaps on each blade
	for blade in _current_blades:
		var overlapping_bodies: Array[Node3D] = blade.get_overlapping_bodies()
		for body in overlapping_bodies:
			_try_hit_target(body)
			
		var overlapping_areas: Array[Area3D] = blade.get_overlapping_areas()
		for area in overlapping_areas:
			var parent := area.get_parent()
			if parent is Node3D:
				_try_hit_target(parent)

func _try_hit_target(target: Node3D) -> void:
	if not is_instance_valid(target) or not target.is_in_group("enemies"):
		return
	if _enemy_hit_cooldowns.has(target):
		return
		
	Combat.hit(target, damage)
	_enemy_hit_cooldowns[target] = hit_cooldown

## Nível 1 = 2 lâminas. Cada nível adiciona 1 lâmina, aumenta o raio de órbita e o dano.
func set_level(new_level: int) -> void:
	level = new_level
	blade_count = 1 + level
	orbit_radius = 2.2 + 0.25 * float(level - 1)
	damage = 15 + 4 * (level - 1)
	_rebuild_blades()

func set_blade_count(count: int) -> void:
	blade_count = count
	_rebuild_blades()

func _rebuild_blades() -> void:
	for blade in _current_blades:
		if is_instance_valid(blade):
			blade.queue_free()
	_current_blades.clear()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.7, 1.0)
	material.emission_energy_multiplier = 2.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(blade_count):
		var angle: float = (TAU / float(blade_count)) * float(i)
		var blade_area := Area3D.new()
		blade_area.name = "BladeArea%d" % i
		# Layer 4 (bit 8) = PlayerHitbox, Mask 3 (bit 4) = Enemies
		blade_area.collision_layer = 8
		blade_area.collision_mask = 4
		blade_area.monitoring = true
		
		# Position along circular orbit
		var pos := Vector3(cos(angle) * orbit_radius, 0.6, sin(angle) * orbit_radius)
		blade_area.position = pos
		# Tangent rotation so the blade points along rotation direction
		blade_area.rotation.y = -angle

		# Collision Shape
		var col_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.4, 0.4, 1.4)
		col_shape.shape = box_shape
		blade_area.add_child(col_shape)

		# Visual Blade Mesh
		var mesh_instance := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.25, 0.08, 1.3)
		box_mesh.material = material
		mesh_instance.mesh = box_mesh
		blade_area.add_child(mesh_instance)

		# Crossguard Visual
		var guard_instance := MeshInstance3D.new()
		var guard_mesh := BoxMesh.new()
		guard_mesh.size = Vector3(0.55, 0.1, 0.15)
		guard_mesh.material = material
		guard_instance.mesh = guard_mesh
		guard_instance.position = Vector3(0, 0, 0.5)
		blade_area.add_child(guard_instance)

		add_child(blade_area)
		_current_blades.append(blade_area)
