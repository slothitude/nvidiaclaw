## memory_node.gd - A concept at a location with physics
## Part of AWR v0.4 - Spatial Memory Engine with Physics
##
## A MemoryNode represents a single concept stored at a spatial location.
## The "nothing" (space) around this node IS its context.
## Concepts can be physical bodies that move, collide, and are simulated.
##
## Memory Palaces: Concepts stored in 3D space form navigable structures.
## Physics-as-Reasoning: Concepts can be simulated to predict outcomes.

class_name MemoryNode
extends RefCounted

# ============================================================
# CORE IDENTITY
# ============================================================

## What is stored - the concept or idea
var concept: String = ""

## Where in 3D space this concept lives
var location: Vector3 = Vector3.ZERO

## Unique identifier for this node
var id: String = ""

# ============================================================
# SPATIAL ORIENTATION (v0.4)
# ============================================================

## Orientation in 3D space (for perspective-taking)
var rotation: Quaternion = Quaternion()

## Size/importance in space
var scale: Vector3 = Vector3.ONE

## Movement direction (for dynamic concepts)
var velocity: Vector3 = Vector3.ZERO

## Angular velocity (rotation per second)
var angular_velocity: Vector3 = Vector3.ZERO

# ============================================================
# SPATIAL RELATIONSHIPS (v0.4)
# ============================================================

## Which direction concept "faces"
var facing: Vector3 = Vector3.FORWARD

## Up direction (for orientation)
var up_vector: Vector3 = Vector3.UP

## Bounding box (for region concepts like places)
var bounds: AABB = AABB()

# ============================================================
# SEMANTIC PROPERTIES (v0.4)
# ============================================================

## Type of concept: "concept", "action", "entity", "event", "place"
var semantic_type: String = "concept"

## Additional metadata (type, tags, description, etc.)
var metadata: Dictionary = {}

## How confident we are in this memory (0-1)
var confidence: float = 1.0

## How "bright" this memory is (attention, 0-1)
var salience: float = 0.5

## Searchable tags
var tags: Array = []

# ============================================================
# TEMPORAL INFORMATION (v0.4)
# ============================================================

## Timestamp when created (in microseconds)
var created_at: int = 0

## Timestamp when last accessed (in microseconds)
var accessed_at: int = 0

## Number of times this node has been accessed
var access_count: int = 0

## When this was first observed
var observed_at: int = 0

## Expiration time (for temporal memories, 0 = never expires)
var valid_until: int = 0

# ============================================================
# CONNECTIONS (v0.2+)
# ============================================================

## Explicit connections to other concepts
## Format: [{"concept": String, "type": String, "strength": float}]
var connections: Array = []

## Hierarchical parent concept
var parent_concept: String = ""

## Hierarchical children concepts
var children: Array = []

# ============================================================
# EMBODIMENT DATA (v0.4)
# ============================================================

## Visual, audio, tactile associations
var sensory_data: Dictionary = {}

## What actions can be performed on/with this concept
var motor_affordances: Array = []

## Positive/negative association (-1 to 1)
var emotional_valence: float = 0.0

# ============================================================
# LEARNING DATA (v0.4)
# ============================================================

## History of prediction errors
var prediction_errors: Array = []

## Times this was reinforced
var reinforcement_count: int = 0

## How fast this memory fades (0 = never, 1 = instant)
var decay_rate: float = 0.01

# ============================================================
# PHYSICS PROPERTIES (v0.4)
# ============================================================

## Can this concept be affected by physics?
var is_physical: bool = false

## Mass for physics simulation
var mass: float = 1.0

## Bounciness (0-1)
var restitution: float = 0.5

## Friction coefficient
var friction: float = 0.3

## Is this a static/immovable concept?
var is_static: bool = false

## Collision radius (for sphere collision)
var collision_radius: float = 1.0

## Accumulated force (cleared each step)
var force: Vector3 = Vector3.ZERO

## Accumulated torque (cleared each step)
var torque: Vector3 = Vector3.ZERO

# ============================================================
# SIGNALS
# ============================================================

signal moved(from: Vector3, to: Vector3)
signal rotated(from: Quaternion, to: Quaternion)
signal collided_with(other, point: Vector3)  # other is MemoryNode
signal decayed(new_salience: float)
signal expired()


func _init(p_concept: String = "", p_location: Vector3 = Vector3.ZERO) -> void:
	concept = p_concept
	location = p_location
	id = _generate_id()
	created_at = Time.get_ticks_usec()
	accessed_at = created_at
	observed_at = created_at


func _generate_id() -> String:
	var hash_input = concept + str(created_at) + str(randf())
	return hash_input.sha256_text().substr(0, 16)


# ============================================================
# ACCESS AND LIFECYCLE
# ============================================================

