## AWR - Agent World Runtime
##
## Not an Agent OS. A new compute substrate.
##
## Current AI paradigm: Thought → Action → Result (symbolic reasoning)
## AWR paradigm: State → Simulate → Evaluate → Commit (physics as reasoning)
##
## v0.3: Now with complete AGI patterns from Meeseeks integration:
##   - BDI Model (Beliefs-Desires-Intentions)
##   - Global Workspace (attention/consciousness)
##   - HTN Planner (hierarchical task decomposition)
##   - Memory-Prediction (learning from errors)
##   - Self-Improvement (performance tracking & strategy)
##   - The Crypt (ancestral wisdom storage)
##   - Delegation (hierarchical spawning)
##
## This autoload provides the main API for AWR functionality.
extends Node

# Preload dependencies - Core
const WorldStateScript = preload("res://addons/awr/core/world_state.gd")
const SimLoopScript = preload("res://addons/awr/core/sim_loop.gd")
const EvaluatorScript = preload("res://addons/awr/core/evaluator.gd")
const CausalBusScript = preload("res://addons/awr/core/causal_bus.gd")
const EventLogScript = preload("res://addons/awr/core/event_log.gd")

# Preload dependencies - Physics
const Collision2DScript = preload("res://addons/awr/physics/collision_2d.gd")
const BroadphaseScript = preload("res://addons/awr/physics/broadphase.gd")

# Preload dependencies - Perception
const PerceptionBridgeScript = preload("res://addons/awr/perception/perception_bridge.gd")
const VLMParserScript = preload("res://addons/awr/perception/vlm_parser.gd")
const ViewportCaptureScript = preload("res://addons/awr/perception/viewport_capture.gd")

# Preload dependencies - WorldGen
const SceneGeneratorScript = preload("res://addons/awr/worldgen/scene_generator.gd")

# Preload dependencies - RealBridge
const RealBridgeScript = preload("res://addons/awr/realbridge/mqtt_client.gd")

# Preload dependencies - Spatial Memory
const SpatialMemoryScript = preload("res://addons/awr/spatial/spatial_memory.gd")
const MemoryNodeScript = preload("res://addons/awr/spatial/memory_node.gd")
const SpatialPathScript = preload("res://addons/awr/spatial/spatial_path.gd")
const SpatialIndexScript = preload("res://addons/awr/spatial/spatial_index.gd")
const PalaceBuilderScript = preload("res://addons/awr/spatial/palace_builder.gd")

# Preload dependencies - Cognitive (AGI Patterns)
const BDIModelScript = preload("res://addons/awr/cognitive/bdi_model.gd")
const GlobalWorkspaceScript = preload("res://addons/awr/cognitive/global_workspace.gd")
const HTNPlannerScript = preload("res://addons/awr/cognitive/htn_planner.gd")
const HTNDomainScript = preload("res://addons/awr/cognitive/htn_domain.gd")
const MemoryPredictionScript = preload("res://addons/awr/cognitive/memory_prediction.gd")
const DelegationScript = preload("res://addons/awr/cognitive/delegation.gd")

# Preload dependencies - Self-Improvement
const PerformanceMonitorScript = preload("res://addons/awr/self_improvement/performance_monitor.gd")
const PatternAnalyzerScript = preload("res://addons/awr/self_improvement/pattern_analyzer.gd")
const StrategyGeneratorScript = preload("res://addons/awr/self_improvement/strategy_generator.gd")
const ValidatorScript = preload("res://addons/awr/self_improvement/validator.gd")

# Preload dependencies - Crypt
const TheCryptScript = preload("res://addons/awr/crypt/crypt.gd")
const BloodlineScript = preload("res://addons/awr/crypt/bloodline.gd")

## Core components
var _world: Variant = null
var _sim_loop: Variant = null
var _causal_bus: Variant = null
var _event_log: Variant = null
var _perception: Variant = null
var _real_bridge: Variant = null
var _scene_gen: Variant = null
var _spatial_memory: Variant = null

