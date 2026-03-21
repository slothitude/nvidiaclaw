## agent_behavior.gd - Physics-Based Agent AI with AWR Integration
## Part of Fantasy Town World-Breaking Demo
##
## Integrates:
## - BDI Model (Beliefs-Desires-Intentions) for goal-directed reasoning
## - Delegation System (Meeseeks pattern) for task escalation
## - Spatial Memory for navigation and location awareness
## - HTN Planner for action decomposition
## - Soul System (personality files) for unique agent personalities
## - Ollama Integration for AI-generated thoughts
## - Speech Bubbles for visible communication
##
## Goal: 1000+ agents with emergent behavior from physics-first principles

class_name AgentBehavior
extends Node

## Configuration
@export var agent_id: String = ""
@export var max_speed: float = 3.0
@export var wander_radius: float = 20.0
@export var goal_update_interval: float = 5.0  # seconds between goal updates
@export var thought_interval: float = 8.0  # seconds between AI thoughts

## AWR Components (loaded at runtime)
var _bdi_model = null
var _delegation = null
var _spatial_memory = null
var _htn_planner = null

## Personal Spatial Memory (each agent has their own!)
var _personal_memory = null

## Soul System
var _soul = null

## Ollama Integration
var _ollama_client = null

## Nanobot Orchestrator (for real tool use)
var _nanobot_orchestrator = null

## Speech Bubble
var _speech_bubble = null

## Agent state
var _current_goal: String = ""
var _current_target: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _time_since_goal_update: float = 0.0
var _is_wandering: bool = true
var _visited_locations: Array = []
var _interaction_cooldown: float = 0.0

## Thought system
var _time_since_thought: float = 0.0
var _is_generating_thought: bool = false
var _pending_thought: String = ""

## Navigation
var _path_points: Array = []
var _current_path_index: int = 0

## Hopping movement
var _hop_timer: float = 0.0
var _hop_interval: float = 0.8  # Time between hops
var _is_grounded: bool = true
var _hop_strength: float = 4.0  # Upward velocity
var _hop_forward_strength: float = 3.0  # Forward velocity during hop

## Skills System
var _skills: Dictionary = {}  # skill_name -> {level: int, experience: float, category: String, tools: Array}
var _current_building: String = ""  # Building the agent is currently in
var _learning_progress: float = 0.0  # Progress toward learning a skill

## Work System
var _workplace: String = ""  # Where the agent works
var _job: String = ""  # Agent's job title
var _work_progress: float = 0.0  # Progress at current task
var _is_working: bool = false

## Economy System
var _money: int = 100  # Starting money
var _money_earned: int = 0  # Total earned
var _money_spent: int = 0  # Total spent

## Needs System (agents must spend money on these!)
var _needs: Dictionary = {
	"hunger": 100.0,      # Decreases over time, buy food at tavern
	"energy": 100.0,      # Decreases with work, rest at tavern/home
	"comfort": 100.0,     # Decreases over time, buy comfort items
	"social": 100.0,      # Decreases when lonely, socialize or drink at tavern
	"knowledge": 100.0,   # Decreases over time, visit library/university
}
var _need_decay_rates: Dictionary = {
	"hunger": 0.5,      # Per second - gets hungry
	"energy": 0.3,      # Gets tired
	"comfort": 0.2,     # Wants comfort
	"social": 0.4,      # Gets lonely
	"knowledge": 0.1,   # Forgets things
}
var _critical_need_threshold: float = 30.0  # Below this, agent seeks to fulfill need
var _needs_check_interval: float = 5.0  # Seconds between need updates
var _time_since_needs_check: float = 0.0

## Task System with Rewards
var _available_tasks: Array = []  # Tasks agent can accept
var _task_rewards: Dictionary = {}  # task_name -> gold_reward

## Todo List System
var _todo_list: Array = []  # Array of {task: String, priority: int, status: String, created: float, reward: int}
var _max_todo_items: int = 10

## Teaching System
var _teaching_cooldown: float = 0.0
var _skills_taught: Array = []  # Skills this agent has taught to others
var _skills_learned_from_others: Array = []  # Skills learned from other agents

## Evolution/Life-Death System
var _generation: int = 1
var _parent_id: String = ""
var _failed_tasks: Array = []  # Tasks this agent failed
var _consecutive_failures: int = 0
var _completed_tasks_count: int = 0
var _time_since_last_success: float = 0.0
var _is_dead: bool = false
var _death_cause: String = ""
var _inherited_skills: Dictionary = {}  # Skills inherited from parent

## Task Sources (where to get tasks)
var _known_task_sources: Array = [
	"Grand Computer",
	"Temple",
	"Task Board"
]

## Bash/API Access
var _bridge_url: String = "http://localhost:8000"  # SSH AI Bridge URL
var _http_bash: HTTPRequest = null
var _bash_cooldown: float = 0.0

## Signals
signal goal_set(goal: String, target: Vector3)
signal goal_completed(goal: String)
signal interaction_started(with_agent: String, type: String)
signal interaction_ended(with_agent: String)
signal thought_spoken(agent_id: String, thought: String)

## References
@onready var _agent_body: RigidBody3D = get_parent()
@onready var _awr: Node = null


func _ready() -> void:
	# Get AWR autoload
	if Engine.has_singleton("AWR"):
		_awr = Engine.get_singleton("AWR")

	_initialize_cognitive_systems()
	_initialize_spatial_awareness()
	_initialize_soul()
	_initialize_speech_bubble()

	# Connect to Ollama client (set by fantasy_town.gd)
	# This will be set externally, but we check in _process

	# Set initial random goal
	_choose_new_goal()

	# Initial thought after a short delay
	_time_since_thought = randf_range(2.0, 5.0)


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

	# Initialize personal spatial memory
	var SpatialMemoryClass = load("res://addons/awr/spatial/spatial_memory.gd")
	_personal_memory = SpatialMemoryClass.new(3.0)  # Smaller cell size for personal memory

	# Try to load saved personal memory
	var memory_path = "user://agent_memories/agent_%s_memory.json" % agent_id
	if FileAccess.file_exists(memory_path):
		var loaded = SpatialMemoryClass.load_from(memory_path)
		if loaded:
			_personal_memory = loaded
			print("[Agent %s] Loaded personal memory with %d nodes" % [agent_id, _personal_memory.size()])

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

	# Store self in personal memory
	_personal_memory.store(
		"self",
		_agent_body.position,
		{
			"type": "self",
			"agent_id": agent_id
		}
	)


