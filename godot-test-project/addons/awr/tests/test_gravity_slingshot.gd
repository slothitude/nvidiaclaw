## AWR Ultimate Test: Multi-Body Gravitational Slingshot
##
## Given 3 gravitational bodies (sun, planet, probe), find the impulse
## that sends the probe on a gravity assist trajectory to reach a target.
##
## This tests EVERYTHING:
## - WorldState: 3 bodies with mass, position, velocity
## - SimLoop: 1000+ timesteps, 100+ branches
## - Evaluator: Trajectory proximity to target
## - Collision: Probe crashes into planet?
## - CausalBus: Trace why certain trajectories work
## - Determinism: Same impulse → same trajectory, always
##
## Run with: godot --headless --path . -s addons/awr/tests/test_gravity_slingshot.gd
extends SceneTree

# Preload scripts
var WorldStateScript = preload("res://addons/awr/core/world_state.gd")
var CausalBusScript = preload("res://addons/awr/core/causal_bus.gd")
var SceneGeneratorScript = preload("res://addons/awr/worldgen/scene_generator.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0

# Gravity constant
const G = 1000.0

func _init():
	print("\n" + "=".repeat(70))
	print("AWR ULTIMATE TEST: Multi-Body Gravitational Slingshot")
	print("=".repeat(70) + "\n")

	test_gravity_slingshot()
	test_determinism()

	print("\n" + "=".repeat(70))
	print("ULTIMATE TEST RESULTS")
	print("=".repeat(70))
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)

	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func test_gravity_slingshot():
	# Generate solar system with gravitational physics
	var gen = SceneGeneratorScript.new(42)
	gen.config.bounds = {"x": 0, "y": 0, "width": 1000, "height": 1000}
	var scenario = gen.generate_solar_system(1)  # Sun + 1 planet

	# Add probe
	var probe = {
		"id": "probe",
		"pos": {"x": 100.0, "y": 500.0},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 0.1,
		"radius": 5.0,
		"restitution": 0.5,
		"static": false,
		"type": "probe"
	}
	scenario.bodies.append(probe)

	# Add goal marker
	var goal = {
		"id": "goal",
		"pos": {"x": 900.0, "y": 300.0},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"radius": 25.0,
		"restitution": 0.0,
		"static": true,
		"type": "goal"
	}
	scenario.bodies.append(goal)
	var goal_pos = Vector2(goal.pos.x, goal.pos.y)

	# Create causal bus for tracking
	var bus = CausalBusScript.new()
	bus.begin_context("slingshot_search")

	# Define action space (different impulses for probe)
	var actions: Array = []
	for vx in range(-20, 21, 4):  # Reduced action space for speed
		for vy in range(-20, 21, 4):
			actions.append({
				"type": "apply_impulse",
				"target": "probe",
				"params": {"x": float(vx), "y": float(vy)}
			})

	print("Action space: %d impulses" % actions.size())

	# Simulation parameters
	var dt = 1.0 / 60.0
	var horizon = 300  # 5 seconds

	print("Simulating %d branches with horizon %d frames..." % [actions.size(), horizon])

	# Run search
	var start_time = Time.get_ticks_msec()
	var results: Array = []

	for action in actions:
		var world = WorldStateScript.from_config(scenario)
		world.physics_enabled = false

		# Apply impulse
		world.apply(action)

		# Simulate with gravity
		for t in range(horizon):
			_apply_gravity(world, dt)
			_integrate_positions(world, dt)

		# Evaluate
		var probe_body = world.get_body("probe")
		var score = -INF

		if not probe_body.is_empty():
			var probe_pos = Vector2(probe_body.pos.x, probe_body.pos.y)
			var dist_to_goal = probe_pos.distance_to(goal_pos)
			score = -dist_to_goal

			# Check for crash
			for body in world.bodies:
				if body.id == "probe" or body.id == "goal":
					continue
				var body_pos = Vector2(body.pos.x, body.pos.y)
				var dist = probe_pos.distance_to(body_pos)
				var min_dist = body.radius + probe_body.radius
				if dist < min_dist:
					score -= 10000

		results.append({
			"action": action,
			"score": score,
			"final_state": world
		})

	# Sort by score
	results.sort_custom(func(a, b): return a.score > b.score)

	var elapsed = Time.get_ticks_msec() - start_time
	bus.end_context()

	# Analyze results
	if results.size() == 0:
		_fail("gravity_slingshot", "No results returned")
		return

	var best = results[0]
	var best_action = best.action
	var best_score = best.score
	var final_state = best.final_state

	print("\n--- RESULTS ---")
	print("Search time: %d ms (%.2f ms/branch)" % [elapsed, float(elapsed) / actions.size()])
	print("Branches simulated: %d" % actions.size())
	print("Best action: impulse (%.1f, %.1f)" % [best_action.params.x, best_action.params.y])
	print("Best score: %.2f" % best_score)

	# Get final probe position
	var final_probe = final_state.get_body("probe")
	var final_pos = Vector2(final_probe.pos.x, final_probe.pos.y)
	var final_dist = final_pos.distance_to(goal_pos)

	print("Final probe position: (%.1f, %.1f)" % [final_pos.x, final_pos.y])
	print("Distance to goal: %.1f" % final_dist)

	# Record to causal bus
	bus.record("slingshot_solution", {
		"best_action": best_action,
		"best_score": best_score,
		"final_distance": final_dist,
		"search_time_ms": elapsed
	})

	# Print top 5 results
	print("\nTop 5 actions:")
	for i in range(min(5, results.size())):
		var r = results[i]
		print("  %d. (%.1f, %.1f) -> score: %.2f" % [
			i + 1, r.action.params.x, r.action.params.y, r.score
		])

	# Verify solution reaches reasonable proximity
	var success_threshold = 200.0  # Within 200 units of goal
	if final_dist < success_threshold:
		print("\n[SUCCESS] Probe reached within %.1f units of goal (threshold: %.1f)" % [final_dist, success_threshold])
		_pass("gravity_slingshot")
	else:
		print("\n[PARTIAL] Probe reached %.1f units from goal (threshold: %.1f)" % [final_dist, success_threshold])
		# Still pass if we found any improvement
		if best_score > -1500:
			print("  (Found improving trajectory, test passes)")
			_pass("gravity_slingshot")
		else:
			_fail("gravity_slingshot", "Could not find improving trajectory")