## Cognitive components (AGI Patterns)
var _bdi_model: Variant = null
var _global_workspace: Variant = null
var _htn_planner: Variant = null
var _htn_domain: Variant = null
var _memory_prediction: Variant = null
var _delegation: Variant = null

## Self-improvement components
var _performance_monitor: Variant = null
var _pattern_analyzer: Variant = null
var _strategy_generator: Variant = null
var _validator: Variant = null

## Crypt components
var _crypt: Variant = null

## Configuration
var config: Dictionary = {
	"dt": 1.0 / 60.0,
	"horizon": 60,
	"debug": false,
	"causal_bus": {
		"max_events": 10000,
		"index_by_target": true
	},
	"perception": {
		"auto_update_world": true,
		"merge_strategy": "update"
	},
	"realbridge": {
		"broker": "localhost",
		"port": 1883
	}
}

## Create a new world from configuration
func create_world(world_config: Dictionary) -> Variant:
	_world = WorldStateScript.from_config(world_config)
	return _world

## Get the current world state
func get_world() -> Variant:
	return _world

## Set the current world state
func set_world(world: Variant) -> void:
	_world = world

## Create a simulation loop with an evaluator
func create_sim(evaluator_func: Callable = Callable()) -> Variant:
	_sim_loop = SimLoopScript.new(_world, evaluator_func)
	_sim_loop.dt = config.dt
	_sim_loop.horizon = config.horizon
	return _sim_loop

## Simulate multiple actions and return all results sorted by score
func simulate(world: Variant, actions: Array, options: Dictionary = {}) -> Dictionary:
	var horizon: int = options.get("horizon", config.horizon)
	var eval_func: Callable = options.get("evaluator", Callable())

	var sim = SimLoopScript.new(world, eval_func)
	sim.horizon = horizon

	var all_results = sim.search_all(actions)
	var best = all_results[0] if all_results.size() > 0 else {}

	return {
		"best_action": best.get("action", {}),
		"best_score": best.get("score", 0.0),
		"best_branch": best,
		"all_results": all_results,
		"branches_simulated": sim.get_branch_count()
	}

## Step the world forward by dt
func step_world(dt: float = -1.0) -> void:
	if _world == null:
		return
	var step_dt = dt if dt > 0 else config.dt
	_world.step(step_dt)

## Apply an action to the world
func apply_action(action: Dictionary) -> void:
	if _world == null:
		return
	_world.apply(action)

## Clone the current world state
func clone_world() -> Variant:
	if _world == null:
		return null
	return _world.clone()

## Quick evaluation helpers
func evaluate_goal(goal_id: String, target_pos: Vector2) -> float:
	if _world == null:
		return -INF
	return EvaluatorScript.goal_distance(_world, goal_id, target_pos)

func evaluate_collision_free() -> float:
	if _world == null:
		return 0.0
	return EvaluatorScript.collision_free(_world)

func evaluate_combined(weights: Dictionary) -> float:
	if _world == null:
		return 0.0
	return EvaluatorScript.combined(_world, weights)

## Generate action space for impulses
static func generate_impulse_actions(body_id: String, range_min: int, range_max: int, step: int) -> Array:
	var actions: Array = []
	for x in range(range_min, range_max + 1, step):
		for y in range(range_min, range_max + 1, step):
			actions.append({
				"type": "apply_impulse",
				"target": body_id,
				"params": {"x": float(x), "y": float(y)}
			})
	return actions

## Generate action space for forces
static func generate_force_actions(body_id: String, range_min: int, range_max: int, step: int) -> Array:
	var actions: Array = []
	for x in range(range_min, range_max + 1, step):
		for y in range(range_min, range_max + 1, step):
			actions.append({
				"type": "apply_force",
				"target": body_id,
				"params": {"x": float(x), "y": float(y)}
			})
	return actions