func _initialize_soul() -> void:
	var SoulClass = load("res://scenes/fantasy_town/agent_soul.gd")
	_soul = SoulClass.new(agent_id)
	_soul.load_or_create()

	# Assign workplace based on personality
	_assign_workplace()

	print("[Agent %s] Soul loaded: %s" % [agent_id, _soul.personality])


func _assign_workplace() -> void:
	# Match personality to job
	var personality_lower = _soul.personality.to_lower()

	if "wise" in personality_lower or "elder" in personality_lower:
		_job = "Scholar"
		_workplace = "library"
	elif "guardian" in personality_lower or "brave" in personality_lower:
		_job = "Guard"
		_workplace = "guard_post"
	elif "healer" in personality_lower or "gentle" in personality_lower:
		_job = "Healer"
		_workplace = "temple"
	elif "poet" in personality_lower or "dreamy" in personality_lower:
		_job = "Bard"
		_workplace = "tavern"
	elif "social" in personality_lower or "butterfly" in personality_lower:
		_job = "Merchant"
		_workplace = "market"
	elif "prankster" in personality_lower or "playful" in personality_lower:
		_job = "Entertainer"
		_workplace = "tavern"
	elif "learner" in personality_lower or "eager" in personality_lower:
		_job = "Student"
		_workplace = "university"
	elif "curious" in personality_lower or "explorer" in personality_lower:
		_job = "Explorer"
		_workplace = "library"
	elif "grumpy" in personality_lower or "wanderer" in personality_lower:
		_job = "Wanderer"
		_workplace = "garden"
	else:  # shy_observer or default
		_job = "Observer"
		_workplace = "garden"

	print("[Agent %s] Assigned job: %s at %s" % [agent_id, _job, _workplace])


func _initialize_speech_bubble() -> void:
	# Load speech bubble scene
	var speech_bubble_scene = load("res://scenes/fantasy_town/speech_bubble.tscn")
	if speech_bubble_scene:
		_speech_bubble = speech_bubble_scene.instantiate()
		# Use call_deferred to avoid "parent busy" error
		_agent_body.call_deferred("add_child", _speech_bubble)


func _is_speech_bubble_ready() -> bool:
	return _speech_bubble != null and is_instance_valid(_speech_bubble) and _speech_bubble.has_method("is_showing")


func set_ollama_client(client: Node) -> void:
	_ollama_client = client
	if _ollama_client:
		# Connect to thought generation signal
		if not _ollama_client.thought_generated.is_connected(_on_thought_generated):
			_ollama_client.thought_generated.connect(_on_thought_generated)


func set_nanobot_orchestrator(orchestrator: Node) -> void:
	_nanobot_orchestrator = orchestrator
	if _nanobot_orchestrator:
		# Connect to response signal
		if not _nanobot_orchestrator.agent_response.is_connected(_on_nanobot_response):
			_nanobot_orchestrator.agent_response.connect(_on_nanobot_response)

		# Spawn this agent in the orchestrator
		var personality = {}
		if _soul:
			personality = {
				"personality": _soul.personality,
				"traits": _soul.traits
			}
		_nanobot_orchestrator.spawn_agent(agent_id, personality)
		print("[Agent %s] Connected to Nanobot Orchestrator" % agent_id)


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

	# Update soul mood based on state
	if _soul:
		var energy = _bdi_model.get_belief("energy", 1.0)
		_soul.mood["energy"] = energy


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
	_process_thoughts(delta)
	_update_needs(delta)

	# Keep agent within bounds and on ground
	_enforce_boundaries()

	_time_since_goal_update += delta
	if _time_since_goal_update >= goal_update_interval:
		_reevaluate_goal()
		_time_since_goal_update = 0.0

	# Update spatial memory with current position
	_update_spatial_memory()


## Update needs over time
func _update_needs(delta: float) -> void:
	_time_since_needs_check += delta

	if _time_since_needs_check >= _needs_check_interval:
		_time_since_needs_check = 0.0

		# Decay all needs
		for need_name in _needs.keys():
			var decay = _need_decay_rates.get(need_name, 0.1) * _needs_check_interval
			_needs[need_name] = max(0.0, _needs[need_name] - decay)

			# Check for critical needs
			if _needs[need_name] < _critical_need_threshold:
				_handle_critical_need(need_name)


## Handle a critical need - agent must spend money or take action
func _handle_critical_need(need_name: String) -> void:
	match need_name:
		"hunger":
			# Need food - go to tavern and buy meal
			if _money >= 5:
				_set_building_target_by_type("tavern")
				print("[Agent %s] Hungry! Going to tavern for food. (Money: %d)" % [agent_id, _money])
			else:
				print("[Agent %s] STARVING! No money for food! (Money: %d)" % [agent_id, _money])
				# Must work urgently!
				_choose_new_goal()

		"energy":
			# Need rest - go to tavern or home
			if _money >= 2:
				_set_building_target_by_type("tavern")
				print("[Agent %s] Tired! Going to rest. (Money: %d)" % [agent_id, _money])
			else:
				# Can rest for free at home
				_set_building_target_by_type("home")

		"comfort":
			# Need comfort items
			if _money >= 10:
				_set_building_target_by_type("market")
				print("[Agent %s] Uncomfortable! Going to market. (Money: %d)" % [agent_id, _money])

		"social":
			# Need social interaction - go to tavern or find agents
			if _money >= 2:
				_set_building_target_by_type("tavern")
				print("[Agent %s] Lonely! Going to tavern for socializing. (Money: %d)" % [agent_id, _money])
			else:
				# Socialize for free by finding other agents
				_is_wandering = true

		"knowledge":
			# Need to learn - go to library
			_set_building_target_by_type("library")
			print("[Agent %s] Forgetting things! Going to library. (Money: %d)" % [agent_id, _money])


