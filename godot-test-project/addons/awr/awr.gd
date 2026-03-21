## AWR - Agent World Runtime
##
## Not an Agent OS. A new compute substrate.
##
## Current AI paradigm: Thought → Action → Result (symbolic reasoning)
## AWR paradigm: State → Simulate → Evaluate → Commit (physics as reasoning)
##
## This autoload provides the main API for AWR functionality.
extends Node

# Preload dependencies
const WorldStateScript = preload("res://addons/awr/core/world_state.gd")
const SimLoopScript = preload("res://addons/awr/core/sim_loop.gd")
const EvaluatorScript = preload("res://addons/awr/core/evaluator.gd")
const CausalBusScript = preload("res://addons/awr/core/causal_bus.gd")
const EventLogScript = preload("res://addons/awr/core/event_log.gd")
const Collision2DScript = preload("res://addons/awr/physics/collision_2d.gd")
const BroadphaseScript = preload("res://addons/awr/physics/broadphase.gd")
const PerceptionBridgeScript = preload("res://addons/awr/perception/perception_bridge.gd")
const VLMParserScript = preload("res://addons/awr/perception/vlm_parser.gd")
const ViewportCaptureScript = preload("res://addons/awr/perception/viewport_capture.gd")
const SceneGeneratorScript = preload("res://addons/awr/worldgen/scene_generator.gd")
const RealBridgeScript = preload("res://addons/awr/realbridge/mqtt_client.gd")

## Core components
var _world: Variant = null
var _sim_loop: Variant = null
var _causal_bus: Variant = null
var _event_log: Variant = null
var _perception: Variant = null
var _real_bridge: Variant = null
var _scene_gen: Variant = null

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
