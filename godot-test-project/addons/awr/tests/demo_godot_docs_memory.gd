## demo_godot_docs_memory.gd - Godot Docs Spatial Memory Demo
## Part of AWR v0.2 - Spatial Memory Engine
##
## Demonstrates loading and querying the Godot documentation spatial memory.
##
## Run with: godot --headless --path godot-test-project -s addons/awr/tests/demo_godot_docs_memory.gd

extends SceneTree

# Load scripts
var SpatialMemoryClass


func _init() -> void:
	SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")

	print("\n" + "=".repeat(70))
	print("  AWR v0.2 - Godot Docs Spatial Memory Demo")
	print("  \"Navigable 3D concept space from Godot documentation\"")
	print("=".repeat(70) + "\n")

	# Load the Godot docs memory
	var memory = SpatialMemoryClass.load_from("res://addons/awr/spatial/godot_docs_memory.json")

	if memory == null:
		push_error("Failed to load godot_docs_memory.json")
		quit(1)
		return

	print("  ✓ Loaded %d memory nodes" % memory.size())
	print()

	# Explore the memory
	_explore_memory(memory)

	# Demo spatial queries
	_demo_spatial_queries(memory)

	# Demo path finding
	_demo_path_finding(memory)

	print("\n" + "=".repeat(70))
	print("  Demo Complete")
	print("=".repeat(70) + "\n")

	quit(0)


func _explore_memory(memory) -> void:
	print("┌─────────────────────────────────────────────────────────────────┐")
	print("│  MEMORY OVERVIEW                                                │")
	print("└─────────────────────────────────────────────────────────────────┘\n")

	var nodes = memory.get_all_nodes()
	print("  Total nodes: %d" % nodes.size())

	# Find unique sources
	var sources = {}
	for node in nodes:
		var src = node.metadata.get("source", "unknown")
		sources[src] = true

	print("  Unique sources: %d" % sources.size())
	print()

	# Show sample nodes
	print("  Sample concepts:")
	for i in range(mini(5, nodes.size())):
		var node = nodes[i]
		var concept = node.concept.substr(0, 50)
		print("    - %s" % concept)
	print()


func _demo_spatial_queries(memory) -> void:
	print("┌─────────────────────────────────────────────────────────────────┐")
	print("│  SPATIAL QUERIES                                                │")
	print("└─────────────────────────────────────────────────────────────────┘\n")

	# Get a random point to query from
	var nodes = memory.get_all_nodes()
	if nodes.size() == 0:
		print("  No nodes to query!")
		return

	var center_node = nodes[0]
	var center = center_node.location

	print("  Query: What's near '%s'?" % center_node.concept.substr(0, 40))
	print()

	# Find neighbors within radius 100
	var neighbors = memory.neighbors(center, 100.0)

	print("  Found %d neighbors within radius 100:" % neighbors.size())
	for i in range(mini(5, neighbors.size())):
		var n = neighbors[i]
		var dist = center.distance_to(n.location)
		print("    - %s (dist: %.1f)" % [n.concept.substr(0, 40), dist])
	print()

	# Find nearest neighbors
	print("  Query: 5 nearest neighbors")
	var nearest = memory.nearest_neighbors(center, 5)
	for n in nearest:
		print("    - %s" % n.concept.substr(0, 40))
	print()


func _demo_path_finding(memory) -> void:
	print("┌─────────────────────────────────────────────────────────────────┐")
	print("│  PATH FINDING (Spatial Reasoning)                               │")
	print("└─────────────────────────────────────────────────────────────────┘\n")

	var nodes = memory.get_all_nodes()
	if nodes.size() < 2:
		print("  Not enough nodes for path finding!")
		return

	# Try to find path between two distant nodes
	var node_a = nodes[0]
	var node_b = nodes[nodes.size() - 1]

	print("  Finding path between:")
	print("    Start: %s" % node_a.concept.substr(0, 50))
	print("    End:   %s" % node_b.concept.substr(0, 50))
	print()

	var path = memory.find_path(node_a.concept, node_b.concept)

	if path == null:
		print("  No path found!")
		return

	print("  Path found!")
	print("    Distance: %.1f units" % path.distance)
	print("    Waypoints: %d" % path.waypoints.size())

	# Show concepts along the path
	var concepts = memory.concepts_along_path(path)
	print("    Concepts along path: %d" % concepts.size())
	for i in range(mini(5, concepts.size())):
		print("      - %s" % concepts[i].substr(0, 50))
	print()

	# Calculate semantic distance
	var sem_dist = memory.semantic_distance(node_a.concept, node_b.concept)
	print("  Semantic distance: %.1f" % sem_dist)
	print()
