extends Area3D
class_name FirePool
## Poça de chamas: dura 3s e causa dano contínuo (DoT) aos inimigos dentro dela, com partículas,
## shader de chão animado e luz tremulante.

const FIRE_SHADER: Shader = preload("res://assets/shaders/fire_pool.gdshader")

@export var duration: float = 3.0
@export var tick_interval: float = 0.5
@export var fade_time: float = 0.5
@export var base_light_energy: float = 2.5

var _damage: int = 5
var _radius: float = 1.5
var _elapsed: float = 0.0
var _tick_timer: float = 0.1
var _material: ShaderMaterial = null
var _light: OmniLight3D = null
var _particles: GPUParticles3D = null

@onready var _shape: CollisionShape3D = $CollisionShape3D

func setup(radius: float, tick_damage: int) -> void:
	_radius = radius
	_damage = tick_damage
	var cylinder := CylinderShape3D.new()
	cylinder.radius = _radius
	cylinder.height = 1.0
	_shape.shape = cylinder
	_shape.position.y = 0.5
	_build_visuals()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += tick_interval
		for body in get_overlapping_bodies():
			Combat.hit(body, _damage)

func _process(_delta: float) -> void:
	if _material == null:
		return
	var fade: float = clampf((duration - _elapsed) / fade_time, 0.0, 1.0)
	_material.set_shader_parameter("fade", fade)
	if fade < 1.0 and _particles.emitting:
		_particles.emitting = false
	var flicker: float = 0.9 + 0.1 * sin(_elapsed * 22.0) + randf_range(-0.04, 0.04)
	_light.light_energy = base_light_energy * fade * flicker

func _build_visuals() -> void:
	# Chão em chamas (quad com shader de ruído animado).
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_radius * 2.3, _radius * 2.3)
	_material = ShaderMaterial.new()
	_material.shader = FIRE_SHADER
	ground.mesh = plane
	ground.material_override = _material
	ground.position.y = 0.05
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	# Labaredas subindo.
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(_radius * 0.85, 0.05, _radius * 0.85)
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.4
	process.gravity = Vector3(0.0, 0.8, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.35, 0.9), Color(1.0, 0.4, 0.05, 0.7), Color(0.3, 0.05, 0.0, 0.0)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture

	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var soft_texture := GradientTexture2D.new()
	soft_texture.gradient = soft
	soft_texture.fill = GradientTexture2D.FILL_RADIAL
	soft_texture.fill_from = Vector2(0.5, 0.5)
	soft_texture.fill_to = Vector2(0.5, 0.0)
	soft_texture.width = 64
	soft_texture.height = 64

	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_material.vertex_color_use_as_albedo = true
	flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_material.albedo_texture = soft_texture
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = flame_material

	_particles = GPUParticles3D.new()
	_particles.process_material = process
	_particles.draw_pass_1 = quad
	_particles.amount = clampi(int(_radius * 14.0), 12, 60)
	_particles.lifetime = 0.9
	_particles.position.y = 0.1
	_particles.visibility_aabb = AABB(Vector3(-_radius - 1.0, -1.0, -_radius - 1.0), Vector3(_radius * 2.0 + 2.0, 4.0, _radius * 2.0 + 2.0))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = base_light_energy
	_light.omni_range = _radius * 3.0 + 2.0
	_light.position.y = 0.8
	add_child(_light)
