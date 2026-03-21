## agent_behavior.gd - Physics-Based Agent AI with AWR Integration
## Part of Fantasy Town World-Breaking Demo
##
## Integrates:
## - BDI Model (Beliefs-Desires-Intentions) for goal-directed reasoning
## - Delegation System (Meeseeks pattern) for task escalation
## - Spatial Memory for navigation and location awareness
## - HTN Planner for action decomposition
##
## Goal: 1000+ agents with emergent behavior from physics-first principles

class_name AgentBehavior
extends Node

## Configuration
@export var agent_id: String = ""
@export var max_speed: float = 3.0
@export var wander_radius: float = 20.0
@export var goal_update_interval: float = 5.0  # seconds between goal updates

## AWR Components (loaded at runtime)
var _bdi_model = null
var _delegation = null
var _spatial_memory = null
var _htn_planner = null

## Agent state
var _current_goal: String = ""
var _current_target: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _time_since_goal_update: float = 0.0
var _is_wandering: bool = true
var _visited_locations: Array = []
var _interaction_cooldown: float = 0.0

## Navigation
var _path_points: Array = []
var _current_path_index: int = 0

## Hopping movement
var _hop_timer: float = 0.0
var _hop_interval: float = 0.8  # Time between hops
var _is_grounded: bool = true
var _hop_strength: float = 4.0  # Upward velocity
var _hop_forward_strength: float = 3.0  # Forward velocity during hop

## Signals
signal goal_set(goal: String, target: Vector3)
signal goal_completed(goal: String)
signal interaction_started(with_agent: String, type: String)
signal interaction_ended(with_agent: String)

## References
@onready var _agent_body: RigidBody3D = get_parent()
@onready var _awr: Node = null


func _ready() -> void:
	# Get AWR autoload
	if Engine.has_singleton("AWR"):
		_awr = Engine.get_singleton("AWR")

	_initialize_cognitive_systems()
	_initialize_spatial_awareness()

	# Set initial random goal
	_choose_new_goal()


func _initialize_cognitive_systems() -> void:
	# Load BDI Model
	var BDIModelClass = load("res://addons/awr/cognitive/bdi_model.gd")
	_bdi_model = BDIModelClass.new()

	# Load Delegation System (Meeseeks pattern)
	var DelegationClass = load("res://addons/awr/cognitive/delegation.gd")
	_delegation = DelegationClass.new()

	# Load HTN Planner
	var HTNPlannerClass = load("res://addons/awr/cognitive/htn_planner.gd")
	var HTNDomainClass = load("res://addons/awr/cognitive/htn_domain.gd")
	var domain = HTNDomainClass.create_navigation_domain()
	_htn_planner = HTNPlannerClass.new(domain)

	# Set initial beliefs
	_update_beliefs_from_world()

	print("[Agent %s] Cognitive systems initialized" % agent_id)


func _initialize_spatial_awareness() -> void:
	# Get spatial memory from AWR if available
	if _awr and _awr.has_method("get_spatial_memory"):
		_spatial_memory = _awr.get_spatial_memory()

	# Store self in spatial memory
	if _spatial_memory:
		_spatial_memory.store(
			"agent_%s" % agent_id,
			_agent_body.position,
			{
				"type": "agent",
				"state": "active",
				"current_goal": _current_goal
			}
		)


func _update_beliefs_from_world() -> void:
	if _bdi_model == null:
		return

	# Update beliefs about self
	_bdi_model.believe("position", _agent_body.position, 1.0, "perception")
	_bdi_model.believe("velocity", _agent_body.linear_velocity, 1.0, "perception")
	_bdi_model.believe("is_moving", _agent_body.linear_velocity.length() > 0.5, 0.9, "perception")

	# Update beliefs about environment
	if _spatial_memory:
		var nearby = _spatial_memory.neighbors(_agent_body.position, 10.0)
		_bdi_model.believe("nearby_objects_count", nearby.size(), 0.8, "spatial_memory")

		# Find nearest building
		var nearest_building = _find_nearest_type("building")
		if nearest_building:
			_bdi_model.believe("nearest_building", nearest_building.location, 0.9, "spatial_memory")
			_bdi_model.believe("nearest_building_distance",
				_agent_body.position.distance_to(nearest_building.location), 0.9, "spatial_memory")


