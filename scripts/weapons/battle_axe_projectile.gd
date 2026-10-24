extends Area3D
class_name BattleAxeProjectile
## Machado em voo parabólico. Detona ao tocar o chão ou ao atingir um inimigo durante a descida,
## causando dano em esfera (consulta de física) ao redor do ponto de impacto.

const GROUND_HEIGHT: float = 0.15

@export var arc_gravity: float = 24.0
@export var spin_speed: float = 14.0

var _velocity: Vector3 = Vector3.ZERO
var _damage: int = 25
var _radius: float = 1.8
var _detonate: bool = false

@onready var _model: Node3D = $Model

func launch(start: Vector3, target: Vector3, damage: int, radius: float) -> void:
	global_position = start
	_damage = damage
	_radius = radius
	var flight_time: float = clampf(0.7 + start.distance_to(target) * 0.03, 0.7, 1.1)
	target.y = GROUND_HEIGHT
	_velocity = Combat.ballistic_velocity(start, target, flight_time, arc_gravity)

func _process(delta: float) -> void:
	_model.rotate_x(spin_speed * delta)

func _physics_process(delta: float) -> void:
	if _detonate:
		_impact()
		return
	_velocity.y -= arc_gravity * delta
	global_position += _velocity * delta
	if _velocity.y < 0.0:
		# Só detona na descida (o machado sobe sobre as cabeças sem acertar): chão ou inimigo ao alcance.
		if global_position.y <= GROUND_HEIGHT or (global_position.y < 1.6 and has_overlapping_bodies()):
			_detonate = true

func _impact() -> void:
	set_physics_process(false)
	var impact_position: Vector3 = Vector3(global_position.x, 0.0, global_position.z)

	var sphere := SphereShape3D.new()
	sphere.radius = _radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, impact_position + Vector3(0.0, 0.5, 0.0))
	query.collision_mask = 4 # Enemies
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 96):
		Combat.hit(result["collider"], _damage)

	_spawn_shockwave(impact_position)
	queue_free()

func _spawn_shockwave(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = _radius
	mesh.bottom_radius = _radius
	mesh.height = 0.04
	mesh.radial_segments = 24
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.78, 0.4, 0.55)
	ring.mesh = mesh
	ring.material_override = material
	ring.scale = Vector3(0.25, 1.0, 0.25)
	Combat.world_root(self).add_child(ring)
	ring.global_position = at + Vector3(0.0, 0.06, 0.0)

	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)
