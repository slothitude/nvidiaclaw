## spatial_memory.gd - The Memory Palace Engine
## Part of AWR v0.2 - Spatial Memory Engine
##
## SpatialMemory is the core of the memory palace system.
## It stores concepts at 3D locations and enables spatial reasoning:
## - Distance = semantic relatedness
## - Path = reasoning chain
## - Neighborhood = category/context
##
## Based on:
## - Method of Loci (2000+ year old memory technique)
## - Cognitive Maps (Nobel Prize 2014 - O'Keefe, Moser & Moser)

class_name SpatialMemory
extends RefCounted

## The memory palace - a 3D space where concepts live
var space: Dictionary = {}  # Vector3 rounded -> node

## Spatial index for efficient queries
var index = null

## All nodes by ID for fast ID lookups
var nodes_by_id: Dictionary = {}  # id -> node

## Configuration
var cell_size: float = 10.0
var path_sample_interval: float = 5.0  # Sample every 5 units along path

## Statistics
var total_stores: int = 0
var total_retrievals: int = 0
var total_path_queries: int = 0

## Script references (loaded at runtime to avoid circular deps)
var _spatial_index_script = null
var _spatial_path_script = null


func _init(p_cell_size: float = 10.0) -> void:
	cell_size = p_cell_size
	_spatial_index_script = load("res://addons/awr/spatial/spatial_index.gd")
	_spatial_path_script = load("res://addons/awr/spatial/spatial_path.gd")
	index = _spatial_index_script.new(cell_size)


#region Core Operations

## Store a concept at a location
## Returns the created node
func store(concept: String, location: Vector3, metadata: Dictionary = {}):
	var node_script = load("res://addons/awr/spatial/memory_node.gd")
	var node = node_script.new(concept, location)
	node.metadata = metadata

	# Store in all indices
	var key = _location_key(location)
	space[key] = node
	nodes_by_id[node.id] = node
	index.insert(node)

	total_stores += 1
	return node


## Retrieve by exact location
func retrieve(location: Vector3):
	total_retrievals += 1
	var key = _location_key(location)
	return space.get(key)


## Retrieve by concept name (case-insensitive)
func retrieve_by_concept(concept: String):
	total_retrievals += 1
	return index.find_by_concept(concept)


## Remove a node by location
func remove(location: Vector3) -> bool:
	var key = _location_key(location)
	if space.has(key):
		var node = space[key]
		space.erase(key)
		nodes_by_id.erase(node.id)
		index.remove(node)
		return true
	return false


## Remove a node by concept name
func remove_by_concept(concept: String) -> bool:
	var node = retrieve_by_concept(concept)
	if node:
		return remove(node.location)
	return false


## Check if a location is occupied
func is_occupied(location: Vector3) -> bool:
	return space.has(_location_key(location))


## Get total number of stored nodes
func size() -> int:
	return nodes_by_id.size()


#endregion

#region Spatial Queries

## Retrieve nearest neighbors within radius
func neighbors(location: Vector3, radius: float) -> Array:
	var results = index.query_sphere(location, radius)

	# Sort by distance
	results.sort_custom(func(a, b):
		return a.location.distance_to(location) < b.location.distance_to(location))

	return results


## Find k nearest neighbors
func nearest_neighbors(location: Vector3, k: int) -> Array:
	return index.query_nearest(location, k)


## Find nearest node to location
func nearest(location: Vector3):
	return index.query_nearest_one(location)


## Get all nodes within a box
func query_box(min_corner: Vector3, max_corner: Vector3) -> Array:
	return index.query_box(min_corner, max_corner)


## Get all stored nodes
func get_all_nodes() -> Array:
	var nodes = []
	for node in nodes_by_id.values():
		nodes.append(node)
	return nodes


#endregion

#region Path Finding & Reasoning

## Find path between two concepts (THIS IS REASONING!)
## Uses A* pathfinding through concept space
func find_path(from_concept: String, to_concept: String):
	total_path_queries += 1

	var from_node = _find_concept(from_concept)
	var to_node = _find_concept(to_concept)

	if from_node == null or to_node == null:
		return null

	var path = _spatial_path_script.new(from_node, to_node)

	# For now, use direct path with waypoint discovery
	# In future: implement full A* through intermediate concepts
	path.waypoints = _discover_waypoints(from_node.location, to_node.location)
	path.distance = _calculate_path_distance(path.waypoints)

	# Discover nodes along the path
	_discover_nodes_along_path(path)

	return path


## Find concept by name (case-insensitive, partial match)
func _find_concept(concept: String):
	# Try exact match first
	var node = index.find_by_concept(concept)
	if node:
		return node

	# Try case-insensitive match
	var concept_lower = concept.to_lower()
	for n in nodes_by_id.values():
		if n.concept.to_lower() == concept_lower:
			return n

	# Try partial match
	for n in nodes_by_id.values():
		if concept_lower in n.concept.to_lower() or n.concept.to_lower() in concept_lower:
			return n

	return null


## Discover waypoints between two locations
## These are intermediate concepts that form a "bridge"
func _discover_waypoints(from: Vector3, to: Vector3) -> Array:
	var waypoints = [from]

	var direction = to - from
	var distance = direction.length()

	# Sample along the path to find interesting intermediate points
	var num_samples = int(distance / path_sample_interval)
	for i in range(1, num_samples + 1):
		var t = float(i) / float(num_samples + 1)
		var sample_point = from.lerp(to, t)

		# Check if there's a node near this point that could be a waypoint
		var nearby = index.query_sphere(sample_point, path_sample_interval / 2)
		if nearby.size() > 0:
			# Add the nearest one as a waypoint
			var nearest_node = nearby[0]
			for n in nearby:
				if n.location.distance_to(sample_point) < nearest_node.location.distance_to(sample_point):
					nearest_node = n
			waypoints.append(nearest_node.location)

	waypoints.append(to)
	return waypoints


