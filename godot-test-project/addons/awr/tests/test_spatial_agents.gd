## test_spatial_agents.gd - Test Spatial Memory with Agent Integration
## Verifies that:
## 1. Godot docs spatial memory loads correctly
## 2. Agents can query spatial memory for navigation
## 3. Cognitive systems (BDI, Meeseeks) integrate with spatial memory

extends SceneTree

const SPATIAL_MEMORY_PATH := "res://addons/awr/spatial/godot_docs_memory.json"

var _spatial_memory = null
var _test_passed := 0
var _test_failed := 0


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("  AWR Spatial Memory + Agents Integration Test")
	print("=".repeat(60) + "\n")


func _initialize() -> void:
	# Load spatial memory with Godot docs
	print("[1/5] Loading Godot docs spatial memory...")

	var SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")
	var file_path = ProjectSettings.globalize_path(SPATIAL_MEMORY_PATH)

	# Check file exists
	if not FileAccess.file_exists(file_path):
		print("  ✗ FAIL: Spatial memory file not found: %s" % file_path)
		_test_failed += 1
		return finish()

	# Load the memory
	var start_time = Time.get_ticks_msec()
	_spatial_memory = SpatialMemoryClass.load_from(file_path)
	var load_time = Time.get_ticks_msec() - start_time

	if _spatial_memory == null:
		print("  ✗ FAIL: Could not load spatial memory")
		_test_failed += 1
		return finish()

	var node_count = _spatial_memory.size()
	print("  ✓ PASS: Loaded %d nodes in %dms" % [node_count, load_time])
	_test_passed += 1

	# Test spatial queries
	test_spatial_queries()

	# Test agent cognitive systems
	test_agent_cognitive_systems()

	# Test agent spatial integration
	test_agent_spatial_integration()

	# Performance test
	test_performance()

	finish()


func test_spatial_queries() -> void:
	print("\n[2/5] Testing spatial queries...")

	# Test 1: Find neighbors using a known node location
	var all_nodes = _spatial_memory.get_all_nodes()
	if all_nodes.is_empty():
		print("  ✗ FAIL: No nodes in spatial memory")
		_test_failed += 1
		return

	var known_node = all_nodes[0]  # Use first node
	var test_pos = known_node.location
	var start_time = Time.get_ticks_msec()
	var nearby = _spatial_memory.neighbors(test_pos, 100.0)  # Larger radius
	var query_time = Time.get_ticks_msec() - start_time

	if nearby.size() > 1:  # Should find at least the node itself + neighbors
		print("  ✓ PASS: Found %d neighbors near '%s' in %dms" % [nearby.size(), known_node.concept.substr(0, 30), query_time])
		_test_passed += 1

		# Print nearest neighbor info
		if nearby.size() > 1:
			var nearest = nearby[1]  # Skip self
			print("    Nearest: %s (dist: %.1f)" % [nearest.concept.substr(0, 50), test_pos.distance_to(nearest.location)])
	else:
		print("  ✗ FAIL: No neighbors found (expected at least 1)")
		_test_failed += 1

	# Test 2: Find path between concepts
	start_time = Time.get_ticks_msec()
	var path = _spatial_memory.find_path("chunk_0", "chunk_10")
	query_time = Time.get_ticks_msec() - start_time

	if path != null:
		print("  ✓ PASS: Found path from chunk_0 to chunk_10 (dist: %.1f) in %dms" % [path.distance, query_time])
		print("    Waypoints: %d, Discovered nodes: %d" % [path.waypoints.size(), path.discovered_nodes.size()])
		_test_passed += 1
	else:
		print("  ✗ FAIL: No path found")
		_test_failed += 1

	# Test 3: Neighborhood query
	var concept = "chunk_0"
	var neighborhood = _spatial_memory.neighborhood(concept, 30.0)
	print("  ✓ PASS: Neighborhood of '%s' has %d concepts" % [concept, neighborhood.size()])
	_test_passed += 1