## Mark this node as accessed (updates stats)
func touch() -> void:
	accessed_at = Time.get_ticks_usec()
	access_count += 1


## Check if this memory has expired
func is_expired() -> bool:
	if valid_until == 0:
		return false
	return Time.get_ticks_usec() > valid_until


## Apply decay to salience (call periodically)
func apply_decay(dt: float) -> void:
	if decay_rate <= 0:
		return

	salience = max(0.0, salience - decay_rate * dt)
	decayed.emit(salience)

	if salience <= 0:
		expired.emit()


## Reinforce this memory (increase salience and confidence)
func reinforce(amount: float = 0.1) -> void:
	salience = min(1.0, salience + amount)
	confidence = min(1.0, confidence + amount * 0.5)
	reinforcement_count += 1


# ============================================================
# SPATIAL QUERIES
# ============================================================

## Get forward direction in world space
func get_forward() -> Vector3:
	return rotation * facing


## Get right direction in world space
func get_right() -> Vector3:
	return rotation * Vector3.RIGHT


## Get up direction in world space
func get_up() -> Vector3:
	return rotation * up_vector


## Look at a target position
func look_at(target: Vector3) -> void:
	var direction = (target - location).normalized()
	if direction.length_squared() > 0.001:
		var old_rotation = rotation

		# Create rotation using Transform3D.looking_at
		var basis = Basis.looking_at(direction, up_vector)
		rotation = basis.get_rotation_quaternion()

		facing = direction
		rotated.emit(old_rotation, rotation)


## Calculate distance to another node
func distance_to(other) -> float:  # other: MemoryNode
	if other == null:
		return INF
	return location.distance_to(other.location)


## Check if a point is within this concept's bounds
func contains_point(point: Vector3) -> bool:
	if bounds.size == Vector3.ZERO:
		# Use collision radius for sphere check
		return location.distance_to(point) <= collision_radius
	return bounds.has_point(point)


## Get the "nothing" around this node - its spatial context
func context(memory, radius: float = 10.0) -> Array:
	if memory == null:
		return []
	return memory.neighbors(location, radius)


## Is this concept visible from a position?
func is_visible_from(from_pos: Vector3, direction: Vector3, fov: float = PI/2) -> bool:
	var to_concept = (location - from_pos).normalized()
	var angle = direction.angle_to(to_concept)
	return angle <= fov / 2.0


## Get approach angle (what angle you'd arrive from)
func approach_angle(from_pos: Vector3) -> float:
	var to_concept = (location - from_pos).normalized()
	return facing.signed_angle_to(to_concept, up_vector)


# ============================================================
# CONNECTIONS
# ============================================================

## Add an explicit connection to another concept
func connect_to(other_concept: String, type: String = "related", strength: float = 1.0) -> void:
	# Check for existing connection
	for conn in connections:
		if conn.concept == other_concept:
			conn.strength = strength
			conn.type = type
			return

	connections.append({
		"concept": other_concept,
		"type": type,
		"strength": strength
	})


## Remove a connection
func disconnect_from(other_concept: String) -> void:
	for i in range(connections.size() - 1, -1, -1):
		if connections[i].concept == other_concept:
			connections.remove_at(i)


## Get connections of a specific type
func get_connections_by_type(type: String) -> Array:
	var result: Array = []
	for conn in connections:
		if conn.type == type:
			result.append(conn)
	return result


## Get strongest connections
func get_strongest_connections(count: int = 5) -> Array:
	var sorted = connections.duplicate()
	sorted.sort_custom(func(a, b): return a.strength > b.strength)
	return sorted.slice(0, count)


# ============================================================
# PHYSICS SIMULATION
# ============================================================

## Apply force to this concept
func apply_force(f: Vector3) -> void:
	if is_static:
		return
	force += f


## Apply impulse (instant velocity change)
func apply_impulse(impulse: Vector3) -> void:
	if is_static:
		return
	velocity += impulse / mass


## Apply torque
func apply_torque(t: Vector3) -> void:
	if is_static:
		return
	torque += t


## Step physics simulation
func step_physics(dt: float) -> void:
	if is_static or not is_physical:
		return

	# Apply accumulated forces
	var acceleration = force / mass
	velocity += acceleration * dt

	# Apply drag
	velocity *= (1.0 - friction * dt)

	# Update position
	var old_location = location
	location += velocity * dt
	moved.emit(old_location, location)

	# Apply torque
	var angular_accel = torque / mass
	angular_velocity += angular_accel * dt
	angular_velocity *= (1.0 - friction * dt)

	# Update rotation
	if angular_velocity.length_squared() > 0.0001:
		var old_rotation = rotation
		var angle = angular_velocity.length() * dt
		var axis = angular_velocity.normalized()
		rotation = Quaternion(axis, angle) * rotation
		rotated.emit(old_rotation, rotation)

	# Clear forces
	force = Vector3.ZERO
	torque = Vector3.ZERO


