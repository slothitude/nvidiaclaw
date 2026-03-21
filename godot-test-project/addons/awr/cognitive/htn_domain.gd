## HTN Domain - Task and Method Definitions
##
## Defines the domain knowledge for the HTN planner.
## Contains primitive tasks (executable) and compound tasks (decomposable).
##
## Usage:
##   var domain = HTNDomain.new()
##   domain.add_primitive("move_to", "Move to a target position")
##   domain.add_compound("navigate_to_goal", "Navigate to the goal location")
##   domain.add_method("navigate_to_goal", "path_follow", ["plan_path", "follow_path"])
##
class_name HTNDomain
extends RefCounted

## All tasks (both primitive and compound)
var tasks: Dictionary = {}

## Methods for decomposing compound tasks
var methods: Dictionary = {}

## Precondition checkers for tasks
var preconditions: Dictionary = {}

## Effect appliers for tasks
var effects: Dictionary = {}

## Signal emitted when a task is added
signal task_added(task_name: String, is_primitive: bool)
## Signal emitted when a method is added
signal method_added(method_name: String, compound_task: String)

## Task types
enum TaskType { PRIMITIVE, COMPOUND }

## Internal task structure
class Task:
	var name: String
	var description: String
	var type: int  # TaskType
	var cost: float = 1.0
	var duration: float = 1.0

	func _init(n: String, d: String, t: int):
		name = n
		description = d
		type = t

## Internal method structure
class Method:
	var name: String
	var compound_task: String
	var subtasks: Array  # Array of task names
	var preconditions_func: Callable = Callable()
	var priority: float = 1.0

	func _init(n: String, ct: String, st: Array):
		name = n
		compound_task = ct
		subtasks = st

## Add a primitive task (executable, cannot be decomposed)
func add_primitive(name: String, description: String, cost: float = 1.0, duration: float = 1.0) -> void:
	var task = Task.new(name, description, TaskType.PRIMITIVE)
	task.cost = cost
	task.duration = duration
	tasks[name] = task
	task_added.emit(name, true)

## Add a compound task (can be decomposed into subtasks)
func add_compound(name: String, description: String) -> void:
	var task = Task.new(name, description, TaskType.COMPOUND)
	tasks[name] = task
	task_added.emit(name, false)

## Add a method for decomposing a compound task
## @param name: Method name (for identification)
## @param compound_task: The compound task this method decomposes
## @param subtasks: Array of subtask names
func add_method(name: String, compound_task: String, subtasks: Array) -> void:
	var method = Method.new(name, compound_task, subtasks)
	if not methods.has(compound_task):
		methods[compound_task] = []
	methods[compound_task].append(method)
	method_added.emit(name, compound_task)

## Set precondition checker for a task
## @param task_name: Task to set precondition for
## @param check_func: Callable that takes a world state and returns bool
func set_precondition(task_name: String, check_func: Callable) -> void:
	preconditions[task_name] = check_func

## Set effect applier for a task
## @param task_name: Task to set effect for
## @param apply_func: Callable that takes and returns a world state
func set_effect(task_name: String, apply_func: Callable) -> void:
	effects[task_name] = apply_func

## Check if a task is primitive
func is_primitive(task_name: String) -> bool:
	if tasks.has(task_name):
		return tasks[task_name].type == TaskType.PRIMITIVE
	return false

## Check if a task is compound
func is_compound(task_name: String) -> bool:
	if tasks.has(task_name):
		return tasks[task_name].type == TaskType.COMPOUND
	return false

## Check if a task exists
func has_task(task_name: String) -> bool:
	return tasks.has(task_name)

## Get task info
func get_task(task_name: String) -> Task:
	return tasks.get(task_name, null)

## Get methods for a compound task
func get_methods(compound_task: String) -> Array:
	return methods.get(compound_task, [])

## Check preconditions for a task
func check_preconditions(task_name: String, world_state: Dictionary) -> bool:
	if preconditions.has(task_name):
		return preconditions[task_name].call(world_state)
	return true  # No preconditions = always valid

## Apply effects for a task
func apply_effects(task_name: String, world_state: Dictionary) -> Dictionary:
	if effects.has(task_name):
		return effects[task_name].call(world_state.duplicate())
	return world_state.duplicate()

## Get all primitive tasks
func get_all_primitives() -> Array:
	var result: Array = []
	for name in tasks:
		if tasks[name].type == TaskType.PRIMITIVE:
			result.append(name)
	return result

## Get all compound tasks
func get_all_compounds() -> Array:
	var result: Array = []
	for name in tasks:
		if tasks[name].type == TaskType.COMPOUND:
			result.append(name)
	return result

## Get total cost of a plan (array of task names)
func get_plan_cost(plan: Array) -> float:
	var total: float = 0.0
	for task_name in plan:
		if tasks.has(task_name):
			total += tasks[task_name].cost
	return total

## Get total duration of a plan
func get_plan_duration(plan: Array) -> float:
	var total: float = 0.0
	for task_name in plan:
		if tasks.has(task_name):
			total += tasks[task_name].duration
	return total

