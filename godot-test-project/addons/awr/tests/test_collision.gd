## AWR Collision Physics Tests
##
## Run with: godot --headless --path . -s addons/awr/tests/test_collision.gd
extends SceneTree

# Preload scripts
var WorldStateScript = preload("res://addons/awr/core/world_state.gd")
var Collision2DScript = preload("res://addons/awr/physics/collision_2d.gd")
var BroadphaseScript = preload("res://addons/awr/physics/broadphase.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0

func _init():
	print("\n=== AWR Collision Physics Tests ===\n")

	test_circle_circle_collision_detect()
	test_circle_circle_no_collision()
	test_collision_resolution_elastic()
	test_collision_resolution_inelastic()
	test_collision_static_body()
	test_boundary_collision()
	test_ray_cast()
	test_broadphase_insert()
	test_broadphase_pairs()
	test_100_bodies_performance()

	print("\n=== Results ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)

	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func test_circle_circle_collision_detect():
	var body_a = {
		"id": "a",
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 0.0, "y": 0.0},
		"radius": 10.0
	}
	var body_b = {
		"id": "b",
		"pos": {"x": 15.0, "y": 0.0},  # 15 apart, radii sum = 20
		"vel": {"x": 0.0, "y": 0.0},
		"radius": 10.0
	}

	var collision = Collision2DScript.circle_circle(body_a, body_b)

	assert(collision.penetration > 0, "Should detect penetration")
	assert(abs(collision.penetration - 5.0) < 0.01, "Penetration should be 5")
	assert(collision.body_a_id == "a", "Body A ID should be set")
	assert(collision.body_b_id == "b", "Body B ID should be set")
	assert(abs(collision.normal.x - 1.0) < 0.01, "Normal should point from A to B")

	_pass("test_circle_circle_collision_detect")

func test_circle_circle_no_collision():
	var body_a = {
		"id": "a",
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 0.0, "y": 0.0},
		"radius": 10.0
	}
	var body_b = {
		"id": "b",
		"pos": {"x": 25.0, "y": 0.0},  # 25 apart, radii sum = 20
		"vel": {"x": 0.0, "y": 0.0},
		"radius": 10.0
	}

	var collision = Collision2DScript.circle_circle(body_a, body_b)

	assert(collision.penetration == 0, "Should not detect collision")

	_pass("test_circle_circle_no_collision")

func test_collision_resolution_elastic():
	var body_a = {
		"id": "a",
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 10.0, "y": 0.0},  # Moving right
		"mass": 1.0,
		"radius": 10.0
	}
	var body_b = {
		"id": "b",
		"pos": {"x": 19.0, "y": 0.0},  # Slightly overlapping
		"vel": {"x": -10.0, "y": 0.0},  # Moving left
		"mass": 1.0,
		"radius": 10.0
	}

	var collision = Collision2DScript.circle_circle(body_a, body_b)
	Collision2DScript.resolve_collision(body_a, body_b, collision, 1.0)  # Fully elastic

	# In elastic collision with equal masses, velocities should swap
	assert(abs(body_a.vel.x - (-10.0)) < 0.1, "Body A should bounce back")
	assert(abs(body_b.vel.x - 10.0) < 0.1, "Body B should bounce back")

	_pass("test_collision_resolution_elastic")

func test_collision_resolution_inelastic():
	var body_a = {
		"id": "a",
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 10.0, "y": 0.0},
		"mass": 1.0,
		"radius": 10.0
	}
	var body_b = {
		"id": "b",
		"pos": {"x": 19.0, "y": 0.0},
		"vel": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"radius": 10.0
	}

	var collision = Collision2DScript.circle_circle(body_a, body_b)
	Collision2DScript.resolve_collision(body_a, body_b, collision, 0.0)  # Fully inelastic

	# In perfectly inelastic collision, both should have same velocity
	var avg_vel = (10.0 + 0.0) / 2.0
	assert(abs(body_a.vel.x - avg_vel) < 0.1, "Body A should share momentum")
	assert(abs(body_b.vel.x - avg_vel) < 0.1, "Body B should share momentum")

	_pass("test_collision_resolution_inelastic")

func test_collision_static_body():
	var body_a = {
		"id": "a",
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 10.0, "y": 0.0},
		"mass": 1.0,
		"radius": 10.0,
		"static": false
	}
	var body_b = {
		"id": "b",
		"pos": {"x": 19.0, "y": 0.0},
		"vel": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"radius": 10.0,
		"static": true  # Static body
	}

	var collision = Collision2DScript.circle_circle(body_a, body_b)
	Collision2DScript.resolve_collision(body_a, body_b, collision, 1.0)

	# Only dynamic body should move
	assert(body_a.vel.x < 0, "Dynamic body should bounce back")
	assert(body_b.vel.x == 0.0, "Static body should not move")

	_pass("test_collision_static_body")

