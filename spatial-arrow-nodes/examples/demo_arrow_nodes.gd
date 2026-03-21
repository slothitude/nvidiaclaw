## demo_arrow_nodes.gd - Demo of 3D Arrow Nodes with Markdown Metadata
## Part of AWR v0.4 - Physics-Enhanced Spatial Memory
##
## This demo showcases:
## 1. THING nodes - concepts rendered as spheres
## 2. ARROW nodes - relationships rendered as 3D arrows
## 3. Markdown metadata attached to each node
## 4. Raycasting to detect what arrows point at
##
## Run: godot --path godot-test-project -s addons/awr/spatial/examples/demo_arrow_nodes.gd

extends SceneTree

const SpatialMemoryScript = preload("res://addons/awr/spatial/spatial_memory.gd")
const SpatialArrowNodeScript = preload("res://addons/awr/spatial/spatial_arrow_node.gd")

# Node types enum from SpatialArrowNode
enum NodeType { THING, ARROW }


func _init() -> void:
	print("\n========================================")
	print("  AWR 3D Arrow Nodes Demo")
	print("  Nodes = Things OR Arrows with Markdown")
	print("========================================\n")

	# Demo markdown parsing
	demo_markdown_parsing()

	# Demo arrow nodes
	demo_arrow_nodes()

	# Demo visualization concept
	demo_visualization_concept()

	print("\n========================================")
	print("  Demo Complete!")
	print("========================================\n")

	quit(0)


func demo_markdown_parsing() -> void:
	print("--- Markdown Metadata Parsing ---\n")

	# Create sample markdown content
	var thing_md = """---
type: thing
name: neural_networks
position: 100, 20, 0
tags: [ai, deep_learning, architecture]
semantic_type: concept
---

# Neural Networks

Computing systems inspired by biological neural networks.

## Definition
A neural network is a series of algorithms that endeavors to recognize
underlying relationships in a set of data.

## Components
- Input layer
- Hidden layers
- Output layer
- Weights and biases
"""

	# Create a thing node manually
	var thing_node = SpatialArrowNodeScript.new()
	thing_node.node_type = NodeType.THING
	thing_node.concept = "neural_networks"
	thing_node.concept_position = Vector3(100, 20, 0)
	thing_node.set_markdown(thing_md)

	# Parse the markdown
	var parsed = thing_node.parse_markdown()

	print("THING Node: neural_networks")
	print("  Frontmatter:")
	for key in parsed.frontmatter:
		print("    %s: %s" % [key, str(parsed.frontmatter[key])])
	print("  Sections:")
	for section in parsed.sections:
		print("    [%s] %d chars" % [section, parsed.sections[section].length()])

	# Create sample arrow markdown
	var arrow_md = """---
type: arrow
name: enables
from: neural_networks
to: deep_learning
strength: 0.9
---

# enables

Neural networks enable deep learning.

## Properties
- Strong relationship
- Direct dependency
"""

	var arrow_node = SpatialArrowNodeScript.new()
	arrow_node.node_type = NodeType.ARROW
	arrow_node.relationship = "enables"
	arrow_node.concept_position = Vector3(100, 20, 0)
	arrow_node.target_concept = "deep_learning"
	arrow_node.source_concept = "neural_networks"
	arrow_node.set_markdown(arrow_md)

	print("\nARROW Node: enables")
	print("  From: %s → To: %s" % [arrow_node.source_concept, arrow_node.target_concept])
	print("  Strength: %s" % str(arrow_node.get_frontmatter("strength", 0.5)))