# ============================================================
# CAUSAL BUS API
# ============================================================

## Get or create the causal bus
func get_causal_bus() -> Variant:
	if _causal_bus == null:
		_causal_bus = CausalBusScript.new()
		_causal_bus.config = config.causal_bus.duplicate()
	return _causal_bus

## Get or create the event log
func get_event_log() -> Variant:
	if _event_log == null:
		_event_log = EventLogScript.new(get_causal_bus())
	return _event_log

## Record an action event
func record_action(action: Dictionary, source: String = "agent") -> String:
	return get_causal_bus().record_action(action, source)

## Get causal chain for an event
func get_causal_chain(event_id: String) -> Array:
	return get_causal_bus().get_causal_chain(event_id)

## Trace why a property changed
func trace_cause(target: String, property: String) -> Array:
	return get_causal_bus().trace_cause(target, property)

# ============================================================
# PERCEPTION API
# ============================================================

## Get or create the perception bridge
func get_perception() -> Variant:
	if _perception == null:
		_perception = PerceptionBridgeScript.new(_world, get_causal_bus())
		_perception.config.merge(config.perception)
	return _perception

## Sync world state from a scene
func sync_from_scene(root_node: Node, bounds: Rect2 = Rect2(0, 0, 10000, 10000)) -> Dictionary:
	return get_perception().sync_from_scene(root_node, bounds)

## Process VLM response
func process_vlm_response(response: String, confidence: float = 1.0) -> Dictionary:
	return get_perception().process_vlm_response(response, confidence)

## Capture viewport for VLM analysis
func capture_viewport(viewport: Viewport, prompt: String = "") -> Dictionary:
	return get_perception().capture_and_prepare(viewport, prompt)

# ============================================================
# WORLDGEN API
# ============================================================

## Get or create the scene generator
func get_scene_generator(seed_value: int = 0) -> Variant:
	if _scene_gen == null:
		_scene_gen = SceneGeneratorScript.new(seed_value)
	return _scene_gen

## Generate a random scene
func generate_random_scene(body_count: int, seed_value: int = 0) -> Dictionary:
	var gen = get_scene_generator(seed_value)
	return gen.generate_random(body_count)

## Generate a solar system scenario
func generate_solar_system(planet_count: int = 3, seed_value: int = 0) -> Dictionary:
	var gen = get_scene_generator(seed_value)
	return gen.generate_solar_system(planet_count)

## Generate a billiards scenario
func generate_billiards(seed_value: int = 0) -> Dictionary:
	var gen = get_scene_generator(seed_value)
	return gen.generate_billiards()

## Generate a maze scenario
func generate_maze(goal_pos: Vector2 = Vector2(900, 500), seed_value: int = 0) -> Dictionary:
	var gen = get_scene_generator(seed_value)
	return gen.generate_maze(goal_pos)

## Generate scene from text description
func generate_from_description(description: String, seed_value: int = 0) -> Dictionary:
	var gen = get_scene_generator(seed_value)
	return gen.generate_from_description(description)

# ============================================================
# REALBRIDGE API (Digital Twin)
# ============================================================

## Get or create the real bridge
func get_real_bridge() -> Variant:
	if _real_bridge == null:
		_real_bridge = RealBridgeScript.new(_world, get_causal_bus())
		_real_bridge.config.merge(config.realbridge)
	return _real_bridge

## Connect to MQTT broker
func connect_hardware(broker: String = "", port: int = 0) -> bool:
	return get_real_bridge().connect_to_broker(broker, port)

## Disconnect from hardware
func disconnect_hardware() -> void:
	get_real_bridge().disconnect()

## Check if connected to hardware
func is_hardware_connected() -> bool:
	return get_real_bridge().is_connected()

## Sync world state to hardware
func sync_to_hardware() -> Dictionary:
	return get_real_bridge().sync_to_world()

## Sync world state from hardware sensors
func sync_from_hardware() -> Dictionary:
	return get_real_bridge().sync_from_world()