## Fulfill need at a building (called when agent arrives at building)
func fulfill_need_at_building(need_name: String, building_type: String) -> bool:
	var costs := {
		"hunger": {"tavern": 5},       # Meal at tavern
		"energy": {"tavern": 2, "home": 0},  # Rest
		"comfort": {"market": 10},     # Buy comfort items
		"social": {"tavern": 2},       # Drink at tavern
		"knowledge": {"library": 0, "university": 0},  # Free to learn
	}

	if not costs.has(need_name):
		return false

	var need_costs = costs[need_name]
	if not need_costs.has(building_type):
		return false

	var cost = need_costs[building_type]

	# Check if can afford
	if _money < cost:
		print("[Agent %s] Cannot afford %s at %s (need %d, have %d)" % [agent_id, need_name, building_type, cost, _money])
		return false

	# Spend money
	if cost > 0:
		spend_money(cost, "%s at %s" % [need_name, building_type])

	# Fulfill need
	_needs[need_name] = min(100.0, _needs[need_name] + 50.0)
	print("[Agent %s] Fulfilled %s at %s (cost: %d)" % [agent_id, need_name, building_type, cost])

	if _soul:
		_soul.update_mood("discovery", 0.1)  # Feeling better

	return true


## Get current needs status
func get_needs() -> Dictionary:
	return _needs.duplicate()


## Get most critical need
func get_critical_need() -> String:
	var lowest_value = 100.0
	var lowest_need = ""

	for need_name in _needs.keys():
		if _needs[need_name] < lowest_value:
			lowest_value = _needs[need_name]
			lowest_need = need_name

	if lowest_value < _critical_need_threshold:
		return lowest_need
	return ""


func _process_thoughts(delta: float) -> void:
	_time_since_thought += delta

	# Generate a new thought periodically
	if _time_since_thought >= thought_interval and not _is_generating_thought:
		if not _is_speech_bubble_ready() or not _speech_bubble.is_showing():
			_request_thought()
			_time_since_thought = 0.0
			# Add some randomness to next thought time
			thought_interval = randf_range(6.0, 12.0)


func _request_thought() -> void:
	# Priority 1: Use Nanobot Orchestrator (real tool use)
	if _nanobot_orchestrator:
		_is_generating_thought = true

		# Build context for thought generation
		var context = _build_thought_context()
		context["skills"] = _skills.keys()
		context["money"] = _money
		context["needs"] = _needs

		# Build thought prompt
		var prompt = _build_nanobot_prompt()

		_nanobot_orchestrator.send_message(agent_id, prompt, context)
		print("[Agent %s] Requesting nanobot thought..." % agent_id)
		return

	# Priority 2: Use Ollama client (fallback)
	if _ollama_client and _soul:
		_is_generating_thought = true

		# Build context for thought generation
		var context = _build_thought_context()

		# Request thought from Ollama
		_ollama_client.generate_thought(agent_id, _soul.to_prompt_data(), context)
		print("[Agent %s] Requesting AI thought..." % agent_id)
	else:
		# Fallback: use a pre-defined thought from soul personality
		print("[Agent %s] Using fallback thought (no Ollama/soul)" % agent_id)
		_show_fallback_thought()


## Build prompt for nanobot
func _build_nanobot_prompt() -> String:
	var prompt := ""

	# Add personality context
	if _soul:
		prompt += "As a %s agent, " % _soul.personality.replace("_", " ")

	# Add current state
	if _is_wandering:
		prompt += "I'm exploring the town. "
	else:
		prompt += "I'm heading to %s. " % _current_goal

	# Add needs context
	var critical = get_critical_need()
	if critical != "":
		prompt += "I need %s urgently! " % critical

	# Add skills context
	if _skills.size() > 0:
		prompt += "I have skills: %s. " % ", ".join(_skills.keys())

	# Request thought
	prompt += "What should I think about or do next? Keep response brief."

	return prompt


## Execute a tool via nanobot orchestrator
func execute_tool_via_nanobot(tool_name: String, params: Dictionary = {}) -> void:
	if not _nanobot_orchestrator:
		push_warning("[Agent %s] No nanobot orchestrator for tool execution" % agent_id)
		return

	print("[Agent %s] Executing tool: %s" % [agent_id, tool_name])
	_nanobot_orchestrator.execute_tool(agent_id, tool_name, params)


func _build_thought_context() -> Dictionary:
	var nearby_objects = []

	if _spatial_memory:
		var nearby = _spatial_memory.neighbors(_agent_body.position, 15.0)
		for node in nearby.slice(0, 5):
			nearby_objects.append({
				"type": node.metadata.get("type", "unknown"),
				"concept": node.concept,
				"distance": _agent_body.position.distance_to(node.location)
			})

	return {
		"current_goal": _current_goal,
		"position": _agent_body.position,
		"is_wandering": _is_wandering,
		"nearby_objects": nearby_objects,
		"visited_count": _visited_locations.size()
	}


func _on_thought_generated(gen_agent_id: String, thought: String) -> void:
	if gen_agent_id != agent_id:
		return

	print("[Agent %s] Received thought: %s" % [agent_id, thought])
	_is_generating_thought = false
	_pending_thought = thought
	_show_thought(thought)


## Handle response from Nanobot Orchestrator
func _on_nanobot_response(response_agent_id: String, response: String) -> void:
	if response_agent_id != agent_id:
		return

	print("[Agent %s] Received nanobot response: %s" % [agent_id, response.left(100)])
	_is_generating_thought = false

	# Show response as thought
	_show_thought(response)

	# Check if this was a tool execution result
	if response.begins_with("Tool executed:") or "executed successfully" in response.to_lower():
		print("[Agent %s] Tool execution complete" % agent_id)


func _show_fallback_thought() -> void:
	if _soul:
		# Generate a simple thought based on current state
		var thoughts = [
			"Exploring the town...",
			"Where should I go next?",
			"This is a nice place.",
			"I wonder what's over there..."
		]
		_show_thought(thoughts[randi() % thoughts.size()])


func _show_thought(text: String) -> void:
	print("[Agent %s] Showing thought: %s" % [agent_id, text])
	if _is_speech_bubble_ready():
		var mood = _get_mood_string()
		_speech_bubble.show_text_with_mood(text, mood)
		thought_spoken.emit(agent_id, text)

		# Record this as a memory
		if _soul:
			_soul.add_memory("Thought: %s" % text)
	else:
		print("[Agent %s] Speech bubble not ready!" % agent_id)


func _get_mood_string() -> String:
	if not _soul:
		return "happy"

	var mood = _soul.mood
	var happiness = mood.get("happiness", 0.5)
	var energy = mood.get("energy", 0.5)
	var curiosity = mood.get("curiosity", 0.5)

	if happiness > 0.8:
		return "excited"
	elif happiness > 0.6:
		return "happy"
	elif energy < 0.3:
		return "tired"
	elif curiosity > 0.8:
		return "curious"
	elif happiness < 0.4:
		return "sad"
	else:
		return "thoughtful"


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

			# Record discovery in soul
			if _soul:
				_soul.add_discovery(target_node.concept, target_node.location)

	_visited_locations.append(_current_target)
	if _visited_locations.size() > 50:
		_visited_locations.pop_front()

	# Store in personal memory
	if _personal_memory:
		_personal_memory.store(
			"visited_%d" % Time.get_ticks_msec(),
			_current_target,
			{"type": "visited_location", "goal": _current_goal}
		)


