## shared_location_memory.gd - Shared Location Discovery System
## Part of Fantasy Town World-Breaking Demo
##
## When any agent discovers a location, all agents learn about it.
## Agents can use goto("location_name") to navigate there.
##
## This creates emergent shared knowledge without explicit communication.

class_name SharedLocationMemory
extends Node

## Signals
signal location_discovered(location_name: String, position: Vector3, purpose: String)
signal location_visited(agent_id: String, location_name: String)

## All discovered locations
## Format: {name: {position: Vector3, purpose: String, discovered_by: String, timestamp: float}}
var _locations: Dictionary = {}

## Agent current locations (for tracking)
var _agent_locations: Dictionary = {}  # agent_id -> location_name

## Save path for persistence
const SAVE_PATH := "user://shared_locations.json"


func _ready() -> void:
	print("[SharedMemory] Location sharing system initialized")
	_load_from_disk()


## Agent discovers a location - broadcasts to all agents
func discover_location(discoverer_id: String, location_name: String, position: Vector3, purpose: String) -> void:
	var key = location_name.to_lower().replace(" ", "_")

	if _locations.has(key):
		# Already known, but update visit count
		_locations[key]["visit_count"] = _locations[key].get("visit_count", 0) + 1
		_save_to_disk()
		return

	_locations[key] = {
		"name": location_name,
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"purpose": purpose,
		"discovered_by": discoverer_id,
		"timestamp": Time.get_unix_time_from_system(),
		"visit_count": 1
	}

	print("[SharedMemory] Agent %s discovered: %s (%s)" % [discoverer_id, location_name, purpose])
	location_discovered.emit(location_name, position, purpose)
	_save_to_disk()


## Get location by name
func get_location(name: String) -> Dictionary:
	var key = name.to_lower().replace(" ", "_")
	if not _locations.has(key):
		return {}

	var loc = _locations[key]
	return {
		"name": loc.name,
		"position": Vector3(loc.position.x, loc.position.y, loc.position.z),
		"purpose": loc.purpose
	}


## Get all locations
func get_all_locations() -> Dictionary:
	return _locations.duplicate()


## Get locations by purpose
func get_locations_by_purpose(purpose: String) -> Array:
	var result = []
	for key in _locations.keys():
		var loc = _locations[key]
		if loc.purpose == purpose:
			result.append({
				"name": loc.name,
				"position": Vector3(loc.position.x, loc.position.y, loc.position.z),
				"purpose": loc.purpose
			})
	return result


## Find nearest location of a specific purpose
func find_nearest_of_type(from_pos: Vector3, purpose: String) -> Dictionary:
	var nearest = {}
	var nearest_dist = INF

	for key in _locations.keys():
		var loc = _locations[key]
		if loc.purpose == purpose:
			var loc_pos = Vector3(loc.position.x, loc.position.y, loc.position.z)
			var dist = from_pos.distance_to(loc_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = {
					"name": loc.name,
					"position": loc_pos,
					"distance": dist
				}

	return nearest


## Find nearest location by name (partial match)
func find_nearest_by_name(from_pos: Vector3, name_pattern: String) -> Dictionary:
	var nearest = {}
	var nearest_dist = INF
	var pattern = name_pattern.to_lower()

	for key in _locations.keys():
		if pattern in key or pattern in _locations[key].name.to_lower():
			var loc = _locations[key]
			var loc_pos = Vector3(loc.position.x, loc.position.y, loc.position.z)
			var dist = from_pos.distance_to(loc_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = {
					"name": loc.name,
					"position": loc_pos,
					"distance": dist
				}

	return nearest


## Record agent visiting a location
func agent_visits(agent_id: String, location_name: String) -> void:
	_agent_locations[agent_id] = location_name

	var key = location_name.to_lower().replace(" ", "_")
	if _locations.has(key):
		_locations[key]["visit_count"] = _locations[key].get("visit_count", 0) + 1
		_locations[key]["last_visited_by"] = agent_id
		_locations[key]["last_visited_time"] = Time.get_unix_time_from_system()

	location_visited.emit(agent_id, location_name)


## Get agents at a location
func get_agents_at_location(location_name: String) -> Array:
	var result = []
	var key = location_name.to_lower().replace(" ", "_")

	for agent_id in _agent_locations.keys():
		if _agent_locations[agent_id].to_lower().replace(" ", "_") == key:
			result.append(agent_id)

	return result


## Get location description for agent prompts
func get_location_description() -> String:
	if _locations.is_empty():
		return "No locations discovered yet."

	var desc = "## Known Locations\n"
	for key in _locations.keys():
		var loc = _locations[key]
		desc += "- %s: %s" % [loc.name, loc.purpose]
		if loc.has("visit_count"):
			desc += " (visited %d times)" % loc.visit_count
		desc += "\n"

	desc += "\nUse goto(\"location_name\") to navigate to any location."
	return desc


## Load from disk
func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_locations = json.data
		print("[SharedMemory] Loaded %d locations from disk" % _locations.size())


## Save to disk
func _save_to_disk() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SharedMemory] Failed to save locations")
		return

	file.store_string(JSON.stringify(_locations, "  "))
	file.close()


## Clear all locations (for testing)
func clear_all() -> void:
	_locations.clear()
	_agent_locations.clear()
	_save_to_disk()
	print("[SharedMemory] All locations cleared")
