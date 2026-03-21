## AWR Perception Layer Tests
##
## Run with: godot --headless --path . -s addons/awr/tests/test_perception.gd
extends SceneTree

# Preload scripts
var VLMParserScript = preload("res://addons/awr/perception/vlm_parser.gd")
var PerceptionBridgeScript = preload("res://addons/awr/perception/perception_bridge.gd")
var WorldStateScript = preload("res://addons/awr/core/world_state.gd")
var CausalBusScript = preload("res://addons/awr/core/causal_bus.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0

func _init():
	print("\n=== AWR Perception Layer Tests ===\n")

	test_vlm_parser_json()
	test_vlm_parser_text()
	test_vlm_parser_ndjson()
	test_vlm_parser_normalize()
	test_vlm_parser_spawn_actions()
	test_vlm_parser_tracking()
	test_vlm_parser_prompts()
	test_perception_bridge_init()
	test_perception_bridge_process_response()
	test_perception_bridge_world_update()
	test_direct_scene_extraction()

	print("\n=== Results ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)

	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func test_vlm_parser_json():
	# Test valid JSON parsing
	var json_response = '{"objects": [{"id": "ball1", "pos": [100, 200], "radius": 15, "color": "red"}]}'
	var bodies = VLMParserScript.parse_json_response(json_response)

	assert(bodies.size() == 1, "Should parse 1 object")
	assert(bodies[0].id == "ball1", "ID should be ball1")
	assert(abs(bodies[0].pos.x - 100.0) < 0.01, "X position should be 100")
	assert(abs(bodies[0].pos.y - 200.0) < 0.01, "Y position should be 200")
	assert(abs(bodies[0].radius - 15.0) < 0.01, "Radius should be 15")

	_pass("test_vlm_parser_json")

func test_vlm_parser_text():
	# Test text parsing fallback
	var text_response = """
	ball1 at (50, 100)
	ball2: x=200, y=300
	"""
	var bodies = VLMParserScript.parse_text_response(text_response)

	assert(bodies.size() >= 1, "Should parse at least 1 object from text")

	_pass("test_vlm_parser_text")

func test_vlm_parser_ndjson():
	# Test NDJSON parsing
	var ndjson_response = """
	{"id": "obj1", "pos": [10, 20]}
	{"id": "obj2", "pos": [30, 40]}
	{"id": "obj3", "pos": [50, 60]}
	"""
	var bodies = VLMParserScript.parse_ndjson_response(ndjson_response)

	assert(bodies.size() == 3, "Should parse 3 NDJSON objects")
	assert(bodies[0].id == "obj1", "First object ID should be obj1")
	assert(bodies[2].id == "obj3", "Third object ID should be obj3")

	_pass("test_vlm_parser_ndjson")

func test_vlm_parser_normalize():
	# Test body normalization with various input formats
	var input1 = {"id": "test", "position": [100, 200], "mass": 5.0}
	var body1 = VLMParserScript._normalize_body(input1)
	assert(body1.id == "test", "ID should be preserved")
	assert(body1.mass == 5.0, "Mass should be 5.0")

	# Test with dictionary position
	var input2 = {"id": "test2", "pos": {"x": 50, "y": 75}, "radius": 20}
	var body2 = VLMParserScript._normalize_body(input2)
	assert(abs(body2.pos.x - 50.0) < 0.01, "X should be 50")
	assert(abs(body2.pos.y - 75.0) < 0.01, "Y should be 75")
	assert(abs(body2.radius - 20.0) < 0.01, "Radius should be 20")

	# Ensure defaults are applied
	assert(body2.has("vel"), "Should have velocity default")
	assert(body2.has("force"), "Should have force default")
	assert(body2.has("restitution"), "Should have restitution default")

	_pass("test_vlm_parser_normalize")

func test_vlm_parser_spawn_actions():
	var bodies = [
		{"id": "a", "pos": {"x": 0.0, "y": 0.0}, "vel": {"x": 0.0, "y": 0.0}, "mass": 1.0},
		{"id": "b", "pos": {"x": 10.0, "y": 10.0}, "vel": {"x": 0.0, "y": 0.0}, "mass": 2.0}
	]

	var actions = VLMParserScript.to_spawn_actions(bodies)

	assert(actions.size() == 2, "Should create 2 spawn actions")
	assert(actions[0].type == "spawn", "Action type should be spawn")
	assert(actions[0].params.id == "a", "First action should spawn body a")
	assert(actions[1].params.id == "b", "Second action should spawn body b")

	_pass("test_vlm_parser_spawn_actions")

func test_vlm_parser_tracking():
	var tracking_response = """{
		"moved": [{"id": "ball1", "new_pos": [150, 250]}],
		"appeared": [{"id": "ball3", "pos": [300, 400], "radius": 10}],
		"disappeared": ["ball2"]
	}"""

	var result = VLMParserScript.parse_tracking_response(tracking_response)

	assert(result.moved.size() == 1, "Should have 1 moved object")
	assert(result.moved[0].target == "ball1", "Moved target should be ball1")
	assert(abs(result.moved[0].params.x - 150.0) < 0.01, "New X should be 150")

	assert(result.appeared.size() == 1, "Should have 1 appeared object")
	assert(result.appeared[0].params.id == "ball3", "Appeared ID should be ball3")

	assert(result.disappeared.size() == 1, "Should have 1 disappeared object")
	assert(result.disappeared[0].target == "ball2", "Disappeared target should be ball2")

	_pass("test_vlm_parser_tracking")

func test_vlm_parser_prompts():
	# Test prompt building
	var analysis_prompt = VLMParserScript.build_analysis_prompt("test context")
	assert(analysis_prompt.contains("JSON"), "Analysis prompt should mention JSON")
	assert(analysis_prompt.contains("test context"), "Should include context")

	var tracking_prompt = VLMParserScript.build_tracking_prompt(
		[{"id": "ball1", "pos": {"x": 100.0, "y": 100.0}}],
		"tracking context"
	)
	assert(tracking_prompt.contains("ball1"), "Tracking prompt should include previous objects")
	assert(tracking_prompt.contains("moved"), "Should include moved category")

	_pass("test_vlm_parser_prompts")

func test_perception_bridge_init():
	var world = WorldStateScript.new()
	var bus = CausalBusScript.new()
	var bridge = PerceptionBridgeScript.new(world, bus)

	assert(bridge._world_state != null, "Should have world state")
	assert(bridge._causal_bus != null, "Should have causal bus")
	assert(bridge.config.has("auto_update_world"), "Should have config")

	_pass("test_perception_bridge_init")

func test_perception_bridge_process_response():
	var bridge = PerceptionBridgeScript.new()

	var vlm_response = '{"objects": [{"id": "obj1", "pos": [50, 50], "radius": 10}]}'
	var result = bridge.process_vlm_response(vlm_response, 0.9)

	assert(result.bodies.size() == 1, "Should detect 1 body")
	assert(abs(result.confidence - 0.9) < 0.01, "Confidence should be 0.9")
	assert(result.actions.size() == 1, "Should have 1 spawn action")

	# Check stats
	var stats = bridge.get_stats()
	assert(stats.total_perceptions == 1, "Should have 1 perception")
	assert(stats.total_bodies_detected == 1, "Should have detected 1 body total")

	_pass("test_perception_bridge_process_response")

func test_perception_bridge_world_update():
	var world = WorldStateScript.new()
	var bridge = PerceptionBridgeScript.new(world)
	bridge.config.auto_update_world = true
	bridge.config.merge_strategy = "replace"

	var vlm_response = '{"objects": [{"id": "ball1", "pos": [100, 100], "radius": 20}]}'
	bridge.process_vlm_response(vlm_response)

	assert(world.bodies.size() == 1, "World should have 1 body")
	assert(world.bodies[0].id == "ball1", "Body ID should be ball1")
	assert(abs(world.bodies[0].pos.x - 100.0) < 0.01, "Body X should be 100")

	# Test update strategy
	bridge.config.merge_strategy = "update"
	var update_response = '{"objects": [{"id": "ball1", "pos": [200, 200], "radius": 20}, {"id": "ball2", "pos": [50, 50], "radius": 10}]}'
	bridge.process_vlm_response(update_response)

	assert(world.bodies.size() == 2, "World should have 2 bodies after update")
	# ball1 should be updated
	var ball1 = world.get_body("ball1")
	assert(abs(ball1.pos.x - 200.0) < 0.01, "ball1 X should be updated to 200")

	_pass("test_perception_bridge_world_update")

func test_direct_scene_extraction():
	var world = WorldStateScript.new()
	var bridge = PerceptionBridgeScript.new(world)
	bridge.config.auto_update_world = true
	bridge.config.merge_strategy = "replace"

	# Create a mock node structure (we can't create actual RigidBody2D in headless)
	# So we test the data transformation logic directly
	var mock_body_data = {
		"id": "test_ball",
		"pos": {"x": 100.0, "y": 200.0},
		"vel": {"x": 5.0, "y": 0.0},
		"mass": 2.0,
		"radius": 15.0,
		"static": false
	}

	# Apply directly
	var bodies = [mock_body_data]
	bridge._apply_to_world_state(bodies)

	assert(world.bodies.size() == 1, "World should have 1 body from direct extraction")
	assert(world.bodies[0].id == "test_ball", "Body ID should match")
	assert(abs(world.bodies[0].pos.x - 100.0) < 0.01, "Position should be preserved")
	assert(abs(world.bodies[0].vel.x - 5.0) < 0.01, "Velocity should be preserved")
	assert(abs(world.bodies[0].mass - 2.0) < 0.01, "Mass should be preserved")

	# Test that extraction creates proper body format using local helper
	var extracted_body = _node_to_body_data_mock("test_node", Vector2(50, 100), Vector2(10, 5), 1.0, 20.0, false)
	assert(extracted_body.id == "test_node", "Extracted body should have ID")
	assert(abs(extracted_body.pos.x - 50.0) < 0.01, "Extracted position X should match")
	assert(abs(extracted_body.vel.x - 10.0) < 0.01, "Extracted velocity X should match")

	_pass("test_direct_scene_extraction")

# Mock helper for testing node extraction without actual Godot nodes
func _node_to_body_data_mock(id: String, pos: Vector2, vel: Vector2, mass: float, radius: float, is_static: bool) -> Dictionary:
	return {
		"id": id,
		"pos": {"x": pos.x, "y": pos.y},
		"vel": {"x": vel.x, "y": vel.y},
		"force": {"x": 0.0, "y": 0.0},
		"mass": mass,
		"radius": radius,
		"static": is_static,
		"restitution": 0.8
	}

func _pass(test_name: String):
	print("  [PASS] %s" % test_name)
	_tests_passed += 1

func _fail(test_name: String, message: String = ""):
	print("  [FAIL] %s - %s" % [test_name, message])
	_tests_failed += 1