func _process_resting(delta: float) -> void:
	# Slow down and stop
	_agent_body.linear_velocity = _agent_body.linear_velocity.lerp(Vector3.ZERO, delta * 2.0)

	# Recover energy
	if _bdi_model:
		var energy = _bdi_model.get_belief("energy", 1.0)
		_bdi_model.believe("energy", min(1.0, energy + delta * 0.1), 1.0, "recovery")

		if _soul:
			_soul.update_mood("rest", delta * 0.1)


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

	# Get other agent's behavior component
	var other_behavior = null
	for child in other_agent.get_children():
		if child is AgentBehavior:
			other_behavior = child
			break

	# Choose interaction type based on skills and context
	var interaction_types = ["greet", "chat", "wave"]
	var interaction = interaction_types[randi() % interaction_types.size()]

	# Check for teaching opportunity
	if other_behavior and _teaching_cooldown <= 0 and _skills.size() > 0:
		# Can I teach them something?
		for skill_name in _skills.keys():
			if _skills[skill_name].get("level", 1) >= 2:
				if not other_behavior._skills.has(skill_name):
					interaction = "teach"
					# Try to teach
					if teach_skill_to(other_behavior, skill_name):
						break

	# Check for trading opportunity
	if other_behavior and interaction != "teach":
		# Trade if both have skills to offer
		if _skills.size() > 0 and other_behavior._skills.size() > 0:
			if randf() < 0.2:  # 20% chance to trade
				interaction = "trade"
				_perform_skill_trade(other_behavior)

	interaction_started.emit(other_name, interaction)
	_interaction_cooldown = 5.0  # 5 second cooldown for conversations

	# Record in spatial memory
	if _spatial_memory:
		_spatial_memory.store(
			"interaction_%s_%s" % [agent_id, other_name],
			_agent_body.position,
			{"type": "interaction", "with": other_name, "kind": interaction}
		)

	# Record in personal memory
	if _personal_memory:
		_personal_memory.store(
			"met_%s" % other_name,
			_agent_body.position,
			{"type": "agent_interaction", "with": other_name, "kind": interaction}
		)

	# Record in soul and start conversation
	if _soul:
		_soul.add_met_agent(other_name, _agent_body.position)
		_soul.update_mood("met_friend", 0.1)

		# Generate conversation based on personality
		_start_conversation(other_agent, interaction)

	print("[Agent %s] %s with %s" % [agent_id, interaction, other_name])


## Perform skill trade with another agent
func _perform_skill_trade(other_behavior: AgentBehavior) -> void:
	# Find a skill I have that they don't, and vice versa
	var my_unique_skills = []
	var their_unique_skills = []

	for skill in _skills.keys():
		if not other_behavior._skills.has(skill):
			my_unique_skills.append(skill)

	for skill in other_behavior._skills.keys():
		if not _skills.has(skill):
			their_unique_skills.append(skill)

	if my_unique_skills.size() > 0 and their_unique_skills.size() > 0:
		# Trade!
		var my_offer = my_unique_skills[randi() % my_unique_skills.size()]
		var their_offer = their_unique_skills[randi() % their_unique_skills.size()]

		# Both agents gain knowledge of the other's skill (level 1)
		_skills[their_offer] = {"level": 1, "experience": 5, "category": "traded"}
		other_behavior._skills[my_offer] = {"level": 1, "experience": 5, "category": "traded"}

		# Both earn a bit of money from knowledge exchange
		earn_money(3, "skill trade with agent_%s" % other_behavior.agent_id)
		other_behavior.earn_money(3, "skill trade with agent_%s" % agent_id)

		print("[Agent %s] Traded %s for %s with Agent %s" % [agent_id, my_offer, their_offer, other_behavior.agent_id])

		if _soul:
			_soul.add_memory("Traded %s for %s with agent_%s" % [my_offer, their_offer, other_behavior.agent_id])
	else:
		print("[Agent %s] No compatible skills to trade with Agent %s" % [agent_id, other_behavior.agent_id])


func _start_conversation(other_agent: RigidBody3D, interaction_type: String) -> void:
	if not _is_speech_bubble_ready() or _speech_bubble.is_showing():
		return

	# Get other agent's behavior
	var other_behavior = null
	for child in other_agent.get_children():
		if child is AgentBehavior:
			other_behavior = child
			break

	# Generate dialogue based on both personalities
	var my_personality = _soul.personality if _soul else "friendly"
	var other_personality = "someone"
	if other_behavior and other_behavior._soul:
		other_personality = other_behavior._soul.personality

	# Conversation templates based on personality type
	var dialogue = _generate_dialogue(interaction_type, my_personality, other_personality)
	_show_chat(dialogue)

	# If other agent has behavior, make them respond
	if other_behavior and other_behavior._speech_bubble:
		if not other_behavior._speech_bubble.is_showing():
			# Delayed response
			await get_tree().create_timer(1.5).timeout
			var response = _generate_response(my_personality, other_behavior._soul.personality if other_behavior._soul else "friendly")
			other_behavior._show_chat(response)


func _generate_dialogue(interaction: String, my_personality: String, other_personality: String) -> String:
	var greetings = {
		"curious_explorer": ["Hi! What's over there?", "Hello! Exploring?", "Hey! Found anything cool?"],
		"shy_observer": ["Um... hi...", "H-hello...", "...hi there..."],
		"social_butterfly": ["HEY! So good to see you!", "Hi friend! How are you?!", "Hello hello!!"],
		"grumpy_wanderer": ["Hmph... hi.", "...greetings.", "Bah, hello I suppose."],
		"dreamy_poet": ["Oh, hello beautiful soul...", "Greetings, fellow wanderer...", "The stars brought us together!"],
		"brave_guardian": ["Greetings, citizen!", "Hail, friend!", "Well met!"],
		"playful_prankster": ["Hehe, peekaboo!", "Gotcha! Hi!", "Surprise! Hello!"],
		"wise_elder": ["Greetings, young one.", "Ah, hello there.", "Welcome, friend."],
		"eager_learner": ["Hi! Can I ask you something?", "Hello! What do you know?", "Hi! Teach me something!"],
		"gentle_healer": ["Hello, dear one.", "Blessings to you.", "Warm greetings, friend."],
		"default": ["Hello!", "Hi there!", "Hey!"]
	}

	var personality_lower = my_personality.to_lower()
	for key in greetings.keys():
		if key in personality_lower or personality_lower in key:
			var options = greetings[key]
			return options[randi() % options.size()]

	var default = greetings["default"]
	return default[randi() % default.size()]


