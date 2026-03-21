## demo_spatial_memory.gd - The Killer Demo
## Part of AWR v0.2 - Spatial Memory Engine
##
## Demonstrates: "How are X and Y related?" via spatial reasoning
##
## Run with: godot --headless --path godot-test-project -s addons/awr/tests/demo_spatial_memory.gd

extends SceneTree

# Load scripts
var SpatialMemoryClass
var PalaceBuilderClass


func _init() -> void:
	SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")
	PalaceBuilderClass = load("res://addons/awr/spatial/palace_builder.gd")

	print("\n" + "=".repeat(70))
	print("  AWR v0.2 - Spatial Memory Engine Demo")
	print("  \"The first AI memory system based on cognitive maps\"")
	print("=".repeat(70) + "\n")

	# Build the demo
	demo_wikipedia_article()

	# Interactive-style queries
	demo_reasoning_queries()

	print("\n" + "=".repeat(70))
	print("  Demo Complete")
	print("=".repeat(70) + "\n")

	quit(0)


func demo_wikipedia_article() -> void:
	print("┌─────────────────────────────────────────────────────────────────┐")
	print("│  INPUT: Knowledge about AI/ML (like a Wikipedia article)       │")
	print("└─────────────────────────────────────────────────────────────────┘\n")

	# Concepts extracted from "machine learning" knowledge domain
	var concepts: Array = [
		# Room 1: ML Fundamentals
		{"name": "machine_learning", "tags": ["ai", "fundamentals"], "metadata": {"summary": "Core AI paradigm"}},
		{"name": "supervised_learning", "tags": ["ai", "fundamentals"], "metadata": {"summary": "Learning from labeled data"}},
		{"name": "unsupervised_learning", "tags": ["ai", "fundamentals"], "metadata": {"summary": "Finding patterns in unlabeled data"}},
		{"name": "data", "tags": ["ai", "fundamentals"], "metadata": {"summary": "Raw information"}},

		# Room 2: Neural Networks
		{"name": "neural_networks", "tags": ["ai", "deep"], "metadata": {"summary": "Brain-inspired architectures"}},
		{"name": "deep_learning", "tags": ["ai", "deep"], "metadata": {"summary": "Multi-layer neural networks"}},
		{"name": "backpropagation", "tags": ["ai", "deep"], "metadata": {"summary": "Gradient computation algorithm"}},
		{"name": "gradients", "tags": ["ai", "deep"], "metadata": {"summary": "Direction of steepest increase"}},

		# Room 3: Applications
		{"name": "computer_vision", "tags": ["ai", "application"], "metadata": {"summary": "Image understanding"}},
		{"name": "nlp", "tags": ["ai", "application"], "metadata": {"summary": "Language processing"}},
		{"name": "reinforcement_learning", "tags": ["ai", "application"], "metadata": {"summary": "Learning from rewards"}},
		{"name": "robotics", "tags": ["ai", "application"], "metadata": {"summary": "Physical AI systems"}},

		# Room 4: Optimization
		{"name": "gradient_descent", "tags": ["math", "optimization"], "metadata": {"summary": "Optimization algorithm"}},
		{"name": "loss_functions", "tags": ["math", "optimization"], "metadata": {"summary": "Error measurement"}},
		{"name": "regularization", "tags": ["math", "optimization"], "metadata": {"summary": "Preventing overfitting"}},
		{"name": "hyperparameters", "tags": ["math", "optimization"], "metadata": {"summary": "Tunable parameters"}},
	]

	print("  Building memory palace from %d concepts..." % concepts.size())

	var builder = PalaceBuilderClass.new()
	var memory = builder.build(concepts)

	print("  ✓ Palace built with %d nodes in %d rooms\n" % [memory.size(), 4])

	# Show the spatial layout
	print("  Spatial Layout:")
	print("  ┌─────────────────────────────────────────────────────────────┐")
	for node in memory.get_all_nodes():
		var room = node.metadata.get("room_index", 0)
		var pos = node.location
		print("  │  [%d] %-25s @ (%3.0f, %3.0f, %3.0f)" % [room, node.concept, pos.x, pos.y, pos.z])
	print("  └─────────────────────────────────────────────────────────────┘\n")


