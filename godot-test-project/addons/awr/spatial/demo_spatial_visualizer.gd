## demo_spatial_visualizer.gd - Demo of 3D Spatial Memory Visualization
## Part of AWR v0.4 - Physics-Enhanced Spatial Memory
##
## This demo creates a 3D visualization of a memory palace with:
## - Nodes as 3D spheres (color-coded by semantic type)
## - Arrows showing connections between concepts
## - Raycasting for interaction
## - Animated connection lines
##
## Run: godot --path godot-test-project -s addons/awr/spatial/demo_spatial_visualizer.gd

extends SceneTree

const SpatialMemoryScript = preload("res://addons/awr/spatial/spatial_memory.gd")
const MemoryNodeScript = preload("res://addons/awr/spatial/memory_node.gd")


func _init() -> void:
	print("\n========================================")
	print("  AWR 3D Spatial Memory Visualization Demo")
	print("========================================\n")

	# Create a spatial memory
	var memory = SpatialMemoryScript.new(10.0)

	# Build a knowledge graph about AI
	_build_ai_knowledge_graph(memory)

	# Create some physical entities
	_create_physical_entities(memory)

	# Create wisdom nodes
	_create_wisdom_nodes(memory)

	# Demo spatial queries
	print("\n--- Spatial Queries ---")
	_demo_spatial_queries(memory)

	# Demo physics simulation
	print("\n--- Physics Simulation ---")
	_demo_physics(memory)

	# Demo 3D visualization concept
	print("\n--- 3D Visualization Design ---")
	_demo_visualization_design(memory)

	print("\n========================================")
	print("  Demo Complete!")
	print("========================================\n")

	quit(0)


func _build_ai_knowledge_graph(memory) -> void:
	print("Building AI knowledge graph...")

	# Core concepts
	var ai = memory.store("artificial_intelligence", Vector3(0, 0, 0), {
		"semantic_type": "concept",
		"tags": ["core", "computer_science"]
	})

	var ml = memory.store("machine_learning", Vector3(50, 20, 0), {
		"semantic_type": "concept",
		"tags": ["core", "learning"]
	})

	var nn = memory.store("neural_networks", Vector3(100, 20, 0), {
		"semantic_type": "concept",
		"tags": ["architecture", "deep_learning"]
	})

	var dl = memory.store("deep_learning", Vector3(150, 25, 0), {
		"semantic_type": "concept",
		"tags": ["architecture"]
	})

	var cv = memory.store("computer_vision", Vector3(0, 0, 100), {
		"semantic_type": "concept",
		"tags": ["application"]
	})

	var nlp = memory.store("natural_language", Vector3(0, 0, -100), {
		"semantic_type": "concept",
		"tags": ["application"]
	})

	var rl = memory.store("reinforcement_learning", Vector3(50, 40, 50), {
		"semantic_type": "concept",
		"tags": ["learning", "agent"]
	})

	# Create connections
	ai.connect_to("machine_learning", "has_subfield", 1.0)
	ml.connect_to("neural_networks", "uses", 0.9)
	ml.connect_to("reinforcement_learning", "includes", 0.8)
	nn.connect_to("deep_learning", "enables", 1.0)
	dl.connect_to("computer_vision", "powers", 0.8)
	dl.connect_to("natural_language", "powers", 0.8)
	ai.connect_to("computer_vision", "application", 0.7)
	ai.connect_to("natural_language", "application", 0.7)

	print("  Created %d concepts with connections" % memory.size())


func _create_physical_entities(memory) -> void:
	print("Creating physical entities...")

	# Create a bouncing ball concept
	var ball = memory.store_entity("bouncing_ball", Vector3(0, 50, 0), 1.0, 2.0)
	ball.metadata["description"] = "A physical ball that demonstrates physics simulation"
	ball.velocity = Vector3(5, 0, 3)
	ball.restitution = 0.8

	# Create a falling cube
	var cube = memory.store_entity("falling_cube", Vector3(30, 80, 20), 2.0, 2.0)
	cube.metadata["description"] = "A heavier cube"
	cube.velocity = Vector3(-2, 0, 1)

	# Create a static floor
	var floor_node = memory.store_entity("floor", Vector3(0, -10, 0), 100.0, 100.0)
	floor_node.is_static = true
	floor_node.collision_radius = 200.0
	floor_node.metadata["description"] = "The ground plane"

	print("  Created %d physical entities" % memory.get_physical_nodes().size())


