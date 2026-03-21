## PerceptionBridge - Coordinates viewport capture, VLM analysis, and WorldState update
##
## This is the main interface for the perception layer.
## Captures viewports, sends to VLM, parses responses, updates WorldState.
## Also supports direct scene extraction from Godot nodes.
class_name PerceptionBridge
extends RefCounted

# Preload dependencies
const ViewportCaptureClass = preload("res://addons/awr/perception/viewport_capture.gd")
const VLMParserClass = preload("res://addons/awr/perception/vlm_parser.gd")

## Emitted when perception completes
signal perception_completed(bodies_detected: int, confidence: float)
## Emitted when perception fails
signal perception_failed(error: String)
## Emitted when raw VLM response is received
signal vlm_response_received(response: String)

## Target WorldState
var _world_state: Variant = null
## Optional CausalBus for logging
var _causal_bus: Variant = null

## Configuration
var config: Dictionary = {
	"auto_update_world": true,
	"merge_strategy": "update",  # "replace", "update", "merge"
	"confidence_threshold": 0.5,
	"capture_resolution": Vector2i(512, 512),
	"save_debug_images": false,
	"debug_path": "user://perception_debug/",
	# Direct scene extraction settings
	"extract_physics_bodies": true,
	"extract_sprites": true,
	"extract_node_groups": ["perception_target"],
	"position_scale": 1.0
}

## Last perception result
var last_result: Dictionary = {}

## Statistics
var _stats: Dictionary = {
	"total_perceptions": 0,
	"total_bodies_detected": 0,
	"average_confidence": 0.0
}

## Create a new perception bridge
func _init(world_state: Variant = null, causal_bus: Variant = null):
	_world_state = world_state
	_causal_bus = causal_bus

## Set the target world state
func set_world_state(world_state: Variant) -> void:
	_world_state = world_state

## Set the causal bus for logging
func set_causal_bus(causal_bus: Variant) -> void:
	_causal_bus = causal_bus

# ============================================================
# DIRECT SCENE EXTRACTION - Get real data from Godot nodes
# ============================================================

## Extract bodies directly from a scene tree (no VLM needed)
## This gets real physics data from actual game objects
func extract_from_scene(root_node: Node, bounds: Rect2 = Rect2(0, 0, 10000, 10000)) -> Array:
	var bodies: Array = []

	# Extract from physics bodies
	if config.extract_physics_bodies:
		bodies.append_array(_extract_physics_bodies(root_node, bounds))

	# Extract from sprites
	if config.extract_sprites:
		bodies.append_array(_extract_sprites(root_node, bounds))

	# Extract from specific groups
	for group in config.extract_node_groups:
		bodies.append_array(_extract_from_group(root_node, group, bounds))

	# Log to causal bus
	if _causal_bus:
		_causal_bus.record("scene_extracted", {
			"source": root_node.name,
			"bodies_found": bodies.size()
		})

	return bodies

## Extract physics bodies (RigidBody2D, StaticBody2D, CharacterBody2D)
func _extract_physics_bodies(node: Node, bounds: Rect2) -> Array:
	var bodies: Array = []

	for child in node.get_children():
		var body_data = _node_to_body_data(child, bounds)
		if not body_data.is_empty():
			bodies.append(body_data)

		# Recurse into children
		if child.get_child_count() > 0:
			bodies.append_array(_extract_physics_bodies(child, bounds))

	return bodies

## Extract sprites with collision shapes
func _extract_sprites(node: Node, bounds: Rect2) -> Array:
	var bodies: Array = []

	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			var body_data = _sprite_to_body_data(child, bounds)
			if not body_data.is_empty():
				bodies.append(body_data)

		# Recurse
		if child.get_child_count() > 0:
			bodies.append_array(_extract_sprites(child, bounds))

	return bodies

## Extract nodes from a specific group
func _extract_from_group(root: Node, group: String, bounds: Rect2) -> Array:
	var bodies: Array = []
	var nodes = root.get_tree().get_nodes_in_group(group) if root.get_tree() else []

	for node in nodes:
		var body_data = _node_to_body_data(node, bounds)
		if not body_data.is_empty():
			body_data.group = group
			bodies.append(body_data)

	return bodies