func _generate_response(my_personality: String, other_personality: String) -> String:
	var responses = {
		"curious_explorer": ["Oh wow, me too!", "Let's explore together!", "Cool! See you around!"],
		"shy_observer": ["...nice to meet you...", "okay... bye...", "um... sure..."],
		"social_butterfly": ["Yay new friend!!", "This is awesome!", "Let's hang out more!"],
		"grumpy_wanderer": ["Hmph... sure.", "Whatever...", "Don't get in my way."],
		"dreamy_poet": ["What a lovely meeting...", "Until we meet again...", "Safe travels, friend..."],
		"brave_guardian": ["Farewell, ally!", "Stay safe!", "Until next time!"],
		"playful_prankster": ["Hehe, bye!", "Catch you later!", "Toodles!"],
		"wise_elder": ["Go well, young one.", "May fortune guide you.", "Until we meet again."],
		"eager_learner": ["Thanks! Bye!", "Cool! See ya!", "I learned so much!"],
		"gentle_healer": ["Be well, friend.", "May peace be with you.", "Take care, dear one."],
		"default": ["Bye!", "See you!", "Take care!"]
	}

	var personality_lower = other_personality.to_lower()
	for key in responses.keys():
		if key in personality_lower or personality_lower in key:
			var options = responses[key]
			return options[randi() % options.size()]

	var default = responses["default"]
	return default[randi() % default.size()]


func _show_chat(text: String) -> void:
	if _is_speech_bubble_ready():
		_speech_bubble.show_text_with_mood(text, "chat")
		thought_spoken.emit(agent_id, text)

		if _soul:
			_soul.add_memory("Chat: %s" % text)


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

			# Record reaching goal in soul
			if _soul:
				_soul.add_memory("Reached goal: %s" % goal)
				_soul.update_mood("discovery", 0.05)

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
	if _teaching_cooldown > 0:
		_teaching_cooldown -= delta
	if _bash_cooldown > 0:
		_bash_cooldown -= delta


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
	var goals = ["explore", "visit_building", "socialize", "rest", "work", "learn", "pray"]

	# Weight by current state
	if _bdi_model:
		var energy = _bdi_model.get_belief("energy", 1.0)
		if energy < 0.3:
			_current_goal = "rest"
			_is_wandering = false
			goal_set.emit(_current_goal, Vector3.ZERO)
			return

	# Skill-based task routing - prefer goals that match skills
	var weighted_goals = []
	for goal in goals:
		var weight = 1.0

		# Boost goals that match agent's skills
		match goal:
			"work":
				if _skills.size() > 0:
					weight += _skills.size() * 0.5  # More skills = more likely to work
				if _money < 50:
					weight += 2.0  # Need money = work more
			"learn":
				if _skills.size() < 3:
					weight += 1.5  # Few skills = should learn
				if _money >= 50:
					weight += 0.5  # Can afford learning
			"socialize":
				if _skills.size() > 2:
					weight += 1.0  # Can teach others
			"explore":
				if _soul and _soul.traits.has("curious"):
					weight += 1.5
			"pray":
				weight += 0.3  # Base chance to pray
				if _soul and _soul.traits.has("pious"):
					weight += 1.0  # Religious agents pray more
				# Pray more when needs are low
				for need_name in _needs.keys():
					if _needs[need_name] < 50:
						weight += 0.2

		for i in range(int(weight * 10)):
			weighted_goals.append(goal)

	# Random weighted selection
	_current_goal = weighted_goals[randi() % weighted_goals.size()]

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
		"work":
			_set_work_target()
		"learn":
			_set_learning_target()
		"pray":
			_set_prayer_target()

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

	# Update personal memory too
	if _personal_memory:
		var self_node = _personal_memory.retrieve_by_concept("self")
		if self_node:
			self_node.location = _agent_body.position


## Todo List System
func add_todo(task: String, priority: int = 5) -> void:
	if _todo_list.size() >= _max_todo_items:
		# Remove lowest priority item
		_todo_list.sort_custom(func(a, b): return a.priority > b.priority)
		_todo_list.pop_back()

	_todo_list.append({
		"task": task,
		"priority": priority,
		"status": "pending",
		"created": Time.get_ticks_msec() / 1000.0
	})
	print("[Agent %s] Added todo: %s (priority %d)" % [agent_id, task, priority])


func complete_todo(task_index: int) -> void:
	if task_index >= 0 and task_index < _todo_list.size():
		_todo_list[task_index]["status"] = "completed"
		var task = _todo_list[task_index]["task"]
		print("[Agent %s] Completed todo: %s" % [agent_id, task])
		# Add to memory
		if _soul:
			_soul.add_memory("Completed task: %s" % task)


func get_next_todo() -> Dictionary:
	if _todo_list.is_empty():
		return {}
	# Sort by priority (higher first), then by creation time
	_todo_list.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.created < b.created
	)
	for todo in _todo_list:
		if todo.status == "pending":
			return todo
	return {}


## ═══════════════════════════════════════════════════════════════════════════════
## EVOLUTION SYSTEM - Life, Death, and Rebirth
## ═══════════════════════════════════════════════════════════════════════════════

## Mark a task as failed (triggers death check)
func fail_task(task: String, reason: String = "unknown") -> void:
	_failed_tasks.append({
		"task": task,
		"reason": reason,
		"time": Time.get_unix_time_from_system()
	})
	_consecutive_failures += 1

	print("[Agent %s] ❌ Task failed: '%s' (Reason: %s)" % [agent_id, task.left(50), reason])
	_show_thought("I failed at: %s... This is troubling." % task.left(40))

	# Check if agent should die
	var evolution = _get_evolution_system()
	if evolution:
		var time_since_success = _time_since_last_success if _completed_tasks_count > 0 else 999.0
		if evolution.check_agent_death(agent_id, _failed_tasks.size(), _consecutive_failures, time_since_success):
			die("Failed tasks: %d, Consecutive: %d" % [_failed_tasks.size(), _consecutive_failures])