## Run predictive simulation ahead of real-time
func predict_ahead(sim_loop: Variant, actions: Array, ms_ahead: int) -> Dictionary:
	return get_real_bridge().predict_ahead(sim_loop, actions, ms_ahead)

## Create a digital twin
func create_digital_twin() -> Variant:
	return get_real_bridge().create_digital_twin()

# ============================================================
# UTILITY METHODS
# ============================================================

## Quick setup: create world, run simulation, return best action
func quick_plan(world_config: Dictionary, actions: Array, eval_func: Callable, options: Dictionary = {}) -> Dictionary:
	var world = create_world(world_config)
	var sim = create_sim(eval_func)

	if options.has("horizon"):
		sim.horizon = options.horizon

	var results = sim.search_all(actions)

	return {
		"world": world,
		"sim": sim,
		"results": results,
		"best_action": results[0].action if results.size() > 0 else {},
		"best_score": results[0].score if results.size() > 0 else 0.0
	}

## Run full perception-simulate-commit cycle
func psc_cycle(viewport: Viewport, actions: Array, eval_func: Callable) -> Dictionary:
	# 1. Perceive
	var perception_result = sync_from_scene(viewport.get_parent())

	# 2. Simulate
	var sim_result = simulate(_world, actions, {"evaluator": eval_func})

	# 3. Commit
	if not sim_result.best_action.is_empty():
		apply_action(sim_result.best_action)
		record_action(sim_result.best_action, "psc_cycle")

	return {
		"perception": perception_result,
		"simulation": sim_result,
		"committed": not sim_result.best_action.is_empty()
	}

## Debug logging
func _log(message: String) -> void:
	if config.debug:
		print("[AWR] %s" % message)

# ============================================================
# SPATIAL MEMORY API (v0.2)
# ============================================================

## Get or create the spatial memory engine
func get_spatial_memory(cell_size: float = 10.0) -> Variant:
	if _spatial_memory == null:
		_spatial_memory = SpatialMemoryScript.new(cell_size)
	return _spatial_memory

## Create a new spatial memory palace
func create_memory_palace(cell_size: float = 10.0) -> Variant:
	return SpatialMemoryScript.new(cell_size)

## Store a concept in spatial memory
func memorize(concept: String, location: Vector3, metadata: Dictionary = {}) -> Variant:
	return get_spatial_memory().store(concept, location, metadata)

## Retrieve a concept from spatial memory
func recall(location: Vector3) -> Variant:
	return get_spatial_memory().retrieve(location)

## Recall a concept by name
func recall_by_concept(concept: String) -> Variant:
	return get_spatial_memory().retrieve_by_concept(concept)

## Find spatial path between two concepts (REASONING!)
func spatial_reason(from_concept: String, to_concept: String) -> Variant:
	return get_spatial_memory().find_path(from_concept, to_concept)

## Get concepts along a path (THE ANSWER!)
func concepts_on_path(path: Variant) -> Array:
	if path == null:
		return []
	return path.get_discovered_concepts()

## Calculate semantic distance between concepts
func semantic_distance(concept_a: String, concept_b: String) -> float:
	return get_spatial_memory().semantic_distance(concept_a, concept_b)

## Find neighbors of a concept
func concept_neighbors(concept: String, radius: float) -> Array:
	return get_spatial_memory().neighborhood(concept, radius)

## Build a memory palace from concepts
func build_palace(concepts: Array[Dictionary]) -> Variant:
	var builder = PalaceBuilderScript.new(get_spatial_memory())
	return builder.build(concepts)

## Build a linear memory palace (sequences/stories)
func build_linear_palace(concepts: Array[String], start: Vector3 = Vector3.ZERO) -> Variant:
	var builder = PalaceBuilderScript.new(get_spatial_memory())
	return builder.build_linear(concepts, start)

