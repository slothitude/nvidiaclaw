## test_spatial_memory.gd - Unit tests for Spatial Memory Engine
## Part of AWR v0.2
##
## Run with: godot --headless --path godot-test-project -s addons/awr/tests/test_spatial_memory.gd

extends SceneTree

# Scripts loaded at runtime to avoid parse-time resolution issues
var MemoryNodeClass
var SpatialIndexClass
var SpatialMemoryClass
var SpatialPathClass
var PalaceBuilderClass

var passed: int = 0
var failed: int = 0


func _init() -> void:
	# Load scripts at runtime
	MemoryNodeClass = load("res://addons/awr/spatial/memory_node.gd")
	SpatialIndexClass = load("res://addons/awr/spatial/spatial_index.gd")
	SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")
	SpatialPathClass = load("res://addons/awr/spatial/spatial_path.gd")
	PalaceBuilderClass = load("res://addons/awr/spatial/palace_builder.gd")

	print("\n========================================")
	print("  AWR Spatial Memory Engine Tests")
	print("========================================\n")

	# Core tests
	test_memory_node()
	test_spatial_index()
	test_spatial_memory()
	test_spatial_path()
	test_palace_builder()
	test_reasoning()

	# Performance tests
	test_performance()

	print("\n========================================")
	print("  Results: %d passed, %d failed" % [passed, failed])
	print("========================================\n")

	quit(0 if failed == 0 else 1)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] " + message)
		passed += 1
	else:
		print("  [FAIL] " + message)
		failed += 1


func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		print("  [PASS] " + message)
		passed += 1
	else:
		print("  [FAIL] " + message + " (expected: %s, got: %s)" % [expected, actual])
		failed += 1


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		print("  [PASS] " + message)
		passed += 1
	else:
		print("  [FAIL] " + message + " (expected: %.4f, got: %.4f)" % [expected, actual])
		failed += 1


#region MemoryNode Tests

func test_memory_node() -> void:
	print("\n--- Testing MemoryNode ---")

	# Test creation
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
	assert_true("related_concept" in node.connections, "Connection added")
	node.disconnect_from("related_concept")
	assert_true("related_concept" not in node.connections, "Connection removed")

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
	assert_equal(results.size(), 2, "Sphere query finds nodes in range")

	# Test nearest query
	var nearest = index.query_nearest_one(Vector3(12, 5, 5))
	assert_equal(nearest.concept, "node2", "Nearest query finds closest node")

	# Test k-nearest
	var k_nearest = index.query_nearest(Vector3(15, 5, 5), 2)
	assert_equal(k_nearest.size(), 2, "K-nearest returns correct count")

	# Test concept lookup
	index.insert(MemoryNodeClass.new("Machine Learning", Vector3(0, 0, 0)))
	var found = index.find_by_concept("machine learning")
	assert_true(found != null, "Concept lookup is case-insensitive")

	# Test removal
	index.remove(node1)
	assert_equal(index.node_count, 3, "Removal decreases count")

#endregion

#region SpatialMemory Tests

func test_spatial_memory() -> void:
	print("\n--- Testing SpatialMemory ---")

	var memory = SpatialMemoryClass.new()

	# Test store and retrieve
	var node = memory.store("concept_a", Vector3(10, 0, 0), {"type": "test"})
	assert_true(node != null, "Store returns node")
	assert_equal(memory.size(), 1, "Memory size increases")

	var retrieved = memory.retrieve(Vector3(10, 0, 0))
	assert_equal(retrieved.concept, "concept_a", "Retrieve by location works")

	# Test retrieve by concept
	var by_concept = memory.retrieve_by_concept("concept_a")
	assert_equal(by_concept.concept, "concept_a", "Retrieve by concept works")

	# Test neighbors
	memory.store("neighbor1", Vector3(12, 0, 0))
	memory.store("neighbor2", Vector3(15, 0, 0))
	memory.store("far_away", Vector3(100, 0, 0))

	var neighbors = memory.neighbors(Vector3(10, 0, 0), 10.0)
	assert_equal(neighbors.size(), 3, "Neighbors query finds nearby nodes")

	# Test semantic distance
	var dist = memory.semantic_distance("concept_a", "neighbor1")
	assert_near(dist, 2.0, 0.1, "Semantic distance calculated correctly")

	var far_dist = memory.semantic_distance("concept_a", "far_away")
	assert_near(far_dist, 90.0, 0.1, "Semantic distance to far node")

	# Test remove
	var removed = memory.remove(Vector3(100, 0, 0))
	assert_true(removed, "Remove returns true")
	assert_equal(memory.size(), 3, "Memory size decreases after remove")

#endregion

#region SpatialPath Tests

