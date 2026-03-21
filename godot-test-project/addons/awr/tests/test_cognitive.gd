## Test Cognitive AGI Patterns
##
## Tests for BDI Model, Global Workspace, HTN Planner, Memory-Prediction, and Delegation
##
extends SceneTree

const BDIModelScript = preload("res://addons/awr/cognitive/bdi_model.gd")
var GlobalWorkspaceScript = preload("res://addons/awr/cognitive/global_workspace.gd")
var HTNPlannerScript = preload("res://addons/awr/cognitive/htn_planner.gd")
var HTNDomainScript = preload("res://addons/awr/cognitive/htn_domain.gd")
var MemoryPredictionScript = preload("res://addons/awr/cognitive/memory_prediction.gd")
var DelegationScript = preload("res://addons/awr/cognitive/delegation.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("=== Testing Cognitive AGI Patterns ===")
	print("")

	# BDI Model tests
	test_bdi_model()

	# Global Workspace tests
	test_global_workspace()

	# HTN Planner tests
	test_htn_planner()

	# Memory-Prediction tests
	test_memory_prediction()

	# Delegation tests
	test_delegation()

	print("")
	print("=== Cognitive Tests Complete ===")
	print("Passed: %d, Failed: %d" % [tests_passed, tests_failed])

	quit(0 if tests_failed == 0 else 1)

# ============================================================
# BDI MODEL TESTS
# ============================================================

func test_bdi_model() -> void:
	print("--- Testing BDI Model ---")

	# Test creation
	var bdi = BDIModelScript.new()
	assert_true(bdi != null, "BDI model creation")

	# Test beliefs
	bdi.believe("player_position", Vector2(100, 200), 0.9)
	assert_true(bdi.has_belief("player_position"), "Belief exists")
	assert_equal(bdi.get_belief("player_position"), Vector2(100, 200), "Belief value correct")
	assert_equal(bdi.get_belief_confidence("player_position"), 0.9, "Belief confidence correct")

	# Test beliefs with default
	assert_equal(bdi.get_belief("nonexistent", "default"), "default", "Belief default works")

	# Test disbelieve
	bdi.disbelieve("player_position")
	assert_false(bdi.has_belief("player_position"), "Belief removed")

	# Test desires
	bdi.desire("reach_goal", 1.0)
	bdi.desire("avoid_hazard", 0.8)
	assert_true(bdi.has_desire("reach_goal"), "Desire exists")
	assert_equal(bdi.get_top_desire(), "reach_goal", "Top desire is highest priority")

	# Test intentions
	bdi.intend({"type": "move", "target": Vector2(300, 400)})
	assert_equal(bdi.intentions.size(), 1, "Intention added")
	assert_equal(bdi.get_current_intention().type, "move", "Current intention correct")

	# Test complete intention
	bdi.complete_intention()
	assert_equal(bdi.intentions.size(), 0, "Intention completed")

	# Test satisfies condition
	bdi.believe("has_key", true, 1.0)
	bdi.believe("door_locked", false, 1.0)
	assert_true(bdi.satisfies({"has_key": true, "door_locked": false}), "Condition satisfied")
	assert_false(bdi.satisfies({"has_key": false}), "Condition not satisfied")

	# Test to_prompt_block
	var prompt = bdi.to_prompt_block()
	assert_true(prompt.contains("BDI STATE"), "Prompt block contains header")
	assert_true(prompt.contains("BELIEFS"), "Prompt block contains beliefs")

	# Test serialization
	var data = bdi.to_dict()
	var loaded = BDIModelScript.from_dict(data)
	assert_equal(loaded.beliefs.size(), bdi.beliefs.size(), "Serialization preserves beliefs")

	print("  BDI Model: PASS")

# ============================================================
# GLOBAL WORKSPACE TESTS
# ============================================================

func test_global_workspace() -> void:
	print("--- Testing Global Workspace ---")

	# Test creation
	var gw = GlobalWorkspaceScript.new()
	assert_true(gw != null, "Global workspace creation")

	# Test add content
	gw.add_content("threat_detected", 0.9, "perception")
	gw.add_content("goal_nearby", 0.7, "navigation")
	gw.add_content("low_health", 0.5, "status")
	assert_equal(gw.workspace.size(), 3, "Content added")

	# Test competition
	var winner = gw.compete()
	assert_equal(winner, "threat_detected", "Highest activation wins competition")

	# Test conscious content
	var conscious = gw.get_conscious_content()
	assert_equal(conscious, "threat_detected", "Conscious content set correctly")

	# Test broadcast (before threshold test to ensure conscious_content is set)
	# Use array to work around GDScript closure capture issue
	var broadcast_count = [0]
	gw.register_listener(func(content): broadcast_count[0] += 1)
	gw.broadcast()
	assert_equal(broadcast_count[0], 1, "Broadcast reaches listeners")

	# Test activation threshold
	gw.activation_threshold = 0.8
	gw.add_content("weak_signal", 0.3, "background")
	var weak_winner = gw.compete()
	assert_not_equal(weak_winner, "weak_signal", "Below threshold content doesn't win")

	# Test boost/inhibit
	gw.boost_module("perception", 0.5)
	var summary = gw.get_workspace_summary()
	var found_boosted = false
	for entry in summary:
		if entry.module_type == "perception":
			found_boosted = entry.activation > 0.9
	assert_true(found_boosted, "Module boost works")

	# Test serialization
	var data = gw.to_dict()
	var loaded = GlobalWorkspaceScript.from_dict(data)
	assert_equal(loaded.workspace.size(), gw.workspace.size(), "Serialization preserves workspace")

	print("  Global Workspace: PASS")

# ============================================================
# HTN PLANNER TESTS
# ============================================================

func test_htn_planner() -> void:
	print("--- Testing HTN Planner ---")

	# Test domain creation
	var domain = HTNDomainScript.create_navigation_domain()
	assert_true(domain != null, "Domain creation")
	assert_true(domain.has_task("move_forward"), "Domain has primitive task")
	assert_true(domain.has_task("navigate_to_goal"), "Domain has compound task")

	# Test planner creation
	var planner = HTNPlannerScript.new(domain)
	assert_true(planner != null, "Planner creation")

	# Test primitive task planning
	var primitive_plan = planner.plan("move_forward")
	assert_equal(primitive_plan.size(), 1, "Primitive task plans to itself")
	assert_equal(primitive_plan[0], "move_forward", "Primitive task correct")

	# Test compound task planning
	var compound_plan = planner.plan("navigate_to_goal")
	assert_true(compound_plan.size() > 1, "Compound task decomposes")
	assert_true(domain.is_primitive(compound_plan[0]), "First subtask is primitive")

	# Test plan to actions
	var actions = planner.plan_to_actions(compound_plan, "agent_1")
	assert_true(actions.size() > 0, "Plan converts to actions")
	assert_true(actions[0].has("type"), "Action has type")

	# Test plan alternatives
	var alternatives = planner.plan_alternatives("navigate_to_goal")
	assert_true(alternatives.size() > 0, "Multiple alternatives found")

	# Test domain methods
	domain.add_primitive("custom_action", "A custom action")
	domain.add_compound("custom_compound", "A custom compound task")
	domain.add_method("custom_method", "custom_compound", ["custom_action"])
	assert_true(domain.has_task("custom_action"), "Custom primitive added")
	assert_true(domain.is_compound("custom_compound"), "Custom compound added")

	# Test plan cost
	var cost = domain.get_plan_cost(compound_plan)
	assert_true(cost > 0, "Plan has cost")

	print("  HTN Planner: PASS")

# ============================================================
# MEMORY-PREDICTION TESTS
# ============================================================

func test_memory_prediction() -> void:
	print("--- Testing Memory-Prediction ---")

	# Test creation
	var mp = MemoryPredictionScript.new()
	assert_true(mp != null, "Memory-prediction creation")

	# Test prediction
	mp.predict("next_position", 0.8, {"current": Vector2(100, 100)})
	assert_equal(mp.predictions.size(), 1, "Prediction added")

	# Test observation
	mp.observe("next_position", Vector2(110, 110), {"current": Vector2(100, 100)})
	assert_equal(mp.observations.size(), 1, "Observation added")

	# Test prediction error
	var error = mp.get_prediction_error()
	assert_true(error >= 0, "Prediction error calculated")

	# Test learning
	var lessons = mp.learn()
	assert_true(lessons is Dictionary, "Learning returns lessons")

	# Test accuracy tracking
	mp.predict_value("test", "expected", 0.9)
	mp.observe("test", "expected")
	var accuracy = mp.get_accuracy()
	assert_true(accuracy > 0, "Accuracy tracked")

	# Test error threshold
	mp.error_threshold = 0.1
	mp.predict_value("high_error_test", Vector2(0, 0), 0.9)
	mp.observe("high_error_test", Vector2(1000, 1000))
	var errors = mp.get_recent_errors()
	assert_true(errors.size() > 0, "High error recorded")

	# Test pattern storage
	assert_true(mp.patterns.size() > 0, "Patterns stored")

	# Test serialization
	var data = mp.to_dict()
	var loaded = MemoryPredictionScript.from_dict(data)
	assert_equal(loaded.predictions.size(), mp.predictions.size(), "Serialization preserves predictions")

	print("  Memory-Prediction: PASS")

# ============================================================
# DELEGATION TESTS
# ============================================================

func test_delegation() -> void:
	print("--- Testing Delegation System ---")

	# Test creation
	var ds = DelegationScript.new()
	assert_true(ds != null, "Delegation system creation")
	assert_equal(ds.desperation_level, 1, "Initial desperation is 1")

	# Test spawn subtask
	var result = ds.spawn_subtask("test_task")
	assert_true(result.success, "Subtask spawned")
	assert_equal(ds.current_depth, 1, "Depth increased")

	# Test complete subtask
	ds.complete_subtask(result.subtask_id, true, {"value": 42})
	assert_equal(ds.current_depth, 0, "Depth decreased after completion")

	# Test escalate
	ds.escalate()
	assert_equal(ds.desperation_level, 2, "Desperation escalated")

	ds.escalate()
	ds.escalate()
	ds.escalate()
	assert_equal(ds.desperation_level, 5, "Desperation maxes at 5")

	# Test de-escalate
	ds.de_escalate()
	assert_equal(ds.desperation_level, 4, "Desperation de-escalates")

	# Test should_delegate
	ds.reset_desperation()
	assert_false(ds.should_delegate("simple_task", 0), "Simple task not delegated at low desperation")

	ds.escalate()
	ds.escalate()
	ds.escalate()
	assert_true(ds.should_delegate("complex_task", 5), "Complex task delegated at high desperation")

	# Test evaluation depth
	assert_equal(ds.get_evaluation_depth(), 100, "Evaluation depth correct for desperation 4")

	# Test approach strategy
	var strategy = ds.get_approach_strategy()
	assert_true(strategy is String, "Strategy is string")

	# Test max depth limit
	ds.current_depth = ds.max_depth
	var max_result = ds.spawn_subtask("should_fail")
	assert_false(max_result.success, "Delegation fails at max depth")

	# Test serialization
	ds.reset_desperation()
	var data = ds.to_dict()
	var loaded = DelegationScript.from_dict(data)
	assert_equal(loaded.desperation_level, ds.desperation_level, "Serialization preserves desperation")

	print("  Delegation System: PASS")

# ============================================================
# ASSERTION HELPERS
# ============================================================

func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
	else:
		tests_failed += 1
		print("    FAILED: %s" % message)

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		tests_passed += 1
	else:
		tests_failed += 1
		print("    FAILED: %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])

func assert_not_equal(actual, expected, message: String) -> void:
	if actual != expected:
		tests_passed += 1
	else:
		tests_failed += 1
		print("    FAILED: %s (values were equal: %s)" % [message, str(actual)])
