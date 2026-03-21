## palace_builder.gd - Auto-organize concepts into spatial structure
## Part of AWR v0.2 - Spatial Memory Engine
##
## PalaceBuilder automatically constructs a memory palace from concepts.
## It clusters related concepts and assigns them to "rooms" in 3D space.
##
## Layout Strategy:
## - Each cluster becomes a "room" at a distinct location
## - Related concepts are placed near each other within rooms
## - Rooms are arranged along a path for mental navigation

class_name PalaceBuilder
extends RefCounted

## The memory palace being built
var memory = null

## Original concepts array (for lookup during arrangement)
var _concepts: Array = []

## Configuration
var room_spacing: float = 50.0  # Distance between rooms
var concept_spacing: float = 5.0  # Distance between concepts in a room
var room_radius: float = 10.0  # Radius of concept placement in room

## Clustering settings
var similarity_threshold: float = 0.3  # Threshold for clustering

## Progress callback (optional)
var on_progress: Callable = Callable()

## Script references (loaded at runtime to avoid circular deps)
var _spatial_memory_script = null


func _init(p_memory = null) -> void:
	if p_memory:
		memory = p_memory
	else:
		_spatial_memory_script = load("res://addons/awr/spatial/spatial_memory.gd")
		memory = _spatial_memory_script.new()


## Build a memory palace from a list of concepts
## Each concept dict should have: name, metadata (optional), tags (optional)
func build(concepts: Array) -> Variant:
	if concepts.is_empty():
		return memory

	_concepts = concepts  # Store for lookup during arrangement

	# Step 1: Cluster concepts by similarity
	var clusters = _cluster_concepts(concepts)
	_report_progress(0.3, "Clustered into %d rooms" % clusters.size())

	# Step 2: Arrange clusters into rooms
	_arrange_rooms(clusters)
	_report_progress(0.8, "Arranged %d concepts" % concepts.size())

	# Step 3: Create explicit connections between related concepts
	_create_connections()
	_report_progress(1.0, "Memory palace complete")

	return memory


## Cluster concepts using simple tag-based clustering
func _cluster_concepts(concepts: Array) -> Array:
	var clusters = []
	var assigned = []
	assigned.resize(concepts.size())
	assigned.fill(false)

	for i in range(concepts.size()):
		if assigned[i]:
			continue

		var cluster = [i]
		assigned[i] = true

		var concept_a = concepts[i]
		var tags_a = concept_a.get("tags", [])

		# Find similar concepts
		for j in range(i + 1, concepts.size()):
			if assigned[j]:
				continue

			var concept_b = concepts[j]
			var tags_b = concept_b.get("tags", [])

			# Calculate similarity based on shared tags
			var similarity = _calculate_tag_similarity(tags_a, tags_b)

			if similarity >= similarity_threshold:
				cluster.append(j)
				assigned[j] = true

		clusters.append(cluster)

	return clusters


## Calculate Jaccard similarity between tag sets
func _calculate_tag_similarity(tags_a: Array, tags_b: Array) -> float:
	if tags_a.is_empty() or tags_b.is_empty():
		return 0.0

	var set_a = {}
	var set_b = {}

	for tag in tags_a:
		set_a[tag.to_lower()] = true
	for tag in tags_b:
		set_b[tag.to_lower()] = true

	var intersection := 0
	for tag in set_a:
		if set_b.has(tag):
			intersection += 1

	var union_size := set_a.size() + set_b.size() - intersection
	return float(intersection) / float(union_size) if union_size > 0 else 0.0


## Arrange clusters into spatial rooms
func _arrange_rooms(clusters: Array) -> void:
	var room_offset = Vector3.ZERO

	for cluster_idx in range(clusters.size()):
		var cluster = clusters[cluster_idx]  # Array of indices into _concepts
		var room_center = room_offset

		# Place concepts in room using radial layout
		var angle_step = TAU / cluster.size() if cluster.size() > 0 else 0

		for concept_idx in range(cluster.size()):
			var concept_index = cluster[concept_idx]  # This is an index, not the data
			var concept_data = _concepts[concept_index]  # Look up the actual concept data

			# Calculate position
			var angle = concept_idx * angle_step
			var radius = minf(room_radius, concept_spacing * cluster.size() / TAU)

			var location: Vector3
			if cluster.size() == 1:
				location = room_center
			else:
				location = room_center + Vector3(
					cos(angle) * radius,
					0,
					sin(angle) * radius
				)

			# Store in memory
			var concept_name = concept_data.get("name", "unnamed")
			var metadata = concept_data.get("metadata", {})
			metadata["room_index"] = cluster_idx
			metadata["room_center"] = {"x": room_center.x, "y": room_center.y, "z": room_center.z}

			memory.store(concept_name, location, metadata)

		# Move to next room position
		room_offset += Vector3(room_spacing, 0, 0)