## Calculate total distance along waypoints
func _calculate_path_distance(waypoints: Array) -> float:
	var total := 0.0
	for i in range(waypoints.size() - 1):
		total += waypoints[i].distance_to(waypoints[i + 1])
	return total


## Discover nodes along a path
func _discover_nodes_along_path(path) -> void:
	path.discovered_nodes.clear()

	for waypoint in path.waypoints:
		var nearby = neighbors(waypoint, path_sample_interval)
		for node in nearby:
			path.add_discovered(node)


## What concepts are along this path? (THESE ARE THE ANSWER!)
func concepts_along_path(path) -> Array:
	var concepts = []
	for node in path.discovered_nodes:
		if node.concept not in concepts:
			concepts.append(node.concept)
	return concepts


## Semantic distance (physical distance = semantic distance)
func semantic_distance(concept_a: String, concept_b: String) -> float:
	var node_a = _find_concept(concept_a)
	var node_b = _find_concept(concept_b)
	if node_a == null or node_b == null:
		return INF
	return node_a.location.distance_to(node_b.location)


#endregion

#region Spatial Reasoning

## Answer: "What is between X and Y?"
## Returns concepts that lie spatially between two concepts
func concepts_between(concept_a: String, concept_b: String, tolerance: float = 5.0) -> Array:
	var node_a = _find_concept(concept_a)
	var node_b = _find_concept(concept_b)
	if node_a == null or node_b == null:
		return []

	var results = []
	var midpoint = (node_a.location + node_b.location) / 2
	var line_dir = (node_b.location - node_a.location).normalized()

	# Find nodes that are:
	# 1. Close to the line between a and b
	# 2. Between a and b (not beyond them)

	for node in nodes_by_id.values():
		if node == node_a or node == node_b:
			continue

		# Project node onto line
		var to_node = node.location - node_a.location
		var projection = to_node.project(line_dir) + node_a.location

		# Check if projection is between a and b
		var t = (projection - node_a.location).dot(line_dir) / node_a.location.distance_to(node_b.location)
		if t < 0 or t > 1:
			continue

		# Check distance from line
		if node.location.distance_to(projection) <= tolerance:
			results.append(node)

	return results


## Answer: "What is near X?"
## Returns concepts in the neighborhood of a concept
func neighborhood(concept: String, radius: float = 15.0) -> Array:
	var node = _find_concept(concept)
	if node == null:
		return []

	var nearby = neighbors(node.location, radius)
	# Remove the node itself
	var results = []
	for n in nearby:
		if n != node:
			results.append(n)
	return results


## Answer: "What region/cluster is X in?"
## Returns all concepts within a region
func region(center: Vector3, size: Vector3) -> Array:
	return query_box(
		center - size / 2,
		center + size / 2
	)


## Find the "center of mass" of related concepts
func centroid(concepts: Array) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0

	for concept in concepts:
		var node = _find_concept(concept)
		if node:
			sum += node.location
			count += 1

	if count == 0:
		return Vector3.ZERO
	return sum / count


#endregion

#region Serialization

## Serialize entire memory palace to dictionary
func to_dict() -> Dictionary:
	var nodes_data = []
	for node in nodes_by_id.values():
		nodes_data.append(node.to_dict())

	return {
		"cell_size": cell_size,
		"path_sample_interval": path_sample_interval,
		"nodes": nodes_data,
		"stats": {
			"total_stores": total_stores,
			"total_retrievals": total_retrievals,
			"total_path_queries": total_path_queries
		}
	}


## Load from dictionary
static func from_dict(data: Dictionary):
	var cls = load("res://addons/awr/spatial/spatial_memory.gd")
	var memory = cls.new(data.get("cell_size", 10.0))
	memory.path_sample_interval = data.get("path_sample_interval", 5.0)

	var node_script = load("res://addons/awr/spatial/memory_node.gd")
	for node_data in data.get("nodes", []):
		var node = node_script.from_dict(node_data)
		var key = memory._location_key(node.location)
		memory.space[key] = node
		memory.nodes_by_id[node.id] = node
		memory.index.insert(node)

	var stats = data.get("stats", {})
	memory.total_stores = stats.get("total_stores", 0)
	memory.total_retrievals = stats.get("total_retrievals", 0)
	memory.total_path_queries = stats.get("total_path_queries", 0)

	return memory


## Save to file
func save(path: String) -> int:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var json_string = JSON.stringify(to_dict(), "  ")
	file.store_string(json_string)
	file.close()
	return OK


## Load from file
static func load_from(path: String):
	if not FileAccess.file_exists(path):
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return null

	return from_dict(json.data)


#endregion

#region Utility

func _location_key(location: Vector3) -> Vector3i:
	# Round to cell coordinates for exact lookups
	return Vector3i(
		int(round(location.x)),
		int(round(location.y)),
		int(round(location.z))
	)


## Clear all memories
func clear() -> void:
	space.clear()
	nodes_by_id.clear()
	index.clear()
	total_stores = 0
	total_retrievals = 0
	total_path_queries = 0


## Get statistics
func get_stats() -> Dictionary:
	return {
		"node_count": size(),
		"index_stats": index.get_stats(),
		"total_stores": total_stores,
		"total_retrievals": total_retrievals,
		"total_path_queries": total_path_queries
	}


func _to_string() -> String:
	return "SpatialMemory(nodes=%d, cells=%d)" % [size(), index.get_stats().cell_count]


#endregion