func demo_reasoning_queries() -> void:
	print("┌─────────────────────────────────────────────────────────────────┐")
	print("│  SPATIAL REASONING: \"How are X and Y related?\"                  │")
	print("└─────────────────────────────────────────────────────────────────┘\n")

	# Build a richer memory for reasoning demo
	var memory = SpatialMemoryClass.new(10.0)

	# Room 1: ML Fundamentals (at origin)
	memory.store("machine_learning", Vector3(0, 0, 0), {"summary": "Core AI paradigm"})
	memory.store("supervised_learning", Vector3(5, 0, 3), {"summary": "Learning from labeled data"})
	memory.store("unsupervised_learning", Vector3(-5, 0, 3), {"summary": "Finding patterns"})
	memory.store("data", Vector3(0, 0, 8), {"summary": "Raw information"})

	# Room 2: Neural Networks (at x=50)
	memory.store("neural_networks", Vector3(50, 0, 0), {"summary": "Brain-inspired architectures"})
	memory.store("deep_learning", Vector3(55, 0, 3), {"summary": "Multi-layer NNs"})
	memory.store("backpropagation", Vector3(45, 0, 3), {"summary": "Gradient algorithm"})
	memory.store("gradients", Vector3(50, 0, 8), {"summary": "Direction vectors"})

	# Room 3: Applications (at x=100)
	memory.store("computer_vision", Vector3(100, 0, 0), {"summary": "Image understanding"})
	memory.store("nlp", Vector3(100, 0, 10), {"summary": "Language processing"})
	memory.store("reinforcement_learning", Vector3(100, 0, -10), {"summary": "Learning from rewards"})
	memory.store("robotics", Vector3(105, 0, 5), {"summary": "Physical AI"})

	# Room 4: Optimization (at x=150)
	memory.store("gradient_descent", Vector3(150, 0, 0), {"summary": "Optimization algorithm"})
	memory.store("loss_functions", Vector3(145, 0, 5), {"summary": "Error measurement"})
	memory.store("optimization", Vector3(155, 0, 5), {"summary": "Finding minima"})

	# Query 1: ML -> Neural Networks
	_query_relationship(memory, "machine_learning", "neural_networks")

	# Query 2: Deep Learning -> Reinforcement Learning
	_query_relationship(memory, "deep_learning", "reinforcement_learning")

	# Query 3: Data -> Computer Vision
	_query_relationship(memory, "data", "computer_vision")

	# Semantic distance comparisons
	print("  ┌─────────────────────────────────────────────────────────────┐")
	print("  │  SEMANTIC DISTANCES (lower = more related)                  │")
	print("  ├─────────────────────────────────────────────────────────────┤")

	var pairs = [
		["machine_learning", "supervised_learning"],
		["machine_learning", "neural_networks"],
		["machine_learning", "computer_vision"],
		["deep_learning", "neural_networks"],
		["deep_learning", "gradient_descent"],
		["nlp", "computer_vision"],
	]

	for pair in pairs:
		var dist = memory.semantic_distance(pair[0], pair[1])
		var relatedness = "HIGH" if dist < 30 else ("MEDIUM" if dist < 80 else "LOW")
		print("  │  %-25s ↔ %-25s: %5.1f  [%s]" % [pair[0], pair[1], dist, relatedness])

	print("  └─────────────────────────────────────────────────────────────┘\n")


func _query_relationship(memory, concept_a: String, concept_b: String) -> void:
	print("  ┌─────────────────────────────────────────────────────────────┐")
	print("  │  QUERY: How are '%s' and '%s' related?" % [concept_a, concept_b])
	print("  ├─────────────────────────────────────────────────────────────┤")

	var path = memory.find_path(concept_a, concept_b)

	if path == null:
		print("  │  No path found!")
		print("  └─────────────────────────────────────────────────────────────┘\n")
		return

	# Get concepts along the path
	var concepts = memory.concepts_along_path(path)

	# Get the nodes
	var node_a = memory.retrieve_by_concept(concept_a)
	var node_b = memory.retrieve_by_concept(concept_b)

	print("  │                                                              │")
	print("  │  %-25s @ (%3.0f, %3.0f, %3.0f)" % [concept_a, node_a.location.x, node_a.location.y, node_a.location.z])
	print("  │          │                                                   │")
	print("  │          │ distance: %.1f units" % path.distance)
	print("  │          ▼                                                   │")

	# Show intermediate concepts
	for concept in concepts:
		if concept != concept_a and concept != concept_b:
			print("  │      → %-52s│" % concept)

	print("  │          │                                                   │")
	print("  │          ▼                                                   │")
	print("  │  %-25s @ (%3.0f, %3.0f, %3.0f)" % [concept_b, node_b.location.x, node_b.location.y, node_b.location.z])
	print("  │                                                              │")
	print("  ├─────────────────────────────────────────────────────────────┤")
	print("  │  ANSWER: '%s' and '%s' are connected via:" % [concept_a, concept_b])
	print("  │          %s" % [", ".join(concepts)])
	print("  └─────────────────────────────────────────────────────────────┘\n")
