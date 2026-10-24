extends CanvasLayer
class_name HUD

@onready var xp_bar: ProgressBar = $TopContainer/XPBar
@onready var level_label: Label = $TopContainer/LevelLabel
@onready var timer_label: Label = $TopContainer/TimerLabel

@onready var hp_bar: ProgressBar = $StatusContainer/HPBar
@onready var hp_label: Label = $StatusContainer/HPBar/HPLabel
@onready var kills_label: Label = $StatusContainer/KillsLabel

@onready var boss_container: Control = $BossContainer
@onready var boss_name_label: Label = $BossContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $BossContainer/BossHPBar

@onready var level_up_panel: Control = $LevelUpPanel
@onready var cards_container: HBoxContainer = $LevelUpPanel/CardsContainer

@onready var chest_panel: Control = $ChestPanel
@onready var chest_rewards_list: VBoxContainer = $ChestPanel/ContentBox/RewardsList
@onready var chest_collect_btn: Button = $ChestPanel/ContentBox/CollectButton

@onready var end_game_panel: Control = $EndGamePanel
@onready var end_title_label: Label = $EndGamePanel/ContentBox/TitleLabel
@onready var end_subtitle_label: Label = $EndGamePanel/ContentBox/SubtitleLabel
@onready var end_stats_label: Label = $EndGamePanel/ContentBox/StatsLabel
@onready var restart_button: Button = $EndGamePanel/ContentBox/RestartButton

var kills_count: int = 0
var _current_level_callback: Callable = Callable()
var _current_chest_callback: Callable = Callable()
var _active_boss: Enemy = null

func _ready() -> void:
	# Garante que a UI receba inputs mesmo durante o get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if boss_container:
		boss_container.visible = false
	if level_up_panel:
		level_up_panel.visible = false
	if chest_panel:
		chest_panel.visible = false
	if end_game_panel:
		end_game_panel.visible = false

	if chest_collect_btn:
		chest_collect_btn.pressed.connect(_on_chest_collect_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func setup_player(player: Knight) -> void:
	if not player:
		return
	player.health_changed.connect(_on_health_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.level_up.connect(_on_level_up)

func update_timer(formatted_time: String) -> void:
	if timer_label:
		timer_label.text = formatted_time

func update_kills(kills: int) -> void:
	kills_count = kills
	if kills_label:
		kills_label.text = "Kills: %d" % kills_count

func _on_health_changed(current: int, max_health: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d HP" % [current, max_health]

func _on_xp_changed(current: int, next_xp: int, level: int) -> void:
	if xp_bar:
		xp_bar.max_value = next_xp
		xp_bar.value = current
	if level_label:
		level_label.text = "LV. %d" % level

func _on_level_up(new_level: int) -> void:
	if level_label:
		level_label.text = "LV. %d" % new_level

# --- BOSS BAR ---

func show_boss_bar(boss: Enemy) -> void:
	_active_boss = boss
	if not boss_container:
		return
	boss_container.visible = true
	boss_name_label.text = boss.display_name
	boss_hp_bar.max_value = boss.max_health
	boss_hp_bar.value = boss.current_health
	boss.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_boss_died)

func _on_boss_health_changed(cur: int, max_hp: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = cur

func _on_boss_died(_boss: Enemy) -> void:
	if boss_container:
		boss_container.visible = false
	_active_boss = null

# --- LEVEL UP PANEL ---

func show_level_up(options: Array[Dictionary], on_select: Callable) -> void:
	_current_level_callback = on_select
	level_up_panel.visible = true

	# Limpa cartas anteriores
	for child in cards_container.get_children():
		child.queue_free()

	for opt in options:
		var card := _create_upgrade_card(opt)
		cards_container.add_child(card)

func _create_upgrade_card(opt: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(240, 320)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Estilo escuro sóbrio
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.28, 0.32, 0.40, 1.0)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.corner_radius_bottom_left = 6

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.15, 0.18, 0.24, 0.98)
	style_hover.border_color = Color(0.9, 0.75, 0.25, 1.0)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.offset_left = 16
	vbox.offset_top = 18
	vbox.offset_right = -16
	vbox.offset_bottom = -18
	vbox.add_theme_constant_override("separation", 10)
	btn.add_child(vbox)

	# Tag de categoria / tipo
	var tag_label := Label.new()
	var kind_str: String = opt.get("kind", "")
	if kind_str == "weapon":
		tag_label.text = "⚔️ ARMA ATIVA"
		tag_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	elif kind_str == "passive":
		tag_label.text = "🛡️ ITEM PASSIVO"
		tag_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
	else:
		tag_label.text = "✨ DÁDIVA"
		tag_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	tag_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tag_label)

	# Título do item
	var title_lbl := Label.new()
	title_lbl.text = opt.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	# Nível alvo
	var lvl_num: int = opt.get("level", 1)
	var lvl_lbl := Label.new()
	lvl_lbl.text = "NOVO!" if lvl_num == 1 else "Nível %d" % lvl_num
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3) if lvl_num == 1 else Color(0.7, 0.7, 0.7))
	vbox.add_child(lvl_lbl)

	# Linha divisória
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Descrição do efeito
	var desc_lbl := Label.new()
	desc_lbl.text = opt.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	btn.pressed.connect(func(): _on_card_selected(opt.get("id", "")))
	return btn

func _on_card_selected(opt_id: String) -> void:
	level_up_panel.visible = false
	if _current_level_callback.is_valid():
		_current_level_callback.call(opt_id)

# --- CHEST PANEL ---

func show_chest_rewards(rewards: Array[String], on_close: Callable) -> void:
	_current_chest_callback = on_close
	chest_panel.visible = true

	for child in chest_rewards_list.get_children():
		child.queue_free()

	for item in rewards:
		var lbl := Label.new()
		lbl.text = "✦  %s" % item
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		chest_rewards_list.add_child(lbl)

func _on_chest_collect_pressed() -> void:
	chest_panel.visible = false
	if _current_chest_callback.is_valid():
		_current_chest_callback.call()

# --- END GAME PANELS (VICTORY / DEFEAT) ---

func show_victory(time_survived: float, level: int, kills: int) -> void:
	end_game_panel.visible = true
	end_title_label.text = "VITÓRIA!"
	end_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	end_subtitle_label.text = "Você sobreviveu aos 5 minutos no Bastião em Ruínas!"

	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	end_stats_label.text = "Tempo Sobrevivido: %02d:%02d\nNível Alcançado: LV. %d\nInimigos Derrotados: %d" % [
		minutes, seconds, level, kills
	]

func show_game_over(time_survived: float, level: int, kills: int) -> void:
	end_game_panel.visible = true
	end_title_label.text = "VOCÊ SUCUMBIU..."
	end_title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	end_subtitle_label.text = "A escuridão do Bastião consumiu sua alma."

	var minutes: int = int(time_survived) / 60
	var seconds: int = int(time_survived) % 60
	end_stats_label.text = "Tempo Sobrevivido: %02d:%02d\nNível Alcançado: LV. %d\nInimigos Derrotados: %d" % [
		minutes, seconds, level, kills
	]

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