## Build a spiral memory palace (exploration)
func build_spiral_palace(concepts: Array[String], center: Vector3 = Vector3.ZERO) -> Variant:
	var builder = PalaceBuilderScript.new(get_spatial_memory())
	return builder.build_spiral(concepts, center)

## Save spatial memory to file
func save_memory(path: String) -> int:
	return get_spatial_memory().save(path)

## Load spatial memory from file
func load_memory(path: String) -> Variant:
	_spatial_memory = SpatialMemoryScript.load_from(path)
	return _spatial_memory

# ============================================================
# COGNITIVE API (AGI Patterns - v0.3)
# ============================================================

## Get or create the BDI model
func get_bdi() -> Variant:
	if _bdi_model == null:
		_bdi_model = BDIModelScript.new()
	return _bdi_model

## Create BDI model from current world state
func create_bdi_from_world(agent_id: String = "") -> Variant:
	_bdi_model = BDIModelScript.from_world_state(_world, agent_id)
	return _bdi_model

## Get or create the global workspace
func get_global_workspace() -> Variant:
	if _global_workspace == null:
		_global_workspace = GlobalWorkspaceScript.new()
	return _global_workspace

## Run attention competition in global workspace
func compete_for_attention() -> Variant:
	var gw = get_global_workspace()
	gw.compete()
	return gw.get_conscious_content()

## Get or create the HTN planner with domain
func get_htn_planner(domain_type: String = "navigation") -> Variant:
	if _htn_planner == null or _htn_domain == null:
		match domain_type:
			"physics":
				_htn_domain = HTNDomainScript.create_physics_domain()
			_:
				_htn_domain = HTNDomainScript.create_navigation_domain()
		_htn_planner = HTNPlannerScript.new(_htn_domain)
	return _htn_planner

## Plan a task using HTN
func htn_plan(task_name: String, world_state: Dictionary = {}) -> Array:
	var planner = get_htn_planner()
	return planner.plan(task_name, world_state)

## Get or create the memory-prediction system
func get_memory_prediction() -> Variant:
	if _memory_prediction == null:
		_memory_prediction = MemoryPredictionScript.new()
	return _memory_prediction

## Make a prediction and learn from errors
func predict_and_learn(what: String, expected: Variant, actual: Variant, context: Dictionary = {}) -> float:
	var mp = get_memory_prediction()
	mp.predict_value(what, expected, 0.8, context)
	mp.observe(what, actual, context)
	mp.learn()
	return mp.get_prediction_error()

## Get or create the delegation system
func get_delegation() -> Variant:
	if _delegation == null:
		_delegation = DelegationScript.new()
	return _delegation

## Check if should delegate a task
func should_delegate(task: String, attempts: int = 0) -> bool:
	return get_delegation().should_delegate(task, attempts)

## Spawn a subtask via delegation
func spawn_subtask(task: String) -> Dictionary:
	return get_delegation().spawn_subtask(task)

# ============================================================
# SELF-IMPROVEMENT API (v0.3)
# ============================================================

## Get or create the performance monitor
func get_performance_monitor() -> Variant:
	if _performance_monitor == null:
		_performance_monitor = PerformanceMonitorScript.new()
	return _performance_monitor

## Record a task outcome for tracking
func record_task_outcome(task_id: String, success: bool, attempts: int = 1, tools: Array = []) -> void:
	get_performance_monitor().record_task(task_id, success, attempts, tools)

## Get or create the pattern analyzer
func get_pattern_analyzer() -> Variant:
	if _pattern_analyzer == null:
		_pattern_analyzer = PatternAnalyzerScript.new(get_performance_monitor())
	return _pattern_analyzer

## Analyze patterns in task history
func analyze_patterns() -> Dictionary:
	return get_pattern_analyzer().analyze()

## Get or create the strategy generator
func get_strategy_generator() -> Variant:
	if _strategy_generator == null:
		_strategy_generator = StrategyGeneratorScript.new(get_pattern_analyzer())
	return _strategy_generator