func demo_arrow_nodes() -> void:
	print("\n--- Arrow Node Types ---\n")

	# Create a spatial memory to hold everything
	var memory = SpatialMemoryScript.new(10.0)

	# Create THING nodes
	var things = [
		{"concept": "artificial_intelligence", "pos": Vector3(0, 0, 0)},
		{"concept": "machine_learning", "pos": Vector3(50, 20, 0)},
		{"concept": "neural_networks", "pos": Vector3(100, 20, 0)},
		{"concept": "deep_learning", "pos": Vector3(150, 25, 0)},
		{"concept": "computer_vision", "pos": Vector3(0, 0, 100)},
	]

	for thing in things:
		memory.store(thing.concept, thing.pos, {"type": "thing"})
		print("  THING: %s @ %s" % [thing.concept, str(thing.pos)])

	# Create ARROW nodes (relationships)
	var arrows = [
		{"rel": "has_subfield", "from": "artificial_intelligence", "to": "machine_learning"},
		{"rel": "uses", "from": "machine_learning", "to": "neural_networks"},
		{"rel": "enables", "from": "neural_networks", "to": "deep_learning"},
		{"rel": "powers", "from": "deep_learning", "to": "computer_vision"},
	]

	print("\n  ARROW relationships:")
	for arrow in arrows:
		var from_node = memory.retrieve_by_concept(arrow.from)
		var to_node = memory.retrieve_by_concept(arrow.to)
		if from_node and to_node:
			# Create arrow node manually
			var arrow_node = SpatialArrowNodeScript.new()
			arrow_node.node_type = NodeType.ARROW
			arrow_node.relationship = arrow.rel
			arrow_node.concept_position = from_node.location
			arrow_node.target_concept = arrow.to
			arrow_node.source_concept = arrow.from
			arrow_node.spatial_memory = memory

			print("    %s ───%s───> %s" % [arrow.from, arrow.rel, arrow.to])
			print("      Distance: %.1f units" % arrow_node.distance_to_target())


func demo_visualization_concept() -> void:
	print("\n--- 3D Visualization Concept ---\n")

	print("  In a Godot 3D scene, nodes are rendered as:")
	print("")
	print("  THING nodes (concepts/entities):")
	print("    ┌─────────────────┐")
	print("    │    [Label]      │  ← Label3D floating above")
	print("    │       ●         │  ← SphereMesh")
	print("    │                 │")
	print("    │  Position: x,y,z│")
	print("    └─────────────────┘")
	print("")
	print("  ARROW nodes (relationships):")
	print("    ┌─────────────────┐")
	print("    │   (has_subfield)│  ← Label3D on arrow")
	print("    │  AI ══════════▶ │  ← Cylinder + Cone")
	print("    │           ML    │")
	print("    │                 │")
	print("    │  RayCast3D ───▶ │  ← For hit detection")
	print("    └─────────────────┘")
	print("")
	print("  Markdown Metadata:")
	print("    - Stored in .md files")
	print("    - Parsed into frontmatter + body")
	print("    - Sections extracted from ## headers")
	print("    - Used for AI context and reasoning")
	print("")
	print("  File structure:")
	print("    spatial_memory/")
	print("    ├── concepts/")
	print("    │   ├── artificial_intelligence.md")
	print("    │   ├── machine_learning.md")
	print("    │   └── neural_networks.md")
	print("    ├── relationships/")
	print("    │   ├── has_subfield.md")
	print("    │   ├── uses.md")
	print("    │   └── enables.md")
	print("    └── visualization.tscn  ← Godot scene")


## Example: Load from markdown file
func load_node_from_markdown(path: String) -> Variant:
	var node = SpatialArrowNodeScript.from_markdown(path)
	if node:
		print("  Loaded: %s from %s" % [str(node), path])
	return node


## Example: Create a complete knowledge graph from markdown files
func create_knowledge_graph_from_markdown(directory: String) -> Array:
	var nodes: Array = []

	var dir = DirAccess.open(directory)
	if dir == null:
		return nodes

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".md"):
			var node = SpatialArrowNodeScript.from_markdown(directory + "/" + file_name)
			if node:
				nodes.append(node)
		file_name = dir.get_next()

	dir.list_dir_end()

	return nodes
