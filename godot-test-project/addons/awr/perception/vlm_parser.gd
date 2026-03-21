## VLMParser - Parses vision model responses into WorldState updates
##
## Converts structured VLM descriptions into body spawn/update actions.
## Supports multiple output formats: JSON, structured text, NDJSON.
class_name VLMParser
extends RefCounted

## Parse VLM response into array of body definitions
## Expected format: JSON array of objects with id, pos, radius, color, etc.
static func parse_json_response(response: String) -> Array:
	var json = JSON.new()
	var error = json.parse(response)

	if error != OK:
		return []

	var data = json.data

	if data is Array:
		return _parse_body_array(data)
	elif data is Dictionary and data.has("objects"):
		return _parse_body_array(data.objects)
	elif data is Dictionary and data.has("bodies"):
		return _parse_body_array(data.bodies)

	return []

## Parse structured text response (fallback when JSON fails)
static func parse_text_response(response: String) -> Array:
	var bodies: Array = []
	var lines = response.split("\n")

	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue

		# Try to extract object from various formats
		var body = _parse_line_to_body(line)
		if not body.is_empty():
			bodies.append(body)

	return bodies

## Parse NDJSON response (one JSON object per line)
static func parse_ndjson_response(response: String) -> Array:
	var bodies: Array = []
	var lines = response.split("\n")

	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue

		var json = JSON.new()
		if json.parse(line) == OK:
			var body = _normalize_body(json.data)
			if not body.is_empty():
				bodies.append(body)

	return bodies

## Parse a single body definition
static func _parse_body_array(data: Array) -> Array:
	var bodies: Array = []
	for item in data:
		var body = _normalize_body(item)
		if not body.is_empty():
			bodies.append(body)
	return bodies

## Normalize body data to standard format
static func _normalize_body(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}

	var body: Dictionary = {}

	# ID
	body.id = data.get("id", data.get("name", data.get("label", "object_%d" % randi())))

	# Position - handle various formats
	if data.has("position"):
		var pos = data.position
		if pos is Array:
			body.pos = {"x": float(pos[0]), "y": float(pos[1])}
		elif pos is Dictionary:
			body.pos = {"x": float(pos.get("x", 0)), "y": float(pos.get("y", 0))}
	elif data.has("pos"):
		var pos = data.pos
		if pos is Array:
			body.pos = {"x": float(pos[0]), "y": float(pos[1])}
		elif pos is Dictionary:
			body.pos = {"x": float(pos.get("x", 0)), "y": float(pos.get("y", 0))}
	elif data.has("x") and data.has("y"):
		body.pos = {"x": float(data.x), "y": float(data.y)}
	else:
		body.pos = {"x": 0.0, "y": 0.0}

	# Velocity
	if data.has("velocity"):
		var vel = data.velocity
		if vel is Array:
			body.vel = {"x": float(vel[0]), "y": float(vel[1])}
		elif vel is Dictionary:
			body.vel = {"x": float(vel.get("x", 0)), "y": float(vel.get("y", 0))}
	elif data.has("vel"):
		var vel = data.vel
		if vel is Array:
			body.vel = {"x": float(vel[0]), "y": float(vel[1])}
		elif vel is Dictionary:
			body.vel = {"x": float(vel.get("x", 0)), "y": float(vel.get("y", 0))}
	else:
		body.vel = {"x": 0.0, "y": 0.0}

	# Physical properties
	body.mass = data.get("mass", data.get("weight", 1.0))
	body.radius = data.get("radius", data.get("size", data.get("width", 10.0)))
	body.restitution = data.get("restitution", data.get("bounciness", 0.8))
	body.static = data.get("static", data.get("fixed", false))

	# Force (start at zero)
	body.force = {"x": 0.0, "y": 0.0}

	# Additional metadata
	if data.has("color"):
		body.color = data.color
	if data.has("type"):
		body.type = data.type
	if data.has("label"):
		body.label = data.label

	return body