## Mark a task as completed (resets failure counter)
func succeed_task(task: String, reward: int = 0) -> void:
	_completed_tasks_count += 1
	_consecutive_failures = 0
	_time_since_last_success = 0.0

	if reward > 0:
		earn_money(reward)

	print("[Agent %s] ✅ Task succeeded: '%s' (Total: %d)" % [agent_id, task.left(50), _completed_tasks_count])

	# Store in soul memory
	if _soul:
		_soul.add_memory("Successfully completed: %s" % task)


## Agent dies and goes to graveyard
func die(cause: String = "unknown") -> void:
	if _is_dead:
		return

	_is_dead = true
	_death_cause = cause

	print("\n[Agent %s] ☠️ DYING: %s" % [agent_id, cause])
	_show_thought("I have failed... My journey ends here.")

	# Prepare data for evolution
	var agent_data = {
		"generation": _generation,
		"failed_tasks": _failed_tasks,
		"completed_tasks": _completed_tasks_count,
		"skills": _skills.duplicate(),
		"personality": {
			"personality": _soul.personality if _soul else "unknown",
			"traits": _soul.traits if _soul else []
		},
		"success_rate": float(_completed_tasks_count) / max(1.0, float(_completed_tasks_count + _failed_tasks.size())),
		"death_cause": cause
	}

	# Notify evolution system
	var evolution = _get_evolution_system()
	if evolution:
		evolution.agent_dies(agent_id, agent_data)

	# Go to graveyard visually
	if _agent_body:
		_agent_body.position = Vector3(-30, 0, -30)  # Graveyard position
		_agent_body.freeze = true

	# Hide speech bubble
	if _speech_bubble:
		_speech_bubble.hide()


## Get the evolution system
func _get_evolution_system():
	return get_node_or_null("/root/AgentEvolution")


## Set inherited traits from parent (called on birth)
func set_inherited_traits(parent_id: String, generation: int, inherited_skills: Dictionary, improved_prompt: String) -> void:
	_parent_id = parent_id
	_generation = generation
	_inherited_skills = inherited_skills.duplicate()

	# Add inherited skills (these start at higher levels)
	for skill_name in inherited_skills.keys():
		var skill_data = inherited_skills[skill_name]
		_skills[skill_name] = {
			"level": skill_data.get("level", 1),
			"experience": skill_data.get("experience", 25),
			"category": _get_skill_category(skill_name),
			"tools": _get_skill_tools(skill_name),
			"source": "inherited"
		}

	print("[Agent %s] Born as Generation %d (Parent: %s)" % [agent_id, generation, parent_id])
	print("[Agent %s] Inherited %d skills: %s" % [agent_id, inherited_skills.size(), str(inherited_skills.keys())])

	# Update soul with generation info
	if _soul:
		_soul.generation = generation
		_soul.parent_id = parent_id


## Go to a task source to get tasks
func goto_task_source() -> void:
	# Pick the nearest known task source
	var best_source = ""
	var best_dist = INF

	for source_name in _known_task_sources:
		var loc = _get_shared_location_memory().get_location(source_name) if _get_shared_location_memory() else {}
		if not loc.is_empty():
			var dist = _agent_body.position.distance_to(loc.position)
			if dist < best_dist:
				best_dist = dist
				best_source = source_name

	if not best_source.is_empty():
		goto(best_source)
		_show_thought("I need work. Heading to %s..." % best_source)
	else:
		# Default to Grand Computer
		goto("Grand Computer")


## Bash Execution System (via SSH AI Bridge)
func execute_bash(command: String) -> void:
	if _bash_cooldown > 0:
		print("[Agent %s] Bash on cooldown: %.1fs" % [agent_id, _bash_cooldown])
		return

	if not _http_bash:
		_http_bash = HTTPRequest.new()
		add_child(_http_bash)
		_http_bash.request_completed.connect(_on_bash_response)

	var url = _bridge_url + "/api/v1/execute"
	var body = JSON.stringify({
		"command": command,
		"session_id": "agent_%s_session" % agent_id
	})

	var error = _http_bash.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		print("[Agent %s] Bash request failed: error %s" % [agent_id, error])
	else:
		_bash_cooldown = 5.0  # 5 second cooldown
		print("[Agent %s] Executing bash: %s" % [agent_id, command])


func _on_bash_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[Agent %s] Bash response error: result=%s code=%s" % [agent_id, result, response_code])
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var data = json.data
		var output = data.get("output", "")
		print("[Agent %s] Bash output: %s" % [agent_id, output.left(200)])

		# Add to memory
		if _soul:
			_soul.add_memory("Bash command output: %s" % output.left(100))


## SearXNG Web Search (via library)
func web_search(query: String) -> void:
	if _ollama_client and _ollama_client.is_search_available():
		_ollama_client.web_search(agent_id, query)
		print("[Agent %s] Searching web: %s" % [agent_id, query])
	else:
		print("[Agent %s] Web search not available (need to visit library)" % agent_id)


## Visit building with purpose
func visit_building(building_name: String, purpose: String) -> void:
	_current_building = building_name
	print("[Agent %s] Visiting %s for %s" % [agent_id, building_name, purpose])

	# Add to memory
	if _soul:
		_soul.add_memory("Visited %s for %s" % [building_name, purpose])

	# Check if this building offers the service
	# This would be populated from fantasy_town.gd


## Learn skill at university
func learn_skill(skill_name: String, skill_data: Dictionary = {}) -> void:
	if _current_building != "university":
		print("[Agent %s] Must be at university to learn skills" % agent_id)
		return

	# Check prerequisites
	var prerequisites = skill_data.get("prerequisites", [])
	for prereq in prerequisites:
		if not _skills.has(prereq):
			print("[Agent %s] Missing prerequisite: %s" % [agent_id, prereq])
			return

	# Check cost
	var cost = skill_data.get("cost", 10)
	if _money < cost:
		print("[Agent %s] Cannot afford skill %s (cost: %d, have: %d)" % [agent_id, skill_name, cost, _money])
		return

	# Deduct cost
	spend_money(cost, "learning %s" % skill_name)

	if _skills.has(skill_name):
		_skills[skill_name]["experience"] += 10
		print("[Agent %s] Gained experience in %s (now %d)" % [agent_id, skill_name, _skills[skill_name]["experience"]])
	else:
		_skills[skill_name] = {
			"level": 1,
			"experience": 10,
			"category": skill_data.get("category", "general"),
			"tools": skill_data.get("tools", [])
		}
		print("[Agent %s] Learned new skill: %s" % [agent_id, skill_name])

		if _soul:
			_soul.add_memory("Learned skill: %s" % skill_name)