func _create_wisdom_nodes(memory) -> void:
	print("Creating wisdom nodes from The Crypt...")

	# Store ancestral wisdom at specific locations
	memory.store_wisdom(
		"avoid_walls",
		Vector3(0, 100, 0),
		"navigation",
		"Always check for collisions before committing to a path"
	)

	memory.store_wisdom(
		"momentum_conservation",
		Vector3(50, 100, 0),
		"physics",
		"Objects in motion tend to stay in motion"
	)

	memory.store_wisdom(
		"hierarchical_planning",
		Vector3(100, 100, 0),
		"strategy",
		"Break complex goals into simpler subtasks"
	)

	print("  Created wisdom nodes")


func _demo_spatial_queries(memory) -> void:
	# Cone query
	var cone_results = memory.cone_query(
		Vector3(0, 0, 0),  # origin
		Vector3(1, 0, 0),  # direction (positive X)
		PI / 3,            # 60 degree cone
		200.0              # max distance
	)
	print("  Cone query (60° forward): %d results" % cone_results.size())
	for result in cone_results.slice(0, 3):
		print("    - %s at distance %.1f" % [result.node.concept, result.distance])

	# Find path
	var path = memory.find_path("artificial_intelligence", "deep_learning")
	if path:
		print("  Path AI -> Deep Learning:")
		print("    Distance: %.1f" % path.distance)
		print("    Concepts: %s" % str(path.get_discovered_concepts()))

	# What is ML near?
	var neighbors = memory.neighborhood("machine_learning", 50.0)
	print("  Neighbors of ML (50 units): %s" % [", ".join(neighbors.map(func(n): return n.concept))])

	# Relative positions
	var to_left = memory.relative_position("machine_learning", "left")
	print("  To the left of ML: %s" % [", ".join(to_left.slice(0, 2).map(func(n): return n.node.concept))])


func _demo_physics(memory) -> void:
	print("  Simulating physics for 1 second (60 steps)...")

	# Disable gravity for demo
	memory.gravity = Vector3(0, 0, 0)

	var ball = memory.retrieve_by_concept("bouncing_ball")
	if ball:
		print("  Ball initial position: %s, velocity: %s" % [str(ball.location), str(ball.velocity)])

		# Apply an impulse
		ball.apply_impulse(Vector3(10, 5, 0))
		print("  Applied impulse, new velocity: %s" % str(ball.velocity))

		# Step physics
		for i in range(60):
			memory.step_physics(1.0 / 60.0)

		print("  Ball final position: %s, velocity: %s" % [str(ball.location), str(ball.velocity)])


func _demo_visualization_design(memory) -> void:
	print("  3D Visualization Design:")
	print("  ┌─────────────────────────────────────────┐")
	print("  │     [AI]───────[ML]───────[NN]──[DL]    │")
	print("  │       │          │                    │  │")
	print("  │       │      [RL]│                    │  │")
	print("  │       ↓          ↓                    ↓  │")
	print("  │     [CV]       [NLP]──────────────────┘  │")
	print("  │                                          │")
	print("  │  ○ = concept (blue)                      │")
	print("  │  ● = entity (green)                      │")
	print("  │  ★ = wisdom (pink)                       │")
	print("  │  ───── = connection (gray)               │")
	print("  │  ────> = strong connection (yellow)      │")
	print("  └─────────────────────────────────────────┘")

	print("\n  To use in Godot scene:")
	print("    var viz = SpatialMemoryVisualizer.new()")
	print("    viz.spatial_memory = my_memory")
	print("    add_child(viz)")
	print("    viz.refresh_visualization()")
	print("\n  Features:")
	print("    - Nodes rendered as colored spheres")
	print("    - Connections shown as lines with arrow heads")
	print("    - Labels floating above nodes")
	print("    - RayCast3D for interaction")
	print("    - Animated pulsing connections")
	print("    - Click to highlight nodes")
