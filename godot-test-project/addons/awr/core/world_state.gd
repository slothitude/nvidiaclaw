## WorldState - Persistent scene graph for AWR
##
## Full snapshot approach - simple, optimize to COW later
## Every node is a fact. A living spatial structure.
class_name WorldState
extends RefCounted

# Preload collision system
const Collision2DScript = preload("res://addons/awr/physics/collision_2d.gd")

## All physics bodies in the world
var bodies: Array = []
## Current simulation time
var time: float = 0.0
## World boundaries
var bounds: Rect2 = Rect2(0, 0, 1000, 1000)
## World configuration metadata
var config: Dictionary = {}
## Enable body-body collision resolution
var physics_enabled: bool = true
## Collision iterations per step
var collision_iterations: int = 4

## Create a deep copy of this world state
func clone() -> Variant:
	var snapshot = get_script().new()
	snapshot.bodies = bodies.duplicate(true)  # Deep copy
	snapshot.time = time
	snapshot.bounds = bounds
	snapshot.config = config.duplicate(true)
	return snapshot

## Apply an action to the world state
func apply(action: Dictionary) -> void:
	match action.type:
		"move":
			var body = _find_body(action.target)
			if not body.is_empty():
				body.pos.x += action.params.get("x", 0.0)
				body.pos.y += action.params.get("y", 0.0)
		"set_position":
			var body = _find_body(action.target)
			if not body.is_empty():
				body.pos.x = action.params.get("x", body.pos.x)
				body.pos.y = action.params.get("y", body.pos.y)
		"apply_force":
			var body = _find_body(action.target)
			if not body.is_empty():
				body.force.x += action.params.get("x", 0.0)
				body.force.y += action.params.get("y", 0.0)
		"apply_impulse":
			var body = _find_body(action.target)
			if not body.is_empty():
				body.vel.x += action.params.get("x", 0.0)
				body.vel.y += action.params.get("y", 0.0)
		"set_velocity":
			var body = _find_body(action.target)
			if not body.is_empty():
				body.vel.x = action.params.get("x", body.vel.x)
				body.vel.y = action.params.get("y", body.vel.y)
		"spawn":
			var new_body = action.params.duplicate(true)
			_ensure_body_defaults(new_body)
			bodies.append(new_body)
		"destroy":
			bodies = bodies.filter(func(b): return b.id != action.target)
		"set_bounds":
			bounds = Rect2(
				action.params.get("x", bounds.position.x),
				action.params.get("y", bounds.position.y),
				action.params.get("width", bounds.size.x),
				action.params.get("height", bounds.size.y)
			)

## Advance simulation by dt seconds
func step(dt: float) -> void:
	# Update velocities and positions (Euler integration)
	for body in bodies:
		var mass: float = body.get("mass", 1.0)
		var force = Vector2(body.force.x, body.force.y)
		var vel = Vector2(body.vel.x, body.vel.y)
		var pos = Vector2(body.pos.x, body.pos.y)
		var restitution: float = body.get("restitution", 0.8)
		var radius: float = body.get("radius", 10.0)
		var is_static: bool = body.get("static", false)

		if not is_static:
			# Apply forces
			vel += force * dt / mass
			pos += vel * dt

			# Boundary collision
			if pos.x - radius < bounds.position.x:
				pos.x = bounds.position.x + radius
				vel.x *= -restitution
			elif pos.x + radius > bounds.position.x + bounds.size.x:
				pos.x = bounds.position.x + bounds.size.x - radius
				vel.x *= -restitution

			if pos.y - radius < bounds.position.y:
				pos.y = bounds.position.y + radius
				vel.y *= -restitution
			elif pos.y + radius > bounds.position.y + bounds.size.y:
				pos.y = bounds.position.y + bounds.size.y - radius
				vel.y *= -restitution

		# Write back
		body.vel.x = vel.x
		body.vel.y = vel.y
		body.pos.x = pos.x
		body.pos.y = pos.y
		body.force.x = 0.0
		body.force.y = 0.0  # Reset forces

	# Resolve body-body collisions
	if physics_enabled:
		Collision2DScript.resolve_all_collisions(self, 0.8, collision_iterations)

	time += dt

## Generate hash for branch comparison
func hash() -> int:
	var h: int = hash_float(time)
	for body in bodies:
		h = h ^ hash_string(body.id)
		h = h ^ hash_float(body.pos.x)
		h = h ^ hash_float(body.pos.y)
		h = h ^ hash_float(body.vel.x)
		h = h ^ hash_float(body.vel.y)
	return h

## Find a body by ID, returns empty dict if not found
func _find_body(id: String) -> Dictionary:
	for body in bodies:
		if body.id == id:
			return body
	return {}

## Get a body by ID (public interface)
func get_body(id: String) -> Dictionary:
	return _find_body(id)

## Check if a body exists
func has_body(id: String) -> bool:
	return not _find_body(id).is_empty()

## Add a body with automatic defaults
func add_body(body: Dictionary) -> void:
	_ensure_body_defaults(body)
	bodies.append(body)

## Ensure body has all required fields
func _ensure_body_defaults(body: Dictionary) -> void:
	if not body.has("id"):
		body.id = "body_%d" % bodies.size()
	if not body.has("pos"):
		body.pos = {"x": 0.0, "y": 0.0}
	if not body.has("vel"):
		body.vel = {"x": 0.0, "y": 0.0}
	if not body.has("force"):
		body.force = {"x": 0.0, "y": 0.0}
	if not body.has("mass"):
		body.mass = 1.0
	if not body.has("restitution"):
		body.restitution = 0.8
	if not body.has("radius"):
		body.radius = 10.0
	if not body.has("static"):
		body.static = false

## Create world from config dictionary
static func from_config(config_dict: Dictionary) -> Variant:
	var script = load("res://addons/awr/core/world_state.gd")
	var state = script.new()

	if config_dict.has("bounds"):
		var b = config_dict.bounds
		state.bounds = Rect2(
			b.get("x", 0),
			b.get("y", 0),
			b.get("width", 1000),
			b.get("height", 1000)
		)

	if config_dict.has("bodies"):
		for body_config in config_dict.bodies:
			var body: Dictionary = {}
			body.id = body_config.get("id", "body_%d" % state.bodies.size())

			# Handle pos as array or dict
			if body_config.has("pos"):
				if body_config.pos is Array:
					body.pos = {"x": float(body_config.pos[0]), "y": float(body_config.pos[1])}
				else:
					body.pos = body_config.pos.duplicate()
			else:
				body.pos = {"x": 0.0, "y": 0.0}

			# Handle vel as array or dict
			if body_config.has("vel"):
				if body_config.vel is Array:
					body.vel = {"x": float(body_config.vel[0]), "y": float(body_config.vel[1])}
				else:
					body.vel = body_config.vel.duplicate()
			else:
				body.vel = {"x": 0.0, "y": 0.0}

			body.force = {"x": 0.0, "y": 0.0}
			body.mass = body_config.get("mass", 1.0)
			body.restitution = body_config.get("restitution", 0.8)
			body.radius = body_config.get("radius", 10.0)
			body.static = body_config.get("static", false)

			state.bodies.append(body)

	state.config = config_dict.duplicate(true)
	return state

## Helper hash functions
static func hash_float(f: float) -> int:
	return var_to_str(f).hash()

static func hash_string(s: String) -> int:
	return s.hash()
