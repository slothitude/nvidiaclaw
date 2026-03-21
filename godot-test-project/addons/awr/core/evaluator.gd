## Evaluator - Scoring functions for branch comparison
##
## Higher score = better outcome
## These functions evaluate WorldState and return a score
class_name Evaluator
extends RefCounted

## Goal proximity - higher score = closer to goal
## Returns negative distance (closer is better)
static func goal_distance(state: Variant, goal_id: String, target_pos: Vector2) -> float:
	var body = state.get_body(goal_id)
	if body.is_empty():
		return -INF

	var body_pos = Vector2(body.pos.x, body.pos.y)
	var dist = body_pos.distance_to(target_pos)
	return -dist  # Negative because closer is better

## Goal distance with array/dict target position support
static func goal_distance_raw(state: Variant, goal_id: String, target) -> float:
	var target_pos: Vector2
	if target is Array:
		target_pos = Vector2(target[0], target[1])
	elif target is Dictionary:
		target_pos = Vector2(target.get("x", 0), target.get("y", 0))
	else:
		target_pos = target

	return goal_distance(state, goal_id, target_pos)

## Collision penalty - higher score = fewer collisions
## Returns negative penalty (no collisions = 0)
static func collision_free(state: Variant) -> float:
	var penalty = 0.0

	for i in range(state.bodies.size()):
		for j in range(i + 1, state.bodies.size()):
			var a = state.bodies[i]
			var b = state.bodies[j]

			var pos_a = Vector2(a.pos.x, a.pos.y)
			var pos_b = Vector2(b.pos.x, b.pos.y)
			var dist = pos_a.distance_to(pos_b)

			var radius_a: float = a.get("radius", 10.0)
			var radius_b: float = b.get("radius", 10.0)
			var min_dist = radius_a + radius_b

			if dist < min_dist:
				penalty += (min_dist - dist)

	return -penalty

## Collision detection - returns true if any collision exists
static func has_collision(state: Variant) -> bool:
	for i in range(state.bodies.size()):
		for j in range(i + 1, state.bodies.size()):
			var a = state.bodies[i]
			var b = state.bodies[j]

			var pos_a = Vector2(a.pos.x, a.pos.y)
			var pos_b = Vector2(b.pos.x, b.pos.y)
			var dist = pos_a.distance_to(pos_b)

			var radius_a: float = a.get("radius", 10.0)
			var radius_b: float = b.get("radius", 10.0)
			var min_dist = radius_a + radius_b

			if dist < min_dist:
				return true

	return false

## Energy efficiency - minimize kinetic energy
## Returns negative energy (less movement = better)
static func energy_efficient(state: Variant) -> float:
	var energy = 0.0

	for body in state.bodies:
		var mass: float = body.get("mass", 1.0)
		var vel = Vector2(body.vel.x, body.vel.y)
		energy += mass * vel.length_squared() * 0.5

	return -energy

## Total kinetic energy (positive value)
static func kinetic_energy(state: Variant) -> float:
	return -energy_efficient(state)

## Speed of a specific body
static func body_speed(state: Variant, body_id: String) -> float:
	var body = state.get_body(body_id)
	if body.is_empty():
		return 0.0

	var vel = Vector2(body.vel.x, body.vel.y)
	return vel.length()

## Combined evaluator with configurable weights
## weights: { "goal": weight, "goal_id": id, "goal_pos": Vector2,
##             "collision": weight, "energy": weight }
static func combined(state: Variant, weights: Dictionary = {}) -> float:
	var score = 0.0

	# Goal distance component
	if weights.has("goal_id") and weights.has("goal_pos"):
		var goal_weight: float = weights.get("goal", 1.0)
		var goal_id: String = weights.goal_id
		var goal_pos = weights.goal_pos
		score += goal_weight * goal_distance_raw(state, goal_id, goal_pos)

	# Collision avoidance component
	var collision_weight: float = weights.get("collision", 1.0)
	score += collision_weight * collision_free(state)

	# Energy efficiency component
	var energy_weight: float = weights.get("energy", 0.0)
	score += energy_weight * energy_efficient(state)

	return score

## Stability - penalize bodies that are moving fast
static func stability(state: Variant, threshold: float = 1.0) -> float:
	var penalty = 0.0

	for body in state.bodies:
		var vel = Vector2(body.vel.x, body.vel.y)
		var speed = vel.length()
		if speed > threshold:
			penalty += speed - threshold

	return -penalty

## Bounds containment - penalize bodies outside bounds
static func bounds_containment(state: Variant) -> float:
	var penalty = 0.0

	for body in state.bodies:
		var pos = Vector2(body.pos.x, body.pos.y)
		var radius: float = body.get("radius", 10.0)

		# Check if body center is within expanded bounds
		var inner_bounds = state.bounds.grow(-radius)
		if not inner_bounds.has_point(pos):
			# Calculate how far outside
			var closest = inner_bounds.get_closest_point(pos)
			penalty += pos.distance_to(closest)

	return -penalty

## Distance between two bodies
static func body_distance(state: Variant, body_a_id: String, body_b_id: String) -> float:
	var body_a = state.get_body(body_a_id)
	var body_b = state.get_body(body_b_id)

	if body_a.is_empty() or body_b.is_empty():
		return INF

	var pos_a = Vector2(body_a.pos.x, body_a.pos.y)
	var pos_b = Vector2(body_b.pos.x, body_b.pos.y)

	return pos_a.distance_to(pos_b)

## Create a callable evaluator for goal distance
static func make_goal_evaluator(goal_id: String, target_pos: Vector2) -> Callable:
	return func(state): return goal_distance(state, goal_id, target_pos)

## Create a callable combined evaluator
static func make_combined_evaluator(weights: Dictionary) -> Callable:
	return func(state): return combined(state, weights)