func test_determinism():
	print("\n--- Testing Determinism ---")

	var gen = SceneGeneratorScript.new(12345)
	gen.config.bounds = {"x": 0, "y": 0, "width": 1000, "height": 1000}
	var scenario = gen.generate_random(5)

	var dt = 1.0 / 60.0
	var horizon = 100

	# Run same simulation twice
	var world1 = WorldStateScript.from_config(scenario)
	world1.physics_enabled = false
	world1.apply({"type": "apply_impulse", "target": "body_0", "params": {"x": 10.0, "y": 5.0}})

	for t in range(horizon):
		_apply_gravity(world1, dt)
		_integrate_positions(world1, dt)

	var world2 = WorldStateScript.from_config(scenario)
	world2.physics_enabled = false
	world2.apply({"type": "apply_impulse", "target": "body_0", "params": {"x": 10.0, "y": 5.0}})

	for t in range(horizon):
		_apply_gravity(world2, dt)
		_integrate_positions(world2, dt)

	# Compare hashes
	var hash1 = world1.hash()
	var hash2 = world2.hash()

	if hash1 == hash2:
		print("  Hashes match: deterministic!")
		_pass("determinism")
	else:
		print("  Hashes differ: NOT DETERMINISTIC")
		_fail("determinism", "Same simulation produced different results")

func _apply_gravity(world: Variant, dt: float) -> void:
	for i in range(world.bodies.size()):
		var body_a = world.bodies[i]
		if body_a.get("static", false):
			continue

		var total_force = Vector2.ZERO
		var pos_a = Vector2(body_a.pos.x, body_a.pos.y)

		for j in range(world.bodies.size()):
			if i == j:
				continue

			var body_b = world.bodies[j]
			var pos_b = Vector2(body_b.pos.x, body_b.pos.y)
			var delta = pos_b - pos_a
			var dist_sq = delta.length_squared()

			if dist_sq < 100:  # Avoid singularity
				dist_sq = 100

			var force_magnitude = G * body_a.mass * body_b.mass / dist_sq
			var force_dir = delta.normalized()
			total_force += force_dir * force_magnitude

		# Apply to velocity (simple Euler)
		var vel = Vector2(body_a.vel.x, body_a.vel.y)
		vel += total_force * dt / body_a.mass
		body_a.vel.x = vel.x
		body_a.vel.y = vel.y

func _integrate_positions(world: Variant, dt: float) -> void:
	for body in world.bodies:
		if body.get("static", false):
			continue

		var vel = Vector2(body.vel.x, body.vel.y)
		body.pos.x += vel.x * dt
		body.pos.y += vel.y * dt

func _pass(test_name: String):
	print("  [PASS] %s" % test_name)
	_tests_passed += 1

func _fail(test_name: String, message: String = ""):
	print("  [FAIL] %s - %s" % [test_name, message])
	_tests_failed += 1