## Generate improvement strategies
func generate_strategies() -> Array:
	return get_strategy_generator().generate()

## Get or create the validator
func get_validator() -> Variant:
	if _validator == null:
		_validator = ValidatorScript.new(get_performance_monitor())
	return _validator

## Validate a strategy
func validate_strategy(strategy: Dictionary, test_func: Callable) -> Dictionary:
	return get_validator().validate_strategy(strategy, test_func)

# ============================================================
# CRYPT API (Ancestral Wisdom - v0.3)
# ============================================================

## Get or create The Crypt
func get_crypt() -> Variant:
	if _crypt == null:
		_crypt = TheCryptScript.new()
	return _crypt

## Entomb a completed session (store wisdom)
func entomb_session(session_id: String, task: String, outcome: Dictionary) -> void:
	get_crypt().entomb(session_id, task, outcome)

## Inherit wisdom from a bloodline
func inherit_wisdom(bloodline_name: String, context: Dictionary = {}) -> Array:
	return get_crypt().inherit(bloodline_name, context)

## Get guidance for a task from ancestral wisdom
func get_ancestral_guidance(task: String, context: Dictionary = {}) -> Array:
	return get_crypt().get_guidance(task, context)

## Save The Crypt to file
func save_crypt(path: String) -> int:
	return get_crypt().save(path)

## Load The Crypt from file
func load_crypt(path: String) -> Variant:
	_crypt = TheCryptScript.load_from(path)
	return _crypt

# ============================================================
# INTEGRATED COGNITIVE CYCLE (v0.3)
# ============================================================

## Run a complete cognitive cycle with AGI patterns
## 1. Update BDI from world state
## 2. Compete for attention in global workspace
## 3. Get ancestral guidance
## 4. Plan with HTN if needed
## 5. Simulate and evaluate
## 6. Commit and learn
func cognitive_cycle(viewport: Viewport, actions: Array, eval_func: Callable, task: String = "navigate") -> Dictionary:
	var result: Dictionary = {}

	# 1. Update BDI from world state
	if _world != null:
		create_bdi_from_world()
		result["bdi_state"] = get_bdi().to_prompt_block()

	# 2. Compete for attention
	var gw = get_global_workspace()
	if _bdi_model != null:
		gw = GlobalWorkspaceScript.from_bdi(_bdi_model)
	gw.compete()
	result["conscious_content"] = gw.get_conscious_content()

	# 3. Get ancestral guidance
	var guidance = get_ancestral_guidance(task)
	result["guidance"] = guidance

	# 4. Plan with HTN if complex task
	var plan = htn_plan(task)
	result["htn_plan"] = plan

	# 5. Simulate and evaluate
	var sim_result = simulate(_world, actions, {"evaluator": eval_func})
	result["simulation"] = sim_result

	# 6. Commit and learn
	if not sim_result.best_action.is_empty():
		apply_action(sim_result.best_action)
		record_action(sim_result.best_action, "cognitive_cycle")
		record_task_outcome("cognitive_cycle_%d" % Time.get_ticks_msec(), true, 1, ["cognitive_cycle"])

		# Learn from prediction
		if _memory_prediction != null:
			_memory_prediction.learn()

	result["committed"] = not sim_result.best_action.is_empty()
	return result

## Get complete cognitive state as prompt block for AI
func get_cognitive_state() -> String:
	var lines: Array = []
	lines.append("=== AWR COGNITIVE STATE ===")

	if _bdi_model != null:
		lines.append(_bdi_model.to_prompt_block())

	if _global_workspace != null:
		lines.append(_global_workspace.to_prompt_block())

	if _delegation != null:
		lines.append(_delegation.to_prompt_block())

	if _crypt != null:
		lines.append(_crypt.to_prompt_block())

	if _memory_prediction != null:
		lines.append(_memory_prediction.to_prompt_block())

	return "\n".join(lines)
