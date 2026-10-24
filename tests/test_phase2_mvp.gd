extends SceneTree

var _failures: int = 0
var _passes: int = 0

func _initialize() -> void:
	print("\n==============================================")
	print("--- Running Ashen Vanguard MVP Test Suite ---")
	print("==============================================")

	test_knight_core_attributes()
	test_knight_passives_and_regen()
	test_xp_gems_and_magnet()
	test_roast_meat_heal()
	test_weapon_manager_and_arsenal()
	test_wave_timeline_and_boss()
	test_treasure_chest()

	print("\n==============================================")
	print("--- MVP Test Results: %d Passed, %d Failed ---" % [_passes, _failures])
	print("==============================================")
	if _failures > 0:
		quit(1)
	else:
		quit(0)

func assert_eq(actual, expected, message: String) -> void:
	if actual == expected:
		_passes += 1
		print("  [PASS] %s" % message)
	else:
		_failures += 1
		printerr("  [FAIL] %s: expected '%s', got '%s'" % [message, str(expected), str(actual)])

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("  [PASS] %s" % message)
	else:
		_failures += 1
		printerr("  [FAIL] %s: condition was FALSE" % message)

func test_knight_core_attributes() -> void:
	print("\n--- Testing Knight Core Attributes ---")
	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight: Knight = knight_scene.instantiate() as Knight
	root.add_child(knight)

	assert_eq(knight.max_health, 120, "Knight max health is 120")
	assert_eq(knight.current_health, 120, "Knight starts with 120 current health")
	assert_eq(knight.move_speed, 5.2, "Knight speed is 5.2 m/s")
	assert_eq(knight.get_armor(), 2, "Knight base armor is 2")
	assert_eq(knight.get_magnet_radius(), 2.5, "Knight base magnet radius is 2.5m")

	# Test armor reduction (10 damage -> 10 - 2 = 8 net damage, 120 - 8 = 112)
	knight.take_damage(10)
	assert_eq(knight.current_health, 112, "Armor reduces 10 damage to 8 (120 - 8 = 112)")

	# Test minimum 1 damage rule (even with 2 armor against 1 damage)
	knight.current_health = 100
	knight._damage_cooldown = 0.0
	knight.take_damage(1)
	assert_eq(knight.current_health, 99, "Minimum 1 damage is always dealt (100 - 1 = 99)")

	knight.queue_free()

func test_knight_passives_and_regen() -> void:
	print("\n--- Testing Passives Scaling and HP Regen ---")
	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight: Knight = knight_scene.instantiate() as Knight
	root.add_child(knight)

	var wm: WeaponManager = knight.weapon_manager

	# Apply Agile Boots (+10% move speed per level)
	var prev_speed: float = knight.get_move_speed()
	wm.add_upgrade("agile_boots")
	assert_true(is_equal_approx(knight.get_move_speed(), prev_speed * 1.1), "Agile Boots +10% move speed")

	# Apply Magnet Amulet (+30% magnet radius per level)
	var base_radius: float = knight.magnet_radius
	wm.add_upgrade("magnet_amulet")
	assert_true(is_equal_approx(knight.get_magnet_radius(), base_radius * 1.3), "Magnet Amulet +30% magnet radius")

	# Apply Iron Shield (+1 armor and 1 HP regen every 5 seconds)
	var base_armor: int = knight.get_armor()
	wm.add_upgrade("iron_shield")
	assert_eq(knight.get_armor(), base_armor + 1, "Iron Shield grants +1 armor")
	assert_true(is_equal_approx(knight.hp_regen_per_second, 0.2), "Iron Shield grants 1 HP / 5s = 0.2 HP/s")

	# Test passive regeneration over time
	knight.current_health = 100
	knight._apply_regeneration(5.0) # 5 seconds of regen = +1 HP
	assert_eq(knight.current_health, 101, "Regenerated 1 HP after 5 seconds")

	knight.queue_free()

func test_xp_gems_and_magnet() -> void:
	print("\n--- Testing XP Gems and Drops ---")
	var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")

	# Blue Gem (Tier 0: +1 XP)
	var gem_blue: XPGem = gem_scene.instantiate() as XPGem
	gem_blue.tier = 0
	root.add_child(gem_blue)
	assert_eq(gem_blue.xp_value, 1, "Blue gem gives +1 XP")
	gem_blue.queue_free()

	# Green Gem (Tier 1: +5 XP)
	var gem_green: XPGem = gem_scene.instantiate() as XPGem
	gem_green.tier = 1
	root.add_child(gem_green)
	assert_eq(gem_green.xp_value, 5, "Green gem gives +5 XP")
	gem_green.queue_free()

	# Red Gem (Tier 2: +25 XP)
	var gem_red: XPGem = gem_scene.instantiate() as XPGem
	gem_red.tier = 2
	root.add_child(gem_red)
	assert_eq(gem_red.xp_value, 25, "Red gem gives +25 XP")
	gem_red.queue_free()