## Create explicit connections between highly related concepts
func _create_connections() -> void:
	var nodes = memory.get_all_nodes()

	for i in range(nodes.size()):
		var node_a = nodes[i]

		# Connect to nearest neighbors
		var nearby = memory.neighbors(node_a.location, concept_spacing * 2)
		for node_b in nearby:
			if node_a != node_b:
				node_a.connect_to(node_b.concept)


## Report progress (if callback is set)
func _report_progress(progress: float, message: String) -> void:
	if on_progress.is_valid():
		on_progress.call(progress, message)


## Build from Wikipedia-style structured data
## Expects: [{"title": "...", "summary": "...", "categories": [...]}, ...]
func build_from_articles(articles: Array) -> Variant:
	var concepts = []

	for article in articles:
		concepts.append({
			"name": article.get("title", ""),
			"metadata": {
				"summary": article.get("summary", ""),
				"source": "wikipedia"
			},
			"tags": article.get("categories", [])
		})

	return build(concepts)


## Build from a knowledge graph structure
## Expects: [{"id": "...", "label": "...", "type": "...", "related": [...]}, ...]
func build_from_graph(nodes: Array) -> Variant:
	var concepts = []

	for node in nodes:
		# Extract tags from type and related nodes
		var tags = []
		if node.has("type"):
			tags.append(node.type)
		for related in node.get("related", []):
			tags.append(related)

		concepts.append({
			"name": node.get("label", node.get("id", "")),
			"metadata": {
				"id": node.get("id", ""),
				"type": node.get("type", ""),
				"related": node.get("related", [])
			},
			"tags": tags
		})

	return build(concepts)


## Build hierarchical memory palace (rooms within rooms)
## Good for nested categories (e.g., Science -> Physics -> Quantum)
func build_hierarchical(hierarchy: Dictionary, base_position: Vector3 = Vector3.ZERO, depth: int = 0) -> Variant:
	var room_scale = pow(0.5, depth)  # Rooms get smaller at deeper levels
	var current_pos = base_position

	for category in hierarchy:
		var category_data = hierarchy[category]

		if category_data is Dictionary:
			# This category has sub-categories
			memory.store(category, current_pos, {"depth": depth, "is_parent": true})

			# Recursively build sub-categories
			var sub_offset = current_pos + Vector3(0, room_spacing * room_scale, 0)
			build_hierarchical(category_data, sub_offset, depth + 1)

		elif category_data is Array:
			# This category has leaf items
			memory.store(category, current_pos, {"depth": depth, "is_parent": false})

			var angle_step = TAU / category_data.size() if category_data.size() > 0 else 0
			for i in range(category_data.size()):
				var item = category_data[i]
				var angle = i * angle_step
				var item_pos = current_pos + Vector3(
					cos(angle) * room_radius * room_scale,
					0,
					sin(angle) * room_radius * room_scale
				)

				if item is String:
					memory.store(item, item_pos, {"depth": depth + 1, "parent": category})
				else:
					memory.store(item.get("name", "unnamed"), item_pos, item.get("metadata", {}))

		else:
			# Simple value
			memory.store(category, current_pos, {"depth": depth})

		current_pos += Vector3(room_spacing * room_scale, 0, 0)

	return memory


## Create a linear memory palace (good for sequences/stories)
## Concepts are arranged along a path for sequential recall
func build_linear(concepts: Array, start: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3(1, 0, 0)) -> Variant:
	var normalized_dir = direction.normalized()
	var current_pos = start

	for concept in concepts:
		memory.store(concept, current_pos)
		current_pos += normalized_dir * concept_spacing

	return memory


## Create a spiral memory palace (good for exploration)
## Concepts spiral outward from center
func build_spiral(concepts: Array, center: Vector3 = Vector3.ZERO, spacing: float = 5.0) -> Variant:
	var angle := 0.0
	var radius := spacing

	for i in range(concepts.size()):
		var pos = center + Vector3(
			cos(angle) * radius,
			0,
			sin(angle) * radius
		)
		memory.store(concepts[i], pos)

		# Advance angle and slowly increase radius
		angle += spacing / radius
		radius += spacing / (TAU)  # Expand radius slightly each step

	return memory