## Check collision with another node
func check_collision(other) -> Dictionary:  # other: MemoryNode
	if not is_physical or not other.is_physical:
		return {"collision": false}

	var dist = location.distance_to(other.location)
	var min_dist = collision_radius + other.collision_radius

	if dist < min_dist:
		var normal = (location - other.location).normalized()
		var penetration = min_dist - dist
		return {
			"collision": true,
			"other": other,
			"normal": normal,
			"penetration": penetration,
			"point": location - normal * collision_radius
		}

	return {"collision": false}


## Resolve collision with another node
func resolve_collision(collision_info: Dictionary) -> void:
	if not collision_info.collision:
		return

	var other = collision_info.other  # MemoryNode
	var normal: Vector3 = collision_info.normal
	var penetration: float = collision_info.penetration

	# Separate bodies
	location += normal * penetration * 0.5

	# Calculate relative velocity
	var rel_vel = velocity - other.velocity
	var vel_along_normal = rel_vel.dot(normal)

	# Don't resolve if velocities are separating
	if vel_along_normal > 0:
		return

	# Calculate restitution
	var e = min(restitution, other.restitution)

	# Calculate impulse scalar
	var total_mass = 1.0 / mass + 1.0 / other.mass
	var j = -(1 + e) * vel_along_normal / total_mass

	# Apply impulse
	var impulse = normal * j
	velocity += impulse / mass

	collided_with.emit(other, collision_info.point)


# ============================================================
# SERIALIZATION
# ============================================================

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		# Core
		"id": id,
		"concept": concept,
		"location": {"x": location.x, "y": location.y, "z": location.z},

		# Spatial orientation
		"rotation": {"x": rotation.x, "y": rotation.y, "z": rotation.z, "w": rotation.w},
		"scale": {"x": scale.x, "y": scale.y, "z": scale.z},
		"velocity": {"x": velocity.x, "y": velocity.y, "z": velocity.z},
		"angular_velocity": {"x": angular_velocity.x, "y": angular_velocity.y, "z": angular_velocity.z},

		# Spatial relationships
		"facing": {"x": facing.x, "y": facing.y, "z": facing.z},
		"up_vector": {"x": up_vector.x, "y": up_vector.y, "z": up_vector.z},
		"bounds": {
			"position": {"x": bounds.position.x, "y": bounds.position.y, "z": bounds.position.z},
			"size": {"x": bounds.size.x, "y": bounds.size.y, "z": bounds.size.z}
		},

		# Semantic
		"semantic_type": semantic_type,
		"metadata": metadata,
		"confidence": confidence,
		"salience": salience,
		"tags": tags,

		# Temporal
		"created_at": created_at,
		"accessed_at": accessed_at,
		"access_count": access_count,
		"observed_at": observed_at,
		"valid_until": valid_until,

		# Connections
		"connections": connections,
		"parent_concept": parent_concept,
		"children": children,

		# Embodiment
		"sensory_data": sensory_data,
		"motor_affordances": motor_affordances,
		"emotional_valence": emotional_valence,

		# Learning
		"prediction_errors": prediction_errors,
		"reinforcement_count": reinforcement_count,
		"decay_rate": decay_rate,

		# Physics
		"is_physical": is_physical,
		"mass": mass,
		"restitution": restitution,
		"friction": friction,
		"is_static": is_static,
		"collision_radius": collision_radius
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new()

	# Core
	node.id = data.get("id", "")
	node.concept = data.get("concept", "")

	var loc = data.get("location", {})
	node.location = Vector3(loc.get("x", 0.0), loc.get("y", 0.0), loc.get("z", 0.0))

	# Spatial orientation
	var rot = data.get("rotation", {})
	node.rotation = Quaternion(
		rot.get("x", 0.0), rot.get("y", 0.0), rot.get("z", 0.0), rot.get("w", 1.0)
	)

	var sc = data.get("scale", {})
	node.scale = Vector3(sc.get("x", 1.0), sc.get("y", 1.0), sc.get("z", 1.0))

	var vel = data.get("velocity", {})
	node.velocity = Vector3(vel.get("x", 0.0), vel.get("y", 0.0), vel.get("z", 0.0))

	var avel = data.get("angular_velocity", {})
	node.angular_velocity = Vector3(
		avel.get("x", 0.0), avel.get("y", 0.0), avel.get("z", 0.0)
	)

	# Spatial relationships
	var fac = data.get("facing", {})
	node.facing = Vector3(fac.get("x", 0.0), fac.get("y", 0.0), fac.get("z", -1.0))

	var upv = data.get("up_vector", {})
	node.up_vector = Vector3(upv.get("x", 0.0), upv.get("y", 1.0), upv.get("z", 0.0))

	var bnd = data.get("bounds", {})
	if bnd.has("position") and bnd.has("size"):
		var bpos = bnd.position
		var bsize = bnd.size
		node.bounds = AABB(
			Vector3(bpos.get("x", 0.0), bpos.get("y", 0.0), bpos.get("z", 0.0)),
			Vector3(bsize.get("x", 0.0), bsize.get("y", 0.0), bsize.get("z", 0.0))
		)

	# Semantic
	node.semantic_type = data.get("semantic_type", "concept")
	node.metadata = data.get("metadata", {})
	node.confidence = data.get("confidence", 1.0)
	node.salience = data.get("salience", 0.5)
	node.tags = data.get("tags", [])

	# Temporal
	node.created_at = data.get("created_at", 0)
	node.accessed_at = data.get("accessed_at", 0)
	node.access_count = data.get("access_count", 0)
	node.observed_at = data.get("observed_at", 0)
	node.valid_until = data.get("valid_until", 0)

	# Connections
	node.connections = data.get("connections", [])
	node.parent_concept = data.get("parent_concept", "")
	node.children = data.get("children", [])

	# Embodiment
	node.sensory_data = data.get("sensory_data", {})
	node.motor_affordances = data.get("motor_affordances", [])
	node.emotional_valence = data.get("emotional_valence", 0.0)

	# Learning
	node.prediction_errors = data.get("prediction_errors", [])
	node.reinforcement_count = data.get("reinforcement_count", 0)
	node.decay_rate = data.get("decay_rate", 0.01)

	# Physics
	node.is_physical = data.get("is_physical", false)
	node.mass = data.get("mass", 1.0)
	node.restitution = data.get("restitution", 0.5)
	node.friction = data.get("friction", 0.3)
	node.is_static = data.get("is_static", false)
	node.collision_radius = data.get("collision_radius", 1.0)

	return node


