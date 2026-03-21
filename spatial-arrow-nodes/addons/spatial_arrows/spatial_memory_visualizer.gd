## spatial_memory_visualizer.gd - 3D Visualization of Spatial Memory
## Part of AWR v0.4 - Physics-Enhanced Spatial Memory
##
## Renders MemoryNodes as 3D objects with arrows/rays showing connections.
## Uses ImmediateMesh for dynamic line drawing and RayCast3D for interaction.
##
## Usage:
##   var viz = SpatialMemoryVisualizer.new()
##   viz.spatial_memory = my_memory
##   add_child(viz)
##   viz.refresh_visualization()

class_name SpatialMemoryVisualizer
extends Node3D

## The spatial memory to visualize
var spatial_memory: Variant = null  # SpatialMemory

## Visualization settings
@export var node_size: float = 1.0
@export var connection_width: float = 0.1
@export var show_labels: bool = true
@export var show_connections: bool = true
@export var show_rays: bool = true
@export var animate_connections: bool = true

## Colors by semantic type
@export var concept_color: Color = Color(0.2, 0.6, 1.0, 0.8)
@export var entity_color: Color = Color(0.2, 1.0, 0.4, 0.8)
@export var action_color: Color = Color(1.0, 0.6, 0.2, 0.8)
@export var place_color: Color = Color(0.6, 0.2, 1.0, 0.8)
@export var event_color: Color = Color(1.0, 0.9, 0.2, 0.8)
@export var wisdom_color: Color = Color(1.0, 0.8, 0.9, 0.9)

## Connection colors
@export var connection_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var strong_connection_color: Color = Color(0.8, 0.8, 0.2, 0.8)
@export var highlighted_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Internal state
var _node_meshes: Dictionary = {}  # node_id -> MeshInstance3D
var _connection_lines: Node3D = null
var _label_nodes: Dictionary = {}  # node_id -> Label3D
var _raycast_nodes: Dictionary = {}  # node_id -> RayCast3D
var _arrow_meshes: Array = []

## Animation time
var _time: float = 0.0

## Currently highlighted node
var _highlighted_node_id: String = ""

## Signals
signal node_clicked(node_id: String, memory_node: Variant)
signal node_hovered(node_id: String, memory_node: Variant)
signal connection_clicked(from_id: String, to_id: String)


func _ready() -> void:
	# Create container for connection lines
	_connection_lines = Node3D.new()
	_connection_lines.name = "ConnectionLines"
	add_child(_connection_lines)


func _process(delta: float) -> void:
	if animate_connections and spatial_memory != null:
		_time += delta
		_update_animated_connections()


## Set the spatial memory to visualize
func set_spatial_memory(memory: Variant) -> void:  # memory: SpatialMemory
	spatial_memory = memory
	refresh_visualization()


## Refresh the entire visualization
func refresh_visualization() -> void:
	_clear_visualization()

	if spatial_memory == null:
		return

	# Get all nodes from spatial memory
	var all_nodes = _get_all_memory_nodes()

	# Create 3D representations
	for node in all_nodes:
		_create_node_mesh(node)
		if show_labels:
			_create_node_label(node)

	# Create connections
	if show_connections:
		_create_all_connections(all_nodes)

	# Create raycasts for interaction
	if show_rays:
		_create_raycast_system(all_nodes)


## Get all memory nodes from spatial memory
func _get_all_memory_nodes() -> Array:
	if spatial_memory == null:
		return []

	# Use the get_all_nodes method if available
	if spatial_memory.has_method("get_all_nodes"):
		return spatial_memory.get_all_nodes()

	return []


## Clear all visualization elements
func _clear_visualization() -> void:
	# Clear node meshes
	for mesh in _node_meshes.values():
		if is_instance_valid(mesh):
			mesh.queue_free()
	_node_meshes.clear()

	# Clear labels
	for label in _label_nodes.values():
		if is_instance_valid(label):
			label.queue_free()
	_label_nodes.clear()

	# Clear raycasts
	for raycast in _raycast_nodes.values():
		if is_instance_valid(raycast):
			raycast.queue_free()
	_raycast_nodes.clear()

	# Clear connection lines
	if _connection_lines != null:
		for child in _connection_lines.get_children():
			child.queue_free()

	# Clear arrows
	for arrow in _arrow_meshes:
		if is_instance_valid(arrow):
			arrow.queue_free()
	_arrow_meshes.clear()