func _find_nearest_type(type_tag: String) -> Variant:
	if _spatial_memory == null:
		return null

	var nearby = _spatial_memory.neighbors(_agent_body.position, 50.0)
	var nearest = null
	var nearest_dist = INF

	for node in nearby:
		if node.metadata.get("type") == type_tag:
			var dist = _agent_body.position.distance_to(node.location)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node

	return nearest


func _physics_process(delta: float) -> void:
	_update_beliefs_from_world()
	_update_desires()
	_process_intentions(delta)
	_handle_interactions(delta)

	# Keep agent within bounds and on ground
	_enforce_boundaries()

	_time_since_goal_update += delta
	if _time_since_goal_update >= goal_update_interval:
		_reevaluate_goal()
		_time_since_goal_update = 0.0

	# Update spatial memory with current position
	_update_spatial_memory()


func _enforce_boundaries() -> void:
	if _agent_body == null:
		return

	var pos = _agent_body.position
	var bound = wander_radius - 2.0

	# Keep within XZ bounds
	var clamped = false
	if pos.x < -bound:
		pos.x = -bound
		clamped = true
	elif pos.x > bound:
		pos.x = bound
		clamped = true
	if pos.z < -bound:
		pos.z = -bound
		clamped = true
	elif pos.z > bound:
		pos.z = bound
		clamped = true

	# Keep on ground (Y = 1)
	if pos.y < 0.5:
		pos.y = 1.0
		_agent_body.linear_velocity.y = 0
		clamped = true

	if clamped:
		_agent_body.position = pos
		# Reset velocity if hitting boundary
		_agent_body.linear_velocity.x *= -0.5
		_agent_body.linear_velocity.z *= -0.5


func _update_desires() -> void:
	if _bdi_model == null:
		return

	# Desires based on current state
	var energy = _bdi_model.get_belief("energy", 1.0)

	# If low energy, desire to rest
	if energy < 0.3:
		_bdi_model.desire("rest", 0.9)
		return

	# If wandering, desire to explore
	if _is_wandering:
		_bdi_model.desire("explore", 0.6)
		_bdi_model.desire("socialize", 0.3)
	else:
		# Goal-directed behavior
		_bdi_model.desire(_current_goal, 0.8)


func _process_intentions(delta: float) -> void:
	if _bdi_model == null:
		return

	# Get highest priority desire
	var top_desire = _get_top_desire()
	if top_desire == "":
		return

	# Form intentions based on desire
	match top_desire:
		"explore":
			_process_wandering(delta)
		"rest":
			_process_resting(delta)
		"socialize":
			_process_socializing(delta)
		_:
			_process_goal_directed(delta, top_desire)


func _get_top_desire() -> String:
	if _bdi_model == null or _bdi_model.desires.is_empty():
		return ""

	var top_priority = -1.0
	var top_goal = ""

	for key in _bdi_model.desires:
		var desire = _bdi_model.desires[key]
		if desire.priority > top_priority:
			top_priority = desire.priority
			top_goal = desire.goal

	return top_goal


func _process_wandering(delta: float) -> void:
	_is_wandering = true

	# If no target or reached target, pick new one
	if _current_target == Vector3.ZERO or _agent_body.position.distance_to(_current_target) < 2.0:
		_choose_wander_target()

	# Move toward target
	_move_toward_target(delta)


func _choose_wander_target() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec() + hash(agent_id)

	# Random direction within wander radius
	var angle = rng.randf() * TAU
	var distance = rng.randf_range(5.0, wander_radius)

	var base_pos = _agent_body.position
	var new_target = base_pos + Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)

	# Clamp target within world bounds (prevent falling off edge)
	var world_bound = wander_radius - 5.0  # Stay 5 units from edge
	new_target.x = clamp(new_target.x, -world_bound, world_bound)
	new_target.z = clamp(new_target.z, -world_bound, world_bound)
	new_target.y = 1.0  # Keep at ground level

	_current_target = new_target

	# If spatial memory available, try to find interesting location
	if _spatial_memory:
		var nearby = _spatial_memory.neighbors(_agent_body.position, wander_radius)
		if nearby.size() > 0:
			# Pick a random nearby object to investigate
			var target_node = nearby[rng.randi() % nearby.size()]
			_current_target = target_node.location
			_current_target.y = 1.0  # Keep at ground level

	_visited_locations.append(_current_target)
	if _visited_locations.size() > 50:
		_visited_locations.pop_front()