func test_spatial_path() -> void:
	print("\n--- Testing SpatialPath ---")

	var start = MemoryNodeClass.new("start", Vector3(0, 0, 0))
	var end = MemoryNodeClass.new("end", Vector3(100, 0, 0))

	var path = SpatialPathClass.new(start, end)

	assert_true(path.is_valid, "Path is valid")
	assert_equal(path.segment_count(), 1, "Path has one segment initially")
	assert_near(path.distance, 100.0, 0.1, "Path distance calculated")

	# Test interpolation
	var mid = path.interpolate(0.5)
	assert_near(mid.x, 50.0, 0.1, "Interpolation at 0.5")
	assert_near(mid.y, 0.0, 0.1, "Interpolation Y correct")

	# Test waypoint insertion
	path.add_waypoint(Vector3(50, 10, 0))
	assert_equal(path.waypoints.size(), 3, "Waypoint added")
	assert_equal(path.segment_count(), 2, "Segment count updated")

	# Test sampling
	var samples = path.sample_points(5)
	assert_equal(samples.size(), 5, "Sampling returns correct count")

	# Test discovered nodes
	path.add_discovered(start)
	path.add_discovered(end)
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
		{"name": "genetics", "tags": ["science", "life"]},
	]

	var memory = builder.build(concepts)

	assert_true(memory.size() == concepts.size(), "All concepts stored")

	# Test that related concepts are close
	var ml = memory.retrieve_by_concept("machine_learning")
	var nn = memory.retrieve_by_concept("neural_networks")
	var bio = memory.retrieve_by_concept("biology")

	assert_true(ml != null, "ML concept found")
	assert_true(nn != null, "NN concept found")
	assert_true(bio != null, "Biology concept found")

	# Related concepts (ML and NN) should be in same room
	var ml_nn_dist = ml.location.distance_to(nn.location)
	var ml_bio_dist = ml.location.distance_to(bio.location)
	assert_true(ml_nn_dist < ml_bio_dist, "Related concepts are closer together")

	# Test linear builder
	var linear_builder = PalaceBuilderClass.new()
	var sequence: Array[String] = ["step1", "step2", "step3", "step4"]
	var linear_memory = linear_builder.build_linear(sequence)

	assert_equal(linear_memory.size(), 4, "Linear build stores all concepts")

#endregion

#region Reasoning Tests

func test_reasoning() -> void:
	print("\n--- Testing Spatial Reasoning ---")

	var memory = SpatialMemoryClass.new()

	# Create a knowledge graph about AI
	# Room 1: ML fundamentals
	memory.store("machine_learning", Vector3(0, 0, 0))
	memory.store("supervised_learning", Vector3(3, 0, 2))
	memory.store("unsupervised_learning", Vector3(-3, 0, 2))
	memory.store("data", Vector3(0, 0, 5))

	# Room 2: Neural Networks
	memory.store("neural_networks", Vector3(50, 0, 0))
	memory.store("deep_learning", Vector3(53, 0, 2))
	memory.store("backpropagation", Vector3(47, 0, 2))
	memory.store("gradients", Vector3(50, 0, 5))

	# Room 3: Applications
	memory.store("computer_vision", Vector3(100, 0, 0))
	memory.store("nlp", Vector3(100, 0, 10))
	memory.store("reinforcement_learning", Vector3(100, 0, -10))

	# Test path finding (this IS reasoning!)
	print("\n  Query: How are machine_learning and neural_networks related?")
	var path = memory.find_path("machine_learning", "neural_networks")
	assert_true(path != null, "Path found between ML and NN")

	var concepts = memory.concepts_along_path(path)
	print("  Concepts along path: " + str(concepts))

	# Test concepts_between
	var between = memory.concepts_between("machine_learning", "neural_networks", 30.0)
	print("  Concepts between: " + str(between.size()) + " nodes")

	# Test neighborhood
	var neighborhood = memory.neighborhood("neural_networks", 15.0)
	print("  Neighborhood of NN: " + str(neighborhood.size()) + " nodes")

	# Test semantic distance
	var ml_nn_dist = memory.semantic_distance("machine_learning", "neural_networks")
	var ml_cv_dist = memory.semantic_distance("machine_learning", "computer_vision")
	assert_true(ml_nn_dist < ml_cv_dist, "ML-NN closer than ML-CV (semantic distance)")

#endregion

#region Performance Tests

func test_performance() -> void:
	print("\n--- Testing Performance ---")

	var memory = SpatialMemoryClass.new(10.0)

	# Store 1000 nodes
	var start_time = Time.get_ticks_usec()
	for i in range(1000):
		var x = randf_range(-500, 500)
		var y = randf_range(-500, 500)
		var z = randf_range(-500, 500)
		memory.store("concept_%d" % i, Vector3(x, y, z))
	var store_time = Time.get_ticks_usec() - start_time

	print("  Store 1000 nodes: %.2f ms" % (store_time / 1000.0))
	assert_true(store_time < 100000, "Store 1000 nodes < 100ms")

	# Query neighbors
	start_time = Time.get_ticks_usec()
	var neighbors = memory.neighbors(Vector3(0, 0, 0), 50.0)
	var query_time = Time.get_ticks_usec() - start_time

	print("  Query neighbors: %.2f ms (%d results)" % [query_time / 1000.0, neighbors.size()])
	assert_true(query_time < 1000, "Query neighbors < 1ms")

	# K-nearest query
	start_time = Time.get_ticks_usec()
	var k_nearest = memory.nearest_neighbors(Vector3(0, 0, 0), 10)
	var kn_query_time = Time.get_ticks_usec() - start_time

	print("  K-nearest query: %.2f ms" % (kn_query_time / 1000.0))
	assert_true(kn_query_time < 5000, "K-nearest query < 5ms")

	# Test index stats
	var stats = memory.get_stats()
	print("  Index stats: %d nodes, %d cells" % [stats.node_count, stats.index_stats.cell_count])

	# Serialization performance
	start_time = Time.get_ticks_usec()
	var dict = memory.to_dict()
	var serialize_time = Time.get_ticks_usec() - start_time
	print("  Serialize: %.2f ms" % (serialize_time / 1000.0))

	# Deserialization performance
	start_time = Time.get_ticks_usec()
	var restored = SpatialMemoryClass.from_dict(dict)
	var deserialize_time = Time.get_ticks_usec() - start_time
	print("  Deserialize: %.2f ms" % (deserialize_time / 1000.0))

	assert_equal(restored.size(), memory.size(), "Restored memory has same size")

#endregion