## Create a 3D mesh for a memory node
func _create_node_mesh(node: Variant) -> void:  # node: MemoryNode
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Node_%s" % node.id
	mesh_instance.position = node.location

	# Create sphere mesh
	var sphere = SphereMesh.new()
	sphere.radius = node_size * node.scale.x
	sphere.height = node_size * 2.0 * node.scale.x
	sphere.radial_segments = 16
	sphere.rings = 8

	mesh_instance.mesh = sphere

	# Create material based on semantic type
	var material = StandardMaterial3D.new()
	material.albedo_color = _get_color_for_type(node.semantic_type)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.3
	material.emission_energy = node.salience  # Salience affects glow

	mesh_instance.set_surface_override_material(0, material)

	# Add collision for clicking
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	collision.shape.radius = node_size * node.scale.x
	static_body.add_child(collision)
	mesh_instance.add_child(static_body)

	# Connect click signal
	static_body.input_event.connect(_on_node_input_event.bind(node.id, node))

	add_child(mesh_instance)
	_node_meshes[node.id] = mesh_instance


## Create a label for a memory node
func _create_node_label(node: Variant) -> void:  # node: MemoryNode
	var label = Label3D.new()
	label.name = "Label_%s" % node.id
	label.position = node.location + Vector3(0, node_size * 1.5, 0)
	label.text = node.concept
	label.font_size = 24
	label.modulate = Color(1, 1, 1, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true

	add_child(label)
	_label_nodes[node.id] = label


## Create all connection lines between nodes
func _create_all_connections(nodes: Array) -> void:
	for node in nodes:
		for conn in node.connections:
			var target = spatial_memory.retrieve_by_concept(conn.concept)
			if target != null:
				_create_connection_line(node, target, conn)


## Create a single connection line with arrow
func _create_connection_line(from_node: Variant, to_node: Variant, connection: Dictionary) -> void:
	var line_container = Node3D.new()
	line_container.name = "Connection_%s_to_%s" % [from_node.id, to_node.id]

	# Create ImmediateMesh for the line
	var mesh_instance = MeshInstance3D.new()
	var immediate = ImmediateMesh.new()
	mesh_instance.mesh = immediate

	# Create line material
	var line_material = StandardMaterial3D.new()
	line_material.vertex_color_use_as_albedo = true
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Draw line
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	immediate.surface_set_color(_get_connection_color(connection.strength))
	immediate.surface_add_vertex(from_node.location)
	immediate.surface_add_vertex(to_node.location)
	immediate.surface_end()

	line_container.add_child(mesh_instance)

	# Create arrow at destination
	var arrow = _create_arrow_mesh(to_node.location, from_node.location, connection.strength)
	line_container.add_child(arrow)
	_arrow_meshes.append(arrow)

	_connection_lines.add_child(line_container)


## Create an arrow mesh pointing from start to end
func _create_arrow_mesh(end_pos: Vector3, start_pos: Vector3, strength: float) -> MeshInstance3D:
	var direction = (end_pos - start_pos).normalized()
	var arrow_size = 0.3 + strength * 0.3

	var mesh_instance = MeshInstance3D.new()

	# Create cone for arrow head
	var cone = ConeMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = arrow_size
	cone.height = arrow_size * 2.0
	cone.radial_segments = 8

	mesh_instance.mesh = cone

	# Position at end, pointing back along direction
	mesh_instance.position = end_pos - direction * arrow_size
	mesh_instance.look_at(end_pos + direction, Vector3.UP)

	# Arrow material
	var material = StandardMaterial3D.new()
	material.albedo_color = _get_connection_color(strength)
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.5

	mesh_instance.set_surface_override_material(0, material)

	return mesh_instance


## Create raycast system for detecting visible connections
func _create_raycast_system(nodes: Array) -> void:
	for node in nodes:
		var raycast = RayCast3D.new()
		raycast.name = "Ray_%s" % node.id
		raycast.position = node.location
		raycast.target_position = node.get_forward() * 100.0
		raycast.enabled = true
		raycast.debug_shape_custom_color = Color(1, 0, 0, 0.5)

		# Store reference for querying
		_raycast_nodes[node.id] = raycast
		add_child(raycast)


## Update animated connections (pulse effect)
func _update_animated_connections() -> void:
	if _connection_lines == null:
		return

	var pulse = sin(_time * 2.0) * 0.3 + 0.7

	for child in _connection_lines.get_children():
		if child is MeshInstance3D:
			var material = child.get_surface_override_material(0)
			if material != null:
				material.albedo_color.a = pulse * 0.6


## Get color for semantic type
func _get_color_for_type(semantic_type: String) -> Color:
	match semantic_type:
		"concept": return concept_color
		"entity": return entity_color
		"action": return action_color
		"place": return place_color
		"event": return event_color
		"wisdom": return wisdom_color
		_: return concept_color


## Get color for connection based on strength
func _get_connection_color(strength: float) -> Color:
	if strength > 0.7:
		return strong_connection_color
	return connection_color.lerp(strong_connection_color, strength)


## Handle node click
func _on_node_input_event(camera: Camera3D, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int, node_id: String, node: Variant) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			node_clicked.emit(node_id, node)
			_highlight_node(node_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Show context menu or info
			pass


## Highlight a specific node
func _highlight_node(node_id: String) -> void:
	# Reset previous highlight
	if _highlighted_node_id != "" and _node_meshes.has(_highlighted_node_id):
		var prev_mesh = _node_meshes[_highlighted_node_id]
		var material = prev_mesh.get_surface_override_material(0)
		if material != null:
			material.emission_energy = 0.3

	# Set new highlight
	_highlighted_node_id = node_id
	if _node_meshes.has(node_id):
		var mesh = _node_meshes[node_id]
		var material = mesh.get_surface_override_material(0)
		if material != null:
			material.emission_energy = 2.0


## Raycast from a node to find what it's pointing at
func raycast_from_node(node_id: String, max_distance: float = 100.0) -> Dictionary:
	if not _raycast_nodes.has(node_id):
		return {"hit": false}

	var raycast: RayCast3D = _raycast_nodes[node_id]
	raycast.target_position = Vector3.FORWARD * max_distance  # Will be transformed by node rotation
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()

		# Find which node was hit
		var hit_node_id = ""
		for id in _node_meshes:
			if _node_meshes[id] == collider or _node_meshes[id].is_ancestor_of(collider):
				hit_node_id = id
				break

		return {
			"hit": true,
			"point": point,
			"normal": normal,
			"node_id": hit_node_id,
			"memory_node": spatial_memory.retrieve_by_concept(hit_node_id) if hit_node_id != "" else null
		}

	return {"hit": false}


## Cone query - find all nodes within a vision cone
func cone_query(origin: Vector3, direction: Vector3, angle: float, distance: float) -> Array:
	var results: Array = []
	var cos_angle = cos(angle / 2.0)

	for node_id in _node_meshes:
		var mesh: MeshInstance3D = _node_meshes[node_id]
		var to_node = (mesh.position - origin).normalized()
		var dot = direction.dot(to_node)

		if dot > cos_angle:
			var dist = origin.distance_to(mesh.position)
			if dist <= distance:
				results.append({
					"node_id": node_id,
					"position": mesh.position,
					"distance": dist,
					"angle": acos(dot)
				})

	# Sort by distance
	results.sort_custom(func(a, b): return a.distance < b.distance)
	return results


## Find path and visualize it
func visualize_path(from_concept: String, to_concept: String) -> void:
	if spatial_memory == null:
		return

	var path = spatial_memory.find_path(from_concept, to_concept)
	if path == null:
		return

	# Highlight all nodes along path
	for node in path.discovered_nodes:
		_highlight_node(node.id)

	# Draw path line
	var path_line = MeshInstance3D.new()
	var immediate = ImmediateMesh.new()
	path_line.mesh = immediate

	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)

	var color = Color(0, 1, 0.5, 0.8)
	for node in path.discovered_nodes:
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(node.location)

	immediate.surface_end()

	_connection_lines.add_child(path_line)


## Get visualization statistics
func get_stats() -> Dictionary:
	return {
		"node_count": _node_meshes.size(),
		"connection_count": _connection_lines.get_child_count() if _connection_lines else 0,
		"label_count": _label_nodes.size(),
		"raycast_count": _raycast_nodes.size(),
		"highlighted_node": _highlighted_node_id
	}