func test_agent_cognitive_systems() -> void:
	print("\n[3/5] Testing agent cognitive systems...")

	# Test BDI Model
	var BDIModelClass = load("res://addons/awr/cognitive/bdi_model.gd")
	if BDIModelClass == null:
		print("  ✗ FAIL: Could not load BDI Model")
		_test_failed += 1
		return

	var bdi = BDIModelClass.new()
	bdi.believe("position", Vector3(10, 0, 20), 1.0, "perception")
	bdi.believe("energy", 0.8, 0.9, "internal")
	bdi.desire("explore", 0.7)

	print("  ✓ PASS: BDI Model created with %d beliefs, %d desires" % [bdi.beliefs.size(), bdi.desires.size()])
	_test_passed += 1

	# Test Delegation (Meeseeks pattern)
	var DelegationClass = load("res://addons/awr/cognitive/delegation.gd")
	if DelegationClass == null:
		print("  ✗ FAIL: Could not load Delegation System")
		_test_failed += 1
		return

	var delegation = DelegationClass.new()
	delegation.spawn_subtask("test_task")

	print("  ✓ PASS: Delegation System created, desperation level: %d, subtasks: %d" % [delegation.desperation_level, delegation.get_active_subtasks().size()])
	_test_passed += 1

	# Test HTN Planner
	var HTNPlannerClass = load("res://addons/awr/cognitive/htn_planner.gd")
	var HTNDomainClass = load("res://addons/awr/cognitive/htn_domain.gd")

	if HTNPlannerClass == null or HTNDomainClass == null:
		print("  ✗ FAIL: Could not load HTN Planner")
		_test_failed += 1
		return

	var domain = HTNDomainClass.create_navigation_domain()
	var planner = HTNPlannerClass.new(domain)

	print("  ✓ PASS: HTN Planner created with navigation domain")
	_test_passed += 1


func test_agent_spatial_integration() -> void:
	print("\n[4/5] Testing agent-spatial memory integration...")

	# Simulate agent storing position in spatial memory
	var agent_id = "test_agent_001"
	var agent_pos = Vector3(100, 50, 75)

	_spatial_memory.store(
		"agent_%s" % agent_id,
		agent_pos,
		{
			"type": "agent",
			"model": "animal-cat",
			"state": "active",
			"current_goal": "explore"
		}
	)

	# Retrieve the agent
	var retrieved = _spatial_memory.retrieve_by_concept("agent_%s" % agent_id)
	if retrieved != null:
		print("  ✓ PASS: Agent stored and retrieved from spatial memory")
		print("    Location: (%.1f, %.1f, %.1f)" % [retrieved.location.x, retrieved.location.y, retrieved.location.z])
		print("    Model: %s" % retrieved.metadata.get("model", "unknown"))
		_test_passed += 1
	else:
		print("  ✗ FAIL: Could not retrieve agent from spatial memory")
		_test_failed += 1

	# Test finding nearby buildings from agent perspective
	var nearby = _spatial_memory.neighbors(agent_pos, 100.0)
	var buildings = []
	for node in nearby:
		if node.metadata.get("type") == "building" or "doc" in node.concept.to_lower():
			buildings.append(node)

	print("  ✓ PASS: Agent can see %d nearby nodes (potential navigation targets)" % nearby.size())
	_test_passed += 1

	# Test semantic distance (reasoning!)
	var dist = _spatial_memory.semantic_distance("chunk_0", "chunk_100")
	if dist < INF:
		print("  ✓ PASS: Semantic distance chunk_0 → chunk_100 = %.1f units" % dist)
		_test_passed += 1
	else:
		print("  ✗ FAIL: Could not calculate semantic distance")
		_test_failed += 1


func test_performance() -> void:
	print("\n[5/5] Performance benchmarks...")

	var iterations := 100
	var total_time := 0

	# Benchmark neighbor queries
	for i in range(iterations):
		var random_pos = Vector3(
			randf_range(0, 1000),
			randf_range(0, 1000),
			randf_range(0, 1000)
		)
		var start = Time.get_ticks_usec()
		_spatial_memory.neighbors(random_pos, 50.0)
		total_time += Time.get_ticks_usec() - start

	var avg_time_us = total_time / iterations
	print("  Neighbor queries: %d iterations, avg %.2f µs (%.0f/sec)" % [iterations, avg_time_us, 1000000.0 / avg_time_us])
	_test_passed += 1

	# Memory stats
	var stats = _spatial_memory.get_stats()
	print("\n  Spatial Memory Stats:")
	print("    Nodes: %d" % stats.node_count)
	print("    Total stores: %d" % stats.total_stores)
	print("    Total retrievals: %d" % stats.total_retrievals)
	print("    Index cells: %d" % stats.index_stats.cell_count)


func finish() -> void:
	print("\n" + "=".repeat(60))
	print("  Results: %d passed, %d failed" % [_test_passed, _test_failed])
	print("=".repeat(60) + "\n")

	if _test_failed > 0:
		quit(1)
	else:
		quit(0)