func test_boundary_collision():
	var state = WorldStateScript.new()
	state.bounds = Rect2(0, 0, 100, 100)
	state.bodies = [{
		"id": "ball",
		"pos": {"x": 95.0, "y": 50.0},
		"vel": {"x": 100.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"restitution": 1.0,
		"radius": 10.0
	}]

	# Step until boundary collision
	for i in range(10):
		state.step(1.0 / 60.0)

	# Ball should have bounced and be within bounds
	assert(state.bodies[0].pos.x <= 90.0, "Ball should stay within right bound")
	assert(state.bodies[0].vel.x < 0, "Ball should be moving left after bounce")

	_pass("test_boundary_collision")

func test_ray_cast():
	var state = WorldStateScript.new()
	state.bodies = [
		{"id": "a", "pos": {"x": 50.0, "y": 50.0}, "vel": {"x": 0.0, "y": 0.0}, "radius": 10.0},
		{"id": "b", "pos": {"x": 100.0, "y": 50.0}, "vel": {"x": 0.0, "y": 0.0}, "radius": 10.0}
	]

	var result = Collision2DScript.ray_cast(state, Vector2(0, 50), Vector2(1, 0))

	assert(result.hit, "Ray should hit")
	assert(result.body_id == "a", "Should hit body A first")
	assert(result.t < 50, "Should hit before reaching A's center")

	_pass("test_ray_cast")

func test_broadphase_insert():
	var broadphase = BroadphaseScript.new()
	broadphase.cell_size = 50.0

	broadphase.insert_body({"id": "a", "pos": {"x": 25.0, "y": 25.0}, "radius": 10.0}, 0)
	broadphase.insert_body({"id": "b", "pos": {"x": 75.0, "y": 25.0}, "radius": 10.0}, 1)

	var stats = broadphase.get_stats()
	assert(stats.total_bodies == 2, "Should have 2 bodies")
	assert(stats.total_cells >= 2, "Bodies should be in different cells")

	_pass("test_broadphase_insert")

func test_broadphase_pairs():
	var broadphase = BroadphaseScript.new()
	broadphase.cell_size = 100.0

	# Two bodies far apart - no potential collision
	broadphase.insert_body({"id": "a", "pos": {"x": 0.0, "y": 0.0}, "radius": 10.0}, 0)
	broadphase.insert_body({"id": "b", "pos": {"x": 500.0, "y": 500.0}, "radius": 10.0}, 1)

	var pairs = broadphase.get_potential_pairs()
	assert(pairs.size() == 0, "Far apart bodies should have no pairs")

	# Two bodies close together - potential collision
	broadphase.clear()
	broadphase.insert_body({"id": "a", "pos": {"x": 0.0, "y": 0.0}, "radius": 10.0}, 0)
	broadphase.insert_body({"id": "b", "pos": {"x": 15.0, "y": 0.0}, "radius": 10.0}, 1)

	pairs = broadphase.get_potential_pairs()
	assert(pairs.size() == 1, "Close bodies should have 1 pair")

	_pass("test_broadphase_pairs")

func test_100_bodies_performance():
	var state = WorldStateScript.new()
	state.bounds = Rect2(0, 0, 500, 500)
	state.physics_enabled = false  # Disable body-body collision for baseline performance

	# Create 100 bodies in a grid
	for i in range(10):
		for j in range(10):
			state.bodies.append({
				"id": "body_%d_%d" % [i, j],
				"pos": {"x": 50.0 + i * 40, "y": 50.0 + j * 40},
				"vel": {"x": randf_range(-10, 10), "y": randf_range(-10, 10)},
				"force": {"x": 0.0, "y": 0.0},
				"mass": 1.0,
				"restitution": 0.8,
				"radius": 15.0
			})

	var start_time = Time.get_ticks_msec()

	# Simulate 60 frames
	for frame in range(60):
		state.step(1.0 / 60.0)

	var elapsed = Time.get_ticks_msec() - start_time

	print("    100 bodies, 60 frames (no body-body): %d ms (%.2f ms/frame)" % [elapsed, elapsed / 60.0])
	assert(elapsed < 500, "100 bodies for 60 frames should complete in <500ms baseline")

	# Now test with collisions enabled but fewer bodies
	state = WorldStateScript.new()
	state.bounds = Rect2(0, 0, 500, 500)
	state.physics_enabled = true

	# Create 30 bodies that will collide
	for i in range(30):
		state.bodies.append({
			"id": "body_%d" % i,
			"pos": {"x": 100.0 + (i % 6) * 50, "y": 100.0 + (i / 6) * 50},
			"vel": {"x": randf_range(-50, 50), "y": randf_range(-50, 50)},
			"force": {"x": 0.0, "y": 0.0},
			"mass": 1.0,
			"restitution": 0.8,
			"radius": 20.0
		})

	start_time = Time.get_ticks_msec()
	for frame in range(60):
		state.step(1.0 / 60.0)
	elapsed = Time.get_ticks_msec() - start_time

	print("    30 bodies with collisions, 60 frames: %d ms (%.2f ms/frame)" % [elapsed, elapsed / 60.0])
	assert(elapsed < 1000, "30 bodies with collisions should complete in <1 second")

	_pass("test_100_bodies_performance")

func _pass(test_name: String):
	print("  [PASS] %s" % test_name)
	_tests_passed += 1

func _fail(test_name: String, message: String = ""):
	print("  [FAIL] %s - %s" % [test_name, message])
	_tests_failed += 1