func _process_resting(delta: float) -> void:
	# Slow down and stop
	_agent_body.linear_velocity = _agent_body.linear_velocity.lerp(Vector3.ZERO, delta * 2.0)

	# Recover energy
	if _bdi_model:
		var energy = _bdi_model.get_belief("energy", 1.0)
		_bdi_model.believe("energy", min(1.0, energy + delta * 0.1), 1.0, "recovery")


func _process_socializing(delta: float) -> void:
	# Find nearby agents
	var nearby_agents = _find_nearby_agents()

	if nearby_agents.is_empty():
		# No agents nearby, continue wandering
		_process_wandering(delta)
		return

	# Pick an agent to interact with
	var target_agent = nearby_agents[0]
	_current_target = target_agent.position

	# Move toward agent
	if _agent_body.position.distance_to(target_agent.position) > 3.0:
		_move_toward_target(delta)
	else:
		# Close enough to interact
		if _interaction_cooldown <= 0:
			_initiate_interaction(target_agent)


func _find_nearby_agents() -> Array:
	var agents = []
	var parent = _agent_body.get_parent()

	if parent:
		for sibling in parent.get_children():
			if sibling != _agent_body and sibling is RigidBody3D:
				if _agent_body.position.distance_to(sibling.position) < 15.0:
					agents.append(sibling)

	return agents


func _initiate_interaction(other_agent: RigidBody3D) -> void:
	var other_name = other_agent.name

	# Random interaction type
	var interaction_types = ["greet", "chat", "trade", "wave"]
	var interaction = interaction_types[randi() % interaction_types.size()]

	interaction_started.emit(other_name, interaction)
	_interaction_cooldown = 3.0  # 3 second cooldown

	# Record in spatial memory
	if _spatial_memory:
		_spatial_memory.store(
			"interaction_%s_%s" % [agent_id, other_name],
			_agent_body.position,
			{"type": "interaction", "with": other_name, "kind": interaction}
		)

	print("[Agent %s] %s with %s" % [agent_id, interaction, other_name])


func _process_goal_directed(delta: float, goal: String) -> void:
	_is_wandering = false

	# Use HTN planner if available
	if _htn_planner:
		var plan = _htn_planner.plan(goal, _get_world_state_for_planning())

		if plan.size() > 0:
			_execute_plan_step(plan[0], delta)
			return

	# Fallback: direct movement toward target
	if _current_target != Vector3.ZERO:
		_move_toward_target(delta)

		# Check if goal reached
		if _agent_body.position.distance_to(_current_target) < 2.0:
			goal_completed.emit(goal)
			_choose_new_goal()


func _get_world_state_for_planning() -> Dictionary:
	return {
		"agent_position": _agent_body.position,
		"agent_velocity": _agent_body.linear_velocity,
		"current_goal": _current_goal,
		"has_target": _current_target != Vector3.ZERO
	}


func _execute_plan_step(step: String, delta: float) -> void:
	match step:
		"approach_target":
			_move_toward_target(delta)
		"stop":
			_agent_body.linear_velocity = _agent_body.linear_velocity.lerp(Vector3.ZERO, delta * 5.0)
		"turn_left", "turn_right":
			_rotate(step == "turn_left", delta)
		_:
			_move_toward_target(delta)


func _rotate(left: bool, delta: float) -> void:
	var axis = Vector3.UP if left else Vector3.DOWN
	_agent_body.angular_velocity = axis * delta * 2.0


func _move_toward_target(delta: float) -> void:
	# Hopping movement - creatures hop instead of smooth gliding
	var direction = (_current_target - _agent_body.position).normalized()
	direction.y = 0  # Keep on ground plane

	# Check if grounded (near y=1)
	_is_grounded = _agent_body.position.y < 1.5

	if _is_grounded:
		_hop_timer += delta

		# Time to hop!
		if _hop_timer >= _hop_interval:
			_hop_timer = 0.0

			# Randomize hop interval slightly for natural feel
			_hop_interval = randf_range(0.6, 1.2)

			# Apply hop velocity - up and forward
			var hop_velocity = Vector3(
				direction.x * _hop_forward_strength,
				_hop_strength,
				direction.z * _hop_forward_strength
			)
			_agent_body.linear_velocity = hop_velocity
	else:
		# In air - let physics handle it (gravity brings us down)
		# Slight air control
		var air_control = 0.5
		_agent_body.linear_velocity.x = lerp(_agent_body.linear_velocity.x, direction.x * max_speed, delta * air_control)
		_agent_body.linear_velocity.z = lerp(_agent_body.linear_velocity.z, direction.z * max_speed, delta * air_control)


