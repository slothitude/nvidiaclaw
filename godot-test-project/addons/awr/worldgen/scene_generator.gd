## SceneGenerator - Procedural scene generation for AWR
##
## Generates WorldState configurations from templates, random seeds,
## or AI descriptions. Creates reproducible test scenarios.
class_name SceneGenerator
extends RefCounted

## RNG seed for reproducibility
var seed_value: int = 0
var _rng: RandomNumberGenerator

## Generation config
var config: Dictionary = {
	"bounds": {"x": 0, "y": 0, "width": 1000, "height": 1000},
	"min_radius": 5.0,
	"max_radius": 30.0,
	"min_mass": 0.5,
	"max_mass": 10.0,
	"restitution": 0.8,
	"margin": 50.0  # Keep bodies this far from edges
}

func _init(initial_seed: int = 0):
	seed_value = initial_seed
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

## Set seed for reproducible generation
func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	_rng.seed = seed_value

## Generate a random scene with N bodies
func generate_random(body_count: int, ensure_no_overlap: bool = true) -> Dictionary:
	var bodies: Array = []
	var bounds = config.bounds
	var margin = config.margin

	for i in range(body_count):
		var body = _generate_random_body(i)
		var attempts = 0
		var max_attempts = 100

		# Ensure no overlap if requested
		while ensure_no_overlap and attempts < max_attempts:
			var overlapping = false
			for other in bodies:
				var dist = Vector2(body.pos.x, body.pos.y).distance_to(
					Vector2(other.pos.x, other.pos.y)
				)
				if dist < body.radius + other.radius + 5.0:
					overlapping = true
					break

			if not overlapping:
				break

			# Regenerate position
			body.pos = {
				"x": _rng.randf_range(margin + config.max_radius, bounds.width - margin - config.max_radius),
				"y": _rng.randf_range(margin + config.max_radius, bounds.height - margin - config.max_radius)
			}
			attempts += 1

		bodies.append(body)

	return {
		"bounds": bounds,
		"bodies": bodies,
		"seed": seed_value
	}

## Generate a single random body
func _generate_random_body(index: int) -> Dictionary:
	var bounds = config.bounds
	var margin = config.margin

	return {
		"id": "body_%d" % index,
		"pos": {
			"x": _rng.randf_range(margin + config.max_radius, bounds.width - margin - config.max_radius),
			"y": _rng.randf_range(margin + config.max_radius, bounds.height - margin - config.max_radius)
		},
		"vel": {
			"x": _rng.randf_range(-50, 50),
			"y": _rng.randf_range(-50, 50)
		},
		"force": {"x": 0.0, "y": 0.0},
		"mass": _rng.randf_range(config.min_mass, config.max_mass),
		"radius": _rng.randf_range(config.min_radius, config.max_radius),
		"restitution": config.restitution,
		"static": false
	}

## Generate a solar system scenario
func generate_solar_system(planet_count: int = 3) -> Dictionary:
	var bodies: Array = []
	var cx = config.bounds.width / 2.0
	var cy = config.bounds.height / 2.0

	# Sun at center (static)
	bodies.append({
		"id": "sun",
		"pos": {"x": cx, "y": cy},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1000.0,
		"radius": 50.0,
		"restitution": 0.0,
		"static": true,
		"type": "star"
	})

	# Planets in orbit
	for i in range(planet_count):
		var orbit_radius = 100.0 + i * 80.0
		var angle = _rng.randf() * TAU
		var orbital_speed = sqrt(1000.0 / orbit_radius) * 2.0  # Simplified orbital mechanics

		bodies.append({
			"id": "planet_%d" % i,
			"pos": {
				"x": cx + cos(angle) * orbit_radius,
				"y": cy + sin(angle) * orbit_radius
			},
			"vel": {
				"x": -sin(angle) * orbital_speed,
				"y": cos(angle) * orbital_speed
			},
			"force": {"x": 0.0, "y": 0.0},
			"mass": 10.0 + i * 5.0,
			"radius": 15.0 + i * 3.0,
			"restitution": 0.5,
			"static": false,
			"type": "planet"
		})

	return {
		"bounds": config.bounds,
		"bodies": bodies,
		"seed": seed_value,
		"scenario": "solar_system"
	}

## Generate a billiards/pool table setup
func generate_billiards() -> Dictionary:
	var bodies: Array = []
	var cx = config.bounds.width / 2.0
	var cy = config.bounds.height / 2.0
	var ball_radius = 12.0
	var ball_mass = 1.0

	# Cue ball
	bodies.append({
		"id": "cue_ball",
		"pos": {"x": cx - 150.0, "y": cy},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": ball_mass,
		"radius": ball_radius,
		"restitution": 0.95,
		"static": false,
		"type": "cue_ball"
	})

	# Triangle of balls
	var start_x = cx + 50.0
	var row = 0
	var ball_num = 0
	while ball_num < 15:
		for j in range(row + 1):
			if ball_num >= 15:
				break
			bodies.append({
				"id": "ball_%d" % ball_num,
				"pos": {
					"x": start_x + row * ball_radius * 1.8,
					"y": cy - row * ball_radius + j * ball_radius * 2.0
				},
				"vel": {"x": 0.0, "y": 0.0},
				"force": {"x": 0.0, "y": 0.0},
				"mass": ball_mass,
				"radius": ball_radius,
				"restitution": 0.95,
				"static": false,
				"type": "ball"
			})
			ball_num += 1
		row += 1

	return {
		"bounds": config.bounds,
		"bodies": bodies,
		"seed": seed_value,
		"scenario": "billiards"
	}