## Set work target based on skills
func _set_work_target() -> void:
	# Find workplace that matches skills
	var best_building = null
	var best_score = 0

	if _spatial_memory:
		var nearby = _spatial_memory.neighbors(_agent_body.position, 50.0)
		for node in nearby:
			if node.metadata.get("type") == "building":
				var score = _score_building_for_skills(node)
				if score > best_score:
					best_score = score
					best_building = node

	if best_building:
		_current_target = best_building.location
		_is_wandering = false
		_is_working = true
		print("[Agent %s] Going to work at %s (score: %d)" % [agent_id, best_building.concept, best_score])
	else:
		# Fallback to assigned workplace
		if _workplace != "":
			_set_building_target_by_type(_workplace)
		else:
			_choose_wander_target()


## Score building based on agent's skills
func _score_building_for_skills(building_node) -> int:
	var score = 0
	var purpose = building_node.metadata.get("purpose", "")
	var services = building_node.metadata.get("services", [])

	# Match skills to building purpose
	for skill_name in _skills.keys():
		var skill = _skills[skill_name]
		var category = skill.get("category", "")

		match purpose:
			"library":
				if category in ["data", "communication", "mcp"]:
					score += skill.level * 2
			"university":
				if category in ["development", "data"]:
					score += skill.level * 2
			"workshop":
				if category in ["development", "devops"]:
					score += skill.level * 3
			"market":
				if category in ["communication", "data"]:
					score += skill.level * 2
			"guard_post":
				if category in ["security", "devops"]:
					score += skill.level * 3
			_:
				score += 1

	return score


## Set learning target (university)
func _set_learning_target() -> void:
	_set_building_target_by_type("university")


## Set prayer target - go to temple
func _set_prayer_target() -> void:
	_set_building_target_by_type("temple")


## Try religious behavior when near temple
func _try_religious_behavior() -> void:
	if _spatial_memory == null:
		return

	# Find nearest temple
	var nearby = _spatial_memory.neighbors(_agent_body.position, 5.0)
	for node in nearby:
		if node.metadata.get("type") == "building" and node.metadata.get("purpose") == "temple":
			_pray_at_temple(node.metadata.get("name", "Temple"))
			return


## Pray at temple - earn divine favor
func _pray_at_temple(temple_name: String) -> void:
	_show_thought("I pray at %s for divine guidance..." % temple_name)

	# Notify divine system
	var divine_system = _get_divine_system()
	if divine_system:
		divine_system.agent_enters_temple(agent_id, temple_name)
		divine_system.receive_offering(agent_id, 5)  # Small offering

	# Boost mood
	if _soul and _soul.mood:
		_soul.mood.happiness = min(1.0, _soul.mood.get("happiness", 0.5) + 0.1)

	# Register visit in shared location memory
	var shared_memory = _get_shared_location_memory()
	if shared_memory:
		shared_memory.agent_visits(agent_id, temple_name)


## Get divine system reference
func _get_divine_system():
	return get_node_or_null("/root/DivineSystem")


## Get shared location memory reference
func _get_shared_location_memory():
	return get_node_or_null("/root/SharedLocationMemory")


## Navigate to a named location (for goto command)
func goto(location_name: String) -> bool:
	var shared_memory = _get_shared_location_memory()
	if not shared_memory:
		print("[Agent %s] No shared location memory available" % agent_id)
		return false

	var loc = shared_memory.get_location(location_name)
	if loc.is_empty():
		print("[Agent %s] Unknown location: %s" % [agent_id, location_name])
		return false

	_current_target = loc.position
	_current_goal = "Go to %s" % location_name
	 _is_wandering = false
	print("[Agent %s] Going to: %s at (%.1f, %.1f)" % [agent_id, location_name, loc.position.x, loc.position.z])

	# Special handling for Grand Computer
	if location_name.to_lower() in ["grand_computer", "grand computer", "claude"]:
		_visit_grand_computer()

	return true


## Visit the Grand Computer and request AI guidance
func visit_grand_computer() -> void:
	var grand_computer = get_node_or_null("/root/GrandComputer")
	if not grand_computer:
		# Try finding in scene tree
		grand_computer = _find_node_in_tree("GrandComputer")

	if not grand_computer:
		print("[Agent %s] Grand Computer not found" % agent_id)
		return

	# Request interaction
	var response = grand_computer.agent_visits(agent_id)

	# Show thought about visiting the Grand Computer
	_show_thought("Approaching the Grand Computer... seeking computational wisdom.")

	# Record visit in shared memory
	var shared_memory = _get_shared_location_memory()
	if shared_memory:
		shared_memory.agent_visits(agent_id, "Grand Computer")

	# Maybe claim a task from Grand Computer
	var available_tasks = grand_computer.get_all_tasks()
	var available = available_tasks.filter(func(t): return t.status == "available")

	if available.size() > 0:
		# Claim the highest priority task
		available.sort_custom(func(a, b): return a.priority > b.priority)
		var best_task = available[0]
		var task_index = available_tasks.find(best_task)

		if grand_computer.claim_task(agent_id, task_index):
			add_todo(best_task.task, best_task.priority)
			_show_thought("The Grand Computer has assigned me: %s (Reward: %d gold)" % [best_task.task.left(60), best_task.reward])
			print("[Agent %s] Claimed Grand Computer task: '%s'" % [agent_id, best_task.task])


## Find node in scene tree by name
func _find_node_in_tree(node_name: String) -> Node:
	var root = get_tree().root
	return _find_node_recursive(root, node_name)


func _find_node_recursive(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, name)
		if result:
			return result
	return null


## Set building target by type
func _set_building_target_by_type(building_type: String) -> void:
	if _spatial_memory == null:
		_choose_wander_target()
		return

	var nearby = _spatial_memory.neighbors(_agent_body.position, 50.0)
	for node in nearby:
		if node.metadata.get("type") == "building" and node.metadata.get("purpose") == building_type:
			_current_target = node.location
			_is_wandering = false
			_current_building = building_type
			return

	# Fallback
	_choose_wander_target()


