## spatial_path.gd - Path between nodes in concept space
## Part of AWR v0.2 - Spatial Memory Engine
##
## A SpatialPath represents a route through 3D concept space.
## The path itself IS the reasoning - concepts along the path
## reveal relationships between the start and end concepts.

class_name SpatialPath
extends RefCounted

## The starting node
var start = null

## The ending node
var end = null

## Waypoint locations along the path (including start and end)
var waypoints: Array = []

## Nodes discovered along the path (populated during traversal)
var discovered_nodes: Array = []

## Total path distance
var distance: float = 0.0

## Whether the path is valid (connects start to end)
var is_valid: bool = false

## Path metadata (algorithm used, computation time, etc.)
var metadata: Dictionary = {}


func _init(p_start = null, p_end = null) -> void:
	start = p_start
	end = p_end
	if start != null and end != null:
		is_valid = true
		waypoints.append(start.location)
		waypoints.append(end.location)
		distance = start.location.distance_to(end.location)


## Add a waypoint to the path
func add_waypoint(location: Vector3) -> void:
	waypoints.append(location)
	_recalculate_distance()


## Insert a waypoint at a specific index
func insert_waypoint(index: int, location: Vector3) -> void:
	if index >= 0 and index <= waypoints.size():
		waypoints.insert(index, location)
		_recalculate_distance()


## Clear all waypoints except start and end
func clear_waypoints() -> void:
	waypoints.clear()
	if start != null:
		waypoints.append(start.location)
	if end != null:
		waypoints.append(end.location)
	_recalculate_distance()


## Recalculate total path distance
func _recalculate_distance() -> void:
	distance = 0.0
	for i in range(waypoints.size() - 1):
		distance += waypoints[i].distance_to(waypoints[i + 1])


## Get the number of segments in the path
func segment_count() -> int:
	return max(0, waypoints.size() - 1)


## Interpolate along the path at parameter t (0.0 to 1.0)
func interpolate(t: float) -> Vector3:
	if waypoints.size() < 2:
		return Vector3.ZERO

	t = clampf(t, 0.0, 1.0)

	# Find which segment we're in
	var total_dist = distance
	if total_dist <= 0:
		return waypoints[0]

	var target_dist = t * total_dist
	var accumulated = 0.0

	for i in range(waypoints.size() - 1):
		var segment_dist = waypoints[i].distance_to(waypoints[i + 1])
		if accumulated + segment_dist >= target_dist:
			# We're in this segment
			var segment_t = (target_dist - accumulated) / segment_dist if segment_dist > 0 else 0.0
			return waypoints[i].lerp(waypoints[i + 1], segment_t)
		accumulated += segment_dist

	return waypoints[waypoints.size() - 1]


## Sample points along the path at regular intervals
func sample_points(count: int) -> Array:
	var points = []
	if count <= 0:
		return points

	for i in range(count):
		var t = float(i) / float(count - 1) if count > 1 else 0.0
		points.append(interpolate(t))

	return points


## Get the direction at a point along the path
func direction_at(t: float) -> Vector3:
	if waypoints.size() < 2:
		return Vector3.ZERO

	# Sample two nearby points
	var epsilon = 0.01
	var p1 = interpolate(maxf(0, t - epsilon))
	var p2 = interpolate(minf(1, t + epsilon))

	var dir = (p2 - p1).normalized()
	return dir


## Add a discovered node along the path
func add_discovered(node) -> void:
	if node != null and node not in discovered_nodes:
		discovered_nodes.append(node)


## Get concepts discovered along this path
func get_discovered_concepts() -> Array:
	var concepts = []
	for node in discovered_nodes:
		if node.concept not in concepts:
			concepts.append(node.concept)
	return concepts


## Serialize to dictionary
func to_dict() -> Dictionary:
	var waypoint_data = []
	for wp in waypoints:
		waypoint_data.append({"x": wp.x, "y": wp.y, "z": wp.z})

	var discovered_data = []
	for node in discovered_nodes:
		discovered_data.append(node.to_dict())

	return {
		"start_id": start.id if start else "",
		"end_id": end.id if end else "",
		"waypoints": waypoint_data,
		"discovered_nodes": discovered_data,
		"distance": distance,
		"is_valid": is_valid,
		"metadata": metadata
	}


func _to_string() -> String:
	return "SpatialPath(%s -> %s, dist=%.2f, waypoints=%d)" % [
		start.concept if start else "null",
		end.concept if end else "null",
		distance,
		waypoints.size()
	]
