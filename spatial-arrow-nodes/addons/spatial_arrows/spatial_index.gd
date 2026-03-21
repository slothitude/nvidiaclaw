## spatial_index.gd - Octree for O(log n) spatial queries
## Part of AWR v0.2 - Spatial Memory Engine
##
## SpatialIndex provides efficient spatial queries using a sparse octree.
## This enables O(log n) queries instead of O(n) linear scans.

class_name SpatialIndex
extends RefCounted

## Cell size for the spatial hash (smaller = more precise, larger = fewer cells)
var cell_size: float = 10.0

## Sparse octree: cell coordinate -> array of nodes in that cell
var octree: Dictionary = {}

## Total number of indexed nodes
var node_count: int = 0

## Name index for fast concept lookups
var concept_index: Dictionary = {}  # concept_name (lowercase) -> node


func _init(p_cell_size: float = 10.0) -> void:
	cell_size = p_cell_size


## Convert a world location to cell coordinates
func _to_cell(location: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(location.x / cell_size)),
		int(floor(location.y / cell_size)),
		int(floor(location.z / cell_size))
	)


## Insert a node into the index
func insert(node) -> void:
	if node == null:
		return

	var cell = _to_cell(node.location)
	if not octree.has(cell):
		octree[cell] = []
	octree[cell].append(node)

	# Add to concept index
	var concept_key = node.concept.to_lower()
	if not concept_index.has(concept_key):
		concept_index[concept_key] = node

	node_count += 1


## Remove a node from the index
func remove(node) -> bool:
	if node == null:
		return false

	var cell = _to_cell(node.location)
	if octree.has(cell):
		var idx = octree[cell].find(node)
		if idx >= 0:
			octree[cell].remove_at(idx)
			if octree[cell].is_empty():
				octree.erase(cell)

			# Remove from concept index
			var concept_key = node.concept.to_lower()
			if concept_index.has(concept_key) and concept_index[concept_key] == node:
				concept_index.erase(concept_key)

			node_count -= 1
			return true
	return false


## Find a node by concept name (case-insensitive)
func find_by_concept(concept: String):
	return concept_index.get(concept.to_lower())


## Query all nodes within a sphere
func query_sphere(center: Vector3, radius: float) -> Array:
	var results = []

	# Calculate which cells might contain nodes within radius
	var min_cell = _to_cell(center - Vector3(radius, radius, radius))
	var max_cell = _to_cell(center + Vector3(radius, radius, radius))

	# Iterate through all potentially overlapping cells
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				var cell = Vector3i(x, y, z)
				if octree.has(cell):
					for node in octree[cell]:
						if node.location.distance_to(center) <= radius:
							results.append(node)

	return results


## Query all nodes within a box (AABB)
func query_box(min_corner: Vector3, max_corner: Vector3) -> Array:
	var results = []

	var min_cell = _to_cell(min_corner)
	var max_cell = _to_cell(max_corner)

	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				var cell = Vector3i(x, y, z)
				if octree.has(cell):
					for node in octree[cell]:
						var loc = node.location
						if loc.x >= min_corner.x and loc.x <= max_corner.x \
						   and loc.y >= min_corner.y and loc.y <= max_corner.y \
						   and loc.z >= min_corner.z and loc.z <= max_corner.z:
							results.append(node)

	return results


## Find the k nearest neighbors to a location
func query_nearest(center: Vector3, k: int) -> Array:
	if k <= 0 or node_count == 0:
		return []

	# Start with a small radius and expand
	var radius = cell_size
	var results = []

	while results.size() < k and radius < cell_size * 100:
		results = query_sphere(center, radius)
		radius *= 2

	# Sort by distance
	results.sort_custom(func(a, b):
		return a.location.distance_to(center) < b.location.distance_to(center))

	# Return top k
	if results.size() > k:
		results = results.slice(0, k)

	return results


## Find the nearest node to a location
func query_nearest_one(center: Vector3):
	var results = query_nearest(center, 1)
	return results[0] if results.size() > 0 else null


## Get all nodes in the index
func get_all() -> Array:
	var results = []
	for cell in octree.values():
		for node in cell:
			results.append(node)
	return results


## Get all occupied cells
func get_occupied_cells() -> Array:
	return octree.keys()


## Get statistics about the index
func get_stats() -> Dictionary:
	var cell_count = octree.size()
	var avg_per_cell = float(node_count) / float(cell_count) if cell_count > 0 else 0.0

	return {
		"node_count": node_count,
		"cell_count": cell_count,
		"avg_per_cell": avg_per_cell,
		"cell_size": cell_size
	}


## Clear the index
func clear() -> void:
	octree.clear()
	concept_index.clear()
	node_count = 0


## Rebuild the index with a new cell size
func rebuild(p_cell_size: float = -1.0) -> void:
	var nodes = get_all()
	clear()

	if p_cell_size > 0:
		cell_size = p_cell_size

	for node in nodes:
		insert(node)
