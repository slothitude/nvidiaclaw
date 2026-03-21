## test_spatial_memory.gd - Test Spatial Memory
## Part of AWR v0.4 - Physics-Enhanced Spatial Memory
extends SceneTree

const MemoryNodeClass = preload("res://addons/awr/spatial/memory_node.gd")
const SpatialMemoryClass = preload("res://addons/awr/spatial/spatial_memory.gd")
const SpatialIndexClass = preload("res://addons/awr/spatial/spatial_index.gd")
const SpatialPathClass = preload("res://addons/awr/spatial/spatial_path.gd")
const PalaceBuilderClass = preload("res://addons/awr/spatial/palace_builder.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("\n========================================")
	print("  AWR Spatial Memory Engine Tests")
	print("========================================\n")

	# Run tests
	test_memory_node()
	test_spatial_index()
	test_spatial_memory()
	test_spatial_path()
	test_palace_builder()
	test_reasoning()
	test_performance()

	print("\n========================================")
	print("  Results: %d passed, %d failed" % [tests_passed, tests_failed])
	print("========================================\n")

	# Exit with appropriate code
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % message)
	else:
		tests_failed += 1
		print("  [FAIL] %s" % message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		tests_passed += 1
		print("  [PASS] %s" % message)
	else:
		tests_failed += 1
		print("  [FAIL] %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])


#region MemoryNode Tests

func test_memory_node() -> void:
	print("\n--- Testing MemoryNode ---")

	var node = MemoryNodeClass.new("test_concept", Vector3(10, 20, 30))
	assert_equal(node.concept, "test_concept", "Node stores concept")
	assert_equal(node.location, Vector3(10, 20, 30), "Node stores location")
	assert_true(node.id != "", "Node has ID")
	assert_true(node.created_at > 0, "Node has timestamp")

	# Test touch (access tracking)
	var old_access_count = node.access_count
	node.touch()
	assert_equal(node.access_count, old_access_count + 1, "Touch increments access count")

	# Test connections
	node.connect_to("related_concept")
	# Check if any connection has the related_concept as its concept
	var has_connection = false
	for conn in node.connections:
		if conn.concept == "related_concept":
			has_connection = true
	assert_true(has_connection, "Connection added")

	node.disconnect_from("related_concept")
	# Check if no connection has the related_concept
	var still_has_connection = false
	for conn in node.connections:
		if conn.concept == "related_concept":
			still_has_connection = true
	assert_false(still_has_connection, "Connection removed")

	# Test serialization
	var dict = node.to_dict()
	assert_equal(dict.concept, "test_concept", "Serialization includes concept")
	assert_true(dict.has("location"), "Serialization includes location")

	var restored = MemoryNodeClass.from_dict(dict)
	assert_equal(restored.concept, node.concept, "Deserialization restores concept")
	assert_equal(restored.location, node.location, "Deserialization restores location")

#endregion

#region SpatialIndex Tests

func test_spatial_index() -> void:
	print("\n--- Testing SpatialIndex ---")

	var index = SpatialIndexClass.new(10.0)

	# Test insertion
	var node1 = MemoryNodeClass.new("node1", Vector3(5, 5, 5))
	var node2 = MemoryNodeClass.new("node2", Vector3(15, 5, 5))
	var node3 = MemoryNodeClass.new("node3", Vector3(25, 5, 5))

	index.insert(node1)
	index.insert(node2)
	index.insert(node3)

	assert_equal(index.node_count, 3, "Index tracks node count")

	# Test sphere query
	var results = index.query_sphere(Vector3(10, 5, 5), 10.0)
	assert_true(results.size() > 0, "Sphere query finds nodes")
	assert_true(node1 in results or node2 in results, "Sphere query finds nearby nodes")

	# Test nearest
	var nearest = index.query_nearest_one(Vector3(6, 5, 5))
	assert_equal(nearest, node1, "Nearest query finds closest node")

	# Test k-nearest
	var k_nearest = index.query_nearest(Vector3(6, 5, 5), 2)
	assert_equal(k_nearest.size(), 2, "K-nearest returns correct count")

	# Test removal
	index.remove(node2)
	assert_equal(index.node_count, 2, "Removal updates count")

	# Test concept lookup
	index.insert(node2)
	var found = index.find_by_concept("node2")
	assert_equal(found, node2, "Concept lookup finds node")

#endregion

#region SpatialMemory Tests

func test_spatial_memory() -> void:
	print("\n--- Testing SpatialMemory ---")

	var memory = SpatialMemoryClass.new(10.0)

	# Test store
	var node = memory.store("test", Vector3(0, 0, 0))
	assert_equal(node.concept, "test", "Store returns node")
	assert_equal(memory.size(), 1, "Memory size increases")

	# Test retrieve
	var retrieved = memory.retrieve(Vector3(0, 0, 0))
	assert_equal(retrieved, node, "Retrieve by location works")

	# Test retrieve by concept
	var by_concept = memory.retrieve_by_concept("test")
	assert_equal(by_concept, node, "Retrieve by concept works")

	# Test neighbors
	memory.store("neighbor1", Vector3(5, 0, 0))
	memory.store("neighbor2", Vector3(15, 0, 0))
	var neighbors = memory.neighbors(Vector3(10, 0, 0), 20.0)
	assert_equal(neighbors.size(), 3, "Neighbors query finds nearby concepts")

	# Test semantic distance
	var dist = memory.semantic_distance("test", "neighbor1")
	assert_true(dist < 20.0, "Semantic distance calculated correctly")

	# Test remove
	var removed = memory.remove(Vector3(5, 0, 0))
	assert_true(removed, "Remove returns true")
	assert_equal(memory.size(), 3, "Memory size decreases after remove")

#endregion

#region SpatialPath Tests

func test_spatial_path() -> void:
	print("\n--- Testing SpatialPath ---")

	var start_node = MemoryNodeClass.new("start", Vector3(0, 0, 0))
	var end_node = MemoryNodeClass.new("end", Vector3(100, 0, 0))

	var path = SpatialPathClass.new(start_node, end_node)
	assert_true(path.is_valid, "Path is valid")
	assert_equal(path.waypoints.size(), 1, "Path has one segment initially")

	# Test path distance
	path.distance = 100.0
	assert_equal(path.distance, 100.0, "Path distance calculated")

	# Test interpolation
	var mid = path.interpolate(0.5)
	assert_equal(mid, Vector3(50, 0, 0), "Interpolation at 0.5")

	# Test waypoint addition
	path.add_waypoint(Vector3(25, 0, 0))
	assert_equal(path.waypoints.size(), 2, "Waypoint added")
	assert_equal(path.segments.size(), 2, "Segment count updated")

	# Test sampling
	var samples = path.sample(10)
	assert_equal(samples.size(), 11, "Sampling returns correct count")

	# Test discovered concepts
	path.add_discovered(start_node)
	path.add_discovered(end_node)
	var concepts = path.get_discovered_concepts()
	assert_true("start" in concepts, "Discovered concepts includes start")
	assert_true("end" in concepts, "Discovered concepts includes end")

#endregion

#region PalaceBuilder Tests

func test_palace_builder() -> void:
	print("\n--- Testing PalaceBuilder ---")

	var builder = PalaceBuilderClass.new()
	var concepts: Array[Dictionary] = [
		{"name": "machine_learning", "tags": ["ai", "data"]},
		{"name": "neural_networks", "tags": ["ai", "deep_learning"]},
		{"name": "statistics", "tags": ["math", "data"]},
		{"name": "biology", "tags": ["science", "life"]},
	]

	var memory = builder.build(concepts)
	assert_equal(memory.size(), 4, "All concepts stored")

	# Check that related concepts are closer together
	var ml_node = memory.retrieve_by_concept("machine_learning")
	var nn_node = memory.retrieve_by_concept("neural_networks")
	var bio_node = memory.retrieve_by_concept("biology")

	assert_true(ml_node != null, "ML concept found")
	assert_true(nn_node != null, "NN concept found")
	assert_true(bio_node != null, "Biology concept found")

	# ML and NN should be closer than ML and Biology
	if ml_node and nn_node and bio_node:
		var ml_nn_dist = ml_node.location.distance_to(nn_node.location)
		var ml_bio_dist = ml_node.location.distance_to(bio_node.location)
		assert_true(ml_nn_dist < ml_bio_dist, "Related concepts are closer together")

	# Test linear build
	var linear_memory = builder.build_linear(["step1", "step2", "step3", "step4"])
	assert_equal(linear_memory.size(), 4, "Linear build stores all concepts")

#endregion

#region Spatial Reasoning Tests

func test_reasoning() -> void:
	print("\n--- Testing Spatial Reasoning ---")

	var memory = SpatialMemoryClass.new(10.0)

	# Build a small knowledge graph
	memory.store("machine_learning", Vector3(0, 0, 0))
	memory.store("neural_networks", Vector3(50, 0, 0))
	memory.store("deep_learning", Vector3(53, 0, 2))
	memory.store("gradients", Vector3(50, 0, 5))
	memory.store("backpropagation", Vector3(50, 0, 8))
	memory.store("computer_vision", Vector3(0, 0, 100))

	# Test path finding
	var path = memory.find_path("machine_learning", "neural_networks")
	assert_true(path != null, "Path found between ML and NN")
	if path:
		var concepts = path.get_discovered_concepts()
		print("  Concepts along path: %s" % str(concepts))
		assert_true(concepts.size() > 0, "Path has discovered concepts")

	# Test neighborhood
	var neighbors = memory.neighborhood("neural_networks", 30.0)
	print("  Neighborhood of NN: %d nodes" % neighbors.size())
	assert_true(neighbors.size() >= 2, "NN has neighbors")

	# Test semantic distance
	var dist = memory.semantic_distance("machine_learning", "neural_networks")
	var dist_cv = memory.semantic_distance("machine_learning", "computer_vision")
	assert_true(dist < dist_cv, "ML-NN closer than ML-CV (semantic distance)")

#endregion

#region Performance Tests

func test_performance() -> void:
	print("\n--- Testing Performance ---")

	var memory = SpatialMemoryClass.new(10.0)
	var start_time = Time.get_ticks_msec()

	# Store 1000 nodes
	for i in range(1000):
		memory.store("concept_%d" % i, Vector3(
			randf_range(-500.0, 500.0),
			randf_range(-500.0, 500.0),
			randf_range(-500.0, 500.0)
		))

	var store_time = Time.get_ticks_msec() - start_time
	print("  Store 1000 nodes: %.2f ms" % store_time)
	assert_true(store_time < 100, "Store 1000 nodes < 100ms")

	# Query neighbors
	start_time = Time.get_ticks_msec()
	var neighbors = memory.neighbors(Vector3(0, 0, 0), 50.0)
	var query_time = Time.get_ticks_msec() - start_time
	print("  Query neighbors: %.2f ms (%d results)" % [query_time, neighbors.size()])
	assert_true(query_time < 1, "Query neighbors < 1ms")

	# K-nearest query
	start_time = Time.get_ticks_msec()
	var k_nearest = memory.nearest_neighbors(Vector3(0, 0, 0), 10)
	var k_time = Time.get_ticks_msec() - start_time
	print("  K-nearest query: %.2f ms" % k_time)
	assert_true(k_time < 5, "K-nearest query < 5ms")

	# Test serialization
	start_time = Time.get_ticks_msec()
	var data = memory.to_dict()
	var ser_time = Time.get_ticks_msec() - start_time
	print("  Serialize: %.2f ms" % ser_time)

	# Test deserialization
	start_time = Time.get_ticks_msec()
	var restored = SpatialMemoryClass.from_dict(data)
	var deser_time = Time.get_ticks_msec() - start_time
	print("  Deserialize: %.2f ms" % deser_time)
	assert_equal(restored.size(), memory.size(), "Restored memory has same size")