## Generate a pendulum scenario
func generate_pendulum(length: float = 200.0, angle: float = PI/4) -> Dictionary:
	var cx = config.bounds.width / 2.0
	var cy = config.bounds.height / 3.0

	var bob_x = cx + sin(angle) * length
	var bob_y = cy + cos(angle) * length

	return {
		"bounds": config.bounds,
		"bodies": [
			{
				"id": "pivot",
				"pos": {"x": cx, "y": cy},
				"vel": {"x": 0.0, "y": 0.0},
				"force": {"x": 0.0, "y": 0.0},
				"mass": 1000.0,
				"radius": 10.0,
				"restitution": 0.0,
				"static": true,
				"type": "pivot"
			},
			{
				"id": "bob",
				"pos": {"x": bob_x, "y": bob_y},
				"vel": {"x": 0.0, "y": 0.0},
				"force": {"x": 0.0, "y": 0.0},
				"mass": 5.0,
				"radius": 20.0,
				"restitution": 0.8,
				"static": false,
				"type": "pendulum_bob",
				"tether_to": "pivot",
				"tether_length": length
			}
		],
		"seed": seed_value,
		"scenario": "pendulum"
	}

## Generate a maze scenario with a navigator
func generate_maze(goal_pos: Vector2 = Vector2(900, 500)) -> Dictionary:
	var bodies: Array = []

	# Navigator (the agent)
	bodies.append({
		"id": "navigator",
		"pos": {"x": 100.0, "y": 500.0},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"radius": 15.0,
		"restitution": 0.5,
		"static": false,
		"type": "agent"
	})

	# Goal marker (static)
	bodies.append({
		"id": "goal",
		"pos": {"x": goal_pos.x, "y": goal_pos.y},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1000.0,
		"radius": 25.0,
		"restitution": 0.0,
		"static": true,
		"type": "goal"
	})

	# Add some obstacles
	var obstacles = [
		{"x": 300, "y": 300, "r": 40},
		{"x": 500, "y": 600, "r": 35},
		{"x": 700, "y": 400, "r": 45},
		{"x": 400, "y": 500, "r": 30},
		{"x": 600, "y": 200, "r": 35}
	]

	for i in range(obstacles.size()):
		var obs = obstacles[i]
		bodies.append({
			"id": "obstacle_%d" % i,
			"pos": {"x": obs.x, "y": obs.y},
			"vel": {"x": 0.0, "y": 0.0},
			"force": {"x": 0.0, "y": 0.0},
			"mass": 1000.0,
			"radius": obs.r,
			"restitution": 0.8,
			"static": true,
			"type": "obstacle"
		})

	return {
		"bounds": config.bounds,
		"bodies": bodies,
		"seed": seed_value,
		"scenario": "maze",
		"goal": {"id": "goal", "pos": {"x": goal_pos.x, "y": goal_pos.y}}
	}

## Generate from a simple text description
func generate_from_description(description: String) -> Dictionary:
	var bodies: Array = []
	var lines = description.split("\n")
	var id_counter = 0

	for line in lines:
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		# Parse "type at x,y" format
		var parts = line.split(" at ")
		if parts.size() == 2:
			var body_type = parts[0].strip_edges()
			var pos_parts = parts[1].replace("(", "").replace(")", "").split(",")
			if pos_parts.size() >= 2:
				var x = pos_parts[0].strip_edges().to_float()
				var y = pos_parts[1].strip_edges().to_float()

				var body = _create_body_from_type(body_type, id_counter)
				body.pos = {"x": x, "y": y}
				bodies.append(body)
				id_counter += 1

	return {
		"bounds": config.bounds,
		"bodies": bodies,
		"seed": seed_value
	}

## Create a body from a type string
func _create_body_from_type(body_type: String, id_num: int) -> Dictionary:
	var body = {
		"id": "body_%d" % id_num,
		"pos": {"x": 0.0, "y": 0.0},
		"vel": {"x": 0.0, "y": 0.0},
		"force": {"x": 0.0, "y": 0.0},
		"mass": 1.0,
		"radius": 15.0,
		"restitution": 0.8,
		"static": false,
		"type": body_type
	}

	match body_type.to_lower():
		"sun", "star":
			body.mass = 1000.0
			body.radius = 50.0
			body.static = true
		"planet":
			body.mass = 10.0
			body.radius = 20.0
		"ball":
			body.mass = 1.0
			body.radius = 12.0
		"wall", "obstacle":
			body.mass = 1000.0
			body.static = true
		"goal":
			body.mass = 1000.0
			body.radius = 25.0
			body.static = true
		"agent":
			body.mass = 1.0
			body.radius = 15.0

	return body
