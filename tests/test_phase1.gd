extends SceneTree

var _failures: int = 0
var _passes: int = 0

func _initialize() -> void:
	print("\n--- Running Phase 1 Test Suite ---")
	
	test_knight_initial_stats()
	test_knight_armor_and_damage()
	test_knight_xp_and_level_up()
	test_skeleton_damage_and_health()
	test_orbit_blades_configuration()
	
	print("\n--- Test Results: %d Passed, %d Failed ---" % [_passes, _failures])
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

func test_knight_initial_stats() -> void:
	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight = knight_scene.instantiate() as Knight
	root.add_child(knight)
	
	assert_eq(knight.max_health, 120, "Knight max health is 120")
	assert_eq(knight.current_health, 120, "Knight current health starts at 120")
	assert_eq(knight.move_speed, 5.2, "Knight speed is 5.2 m/s")
	assert_eq(knight.armor, 2, "Knight base armor is 2")
	assert_eq(knight.current_level, 1, "Knight starts at Level 1")
	assert_eq(knight.magnet_radius, 2.5, "Knight magnet radius is 2.5m")
	
	knight.queue_free()

func test_knight_armor_and_damage() -> void:
	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight = knight_scene.instantiate() as Knight
	root.add_child(knight)
	
	# Taking 10 damage: net damage should be 10 - 2 (armor) = 8.
	knight.take_damage(10)
	assert_eq(knight.current_health, 112, "Knight armor mitigates 2 damage (120 - 8 = 112)")
	
	knight.queue_free()

func test_knight_xp_and_level_up() -> void:
	var knight_scene: PackedScene = load("res://scenes/characters/knight.tscn")
	var knight = knight_scene.instantiate() as Knight
	root.add_child(knight)
	
	var initial_level: int = knight.current_level
	knight.collect_xp(knight.xp_to_next_level)
	assert_eq(knight.current_level, initial_level + 1, "Knight levels up when collecting required XP")
	
	knight.queue_free()

func test_skeleton_damage_and_health() -> void:
	var skel_scene: PackedScene = load("res://scenes/enemies/dummy_skeleton.tscn")
	var skeleton = skel_scene.instantiate() as DummySkeleton
	root.add_child(skeleton)
	
	assert_eq(skeleton.max_health, 20, "Skeleton max health is 20")
	assert_eq(skeleton.current_health, 20, "Skeleton starts with full health")
	
	skeleton.take_damage(15)
	assert_eq(skeleton.current_health, 5, "Skeleton takes 15 damage, remaining HP is 5")
	
	skeleton.queue_free()

func test_orbit_blades_configuration() -> void:
	var blades_scene: PackedScene = load("res://scenes/weapons/orbit_blades.tscn")
	var blades = blades_scene.instantiate() as OrbitBlades
	root.add_child(blades)
	
	assert_eq(blades.blade_count, 2, "OrbitBlades starts with 2 blades")
	assert_eq(blades.damage, 15, "OrbitBlades deals 15 damage")
	
	blades.queue_free()
