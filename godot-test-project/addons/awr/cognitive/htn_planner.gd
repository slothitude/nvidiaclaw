## HTN Planner - Hierarchical Task Network Planner
##
## Decomposes high-level goals into primitive executable actions.
## Uses depth-first search with backtracking to find valid plans.
##
## Usage:
##   var domain = HTNDomain.create_navigation_domain()
##   var planner = HTNPlanner.new(domain)
##   var plan = planner.plan("navigate_to_goal", world_state)
##   # plan = ["approach_target", "stop"]
##
class_name HTNPlanner
extends RefCounted

## The domain this planner operates on
var domain: Variant

## Maximum search depth (prevents infinite recursion)
var max_depth: int = 10

## Maximum number of alternative plans to consider
var max_alternatives: int = 5

## Whether to validate preconditions during planning
var validate_preconditions: bool = true

## Current world state for planning
var current_state: Dictionary = {}

## Planning statistics
var stats: Dictionary = {
	"nodes_explored": 0,
	"backtracks": 0,
	"plans_found": 0
}

## Signal emitted when a plan is found
signal plan_found(plan: Array, cost: float)
## Signal emitted when planning fails
signal plan_failed(reason: String)

func _init(d: Variant) -> void:
	domain = d

## Plan how to accomplish a task
## @param task_name: The task to accomplish
## @param world_state: Current world state (for precondition checking)
## @returns Array of primitive task names, or empty array if no plan found
func plan(task_name: String, world_state: Dictionary = {}) -> Array:
	stats = {"nodes_explored": 0, "backtracks": 0, "plans_found": 0}
	current_state = world_state.duplicate()

	var result = _plan_recursive(task_name, world_state.duplicate(), 0)

	if result.is_empty():
		plan_failed.emit("No valid plan found for: %s" % task_name)
	else:
		stats.plans_found = 1
		plan_found.emit(result, domain.get_plan_cost(result))

	return result

## Plan multiple alternative ways to accomplish a task
func plan_alternatives(task_name: String, world_state: Dictionary = {}) -> Array:
	var all_plans: Array = []
	stats = {"nodes_explored": 0, "backtracks": 0, "plans_found": 0}
	current_state = world_state.duplicate()

	_plan_all_recursive(task_name, world_state.duplicate(), 0, all_plans)

	# Sort by cost
	all_plans.sort_custom(func(a, b): return domain.get_plan_cost(a) < domain.get_plan_cost(b))

	# Limit to max_alternatives
	if all_plans.size() > max_alternatives:
		all_plans = all_plans.slice(0, max_alternatives)

	return all_plans

## Recursive planning function
func _plan_recursive(task_name: String, state: Dictionary, depth: int) -> Array:
	stats.nodes_explored += 1

	# Depth limit
	if depth > max_depth:
		stats.backtracks += 1
		return []

	# Task must exist
	if not domain.has_task(task_name):
		stats.backtracks += 1
		return []

	# Check preconditions if enabled
	if validate_preconditions and not domain.check_preconditions(task_name, state):
		stats.backtracks += 1
		return []

	# Primitive task - return it directly
	if domain.is_primitive(task_name):
		return [task_name]

	# Compound task - try each method
	var task_methods = domain.get_methods(task_name)
	if task_methods.is_empty():
		stats.backtracks += 1
		return []

	# Sort methods by priority
	task_methods.sort_custom(func(a, b): return a.priority > b.priority)

	# Try each method
	for method in task_methods:
		var plan: Array = []
		var method_state = state.duplicate()
		var valid = true

		# Check method preconditions if available
		if method.preconditions_func.is_valid():
			if not method.preconditions_func.call(method_state):
				continue

		# Try to plan each subtask
		for subtask in method.subtasks:
			var subtask_plan = _plan_recursive(subtask, method_state, depth + 1)
			if subtask_plan.is_empty():
				valid = false
				break
			plan.append_array(subtask_plan)

			# Apply effects for state tracking
			for st in subtask_plan:
				method_state = domain.apply_effects(st, method_state)

		if valid:
			return plan

		stats.backtracks += 1

	return []

## Recursive planning for all alternatives
func _plan_all_recursive(task_name: String, state: Dictionary, depth: int, all_plans: Array) -> void:
	stats.nodes_explored += 1

	if depth > max_depth:
		stats.backtracks += 1
		return

	if not domain.has_task(task_name):
		return

	if validate_preconditions and not domain.check_preconditions(task_name, state):
		return

	# Primitive task
	if domain.is_primitive(task_name):
		all_plans.append([task_name])
		return

	# Compound task
	var task_methods = domain.get_methods(task_name)
	task_methods.sort_custom(func(a, b): return a.priority > b.priority)

	for method in task_methods:
		if method.preconditions_func.is_valid() and not method.preconditions_func.call(state):
			continue

		var subtask_plans: Array = [[]]  # Start with empty plan

		for subtask in method.subtasks:
			var new_plans: Array = []
			var subtask_state = state.duplicate()

			# Get all ways to accomplish this subtask
			var subtask_alternatives: Array = []
			_collect_alternatives(subtask, subtask_state, depth + 1, subtask_alternatives)

			if subtask_alternatives.is_empty():
				# This method doesn't work, try next
				new_plans = []
				break

			# Combine with existing plans
			for existing in subtask_plans:
				for alt in subtask_alternatives:
					var combined = existing.duplicate()
					combined.append_array(alt)
					new_plans.append(combined)

			subtask_plans = new_plans

			if subtask_plans.is_empty():
				break

		# Add all valid plans from this method
		for p in subtask_plans:
			if p.size() > 0:
				all_plans.append(p)