## Convert a Godot node to body data dictionary
func _node_to_body_data(node: Node, bounds: Rect2) -> Dictionary:
	var body: Dictionary = {}

	# Check if node has position
	if not ("position" in node):
		return {}

	var pos: Vector2 = node.position * config.position_scale

	# Filter by bounds
	if not bounds.has_point(pos):
		return {}

	body.id = str(node.name)
	body.pos = {"x": pos.x, "y": pos.y}
	body.vel = {"x": 0.0, "y": 0.0}
	body.force = {"x": 0.0, "y": 0.0}

	# Handle physics bodies
	if node is RigidBody2D:
		var rb: RigidBody2D = node
		body.vel = {"x": rb.linear_velocity.x, "y": rb.linear_velocity.y}
		body.mass = rb.mass
		body.static = false

		# Get radius from collision shape
		var shape = _get_collision_radius(rb)
		if shape > 0:
			body.radius = shape

	elif node is StaticBody2D:
		body.mass = 1000.0  # Effectively infinite
		body.static = true
		var shape = _get_collision_radius(node)
		if shape > 0:
			body.radius = shape

	elif node is CharacterBody2D:
		var cb: CharacterBody2D = node
		body.vel = {"x": cb.velocity.x, "y": cb.velocity.y}
		body.mass = 1.0
		body.static = false

	# Apply defaults
	if not body.has("mass"):
		body.mass = 1.0
	if not body.has("radius"):
		body.radius = 10.0
	if not body.has("restitution"):
		body.restitution = 0.8

	return body

## Convert sprite to body data
func _sprite_to_body_data(sprite: Node, bounds: Rect2) -> Dictionary:
	if not ("position" in sprite):
		return {}

	var pos: Vector2 = sprite.position * config.position_scale

	if not bounds.has_point(pos):
		return {}

	var body: Dictionary = {}
	body.id = str(sprite.name)
	body.pos = {"x": pos.x, "y": pos.y}
	body.vel = {"x": 0.0, "y": 0.0}
	body.force = {"x": 0.0, "y": 0.0}
	body.mass = 1.0
	body.restitution = 0.8

	# Estimate radius from sprite size
	if sprite is Sprite2D:
		var texture = sprite.texture
		if texture:
			var size = texture.get_size() * sprite.scale
			body.radius = max(size.x, size.y) / 2.0
		else:
			body.radius = 10.0

	return body

## Get collision radius from a physics body
func _get_collision_radius(body: Node) -> float:
	for child in body.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape is CircleShape2D:
				return shape.radius * child.scale.x
			elif shape is RectangleShape2D:
				var half = shape.size / 2.0
				return max(half.x, half.y) * max(child.scale.x, child.scale.y)
			elif shape is CapsuleShape2D:
				return (shape.radius + shape.height / 2.0) * max(child.scale.x, child.scale.y)
	return 0.0

## Extract and apply to WorldState in one call
func sync_from_scene(root_node: Node, bounds: Rect2 = Rect2(0, 0, 10000, 10000)) -> Dictionary:
	var bodies = extract_from_scene(root_node, bounds)

	# Update statistics
	_stats.total_perceptions += 1
	_stats.total_bodies_detected += bodies.size()
	_stats.average_confidence = 1.0  # Direct extraction is 100% confident

	# Store result
	last_result = {
		"bodies": bodies,
		"confidence": 1.0,
		"timestamp": Time.get_ticks_msec(),
		"source": "direct_extraction"
	}

	# Apply to WorldState
	if config.auto_update_world and _world_state != null:
		_apply_to_world_state(bodies)

	perception_completed.emit(bodies.size(), 1.0)

	return {
		"bodies": bodies,
		"confidence": 1.0,
		"actions": VLMParserClass.to_spawn_actions(bodies)
	}

# ============================================================
# VLM-BASED PERCEPTION (for visual analysis)
# ============================================================

