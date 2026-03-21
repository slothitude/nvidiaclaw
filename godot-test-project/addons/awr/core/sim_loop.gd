## SimLoop - Branching simulation engine for AWR
##
## The core primitive: deterministic branching execution
## Clones world state, applies hypothetical actions,
## advances time, scores outcomes, commits or discards branches.
##
## "Imagination as computation"
class_name SimLoop
extends RefCounted

# Preload WorldState to avoid circular dependency issues
const WorldStateScript = preload("res://addons/awr/core/world_state.gd")

## Emitted when a branch simulation completes
signal branch_complete(score: float, action: Dictionary, final_state: Variant)
## Emitted when the best action is found
signal best_found(action: Dictionary, score: float)
## Emitted during search for progress tracking
signal search_progress(completed: int, total: int, best_score: float)

## The root state to branch from
var root_state: Variant  # WorldState
## Time step for simulation
var dt: float = 1.0 / 60.0
## Number of steps to simulate (horizon in frames)
var horizon: int = 60  # 1 second at 60fps
## Scoring function
var evaluator: Callable

## Statistics
var _branches_simulated: int = 0

## Initialize with a world state and optional evaluator function
func _init(initial_state: Variant = null, eval_func: Callable = Callable()):
	root_state = initial_state
	evaluator = eval_func

## Simulate a single branch: clone, apply action, step forward, score
func simulate_branch(state: Variant, action: Dictionary) -> Dictionary:
	var sim = state.clone()
	sim.apply(action)

	for t in range(horizon):
		sim.step(dt)

	var score = 0.0
	if evaluator.is_valid():
		score = evaluator.call(sim)

	_branches_simulated += 1
	branch_complete.emit(score, action, sim)

	return {
		"action": action,
		"score": score,
		"final_state": sim,
		"final_time": sim.time
	}

## Search for the best action in the action space
func search_best(action_space: Array) -> Dictionary:
	var best_score = -INF
	var best_action: Dictionary = {}
	var best_final_state: Variant = null

	var completed = 0
	for action in action_space:
		var result = simulate_branch(root_state, action)

		if result.score > best_score:
			best_score = result.score
			best_action = result.action
			best_final_state = result.final_state

		completed += 1
		search_progress.emit(completed, action_space.size(), best_score)

	best_found.emit(best_action, best_score)

	return {
		"action": best_action,
		"score": best_score,
		"final_state": best_final_state
	}

## Simulate all actions and return sorted results
func search_all(action_space: Array) -> Array:
	var results: Array[Dictionary] = []

	var completed = 0
	var best_score = -INF

	for action in action_space:
		var result = simulate_branch(root_state, action)
		results.append(result)

		completed += 1
		if result.score > best_score:
			best_score = result.score
		search_progress.emit(completed, action_space.size(), best_score)

	# Sort by score descending
	results.sort_custom(func(a, b): return a.score > b.score)
	return results

## Simulate a sequence of actions (multi-step planning)
func simulate_sequence(state: Variant, actions: Array) -> Dictionary:
	var sim = state.clone()

	for action in actions:
		sim.apply(action)
		for t in range(horizon):
			sim.step(dt)

	var score = 0.0
	if evaluator.is_valid():
		score = evaluator.call(sim)

	return {
		"actions": actions,
		"score": score,
		"final_state": sim,
		"final_time": sim.time
	}

## Get number of branches simulated
func get_branch_count() -> int:
	return _branches_simulated

## Reset statistics
func reset_stats() -> void:
	_branches_simulated = 0

## Set the evaluator function
func set_evaluator(eval_func: Callable) -> void:
	evaluator = eval_func

## Update the root state
func set_root_state(state: Variant) -> void:
	root_state = state

## Set simulation parameters
func configure(time_step: float, horizon_frames: int) -> void:
	dt = time_step
	horizon = horizon_frames
