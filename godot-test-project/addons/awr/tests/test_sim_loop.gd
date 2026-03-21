## AWR SimLoop Unit Tests
##
## Run with: godot --headless --path . -s addons/awr/tests/test_sim_loop.gd
extends SceneTree

# Preload scripts
var WorldStateScript = preload("res://addons/awr/core/world_state.gd")
var SimLoopScript = preload("res://addons/awr/core/sim_loop.gd")
var EvaluatorScript = preload("res://addons/awr/core/evaluator.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0

func _init():
	print("\n=== AWR SimLoop Tests ===\n")

	test_world_state_clone()
	test_world_state_step()
	test_world_state_bounds()
	test_determinism()
	test_branch_simulation()
	test_branch_search()
	test_evaluator_goal_distance()
	test_evaluator_collision_free()
	test_evaluator_combined()
	test_action_types()

	print("\n=== Results ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)

	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func test_world_state_clone():
	var state = WorldStateScript.new()
	state.bodies = [{
		"id": "a",
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 1.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"restitution": 0.8,
		"radius": 10.0
	}]

	var clone = state.clone()
	assert(clone.bodies[0].pos.x == 0.0, "Clone should have same position")

	# Modify clone
	clone.apply({"type": "move", "target": "a", "params": {"x": 10.0, "y": 0.0}})
	assert(clone.bodies[0].pos.x == 10.0, "Clone should be modified")
	assert(state.bodies[0].pos.x == 0.0, "Original should be unchanged")

	_pass("test_world_state_clone")

func test_world_state_step():
	var state = WorldStateScript.new()
	state.bodies = [{
		"id": "ball",
		"pos": {"x": 50.0, "y": 50.0},
		"vel": {"x": 10.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"restitution": 0.8,
		"radius": 10.0
	}]

	state.step(1.0 / 60.0)

	# Ball should have moved
	assert(abs(state.bodies[0].pos.x - 50.166) < 0.01, "Ball should move right")
	assert(abs(state.bodies[0].pos.y - 50.0) < 0.01, "Ball Y unchanged")

	_pass("test_world_state_step")

func test_world_state_bounds():
	var state = WorldStateScript.new()
	state.bounds = Rect2(0, 0, 100, 100)
	state.bodies = [{
		"id": "ball",
		"pos": {"x": 95.0, "y": 50.0},
		"vel": {"x": 100.0, "y": 0.0},  # Moving fast right
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"restitution": 1.0,
		"radius": 10.0
	}]

	# Step multiple times to hit boundary
	for i in range(100):
		state.step(1.0 / 60.0)

	# Ball should have bounced and be within bounds
	assert(state.bodies[0].pos.x <= 90.0, "Ball should stay within right bound")
	assert(state.bodies[0].pos.x >= 10.0, "Ball should stay within left bound")

	_pass("test_world_state_bounds")

func test_determinism():
	var state1 = _create_test_state()
	var state2 = _create_test_state()

	var action = {"type": "apply_impulse", "target": "ball", "params": {"x": 5.0, "y": 0.0}}
	state1.apply(action)
	state2.apply(action)

	for i in range(100):
		state1.step(1.0 / 60.0)
		state2.step(1.0 / 60.0)

	assert(state1.hash() == state2.hash(), "States should be identical (deterministic)")

	# Also check actual values match
	assert(state1.bodies[0].pos.x == state2.bodies[0].pos.x, "X positions should match")
	assert(state1.bodies[0].pos.y == state2.bodies[0].pos.y, "Y positions should match")

	_pass("test_determinism")

func test_branch_simulation():
	var state = _create_test_state()
	var sim = SimLoopScript.new(state)
	sim.horizon = 10  # Short horizon for testing

	var action = {"type": "apply_impulse", "target": "ball", "params": {"x": 10.0, "y": 0.0}}
	var result = sim.simulate_branch(state, action)

	assert(result.has("score"), "Result should have score")
	assert(result.has("final_state"), "Result should have final_state")

	# Original state unchanged
	assert(state.bodies[0].pos.x == 50.0, "Original state should be unchanged")

	_pass("test_branch_simulation")

func test_branch_search():
	var state = _create_test_state()
	var eval_func = func(s): return EvaluatorScript.goal_distance(s, "ball", Vector2(100, 0))
	var sim = SimLoopScript.new(state, eval_func)
	sim.horizon = 30

	var actions: Array = [
		{"type": "apply_impulse", "target": "ball", "params": {"x": 10.0, "y": 0.0}},  # Toward goal
		{"type": "apply_impulse", "target": "ball", "params": {"x": -10.0, "y": 0.0}}, # Away from goal
		{"type": "apply_impulse", "target": "ball", "params": {"x": 0.0, "y": 10.0}},  # Perpendicular
	]

	var result = sim.search_best(actions)

	assert(result.action.params.x == 10.0, "Should choose action moving toward goal")
	assert(result.score > -100.0, "Score should be reasonable")

	_pass("test_branch_search")

func test_evaluator_goal_distance():
	var state = _create_test_state()

	# Ball at (50, 50), goal at (100, 0)
	var score = EvaluatorScript.goal_distance(state, "ball", Vector2(100, 0))
	# Distance should be sqrt(50^2 + 50^2) = ~70.7
	assert(abs(score - (-70.71)) < 0.1, "Goal distance should be ~-70.71")

	# Test collision-free (no collisions in this state)
	var collision_score = EvaluatorScript.collision_free(state)
	assert(collision_score == 0.0, "No collisions expected")

	_pass("test_evaluator_goal_distance")

func test_evaluator_collision_free():
	var state = WorldStateScript.new()
	state.bodies = [
		{
			"id": "a",
			"pos": {"x": 0.0, "y": 0.0},
			"vel": {"x": 0.0, "y": 0.0},
			"force": {"x": 0.0, "y": 0.0},
			"mass": 1.0,
			"radius": 10.0
		},
		{
			"id": "b",
			"pos": {"x": 15.0, "y": 0.0},  # 15 units apart, radii sum = 20
			"vel": {"x": 0.0, "y": 0.0},
			"force": {"x": 0.0, "y": 0.0},
			"mass": 1.0,
			"radius": 10.0
		}
	]

	var score = EvaluatorScript.collision_free(state)
	# Overlap = 20 - 15 = 5
	assert(abs(score - (-5.0)) < 0.01, "Collision penalty should be -5")

	assert(EvaluatorScript.has_collision(state), "Should detect collision")

	_pass("test_evaluator_collision_free")

func test_evaluator_combined():
	var state = _create_test_state()

	var weights = {
		"goal": 1.0,
		"goal_id": "ball",
		"goal_pos": Vector2(100, 0),
		"collision": 0.5,
		"energy": 0.1
	}

	var score = EvaluatorScript.combined(state, weights)
	# Should be: goal_distance + 0.5 * collision_free + 0.1 * energy_efficient
	assert(score < 0.0, "Combined score should be negative (distance penalty)")

	_pass("test_evaluator_combined")

func test_action_types():
	var state = _create_test_state()

	# Test apply_force
	var state1 = state.clone()
	state1.apply({"type": "apply_force", "target": "ball", "params": {"x": 10.0, "y": 0.0}})
	assert(state1.bodies[0].force.x == 10.0, "Force should be applied")

	# Test apply_impulse
	var state2 = state.clone()
	state2.apply({"type": "apply_impulse", "target": "ball", "params": {"x": 10.0, "y": 0.0}})
	assert(state2.bodies[0].vel.x == 10.0, "Impulse should be applied")

	# Test set_velocity
	var state3 = state.clone()
	state3.apply({"type": "set_velocity", "target": "ball", "params": {"x": 5.0, "y": 5.0}})
	assert(state3.bodies[0].vel.x == 5.0, "Velocity should be set")
	assert(state3.bodies[0].vel.y == 5.0, "Velocity Y should be set")

	# Test spawn
	var state4 = state.clone()
	state4.apply({
		"type": "spawn",
		"params": {"id": "new_ball", "pos": {"x": 100.0, "y": 100.0}, "mass": 2.0}
	})
	assert(state4.bodies.size() == 2, "Should have 2 bodies")
	assert(state4.bodies[1].id == "new_ball", "New body should have correct ID")

	# Test destroy
	var state5 = state.clone()
	state5.apply({"type": "destroy", "target": "ball"})
	assert(state5.bodies.is_empty(), "Body should be destroyed")

	_pass("test_action_types")

func _create_test_state():
	var state = WorldStateScript.new()
	state.bodies = [{
		"id": "ball",
		"pos": {"x": 50.0, "y": 50.0},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"restitution": 0.8,
		"radius": 10.0
	}]
	return state

func _pass(test_name: String):
	print("  [PASS] %s" % test_name)
	_tests_passed += 1

func _fail(test_name: String, message: String = ""):
	print("  [FAIL] %s - %s" % [test_name, message])
	_tests_failed += 1
