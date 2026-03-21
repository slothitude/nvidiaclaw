## Broadphase - Spatial partitioning for efficient collision detection
##
## Uses grid-based spatial hashing to reduce O(n²) to O(n) average case.
## Essential for handling 100+ bodies efficiently.
class_name Broadphase
extends RefCounted

## Grid cell size (should be larger than largest body diameter)
var cell_size: float = 100.0

## Spatial hash: cell_key -> Array of body indices
var _cells: Dictionary = {}

## Body bounds cache
var _body_bounds: Array = []

## Clear the spatial hash
func clear() -> void:
	_cells.clear()
	_body_bounds.clear()

## Insert a body into the spatial hash
func insert_body(body: Dictionary, index: int) -> void:
	var pos = Vector2(body.pos.x, body.pos.y)
	var radius: float = body.get("radius", 10.0)

	# Calculate AABB bounds
	var min_x = pos.x - radius
	var max_x = pos.x + radius
	var min_y = pos.y - radius
	var max_y = pos.y + radius

	# Store bounds
	while _body_bounds.size() <= index:
		_body_bounds.append({})
	_body_bounds[index] = {
		"min_x": min_x, "max_x": max_x,
		"min_y": min_y, "max_y": max_y
	}

	# Insert into all overlapping cells
	var cell_min_x = int(floor(min_x / cell_size))
	var cell_max_x = int(floor(max_x / cell_size))
	var cell_min_y = int(floor(min_y / cell_size))
	var cell_max_y = int(floor(max_y / cell_size))

	for cx in range(cell_min_x, cell_max_x + 1):
		for cy in range(cell_min_y, cell_max_y + 1):
			var key = _cell_key(cx, cy)
			if not _cells.has(key):
				_cells[key] = []
			_cells[key].append(index)

## Build spatial hash from all bodies in a world state
func build(state: Variant) -> void:
	clear()
	for i in range(state.bodies.size()):
		insert_body(state.bodies[i], i)

## Get potential collision pairs (broadphase)
func get_potential_pairs() -> Array:
	var pairs: Array = []
	var seen: Dictionary = {}

	for key in _cells.keys():
		var cell_bodies: Array = _cells[key]
		if cell_bodies.size() < 2:
			continue

		for i in range(cell_bodies.size()):
			for j in range(i + 1, cell_bodies.size()):
				var a = cell_bodies[i]
				var b = cell_bodies[j]
				var pair_key = _pair_key(a, b)

				if not seen.has(pair_key):
					seen[pair_key] = true
					pairs.append([a, b])

	return pairs

## Generate cell key from cell coordinates
func _cell_key(cx: int, cy: int) -> int:
	# Combine into single integer hash
	# Use Cantor pairing function
	var a = cx + 10000  # Offset to handle negative coords
	var b = cy + 10000
	return (a + b) * (a + b + 1) / 2 + b

## Generate unique pair key
func _pair_key(a: int, b: int) -> int:
	if a > b:
		var temp = a
		a = b
		b = temp
	return a * 100000 + b

## AABB overlap test (narrow phase)
static func aabb_overlaps(bounds_a: Dictionary, bounds_b: Dictionary) -> bool:
	return bounds_a.max_x > bounds_b.min_x and \
		   bounds_a.min_x < bounds_b.max_x and \
		   bounds_a.max_y > bounds_b.min_y and \
		   bounds_a.min_y < bounds_b.max_y

## Get bodies near a point
func query_point(point: Vector2) -> Array:
	var cx = int(floor(point.x / cell_size))
	var cy = int(floor(point.y / cell_size))
	var key = _cell_key(cx, cy)

	if _cells.has(key):
		return _cells[key].duplicate()
	return []

## Get bodies in a rectangular region
func query_region(min_pos: Vector2, max_pos: Vector2) -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	var cell_min_x = int(floor(min_pos.x / cell_size))
	var cell_max_x = int(floor(max_pos.x / cell_size))
	var cell_min_y = int(floor(min_pos.y / cell_size))
	var cell_max_y = int(floor(max_pos.y / cell_size))

	for cx in range(cell_min_x, cell_max_x + 1):
		for cy in range(cell_min_y, cell_max_y + 1):
			var key = _cell_key(cx, cy)
			if _cells.has(key):
				for idx in _cells[key]:
					if not seen.has(idx):
						seen[idx] = true
						result.append(idx)

	return result

## Statistics for debugging
func get_stats() -> Dictionary:
	var total_bodies = _body_bounds.size()
	var total_cells = _cells.size()
	var avg_per_cell = 0.0

	if total_cells > 0:
		var total_entries = 0
		for key in _cells.keys():
			total_entries += _cells[key].size()
		avg_per_cell = float(total_entries) / float(total_cells)

	return {
		"total_bodies": total_bodies,
		"total_cells": total_cells,
		"avg_bodies_per_cell": avg_per_cell
	}