## Convert to dictionary
func to_dict() -> Dictionary:
	var tasks_data: Dictionary = {}
	for name in tasks:
		var t: Task = tasks[name]
		tasks_data[name] = {
			"description": t.description,
			"type": "primitive" if t.type == TaskType.PRIMITIVE else "compound",
			"cost": t.cost,
			"duration": t.duration
		}

	var methods_data: Dictionary = {}
	for ct in methods:
		methods_data[ct] = []
		for m in methods[ct]:
			methods_data[ct].append({
				"name": m.name,
				"subtasks": m.subtasks,
				"priority": m.priority
			})

	return {
		"tasks": tasks_data,
		"methods": methods_data
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/cognitive/htn_domain.gd")
	var domain = script.new()

	for name in data.get("tasks", {}):
		var t_data = data.tasks[name]
		if t_data.type == "primitive":
			domain.add_primitive(name, t_data.description, t_data.get("cost", 1.0), t_data.get("duration", 1.0))
		else:
			domain.add_compound(name, t_data.description)

	for ct in data.get("methods", {}):
		for m_data in data.methods[ct]:
			domain.add_method(m_data.name, ct, m_data.subtasks)

	return domain

## Create a default navigation domain
static func create_navigation_domain() -> Variant:
	var script = preload("res://addons/awr/cognitive/htn_domain.gd")
	var domain = script.new()

	# Primitives
	domain.add_primitive("move_forward", "Move forward one unit", 1.0, 0.5)
	domain.add_primitive("turn_left", "Turn left 90 degrees", 0.5, 0.2)
	domain.add_primitive("turn_right", "Turn right 90 degrees", 0.5, 0.2)
	domain.add_primitive("stop", "Stop moving", 0.1, 0.1)
	domain.add_primitive("apply_impulse", "Apply an impulse force", 1.0, 0.1)
	domain.add_primitive("wait", "Wait for a moment", 0.1, 1.0)

	# Compounds
	domain.add_compound("navigate_to_goal", "Navigate to the goal location")
	domain.add_compound("avoid_obstacle", "Avoid an obstacle")
	domain.add_compound("approach_target", "Approach a target")
	domain.add_compound("explore_area", "Explore an unknown area")

	# Methods for navigate_to_goal
	domain.add_method("direct_approach", "navigate_to_goal", ["approach_target", "stop"])
	domain.add_method("careful_approach", "navigate_to_goal", ["approach_target", "avoid_obstacle", "approach_target", "stop"])

	# Methods for avoid_obstacle
	domain.add_method("turn_left_avoid", "avoid_obstacle", ["turn_left", "move_forward", "turn_right", "move_forward"])
	domain.add_method("turn_right_avoid", "avoid_obstacle", ["turn_right", "move_forward", "turn_left", "move_forward"])

	# Methods for approach_target
	domain.add_method("simple_approach", "approach_target", ["move_forward"])
	domain.add_method("impulse_approach", "approach_target", ["apply_impulse"])

	# Methods for explore_area
	domain.add_method("spiral_explore", "explore_area", ["turn_right", "move_forward", "move_forward", "explore_area"])
	domain.add_method("random_explore", "explore_area", ["move_forward", "wait", "turn_left", "explore_area"])

	return domain

## Create a default physics domain
static func create_physics_domain() -> Variant:
	var script = preload("res://addons/awr/cognitive/htn_domain.gd")
	var domain = script.new()

	# Primitives
	domain.add_primitive("apply_force_small", "Apply small force", 1.0, 0.1)
	domain.add_primitive("apply_force_medium", "Apply medium force", 1.0, 0.1)
	domain.add_primitive("apply_force_large", "Apply large force", 1.0, 0.1)
	domain.add_primitive("apply_impulse_north", "Apply impulse north", 1.0, 0.1)
	domain.add_primitive("apply_impulse_south", "Apply impulse south", 1.0, 0.1)
	domain.add_primitive("apply_impulse_east", "Apply impulse east", 1.0, 0.1)
	domain.add_primitive("apply_impulse_west", "Apply impulse west", 1.0, 0.1)
	domain.add_primitive("wait_physics", "Wait for physics to settle", 0.1, 1.0)

	# Compounds
	domain.add_compound("move_toward_goal", "Move toward the goal")
	domain.add_compound("stop_at_goal", "Stop at goal position")
	domain.add_compound("bounce_off_wall", "Bounce off a wall")

	# Methods
	domain.add_method("gentle_move", "move_toward_goal", ["apply_force_small", "wait_physics"])
	domain.add_method("aggressive_move", "move_toward_goal", ["apply_force_large", "wait_physics"])
	domain.add_method("cardinal_north", "move_toward_goal", ["apply_impulse_north", "wait_physics"])
	domain.add_method("cardinal_south", "move_toward_goal", ["apply_impulse_south", "wait_physics"])
	domain.add_method("cardinal_east", "move_toward_goal", ["apply_impulse_east", "wait_physics"])
	domain.add_method("cardinal_west", "move_toward_goal", ["apply_impulse_west", "wait_physics"])

	domain.add_method("gentle_stop", "stop_at_goal", ["apply_force_small", "wait_physics"])
	domain.add_method("bounce_reverse", "bounce_off_wall", ["apply_force_medium", "wait_physics"])

	return domain