## Parse a single line into a body
static func _parse_line_to_body(line: String) -> Dictionary:
	var body: Dictionary = {}

	# Try to extract position with regex patterns
	var patterns = [
		# "object_name at (x, y)" format
		RegEx.create_from_string("(\\w+)\\s+at\\s+\\(([\\d.]+),\\s*([\\d.]+)\\)"),
		# "name: x=10, y=20" format
		RegEx.create_from_string("(\\w+):\\s*x=([\\d.]+),\\s*y=([\\d.]+)"),
		# JSON-like format
		RegEx.create_from_string('"id":\\s*"(\\w+)"[^}]*"pos":\\s*\\[([\\d.]+),\\s*([\\d.]+)\\]'),
	]

	for pattern in patterns:
		var regex = RegEx.create_from_string(pattern.get_pattern()) if pattern is RegEx else pattern
		var match = regex.search(line)
		if match:
			body.id = match.get_string(1)
			body.pos = {"x": match.get_string(2).to_float(), "y": match.get_string(3).to_float()}
			body.vel = {"x": 0.0, "y": 0.0}
			body.force = {"x": 0.0, "y": 0.0}
			body.mass = 1.0
			body.radius = 10.0
			body.restitution = 0.8
			return body

	return {}

## Build a prompt for scene analysis
static func build_analysis_prompt(context: String = "") -> String:
	var prompt = """Analyze this image and describe all visible objects.

For each object, provide:
- id: unique identifier
- pos: [x, y] position (normalized 0-1000)
- radius: approximate size
- color: main color
- type: object category

Return as JSON array:
{"objects": [{"id": "...", "pos": [x, y], "radius": ..., "color": "...", "type": "..."}]}"""

	if not context.is_empty():
		prompt += "\n\nContext: " + context

	return prompt

## Build a prompt for object tracking
static func build_tracking_prompt(previous_objects: Array, context: String = "") -> String:
	var prompt = """Track objects between frames.

Previous objects:
%s

Identify:
1. Objects that moved (new position)
2. Objects that appeared (new)
3. Objects that disappeared (removed)

Return JSON:
{
  "moved": [{"id": "...", "new_pos": [x, y]}],
  "appeared": [{"id": "...", "pos": [x, y], "radius": ...}],
  "disappeared": ["id1", "id2"]
}""" % JSON.stringify(previous_objects, "  ")

	if not context.is_empty():
		prompt += "\n\nContext: " + context

	return prompt

## Convert parsed bodies to WorldState spawn actions
static func to_spawn_actions(bodies: Array) -> Array:
	var actions: Array = []
	for body in bodies:
		actions.append({
			"type": "spawn",
			"params": body
		})
	return actions

## Create update actions from tracking response
static func parse_tracking_response(response: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(response) != OK:
		return {"moved": [], "appeared": [], "disappeared": []}

	var data = json.data
	var result: Dictionary = {"moved": [], "appeared": [], "disappeared": []}

	# Parse moved objects
	if data.has("moved"):
		for item in data.moved:
			var action = {
				"type": "set_position",
				"target": item.get("id", ""),
				"params": {}
			}
			if item.has("new_pos"):
				var pos = item.new_pos
				if pos is Array:
					action.params.x = float(pos[0])
					action.params.y = float(pos[1])
				elif pos is Dictionary:
					action.params.x = float(pos.get("x", 0))
					action.params.y = float(pos.get("y", 0))
			result.moved.append(action)

	# Parse appeared objects
	if data.has("appeared"):
		for item in data.appeared:
			var body = _normalize_body(item)
			if not body.is_empty():
				result.appeared.append({"type": "spawn", "params": body})

	# Parse disappeared objects
	if data.has("disappeared"):
		for id in data.disappeared:
			result.disappeared.append({"type": "destroy", "target": str(id)})

	return result
