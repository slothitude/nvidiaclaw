## Collision2D - 2D rigid body collision detection and response
##
## Handles circle-circle collisions with elastic/inelastic response.
## Designed for deterministic simulation - no randomness.
class_name Collision2D
extends RefCounted

## Collision result structure
class CollisionResult:
	var body_a_id: String = ""
	var body_b_id: String = ""
	var normal: Vector2 = Vector2.ZERO  # Normal from A to B
	var penetration: float = 0.0
	var contact_point: Vector2 = Vector2.ZERO

	static func from_dict(d: Dictionary) -> CollisionResult:
		var result = CollisionResult.new()
		result.body_a_id = d.get("body_a_id", "")
		result.body_b_id = d.get("body_b_id", "")
		result.normal = d.get("normal", Vector2.ZERO)
		result.penetration = d.get("penetration", 0.0)
		result.contact_point = d.get("contact_point", Vector2.ZERO)
		return result

	func to_dict() -> Dictionary:
		return {
			"body_a_id": body_a_id,
			"body_b_id": body_b_id,
			"normal": normal,
			"penetration": penetration,
			"contact_point": contact_point
		}

## Check collision between two circle bodies
static func circle_circle(body_a: Dictionary, body_b: Dictionary) -> CollisionResult:
	var result = CollisionResult.new()

	var pos_a = Vector2(body_a.pos.x, body_a.pos.y)
	var pos_b = Vector2(body_b.pos.x, body_b.pos.y)
	var radius_a: float = body_a.get("radius", 10.0)
	var radius_b: float = body_b.get("radius", 10.0)

	var delta = pos_b - pos_a
	var dist_sq = delta.length_squared()
	var min_dist = radius_a + radius_b

	if dist_sq < min_dist * min_dist and dist_sq > 0.0001:
		var dist = sqrt(dist_sq)
		result.body_a_id = body_a.id
		result.body_b_id = body_b.id
		result.normal = delta / dist
		result.penetration = min_dist - dist
		result.contact_point = pos_a + result.normal * (radius_a - result.penetration * 0.5)

	return result

## Resolve collision between two bodies (modifies them in place)
static func resolve_collision(body_a: Dictionary, body_b: Dictionary, collision: CollisionResult, restitution: float = 0.8) -> void:
	# Skip if both are static
	var static_a: bool = body_a.get("static", false)
	var static_b: bool = body_b.get("static", false)
	if static_a and static_b:
		return

	var vel_a = Vector2(body_a.vel.x, body_a.vel.y)
	var vel_b = Vector2(body_b.vel.x, body_b.vel.y)
	var mass_a: float = body_a.get("mass", 1.0)
	var mass_b: float = body_b.get("mass", 1.0)

	# Handle static bodies (infinite mass)
	var inv_mass_a = 0.0 if static_a else 1.0 / mass_a
	var inv_mass_b = 0.0 if static_b else 1.0 / mass_b

	# Relative velocity (B relative to A)
	var rel_vel = vel_b - vel_a
	var vel_along_normal = rel_vel.dot(collision.normal)

	# Don't resolve if velocities are separating
	if vel_along_normal > 0:
		return

	# Calculate impulse scalar
	var e = restitution  # Coefficient of restitution
	var j = -(1.0 + e) * vel_along_normal
	var total_inv_mass = inv_mass_a + inv_mass_b
	if total_inv_mass > 0:
		j /= total_inv_mass
	else:
		return  # Both have infinite mass

	# Apply impulse
	var impulse = collision.normal * j

	if not static_a:
		var new_vel_a = vel_a - impulse * inv_mass_a
		body_a.vel.x = new_vel_a.x
		body_a.vel.y = new_vel_a.y

	if not static_b:
		var new_vel_b = vel_b + impulse * inv_mass_b
		body_b.vel.x = new_vel_b.x
		body_b.vel.y = new_vel_b.y

	# Positional correction to prevent sinking
	var percent: float = 0.4  # Penetration percentage to correct
	var slop: float = 0.01   # Penetration allowance

	var correction_magnitude = max(collision.penetration - slop, 0.0) * percent
	if total_inv_mass > 0:
		correction_magnitude /= total_inv_mass
	var correction = collision.normal * correction_magnitude

	if not static_a:
		body_a.pos.x -= correction.x * inv_mass_a
		body_a.pos.y -= correction.y * inv_mass_a

	if not static_b:
		body_b.pos.x += correction.x * inv_mass_b
		body_b.pos.y += correction.y * inv_mass_b

## Check and resolve all collisions in a world state
static func resolve_all_collisions(state: Variant, restitution: float = 0.8, iterations: int = 4) -> Array:
	var collisions: Array = []

	for _iter in range(iterations):
		collisions.clear()

		# Detect all collisions
		for i in range(state.bodies.size()):
			for j in range(i + 1, state.bodies.size()):
				var body_a = state.bodies[i]
				var body_b = state.bodies[j]

				var collision = circle_circle(body_a, body_b)
				if collision.penetration > 0:
					collisions.append(collision)
					resolve_collision(body_a, body_b, collision, restitution)

	return collisions

## Detect all collisions without resolving them
static func detect_all_collisions(state: Variant) -> Array:
	var collisions: Array = []

	for i in range(state.bodies.size()):
		for j in range(i + 1, state.bodies.size()):
			var body_a = state.bodies[i]
			var body_b = state.bodies[j]

			var collision = circle_circle(body_a, body_b)
			if collision.penetration > 0:
				collisions.append(collision)

	return collisions

## Check if a point is inside a circle body
static func point_in_circle(point: Vector2, body: Dictionary) -> bool:
	var pos = Vector2(body.pos.x, body.pos.y)
	var radius: float = body.get("radius", 10.0)
	return point.distance_squared_to(pos) <= radius * radius

## Find the nearest body to a point
static func nearest_body_to_point(state: Variant, point: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_dist: float = INF

	for body in state.bodies:
		var pos = Vector2(body.pos.x, body.pos.y)
		var dist = point.distance_squared_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body

	return nearest

## Ray-circle intersection test
static func ray_circle(ray_origin: Vector2, ray_dir: Vector2, body: Dictionary) -> Dictionary:
	var pos = Vector2(body.pos.x, body.pos.y)
	var radius: float = body.get("radius", 10.0)

	var m = ray_origin - pos
	var b = m.dot(ray_dir)
	var c = m.dot(m) - radius * radius

	# Exit if ray origin outside circle and pointing away
	if c > 0.0 and b > 0.0:
		return {"hit": false}

	var discr = b * b - c

	# Negative discriminant means ray misses
	if discr < 0.0:
		return {"hit": false}

	var t = -b - sqrt(discr)

	# If t < 0, ray started inside circle
	if t < 0.0:
		t = 0.0

	var hit_point = ray_origin + ray_dir * t
	var normal = (hit_point - pos).normalized()

	return {
		"hit": true,
		"t": t,
		"point": hit_point,
		"normal": normal,
		"body_id": body.id
	}

## Cast a ray through all bodies and find the nearest hit
static func ray_cast(state: Variant, ray_origin: Vector2, ray_dir: Vector2, max_dist: float = 10000.0) -> Dictionary:
	var nearest_hit: Dictionary = {"hit": false, "t": max_dist}
	var ray_dir_norm = ray_dir.normalized()

	for body in state.bodies:
		var result = ray_circle(ray_origin, ray_dir_norm, body)
		if result.hit and result.t < nearest_hit.t:
			nearest_hit = result

	if not nearest_hit.hit:
		nearest_hit.t = max_dist

	return nearest_hit