## Collect all primitive alternatives for a task
func _collect_alternatives(task_name: String, state: Dictionary, depth: int, alternatives: Array) -> void:
	if domain.is_primitive(task_name):
		alternatives.append([task_name])
		return

	if depth > max_depth:
		return

	var task_methods = domain.get_methods(task_name)
	for method in task_methods:
		var plan: Array = []
		var valid = true

		for subtask in method.subtasks:
			var subtask_alts: Array = []
			_collect_alternatives(subtask, state.duplicate(), depth + 1, subtask_alts)

			if subtask_alts.is_empty():
				valid = false
				break

			# Use first alternative (for simplicity)
			plan.append_array(subtask_alts[0])

		if valid and plan.size() > 0:
			alternatives.append(plan)

## Convert plan to action dictionaries
func plan_to_actions(plan: Array, target_id: String = "") -> Array:
	var actions: Array = []

	for task_name in plan:
		var action = _task_to_action(task_name, target_id)
		if not action.is_empty():
			actions.append(action)

	return actions

## Convert a single task to an action dictionary
func _task_to_action(task_name: String, target_id: String) -> Dictionary:
	var action: Dictionary = {"task": task_name}

	if target_id != "":
		action["target"] = target_id

	# Map common task names to action types
	match task_name:
		"move_forward":
			action["type"] = "apply_impulse"
			action["params"] = {"x": 0.0, "y": 100.0}
		"turn_left":
			action["type"] = "rotate"
			action["params"] = {"angle": -PI / 2}
		"turn_right":
			action["type"] = "rotate"
			action["params"] = {"angle": PI / 2}
		"apply_impulse_north":
			action["type"] = "apply_impulse"
			action["params"] = {"x": 0.0, "y": 100.0}
		"apply_impulse_south":
			action["type"] = "apply_impulse"
			action["params"] = {"x": 0.0, "y": -100.0}
		"apply_impulse_east":
			action["type"] = "apply_impulse"
			action["params"] = {"x": 100.0, "y": 0.0}
		"apply_impulse_west":
			action["type"] = "apply_impulse"
			action["params"] = {"x": -100.0, "y": 0.0}
		"apply_force_small":
			action["type"] = "apply_force"
			action["params"] = {"x": 50.0, "y": 50.0}
		"apply_force_medium":
			action["type"] = "apply_force"
			action["params"] = {"x": 100.0, "y": 100.0}
		"apply_force_large":
			action["type"] = "apply_force"
			action["params"] = {"x": 200.0, "y": 200.0}
		"stop", "wait", "wait_physics":
			action["type"] = "wait"
			action["params"] = {}
		_:
			action["type"] = "custom"

	return action

## Get planning statistics
func get_stats() -> Dictionary:
	return stats.duplicate()

## Convert plan to human-readable string
func plan_to_string(plan: Array) -> String:
	if plan.is_empty():
		return "(empty plan)"

	var lines: Array = []
	var total_cost = 0.0
	var total_duration = 0.0

	for i in range(plan.size()):
		var task_name = plan[i]
		var task = domain.get_task(task_name)
		if task:
			lines.append("%d. %s - %s" % [i + 1, task_name, task.description])
			total_cost += task.cost
			total_duration += task.duration
		else:
			lines.append("%d. %s (unknown)" % [i + 1, task_name])

	lines.append("")
	lines.append("Total cost: %.2f, Duration: %.2f" % [total_cost, total_duration])

	return "\n".join(lines)

## Convert plan to prompt block for AI
func to_prompt_block(plan: Array) -> String:
	var lines: Array = []
	lines.append("=== HTN PLAN ===")
	lines.append("Task: Decompose compound tasks into primitives")
	lines.append("")
	lines.append("PLAN:")
	lines.append(plan_to_string(plan))
	lines.append("")
	lines.append("STATS:")
	lines.append("  Nodes explored: %d" % stats.nodes_explored)
	lines.append("  Backtracks: %d" % stats.backtracks)

	return "\n".join(lines)

## Check if a plan is valid (all tasks are primitive)
func is_valid_plan(plan: Array) -> bool:
	for task_name in plan:
		if not domain.is_primitive(task_name):
			return false
	return true

## Estimate plan success probability based on preconditions
func estimate_success_probability(plan: Array, world_state: Dictionary) -> float:
	var state = world_state.duplicate()
	var success_prob = 1.0

	for task_name in plan:
		if not domain.check_preconditions(task_name, state):
			return 0.0

		# Apply effects (if any) to track state changes
		state = domain.apply_effects(task_name, state)

		# Reduce probability slightly for each step (uncertainty accumulates)
		success_prob *= 0.95

	return success_prob