# ============================================================
# UTILITIES
# ============================================================

## Convert to AI-friendly prompt block
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== %s [%s] ===" % [concept.to_upper(), semantic_type])
	lines.append("Location: %s" % str(location))
	lines.append("Confidence: %.0f%%, Salience: %.0f%%" % [confidence * 100, salience * 100])

	if is_physical:
		lines.append("Physics: mass=%.1f, velocity=%s" % [mass, str(velocity)])

	if not connections.is_empty():
		lines.append("Connected to: %s" % [", ".join(connections.map(func(c): return c.concept))])

	if not motor_affordances.is_empty():
		lines.append("Affordances: %s" % [", ".join(motor_affordances)])

	if emotional_valence != 0.0:
		var emotion = "positive" if emotional_valence > 0 else "negative"
		lines.append("Emotional: %s (%.1f)" % [emotion, abs(emotional_valence)])

	return "\n".join(lines)


func _to_string() -> String:
	var physics_str = " [physical]" if is_physical else ""
	return "MemoryNode(%s @ %s, type=%s, salience=%.0f%%%s)" % [
		concept, location, semantic_type, salience * 100, physics_str
	]


# ============================================================
# FACTORY METHODS
# ============================================================

## Create a concept node
static func create_concept(p_name: String, p_loc: Vector3, p_meta: Dictionary = {}):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new(p_name, p_loc)
	node.semantic_type = "concept"
	node.metadata = p_meta
	return node


## Create an entity node (physical thing)
static func create_entity(p_name: String, p_loc: Vector3, p_mass: float = 1.0):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new(p_name, p_loc)
	node.semantic_type = "entity"
	node.is_physical = true
	node.mass = p_mass
	node.collision_radius = 1.0
	return node


## Create an action node
static func create_action(p_name: String, p_loc: Vector3, p_affordances: Array = []):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new(p_name, p_loc)
	node.semantic_type = "action"
	node.motor_affordances = p_affordances
	return node


## Create a place node (region)
static func create_place(p_name: String, p_center: Vector3, p_size: Vector3):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new(p_name, p_center)
	node.semantic_type = "place"
	node.bounds = AABB(p_center - p_size / 2, p_size)
	node.is_static = true
	return node


## Create an event node (temporal)
static func create_event(p_name: String, p_loc: Vector3, p_duration_ms: int = 60000):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new(p_name, p_loc)
	node.semantic_type = "event"
	node.valid_until = Time.get_ticks_usec() + p_duration_ms * 1000
	return node


## Create a wisdom node (from The Crypt)
static func create_wisdom(p_name: String, p_loc: Vector3, p_bloodline: String, p_lesson: String):  # Returns MemoryNode
	var script = load("res://addons/awr/spatial/memory_node.gd")
	var node = script.new(p_name, p_loc)
	node.semantic_type = "wisdom"
	node.metadata["bloodline"] = p_bloodline
	node.metadata["lesson"] = p_lesson
	node.decay_rate = 0.0  # Wisdom doesn't decay
	return node