## Capture viewport and prepare for VLM analysis
func capture_and_prepare(viewport: Viewport, prompt: String = "") -> Dictionary:
	if viewport == null:
		perception_failed.emit("Viewport is null")
		return {"error": "Viewport is null"}

	# Capture viewport
	var image = ViewportCaptureClass.capture_viewport(viewport)
	if image.is_empty():
		perception_failed.emit("Failed to capture viewport")
		return {"error": "Failed to capture viewport"}

	# Resize if needed
	var target_res = config.capture_resolution
	if image.get_width() != target_res.x or image.get_height() != target_res.y:
		image.resize(target_res.x, target_res.y)

	# Save to temp file for VLM access
	var temp_path = ViewportCaptureClass.capture_to_temp_file(viewport, "vlm_input.png")
	var global_path = ViewportCaptureClass.get_global_path(temp_path)

	# Build default prompt if not provided
	if prompt.is_empty():
		prompt = VLMParserClass.build_analysis_prompt()

	# Save debug image if enabled
	if config.save_debug_images:
		var debug_path = "%sperception_%d.png" % [config.debug_path, Time.get_ticks_msec()]
		image.save_png(debug_path)

	# Log to causal bus
	if _causal_bus:
		_causal_bus.record("perception_captured", {
			"image_path": global_path,
			"resolution": {"x": image.get_width(), "y": image.get_height()}
		})

	return {
		"image_path": global_path,
		"image": image,
		"prompt": prompt,
		"base64": ViewportCaptureClass.image_to_base64(image)
	}

## Process VLM response and update WorldState
func process_vlm_response(response: String, confidence: float = 1.0) -> Dictionary:
	vlm_response_received.emit(response)

	# Parse response
	var bodies = VLMParserClass.parse_json_response(response)
	if bodies.is_empty():
		# Try text parsing as fallback
		bodies = VLMParserClass.parse_text_response(response)

	if bodies.is_empty():
		perception_failed.emit("Failed to parse VLM response")
		return {"error": "Failed to parse VLM response", "bodies": []}

	# Update statistics
	_stats.total_perceptions += 1
	_stats.total_bodies_detected += bodies.size()
	_stats.average_confidence = (
		(_stats.average_confidence * (_stats.total_perceptions - 1) + confidence)
		/ _stats.total_perceptions
	)

	# Store result
	last_result = {
		"bodies": bodies,
		"confidence": confidence,
		"timestamp": Time.get_ticks_msec(),
		"raw_response": response,
		"source": "vlm"
	}

	# Update WorldState if enabled
	if config.auto_update_world and _world_state != null:
		_apply_to_world_state(bodies)

	# Log to causal bus
	if _causal_bus:
		_causal_bus.record("perception_received", {
			"source": "vlm",
			"objects_detected": bodies.size(),
			"confidence": confidence
		})

	perception_completed.emit(bodies.size(), confidence)

	return {
		"bodies": bodies,
		"confidence": confidence,
		"actions": VLMParserClass.to_spawn_actions(bodies)
	}

## Apply detected bodies to WorldState
func _apply_to_world_state(bodies: Array) -> void:
	if _world_state == null:
		return

	match config.merge_strategy:
		"replace":
			# Clear existing and add all new
			_world_state.bodies.clear()
			for body in bodies:
				_world_state.add_body(body)
		"update":
			# Update existing, add new
			for body in bodies:
				if _world_state.has_body(body.id):
					# Update existing body
					var existing = _world_state.get_body(body.id)
					for key in body.keys():
						existing[key] = body[key]
				else:
					# Add new body
					_world_state.add_body(body)
		"merge":
			# Keep existing, only add truly new
			for body in bodies:
				if not _world_state.has_body(body.id):
					_world_state.add_body(body)

## Track objects between frames
func track_objects(viewport: Viewport, previous_objects: Array) -> Dictionary:
	var prep = capture_and_prepare(viewport)
	if prep.has("error"):
		return prep

	var prompt = VLMParserClass.build_tracking_prompt(previous_objects)
	prep.prompt = prompt

	return prep

## Process tracking response
func process_tracking_response(response: String) -> Dictionary:
	var tracking = VLMParserClass.parse_tracking_response(response)

	# Apply to world state if enabled
	if config.auto_update_world and _world_state != null:
		# Apply moves
		for action in tracking.moved:
			_world_state.apply(action)

		# Apply spawns
		for action in tracking.appeared:
			_world_state.apply(action)

		# Apply destroys
		for action in tracking.disappeared:
			_world_state.apply(action)

	return tracking

## Get perception statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()

## Clear last result
func clear_last_result() -> void:
	last_result.clear()

## Check if perception confidence is above threshold
func is_confident() -> bool:
	return last_result.get("confidence", 0.0) >= config.confidence_threshold

## Get detected bodies from last perception
func get_detected_bodies() -> Array:
	return last_result.get("bodies", [])

## Create a perception bridge for a world state (factory method)
static func create(world_state: Variant, causal_bus: Variant = null) -> Variant:
	var script = load("res://addons/awr/perception/perception_bridge.gd")
	return script.new(world_state, causal_bus)