func test_roast_meat_heal() -> void:
	print("\n--- Testing Roast Meat (Rare Drop) ---")
	var meat_scene: PackedScene = load("res://scenes/pickups/roast_meat.tscn")
	var meat: RoastMeat = meat_scene.instantiate() as RoastMeat
	root.add_child(meat)
	assert_eq(meat.heal_amount, 30, "Roast meat heals 30 HP")

	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight: Knight = knight_scene.instantiate() as Knight
	root.add_child(knight)

	knight.current_health = 60
	knight.heal(meat.heal_amount)
	assert_eq(knight.current_health, 90, "Knight healed from 60 to 90 HP")

	# Should not overheal beyond max_health (120)
	knight.heal(50)
	assert_eq(knight.current_health, 120, "Knight healing capped at 120 max HP")

	meat.queue_free()
	knight.queue_free()

func test_weapon_manager_and_arsenal() -> void:
	print("\n--- Testing Arsenal and Upgrade Rolling ---")
	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight: Knight = knight_scene.instantiate() as Knight
	root.add_child(knight)

	var wm: WeaponManager = knight.weapon_manager
	assert_eq(wm.get_level("orbit_blades"), 1, "Orbit Blades starts equipped at level 1")

	# Test rolling 3 options
	var options: Array[Dictionary] = wm.roll_options(3)
	assert_eq(options.size(), 3, "Rolls exactly 3 upgrade options")

	# Test equipping each active weapon
	wm.add_upgrade("magic_darts")
	assert_eq(wm.get_level("magic_darts"), 1, "Equipped Magic Darts at Level 1")

	wm.add_upgrade("battle_axe")
	assert_eq(wm.get_level("battle_axe"), 1, "Equipped Battle Axe at Level 1")

	wm.add_upgrade("fire_flask")
	assert_eq(wm.get_level("fire_flask"), 1, "Equipped Fire Flask at Level 1")

	# Test Orbit Blades level 2 scaling (+1 blade, total 3)
	wm.add_upgrade("orbit_blades")
	assert_eq(wm.get_level("orbit_blades"), 2, "Orbit Blades upgraded to Level 2")

	var blades: OrbitBlades = wm._weapon_nodes["orbit_blades"] as OrbitBlades
	assert_eq(blades.blade_count, 3, "Orbit Blades Level 2 has 3 orbiting blades")
	assert_eq(blades.damage, 19, "Orbit Blades Level 2 deals 19 damage")

	knight.queue_free()

func test_wave_timeline_and_boss() -> void:
	print("\n--- Testing Wave Timeline and Boss ---")
	var wm := WaveManager.new()
	root.add_child(wm)

	# 00:00 - 01:00: spawn interval is 1.8s
	wm.elapsed_time = 30.0
	assert_eq(wm._get_spawn_interval(), 1.8, "Early game (00:30) spawn interval is 1.8s")

	# 01:00 - 02:30: spawn interval doubles to 0.9s
	wm.elapsed_time = 90.0
	assert_eq(wm._get_spawn_interval(), 0.9, "Mid game (01:30) spawn density doubles to 0.9s")

	# Check boss scene load
	var boss: Enemy = wm.boss_scene.instantiate() as Enemy
	root.add_child(boss)
	assert_true(boss.is_boss, "Mini-Boss is flagged as boss")
	assert_eq(boss.max_health, 500, "Boss has 500 max HP")
	assert_eq(boss.touch_damage, 20, "Boss deals 20 touch damage")
	assert_true(boss.chest_drop_scene != null, "Boss drops treasure chest")

	boss.queue_free()
	wm.queue_free()

func test_treasure_chest() -> void:
	print("\n--- Testing Treasure Chest ---")
	var chest_scene: PackedScene = load("res://scenes/pickups/treasure_chest.tscn")
	var chest: TreasureChest = chest_scene.instantiate() as TreasureChest
	root.add_child(chest)
	assert_true(chest != null, "TreasureChest instantiated successfully")
	chest.queue_free()