## Inter-agent teaching system
func teach_skill_to(other_agent: AgentBehavior, skill_name: String) -> bool:
	if _teaching_cooldown > 0:
		return false

	if not _skills.has(skill_name):
		return false

	var my_skill = _skills[skill_name]
	if my_skill.get("level", 1) < 2:
		print("[Agent %s] Need level 2+ to teach %s" % [agent_id, skill_name])
		return false

	# Check if other agent has prerequisites
	var skill_data = {"prerequisites": []}  # Would come from BUILDING_TYPES
	for prereq in skill_data.get("prerequisites", []):
		if not other_agent._skills.has(prereq):
			return false

	# Teaching costs time but earns money
	_teaching_cooldown = 10.0
	_skills_taught.append(skill_name)

	# Teacher earns money
	earn_money(5, "teaching %s" % skill_name)

	# Other agent learns
	other_agent.learn_skill_from_agent(skill_name, self)

	print("[Agent %s] Taught %s to Agent %s" % [agent_id, skill_name, other_agent.agent_id])

	if _soul:
		_soul.add_memory("Taught %s to agent_%s" % [skill_name, other_agent.agent_id])

	return true


## Learn skill from another agent
func learn_skill_from_agent(skill_name: String, teacher: AgentBehavior) -> void:
	if _skills.has(skill_name):
		_skills[skill_name]["experience"] += 15  # Learning from agent is faster
	else:
		_skills[skill_name] = {
			"level": 1,
			"experience": 20,  # Bonus XP from personal instruction
			"category": "learned",
			"tools": []
		}

	_skills_learned_from_others.append(skill_name)

	print("[Agent %s] Learned %s from Agent %s" % [agent_id, skill_name, teacher.agent_id])

	if _soul:
		_soul.add_memory("Learned %s from agent_%s" % [skill_name, teacher.agent_id])


## Economy: Earn money
func earn_money(amount: int, reason: String) -> void:
	_money += amount
	_money_earned += amount
	print("[Agent %s] Earned %d gold for: %s (total: %d)" % [agent_id, amount, reason, _money])

	if _soul:
		_soul.add_memory("Earned %d gold: %s" % [amount, reason])


## Economy: Spend money
func spend_money(amount: int, reason: String) -> bool:
	if _money < amount:
		print("[Agent %s] Cannot afford %d for: %s (have: %d)" % [agent_id, amount, reason, _money])
		return false

	_money -= amount
	_money_spent += amount
	print("[Agent %s] Spent %d gold on: %s (remaining: %d)" % [agent_id, amount, reason, _money])

	if _soul:
		_soul.add_memory("Spent %d gold: %s" % [amount, reason])

	return true


## Task system: Add task with reward
func add_task_with_reward(task: String, priority: int, reward: int) -> void:
	if _todo_list.size() >= _max_todo_items:
		_todo_list.sort_custom(func(a, b): return a.priority > b.priority)
		_todo_list.pop_back()

	_todo_list.append({
		"task": task,
		"priority": priority,
		"status": "pending",
		"created": Time.get_ticks_msec() / 1000.0,
		"reward": reward
	})

	_task_rewards[task] = reward
	print("[Agent %s] Added task: %s (priority %d, reward %d)" % [agent_id, task, priority, reward])


## Complete task and claim reward
func complete_task_with_reward(task_index: int) -> void:
	if task_index >= 0 and task_index < _todo_list.size():
		var task = _todo_list[task_index]
		task["status"] = "completed"

		var reward = task.get("reward", 0)
		if reward > 0:
			earn_money(reward, "completed task: %s" % task.task)

		if _soul:
			_soul.add_memory("Completed task: %s (+%d gold)" % [task.task, reward])


## Check if agent can do a task based on skills
func can_do_task(task_description: String) -> Dictionary:
	var task_lower = task_description.to_lower()
	var matching_skills = []
	var can_do = false

	for skill_name in _skills.keys():
		var skill = _skills[skill_name]
		var category = skill.get("category", "")
		var tools = skill.get("tools", [])

		# Match task keywords to skill category/tools
		match category:
			"development":
				if task_lower.contains_any(["code", "script", "python", "program", "develop"]):
					matching_skills.append(skill_name)
					can_do = true
			"devops":
				if task_lower.contains_any(["deploy", "docker", "server", "container", "kubernetes"]):
					matching_skills.append(skill_name)
					can_do = true
			"data":
				if task_lower.contains_any(["analyze", "data", "scrape", "etl", "ml", "machine learning"]):
					matching_skills.append(skill_name)
					can_do = true
			"security":
				if task_lower.contains_any(["security", "audit", "vulnerability", "scan"]):
					matching_skills.append(skill_name)
					can_do = true
			"cloud":
				if task_lower.contains_any(["aws", "cloud", "terraform", "serverless"]):
					matching_skills.append(skill_name)
					can_do = true
			"mcp":
				if task_lower.contains_any(["search", "web", "github", "database"]):
					matching_skills.append(skill_name)
					can_do = true

	return {"can_do": can_do, "matching_skills": matching_skills}


## Get skills by category
func get_skills_by_category(category: String) -> Array:
	var result = []
	for skill_name in _skills.keys():
		if _skills[skill_name].get("category", "") == category:
			result.append(skill_name)
	return result


## Get total skill level
func get_total_skill_level() -> int:
	var total = 0
	for skill_name in _skills.keys():
		total += _skills[skill_name].get("level", 1)
	return total


## Get money status
func get_money_status() -> Dictionary:
	return {
		"current": _money,
		"earned": _money_earned,
		"spent": _money_spent
	}


## Save personal memory to disk
func save_personal_memory() -> void:
	if _personal_memory:
		var dir = "user://agent_memories/"
		DirAccess.make_dir_recursive_absolute(dir)
		var path = dir + "agent_%s_memory.json" % agent_id
		_personal_memory.save(path)

	if _soul:
		_soul.save_to_file("user://souls/soul_%s.md" % agent_id)


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
		"position": _agent_body.position,
		"soul_traits": _soul.traits if _soul else [],
		"soul_mood": _soul.mood if _soul else {}
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

	if _soul:
		lines.append("\nSOUL:")
		lines.append("  Personality: %s" % _soul.personality)
		lines.append("  Mood: h=%.1f e=%.1f c=%.1f" % [
			_soul.mood.get("happiness", 0.5),
			_soul.mood.get("energy", 0.5),
			_soul.mood.get("curiosity", 0.5)
		])
		lines.append("  Memories: %d" % _soul.memories.size())

	return "\n".join(lines)


## Clean up on exit
func _exit_tree() -> void:
	save_personal_memory()
