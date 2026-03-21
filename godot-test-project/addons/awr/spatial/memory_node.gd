## memory_node.gd - A concept at a location
## Part of AWR v0.2 - Spatial Memory Engine
##
## A MemoryNode represents a single concept stored at a spatial location.
## The "nothing" (space) around this node IS its context.

class_name MemoryNode
extends RefCounted

## What is stored - the concept or idea
var concept: String = ""

## Where in 3D space this concept lives
var location: Vector3 = Vector3.ZERO

## Additional metadata (type, tags, description, etc.)
var metadata: Dictionary = {}

## Explicit connections to other concepts (by name)
var connections: Array = []

## Timestamp when created (in microseconds)
var created_at: int = 0

## Timestamp when last accessed (in microseconds)
var accessed_at: int = 0

## Number of times this node has been accessed
var access_count: int = 0

## Unique identifier for this node
var id: String = ""


func _init(p_concept: String = "", p_location: Vector3 = Vector3.ZERO) -> void:
	concept = p_concept
	location = p_location
	id = _generate_id()
	created_at = Time.get_ticks_usec()
	accessed_at = created_at


func _generate_id() -> String:
	# Generate a unique ID based on concept and timestamp
	var hash_input = concept + str(created_at) + str(randf())
	return hash_input.sha256_text().substr(0, 16)


## Mark this node as accessed (updates stats)
func touch() -> void:
	accessed_at = Time.get_ticks_usec()
	access_count += 1


## Add an explicit connection to another concept
func connect_to(other_concept: String) -> void:
	if other_concept not in connections:
		connections.append(other_concept)


## Remove a connection
func disconnect_from(other_concept: String) -> void:
	connections.erase(other_concept)


## Get the "nothing" around this node - its spatial context
## Returns all MemoryNodes within the given radius
func context(memory, radius: float = 10.0) -> Array:
	if memory == null:
		return []
	return memory.neighbors(location, radius)


## Calculate Euclidean distance to another node
func distance_to(other) -> float:
	if other == null:
		return INF
	return location.distance_to(other.location)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"concept": concept,
		"location": {"x": location.x, "y": location.y, "z": location.z},
		"metadata": metadata,
		"connections": connections,
		"created_at": created_at,
		"accessed_at": accessed_at,
		"access_count": access_count
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary):
	var cls = load("res://addons/awr/spatial/memory_node.gd")
	var node = cls.new()
	node.id = data.get("id", "")
	node.concept = data.get("concept", "")
	var loc = data.get("location", {})
	node.location = Vector3(
		loc.get("x", 0.0),
		loc.get("y", 0.0),
		loc.get("z", 0.0)
	)
	node.metadata = data.get("metadata", {})
	node.connections = data.get("connections", [])
	node.created_at = data.get("created_at", 0)
	node.accessed_at = data.get("accessed_at", 0)
	node.access_count = data.get("access_count", 0)
	return node


func _to_string() -> String:
	return "MemoryNode(%s @ %s, accessed=%d)" % [concept, location, access_count]
