extends Node3D
## Demo Scene for Spatial Arrow Nodes
##
## Demonstrates:
## - THING nodes (concepts) rendered as spheres
## - ARROW nodes (relationships) rendered as 3D arrows
## - Markdown metadata loading
## - Spatial queries

const SpatialMemoryScript = preload("res://addons/spatial_arrows/spatial_memory.gd")
const SpatialArrowNodeScript = preload("res://addons/spatial_arrows/spatial_arrow_node.gd")
const SpatialMemoryVisualizer = preload("res://addons/spatial_arrows/spatial_memory_visualizer.gd")

var memory = null
var visualizer = null

# Node types
enum NodeType { THING, ARROW }


func _ready() -> void:
	print("=== Spatial Arrow Nodes Demo ===")

	# Create spatial memory
	memory = SpatialMemoryScript.new(10.0)

	# Build knowledge graph
	_build_knowledge_graph()

	# Create visualizer
	visualizer = SpatialMemoryVisualizer.new()
	visualizer.spatial_memory = memory
	add_child(visualizer)
	visualizer.refresh_visualization()

	# Create 3D arrow nodes
	_create_3d_nodes()

	# Setup camera
	_setup_camera()

	print("Demo ready. Use mouse to orbit camera.")


func _build_knowledge_graph() -> void:
	# Store concepts (THINGs)
	memory.store("artificial_intelligence", Vector3(0, 0, 0), {"type": "thing"})
	memory.store("machine_learning", Vector3(50, 20, 0), {"type": "thing"})
	memory.store("neural_networks", Vector3(100, 20, 0), {"type": "thing"})
	memory.store("deep_learning", Vector3(150, 25, 0), {"type": "thing"})
	memory.store("computer_vision", Vector3(0, 0, 100), {"type": "thing"})

	# Create connections (will be rendered as ARROWs)
	var ai = memory.retrieve_by_concept("artificial_intelligence")
	var ml = memory.retrieve_by_concept("machine_learning")
	var nn = memory.retrieve_by_concept("neural_networks")
	var dl = memory.retrieve_by_concept("deep_learning")
	var cv = memory.retrieve_by_concept("computer_vision")

	if ai: ai.connect_to("machine_learning", "has_subfield", 1.0)
	if ml: ml.connect_to("neural_networks", "uses", 0.9)
	if nn: nn.connect_to("deep_learning", "enables", 1.0)
	if dl: dl.connect_to("computer_vision", "powers", 0.8)

	print("Created %d concepts with connections" % memory.size())


func _create_3d_nodes() -> void:
	# Create THING nodes for each concept
	for node in memory.get_all_nodes():
		var thing = SpatialArrowNodeScript.new()
		thing.node_type = NodeType.THING
		thing.concept = node.concept
		thing.concept_position = node.location
		add_child(thing)

	# Create ARROW nodes for connections
	for node in memory.get_all_nodes():
		for conn in node.connections:
			var arrow = SpatialArrowNodeScript.new()
			arrow.node_type = NodeType.ARROW
			arrow.relationship = conn.type
			arrow.source_concept = node.concept
			arrow.target_concept = conn.concept
			arrow.concept_position = node.location
			arrow.spatial_memory = memory
			add_child(arrow)


func _setup_camera() -> void:
	# Add a camera controller
	var camera = Camera3D.new()
	camera.position = Vector3(100, 100, 100)
	camera.look_at(Vector3(50, 0, 0))
	add_child(camera)

	# Add some lighting
	var light = DirectionalLight3D.new()
	light.position = Vector3(50, 100, 50)
	light.look_at(Vector3(50, 0, 0))
	add_child(light)

	# Add ambient light
	var ambient = WorldEnvironment.new()
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SKY
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	ambient.environment = env
	add_child(ambient)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Toggle visualization
				if visualizer:
					visualizer.visible = not visualizer.visible
			KEY_R:
				# Refresh visualization
				if visualizer:
					visualizer.refresh_visualization()
			KEY_ESCAPE:
				get_tree().quit()
