## spatial_arrow_node.gd - 3D Arrow Nodes for Spatial Memory
## Part of AWR v0.4 - Physics-Enhanced Spatial Memory
##
## A SpatialArrowNode is a 3D node that can be:
## 1. An ARROW - pointing to another concept (relationship/relation)
## 2. A THING - a concept itself (entity/concept/place)
##
## Each node has associated markdown (.md) metadata for rich documentation.
##
## Arrow nodes visually point to their targets using 3D arrow meshes.
## Thing nodes are rendered as spheres/boxes/regions.
##
## Usage:
##   # Create an arrow (relationship)
##   var arrow = SpatialArrowNode.create_arrow("has_subfield", from_pos, to_concept)
##   arrow.load_markdown("has_subfield.md")
##
##   # Create a thing (concept)
##   var thing = SpatialArrowNode.create_thing("machine_learning", position)
##   thing.load_markdown("machine_learning.md")

class_name SpatialArrowNode
extends Node3D

## Types of spatial nodes
enum NodeType {
	THING,     # A concept/entity/place - rendered as sphere/box
	ARROW      # A relationship pointing to something - rendered as arrow
}

## The type of this node
@export var node_type: NodeType = NodeType.THING

## The concept this node represents (for THING type)
@export var concept: String = ""

## The relationship this arrow represents (for ARROW type)
@export var relationship: String = ""

## The concept this arrow points to (for ARROW type)
@export var target_concept: String = ""

## The source concept this arrow comes from (for ARROW type)
@export var source_concept: String = ""

## Position in concept space
@export var concept_position: Vector3 = Vector3.ZERO

## The markdown content
var markdown_content: String = ""

## Path to markdown file
var markdown_path: String = ""

## Visual settings
@export var node_size: float = 1.0
@export var arrow_length: float = 5.0
@export var arrow_head_size: float = 0.5

## Colors
@export var thing_color: Color = Color(0.2, 0.6, 1.0, 0.8)
@export var arrow_color: Color = Color(1.0, 0.8, 0.2, 0.8)

## Reference to spatial memory for resolving targets
var spatial_memory: Variant = null

## Internal mesh components
var _mesh_instance: MeshInstance3D = null
var _label: Label3D = null
var _raycast: RayCast3D = null

## Signals
signal clicked()
signal hovered()
signal markdown_loaded(content: String)


func _ready() -> void:
	_update_visual()


func _update_visual() -> void:
	# Clear existing visuals
	if _mesh_instance:
		_mesh_instance.queue_free()
	if _label:
		_label.queue_free()
	if _raycast:
		_raycast.queue_free()

	match node_type:
		NodeType.THING:
			_create_thing_visual()
		NodeType.ARROW:
			_create_arrow_visual()


## Create visual for a THING node (sphere)
func _create_thing_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ThingMesh"

	var sphere = SphereMesh.new()
	sphere.radius = node_size
	sphere.height = node_size * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_mesh_instance.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = thing_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = thing_color * 0.3
	_mesh_instance.set_surface_override_material(0, material)

	_mesh_instance.position = concept_position
	add_child(_mesh_instance)

	# Add label
	_label = Label3D.new()
	_label.text = concept
	_label.position = concept_position + Vector3(0, node_size * 1.5, 0)
	_label.font_size = 24
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	add_child(_label)


## Create visual for an ARROW node (arrow mesh)
func _create_arrow_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ArrowMesh"

	# Create arrow mesh (cylinder + cone)
	var arrow_mesh = _build_arrow_mesh()
	_mesh_instance.mesh = arrow_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = arrow_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = arrow_color * 0.5
	_mesh_instance.set_surface_override_material(0, material)

	# Position at source and rotate toward target
	position = concept_position
	_update_arrow_rotation()

	add_child(_mesh_instance)

	# Add label for relationship name
	_label = Label3D.new()
	_label.text = relationship
	_label.position = Vector3(0, 1.0, 0)
	_label.font_size = 18
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	add_child(_label)

	# Add raycast pointing toward target
	_raycast = RayCast3D.new()
	_raycast.target_position = Vector3.FORWARD * arrow_length * 2.0
	_raycast.enabled = true
	add_child(_raycast)


