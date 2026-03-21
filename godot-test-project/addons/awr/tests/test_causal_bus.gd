## AWR CausalBus Tests
##
## Run with: godot --headless --path . -s addons/awr/tests/test_causal_bus.gd
extends SceneTree

# Preload scripts
var CausalBusScript = preload("res://addons/awr/core/causal_bus.gd")
var EventLogScript = preload("res://addons/awr/core/event_log.gd")
var WorldStateScript = preload("res://addons/awr/core/world_state.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0

func _init():
	print("\n=== AWR CausalBus Tests ===\n")

	test_event_recording()
	test_context_stack()
	test_causal_chain()
	test_target_indexing()
	test_state_change_recording()
	test_action_recording()
	test_cause_query()
	test_event_export_import()
	test_max_events_limit()
	test_event_log_helper()

	print("\n=== Results ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)

	if _tests_failed > 0:
		quit(1)
	else:
		quit(0)

func test_event_recording():
	var bus = CausalBusScript.new()

	var event_id = bus.record("test_event", {"key": "value"})

	assert(not event_id.is_empty(), "Should return event ID")
	assert(event_id.begins_with("evt_"), "Event ID should start with evt_")

	var event = bus.get_event(event_id)
	assert(not event.is_empty(), "Should find recorded event")
	assert(event.type == "test_event", "Event type should match")
	assert(event.data.key == "value", "Event data should match")
	assert(event.timestamp > 0, "Event should have timestamp")

	_pass("test_event_recording")

func test_context_stack():
	var bus = CausalBusScript.new()

	# Record without context
	var event1_id = bus.record("event1", {})
	var event1 = bus.get_event(event1_id)
	assert(event1.context == "root", "Default context should be root")

	# Begin context
	bus.begin_context("action_1")
	var event2_id = bus.record("event2", {})
	var event2 = bus.get_event(event2_id)
	assert(event2.context == "action_1", "Event should have context")

	# Nested context
	bus.begin_context("action_2")
	var event3_id = bus.record("event3", {})
	var event3 = bus.get_event(event3_id)
	assert(event3.context == "action_2", "Event should have nested context")

	# End context
	var ended = bus.end_context()
	assert(ended == "action_2", "Should return ended context")

	var event4_id = bus.record("event4", {})
	var event4 = bus.get_event(event4_id)
	assert(event4.context == "action_1", "Should be back to action_1")

	_pass("test_context_stack")

func test_causal_chain():
	var bus = CausalBusScript.new()

	# Create a chain of events with explicit cause links
	var action_id = bus.record_action({"type": "impulse"}, "planner")
	var step_id = bus.record_step(0.016, action_id)
	var collision_id = bus.record_collision("ball1", "ball2", 10.0, step_id)

	# Get causal chain starting from collision
	var chain = bus.get_causal_chain(collision_id)

	# Chain should include at least the collision and the step that caused it
	assert(chain.size() >= 1, "Chain should have at least 1 event (collision)")

	# Verify the first event is the collision
	assert(chain[0].id == collision_id, "First event should be the collision")
	assert(chain[0].data.cause == step_id, "Collision cause should be step")

	_pass("test_causal_chain")

func test_target_indexing():
	var bus = CausalBusScript.new()

	bus.record("action", {"target": "ball1", "action_type": "move"})
	bus.record("state_change", {"target": "ball1", "property": "position"})
	bus.record("collision", {"target": "ball2", "body_a": "ball1", "body_b": "ball2"})

	var events = bus.get_events_for_target("ball1")

	assert(events.size() == 2, "Should find 2 events for ball1")

	_pass("test_target_indexing")

func test_state_change_recording():
	var bus = CausalBusScript.new()

	var cause_id = bus.record_action({"type": "apply_impulse", "target": "ball"}, "agent")

	var change_id = bus.record_state_change("ball", "position",
		Vector2(0, 0), Vector2(10, 5), cause_id)

	assert(not change_id.is_empty(), "Should record state change")

	var change_event = bus.get_event(change_id)
	assert(change_event.type == "state_change", "Type should be state_change")
	assert(change_event.target == "ball", "Target should be ball")
	assert(change_event.data.property == "position", "Property should be position")
	assert(change_event.data.cause == cause_id, "Cause should link to action")

	_pass("test_state_change_recording")

func test_action_recording():
	var bus = CausalBusScript.new()

	var action = {"type": "apply_impulse", "target": "ball", "params": {"x": 10, "y": 0}}
	var action_id = bus.record_action(action, "planner")

	var event = bus.get_event(action_id)

	assert(event.type == "action", "Type should be action")
	assert(event.data.action_type == "apply_impulse", "Action type should match")
	assert(event.data.source == "planner", "Source should be planner")

	_pass("test_action_recording")

func test_cause_query():
	var bus = CausalBusScript.new()

	# Simulate a causal chain
	bus.begin_context("search")
	var action_id = bus.record_action({"type": "apply_impulse", "target": "ball"}, "planner")
	bus.record_state_change("ball", "position", Vector2(0, 0), Vector2(5, 0), action_id)
	bus.record_state_change("ball", "velocity", Vector2(0, 0), Vector2(10, 0), action_id)
	bus.end_context()

	# Query: what caused ball's position to change?
	var cause_chain = bus.trace_cause("ball", "position")

	assert(cause_chain.size() >= 1, "Should find cause chain")
	assert(cause_chain[0].type == "state_change", "First should be state change")

	_pass("test_cause_query")

func test_event_export_import():
	var bus1 = CausalBusScript.new()

	bus1.record("event1", {"data": "a"})
	bus1.record("event2", {"data": "b"})
	bus1.record("event3", {"target": "ball"})

	var exported = bus1.export_events()
	assert(exported.size() == 3, "Should export 3 events")

	# Import into new bus
	var bus2 = CausalBusScript.new()
	bus2.import_events(exported)

	assert(bus2.get_stats().total_events == 3, "Should import 3 events")

	var events = bus2.get_events_for_target("ball")
	assert(events.size() == 1, "Should have indexed target")

	_pass("test_event_export_import")

func test_max_events_limit():
	var bus = CausalBusScript.new()
	bus.config.max_events = 5

	# Record more than max
	for i in range(10):
		bus.record("event", {"index": i})

	assert(bus._events.size() == 5, "Should only keep max_events")

	_pass("test_max_events_limit")

func test_event_log_helper():
	var bus = CausalBusScript.new()
	var log = EventLogScript.new(bus)

	# Test body spawn
	log.body_spawned("ball1", {"pos": Vector2(0, 0)})
	var spawn_events = bus.get_events_by_type("body_spawned")
	assert(spawn_events.size() == 1, "Should record spawn")

	# Test position change
	log.position_changed("ball1", Vector2(0, 0), Vector2(10, 10))
	var change_events = bus.get_events_by_type("state_change")
	assert(change_events.size() == 1, "Should record position change")

	# Test branch lifecycle
	log.begin_context("branch_1")
	log.branch_started("branch_1", {"type": "impulse", "params": {"x": 10}})
	log.branch_completed("branch_1", 15.5, 12345)
	var branch_events = bus.get_events_by_type("branch_started")
	assert(branch_events.size() == 1, "Should record branch start")

	_pass("test_event_log_helper")

func _pass(test_name: String):
	print("  [PASS] %s" % test_name)
	_tests_passed += 1

func _fail(test_name: String, message: String = ""):
	print("  [FAIL] %s - %s" % [test_name, message])
	_tests_failed += 1
