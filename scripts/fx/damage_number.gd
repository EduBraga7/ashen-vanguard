extends Label3D
class_name DamageNumber
## Número de dano flutuante: branco = normal, amarelo e maior = crítico.

const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const CRIT_COLOR: Color = Color(1.0, 0.85, 0.1, 1.0)
const RISE_HEIGHT: float = 1.3
const LIFETIME: float = 0.75

static func spawn(parent: Node, world_position: Vector3, amount: int, is_crit: bool) -> void:
	var number := DamageNumber.new()
	number.text = str(amount)
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.fixed_size = false
	number.shaded = false
	number.double_sided = true
	number.pixel_size = 0.011
	number.font_size = 56
	number.outline_size = 14
	number.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	number.modulate = CRIT_COLOR if is_crit else NORMAL_COLOR
	number.render_priority = 10
	number.outline_render_priority = 9
	parent.add_child(number)
	number.global_position = world_position
	number._animate(is_crit)

func _animate(is_crit: bool) -> void:
	var final_scale: Vector3 = Vector3.ONE * (1.35 if is_crit else 1.0)
	scale = final_scale * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# Pop de entrada, subida suave e fade-out na segunda metade da vida.
	tween.tween_property(self, "scale", final_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y + RISE_HEIGHT, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.tween_property(self, "outline_modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