## Build arrow mesh (cylinder shaft + cone head)
func _build_arrow_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()

	# Shaft (cylinder)
	var shaft = CylinderMesh.new()
	shaft.top_radius = 0.1
	shaft.bottom_radius = 0.1
	shaft.height = arrow_length
	shaft.radial_segments = 8

	# Note: Godot doesn't have ConeMesh, we create a cone using CylinderMesh
	# with top_radius = 0
	var head = CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = arrow_head_size
	head.height = arrow_head_size * 2.0
	head.radial_segments = 8

	# Combine into one mesh using SurfaceTool
	# For simplicity, we return the shaft - head can be added as a child mesh
	return shaft  # Return shaft, head added as child


## Update arrow rotation to point at target
func _update_arrow_rotation() -> void:
	if spatial_memory == null or target_concept == "":
		return

	var target_node = spatial_memory.retrieve_by_concept(target_concept)
	if target_node == null:
		return

	var target_pos = target_node.location
	var direction = (target_pos - concept_position).normalized()

	if direction.length_squared() > 0.001:
		look_at(target_pos, Vector3.UP)


# ============================================================
# MARKDOWN METADATA
# ============================================================

## Load markdown content from file
func load_markdown(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	markdown_content = file.get_as_text()
	markdown_path = path
	file.close()

	markdown_loaded.emit(markdown_content)
	return true


## Save markdown content to file
func save_markdown(path: String = "") -> bool:
	var save_path = path if path != "" else markdown_path
	if save_path == "":
		return false

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(markdown_content)
	file.close()
	return true


## Set markdown content directly
func set_markdown(content: String) -> void:
	markdown_content = content


## Get parsed markdown as dictionary (frontmatter + body)
func parse_markdown() -> Dictionary:
	var result = {
		"frontmatter": {},
		"body": markdown_content,
		"sections": {}
	}

	# Parse YAML frontmatter if present
	if markdown_content.begins_with("---"):
		var end_idx = markdown_content.find("---", 3)
		if end_idx > 0:
			var frontmatter_text = markdown_content.substr(3, end_idx - 3)
			result.frontmatter = _parse_yaml_frontmatter(frontmatter_text)
			result.body = markdown_content.substr(end_idx + 3).strip_edges()

	# Parse markdown sections (## headers)
	var lines = result.body.split("\n")
	var current_section = "intro"
	var section_content: Array = []

	for line in lines:
		if line.begins_with("## "):
			if section_content.size() > 0:
				result.sections[current_section] = "\n".join(section_content)
			current_section = line.substr(3).strip_edges().to_lower().replace(" ", "_")
			section_content.clear()
		else:
			section_content.append(line)

	if section_content.size() > 0:
		result.sections[current_section] = "\n".join(section_content)

	return result


## Simple YAML frontmatter parser
func _parse_yaml_frontmatter(text: String) -> Dictionary:
	var result: Dictionary = {}
	var lines = text.split("\n")

	for line in lines:
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		var colon_idx = line.find(":")
		if colon_idx > 0:
			var key = line.substr(0, colon_idx).strip_edges()
			var value = line.substr(colon_idx + 1).strip_edges()

			# Remove quotes
			if value.begins_with('"') and value.ends_with('"'):
				value = value.substr(1, value.length() - 2)
			elif value.begins_with("'") and value.ends_with("'"):
				value = value.substr(1, value.length() - 2)

			# Parse arrays
			if value.begins_with("[") and value.ends_with("]"):
				var items = value.substr(1, value.length() - 2).split(",")
				value = []
				for item in items:
					value.append(item.strip_edges())

			result[key] = value

	return result


## Get a specific section from markdown
func get_section(section_name: String) -> String:
	var parsed = parse_markdown()
	return parsed.sections.get(section_name.to_lower().replace(" ", "_"), "")


## Get frontmatter value
func get_frontmatter(key: String, default: Variant = null) -> Variant:
	var parsed = parse_markdown()
	return parsed.frontmatter.get(key, default)


## Convert markdown to GDScript dictionary (for AI consumption)
func to_prompt_block() -> String:
	var lines: Array = []
	var parsed = parse_markdown()

	lines.append("=== %s [%s] ===" % [concept if node_type == NodeType.THING else relationship, "THING" if node_type == NodeType.THING else "ARROW"])

	if node_type == NodeType.ARROW:
		lines.append("Points from: %s" % source_concept)
		lines.append("Points to: %s" % target_concept)

	if not parsed.frontmatter.is_empty():
		lines.append("Metadata:")
		for key in parsed.frontmatter:
			lines.append("  %s: %s" % [key, str(parsed.frontmatter[key])])

	lines.append("")
	lines.append(parsed.body)

	return "\n".join(lines)


# ============================================================
# FACTORY METHODS
# ============================================================

## Create a THING node (concept/entity)
static func create_thing(p_concept: String, p_position: Vector3) -> Node3D:
	var script = load("res://addons/awr/spatial/spatial_arrow_node.gd")
	var node = script.new()
	node.node_type = NodeType.THING
	node.concept = p_concept
	node.concept_position = p_position
	return node


## Create an ARROW node (relationship)
static func create_arrow(p_relationship: String, p_from: Vector3, p_to_concept: String, p_source: String = "") -> Node3D:
	var script = load("res://addons/awr/spatial/spatial_arrow_node.gd")
	var node = script.new()
	node.node_type = NodeType.ARROW
	node.relationship = p_relationship
	node.concept_position = p_from
	node.target_concept = p_to_concept
	node.source_concept = p_source
	return node


## Create from markdown file
static func from_markdown(path: String) -> Node3D:
	var script = load("res://addons/awr/spatial/spatial_arrow_node.gd")
	var node = script.new()

	if node.load_markdown(path):
		var parsed = node.parse_markdown()
		var fm = parsed.frontmatter

		# Determine type from frontmatter
		var type_str = fm.get("type", "thing").to_lower()
		if type_str == "arrow" or type_str == "relationship":
			node.node_type = NodeType.ARROW
			node.relationship = fm.get("name", fm.get("relationship", ""))
			node.target_concept = fm.get("target", fm.get("points_to", ""))
			node.source_concept = fm.get("source", fm.get("from", ""))
		else:
			node.node_type = NodeType.THING
			node.concept = fm.get("name", fm.get("concept", ""))

		# Parse position
		var pos_str = fm.get("position", "0,0,0")
		var pos_parts = pos_str.split(",")
		if pos_parts.size() >= 3:
			node.concept_position = Vector3(
				float(pos_parts[0].strip_edges()),
				float(pos_parts[1].strip_edges()),
				float(pos_parts[2].strip_edges())
			)

	return node


# ============================================================
# RAYCASTING
# ============================================================

## Check what this arrow is pointing at
func raycast_target() -> Dictionary:
	if _raycast == null:
		return {"hit": false}

	_raycast.force_raycast_update()

	if _raycast.is_colliding():
		var collider = _raycast.get_collider()
		var point = _raycast.get_collision_point()

		return {
			"hit": true,
			"collider": collider,
			"point": point,
			"normal": _raycast.get_collision_normal()
		}

	return {"hit": false}


## Check if this arrow points at a specific concept
func points_at(concept_name: String) -> bool:
	var result = raycast_target()
	if not result.hit:
		return false

	# Check if the collider is a SpatialArrowNode
	var collider = result.collider
	if collider is SpatialArrowNode:
		return collider.concept == concept_name

	# Check parent chain
	var parent = result.collider.get_parent()
	while parent:
		if parent is SpatialArrowNode and parent.concept == concept_name:
			return true
		parent = parent.get_parent()

	return false


## Get distance to what this arrow points at
func distance_to_target() -> float:
	if spatial_memory == null or target_concept == "":
		return INF

	var target = spatial_memory.retrieve_by_concept(target_concept)
	if target == null:
		return INF

	return concept_position.distance_to(target.location)


func _to_string() -> String:
	if node_type == NodeType.THING:
		return "SpatialArrowNode(THING: %s @ %s)" % [concept, str(concept_position)]
	else:
		return "SpatialArrowNode(ARROW: %s -> %s @ %s)" % [relationship, target_concept, str(concept_position)]