func _handle_interactions(delta: float) -> void:
	if _interaction_cooldown > 0:
		_interaction_cooldown -= delta


func _reevaluate_goal() -> void:
	# Check if current goal is still valid
	if _bdi_model:
		var energy = _bdi_model.get_belief("energy", 1.0)

		# Delegation check (Meeseeks pattern)
		if energy < 0.2 and _delegation:
			if _delegation.should_delegate("maintain_energy", 0):
				_delegation.escalate()
				# Spawn subtask to find food/rest
				var subtask = _delegation.spawn_subtask("find_rest_location")
				print("[Agent %s] Delegating at desperation %d" % [agent_id, _delegation.desperation_level])

	# Periodically choose new goal for variety
	if randf() < 0.1:  # 10% chance
		_choose_new_goal()


func _choose_new_goal() -> void:
	var goals = ["explore", "visit_building", "socialize", "rest"]

	# Weight by current state
	if _bdi_model:
		var energy = _bdi_model.get_belief("energy", 1.0)
		if energy < 0.3:
			_current_goal = "rest"
			_is_wandering = false
			goal_set.emit(_current_goal, Vector3.ZERO)
			return

	# Random goal selection
	_current_goal = goals[randi() % goals.size()]

	# Set target based on goal
	match _current_goal:
		"explore":
			_is_wandering = true
			_choose_wander_target()
		"visit_building":
			_set_building_target()
		"socialize":
			_is_wandering = true
		"rest":
			_current_target = _agent_body.position  # Stay in place

	goal_set.emit(_current_goal, _current_target)


func _set_building_target() -> void:
	if _spatial_memory == null:
		_choose_wander_target()
		return

	# Find a building to visit
	var nearby = _spatial_memory.neighbors(_agent_body.position, 50.0)
	var buildings = []

	for node in nearby:
		if node.metadata.get("type") == "building":
			buildings.append(node)

	if buildings.is_empty():
		_choose_wander_target()
		return

	# Pick random building
	var target_building = buildings[randi() % buildings.size()]
	_current_target = target_building.location
	_is_wandering = false


func _update_spatial_memory() -> void:
	if _spatial_memory == null:
		return

	# Update self in spatial memory
	var self_key = "agent_%s" % agent_id
	var existing = _spatial_memory.retrieve_by_concept(self_key)

	if existing:
		existing.location = _agent_body.position
		existing.metadata["current_goal"] = _current_goal
		existing.metadata["is_moving"] = _agent_body.linear_velocity.length() > 0.5
		existing.access_count += 1


## Public API: Set a specific goal
func set_goal(goal_name: String, target: Vector3) -> void:
	_current_goal = goal_name
	_current_target = target
	_is_wandering = false
	goal_set.emit(goal_name, target)


## Public API: Get current cognitive state
func get_cognitive_state() -> Dictionary:
	return {
		"agent_id": agent_id,
		"current_goal": _current_goal,
		"current_target": _current_target,
		"is_wandering": _is_wandering,
		"bdi_beliefs": _bdi_model.beliefs.keys() if _bdi_model else [],
		"desperation": _delegation.desperation_level if _delegation else 1,
		"position": _agent_body.position
	}


## Convert to prompt block for AI
func to_prompt_block() -> String:
	var lines = []
	lines.append("=== AGENT %s ===" % agent_id.to_upper())
	lines.append("Goal: %s" % _current_goal)
	lines.append("Position: (%.1f, %.1f, %.1f)" % [_agent_body.position.x, _agent_body.position.y, _agent_body.position.z])
	lines.append("Mode: %s" % ("wandering" if _is_wandering else "goal-directed"))

	if _bdi_model:
		lines.append("\nBELIEFS:")
		for key in _bdi_model.beliefs:
			var belief = _bdi_model.beliefs[key]
			lines.append("  %s: %s (confidence: %.1f)" % [key, str(belief.value), belief.confidence])

	if _delegation:
		lines.append("\nDESPERATION: %d/5" % _delegation.desperation_level)

	return "\n".join(lines)
