## Delegation System - Hierarchical Spawning with Desperation Scale
##
## Implements hierarchical task delegation with a desperation scale.
## Based on the Meeseeks AGI pattern of escalating to higher-level agents.
##
## Desperation Scale:
## 1 = Try simple approaches
## 2 = Try moderate approaches
## 3 = Try complex approaches
## 4 = Ask for help / spawn subtask
## 5 = Emergency - try anything
##
## Usage:
##   var delegation = DelegationSystem.new()
##   if delegation.should_delegate(task):
##       var subtask = delegation.spawn_subtask(task)
##   delegation.escalate()  # Increase desperation
##
class_name DelegationSystem
extends RefCounted

## Current desperation level (1-5)
var desperation_level: int = 1

## Maximum desperation level
var max_desperation: int = 5

## Maximum subtask depth
var max_depth: int = 5

## Current subtask depth
var current_depth: int = 0

## Subtask history
var subtask_history: Array = []

## Maximum history size
var max_history: int = 50

## Success threshold to decrease desperation
var success_threshold: int = 3

## Consecutive successes counter
var consecutive_successes: int = 0

## Evaluation depth multipliers per desperation level
var evaluation_depths: Dictionary = {
	1: 10,   # Quick evaluation
	2: 25,   # Standard evaluation
	3: 50,   # Deep evaluation
	4: 100,  # Exhaustive evaluation
	5: 200   # Maximum evaluation
}

## Signal emitted when subtask is spawned
signal subtask_spawned(subtask_id: String, task: String, level: int)
## Signal emitted when desperation level changes
signal desperation_changed(old_level: int, new_level: int)
## Signal emitted when delegation fails
signal delegation_failed(task: String, reason: String)

## Internal subtask structure
class Subtask:
	var id: String
	var task: String
	var parent_id: String
	var depth: int
	var desperation_at_spawn: int
	var status: String = "pending"  # pending, running, success, failed
	var result: Dictionary = {}
	var created_at: int
	var completed_at: int = 0

	func _init(i: String, t: String, p: String, d: int, des: int):
		id = i
		task = t
		parent_id = p
		depth = d
		desperation_at_spawn = des
		created_at = Time.get_ticks_msec()

## Spawn a subtask
## @param task: The task to delegate
## @param level: Optional starting desperation level
## @returns Subtask dictionary
func spawn_subtask(task: String, level: int = -1) -> Dictionary:
	if current_depth >= max_depth:
		delegation_failed.emit(task, "Maximum delegation depth reached")
		return {"success": false, "reason": "max_depth_exceeded"}

	var spawn_level = level if level > 0 else desperation_level
	var subtask_id = _generate_subtask_id()

	var subtask = Subtask.new(subtask_id, task, _get_current_parent_id(), current_depth + 1, spawn_level)
	subtask.status = "running"

	subtask_history.append(subtask)
	if subtask_history.size() > max_history:
		subtask_history.pop_front()

	current_depth += 1
	subtask_spawned.emit(subtask_id, task, spawn_level)

	return {
		"success": true,
		"subtask_id": subtask_id,
		"task": task,
		"depth": current_depth,
		"desperation": spawn_level
	}

## Complete a subtask
func complete_subtask(subtask_id: String, success: bool, result: Dictionary = {}) -> void:
	for subtask in subtask_history:
		if subtask.id == subtask_id:
			subtask.status = "success" if success else "failed"
			subtask.result = result
			subtask.completed_at = Time.get_ticks_msec()
			current_depth = max(0, current_depth - 1)

			if success:
				_handle_success()
			else:
				_handle_failure()
			break

## Handle successful subtask
func _handle_success() -> void:
	consecutive_successes += 1

	# Decrease desperation after consecutive successes
	if consecutive_successes >= success_threshold and desperation_level > 1:
		var old = desperation_level
		desperation_level = max(1, desperation_level - 1)
		consecutive_successes = 0
		desperation_changed.emit(old, desperation_level)

## Handle failed subtask
func _handle_failure() -> void:
	consecutive_successes = 0

## Escalate desperation level
func escalate() -> void:
	if desperation_level < max_desperation:
		var old = desperation_level
		desperation_level += 1
		desperation_changed.emit(old, desperation_level)

## De-escalate desperation level
func de_escalate() -> void:
	if desperation_level > 1:
		var old = desperation_level
		desperation_level -= 1
		desperation_changed.emit(old, desperation_level)

## Reset desperation to minimum
func reset_desperation() -> void:
	var old = desperation_level
	desperation_level = 1
	consecutive_successes = 0
	if old != desperation_level:
		desperation_changed.emit(old, desperation_level)

## Check if task should be delegated
## @param task: The task to check
## @param attempts: Number of attempts made so far
## @returns True if should delegate
func should_delegate(task: String, attempts: int = 0) -> bool:
	# Check depth limit
	if current_depth >= max_depth:
		return false

	# Delegate if desperation is high and attempts are failing
	if desperation_level >= 4 and attempts >= 3:
		return true

	# Delegate if task complexity is high
	if _is_complex_task(task) and desperation_level >= 3:
		return true

	# Always delegate at maximum desperation
	if desperation_level >= max_desperation:
		return true

	return false

## Check if task is complex
func _is_complex_task(task: String) -> bool:
	var complex_keywords = ["multi", "compound", "hierarchical", "parallel", "coordinate"]
	task = task.to_lower()
	for keyword in complex_keywords:
		if keyword in task:
			return true
	return false

## Get evaluation depth for current desperation
func get_evaluation_depth() -> int:
	return evaluation_depths.get(desperation_level, 50)

## Get approach strategy for current desperation
func get_approach_strategy() -> String:
	match desperation_level:
		1:
			return "simple"  # Try simplest approach
		2:
			return "standard"  # Try standard approaches
		3:
			return "thorough"  # Try multiple approaches
		4:
			return "exhaustive"  # Try all approaches
		5:
			return "emergency"  # Try anything, accept partial success
		_:
			return "standard"

## Generate subtask ID
func _generate_subtask_id() -> String:
	return "subtask_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

## Get current parent ID
func _get_current_parent_id() -> String:
	if subtask_history.is_empty():
		return "root"
	# Find most recent running subtask
	for i in range(subtask_history.size() - 1, -1, -1):
		if subtask_history[i].status == "running":
			return subtask_history[i].id
	return "root"

## Get active subtasks
func get_active_subtasks() -> Array:
	var active: Array = []
	for subtask in subtask_history:
		if subtask.status == "running":
			active.append(subtask)
	return active

## Get subtask tree
func get_subtask_tree() -> Dictionary:
	var tree: Dictionary = {"root": {"children": []}}

	for subtask in subtask_history:
		var node = {
			"id": subtask.id,
			"task": subtask.task,
			"status": subtask.status,
			"children": []
		}

		if subtask.parent_id == "root":
			tree.root.children.append(node)
		else:
			_find_and_add_child(tree.root, subtask.parent_id, node)

	return tree

## Find and add child to tree
func _find_and_add_child(parent: Dictionary, target_id: String, child: Dictionary) -> bool:
	for node in parent.children:
		if node.id == target_id:
			node.children.append(child)
			return true
		if _find_and_add_child(node, target_id, child):
			return true
	return false

## Get delegation statistics
func get_stats() -> Dictionary:
	var total = subtask_history.size()
	var successes = 0
	var failures = 0
	var pending = 0

	for subtask in subtask_history:
		match subtask.status:
			"success":
				successes += 1
			"failed":
				failures += 1
			_, "pending", "running":
				pending += 1

	return {
		"desperation_level": desperation_level,
		"current_depth": current_depth,
		"total_subtasks": total,
		"successes": successes,
		"failures": failures,
		"pending": pending,
		"success_rate": float(successes) / float(total) if total > 0 else 0.0,
		"consecutive_successes": consecutive_successes
	}

## Get suggested actions for current state
func get_suggested_actions() -> Array:
	var suggestions: Array = []

	match desperation_level:
		1:
			suggestions.append("Try simple approach first")
			suggestions.append("Use default parameters")
		2:
			suggestions.append("Try alternative approaches")
			suggestions.append("Adjust parameters moderately")
		3:
			suggestions.append("Consider multiple strategies")
			suggestions.append("Evaluate more branches")
			suggestions.append("Check for patterns")
		4:
			suggestions.append("Spawn subtask for parallel exploration")
			suggestions.append("Try unconventional approaches")
			suggestions.append("Request additional resources")
		5:
			suggestions.append("Try any approach that might work")
			suggestions.append("Accept partial success")
			suggestions.append("Escalate to higher authority")
			suggestions.append("Consider task modification")

	return suggestions

## Convert to prompt block for AI
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== DELEGATION STATUS ===")

	var stats = get_stats()
	lines.append("Desperation: %d/%d (%s strategy)" % [
		desperation_level, max_desperation, get_approach_strategy()
	])
	lines.append("Depth: %d/%d" % [current_depth, max_depth])
	lines.append("Evaluation depth: %d branches" % get_evaluation_depth())
	lines.append("")
	lines.append("STATS:")
	lines.append("  Subtasks: %d total, %d success, %d failed, %d pending" % [
		stats.total_subtasks, stats.successes, stats.failures, stats.pending
	])
	lines.append("  Success rate: %.1f%%" % [stats.success_rate * 100])

	var suggestions = get_suggested_actions()
	if not suggestions.is_empty():
		lines.append("")
		lines.append("SUGGESTED ACTIONS:")
		for s in suggestions:
			lines.append("  - %s" % s)

	return "\n".join(lines)

## Export to dictionary
func to_dict() -> Dictionary:
	var history_data: Array = []
	for subtask in subtask_history:
		history_data.append({
			"id": subtask.id,
			"task": subtask.task,
			"parent_id": subtask.parent_id,
			"depth": subtask.depth,
			"desperation_at_spawn": subtask.desperation_at_spawn,
			"status": subtask.status,
			"result": subtask.result,
			"created_at": subtask.created_at,
			"completed_at": subtask.completed_at
		})

	return {
		"desperation_level": desperation_level,
		"max_desperation": max_desperation,
		"max_depth": max_depth,
		"current_depth": current_depth,
		"subtask_history": history_data,
		"max_history": max_history,
		"success_threshold": success_threshold,
		"consecutive_successes": consecutive_successes,
		"evaluation_depths": evaluation_depths.duplicate()
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/cognitive/delegation.gd")
	var ds = script.new()
	ds.desperation_level = data.get("desperation_level", 1)
	ds.max_desperation = data.get("max_desperation", 5)
	ds.max_depth = data.get("max_depth", 5)
	ds.current_depth = data.get("current_depth", 0)
	ds.max_history = data.get("max_history", 50)
	ds.success_threshold = data.get("success_threshold", 3)
	ds.consecutive_successes = data.get("consecutive_successes", 0)
	ds.evaluation_depths = data.get("evaluation_depths", ds.evaluation_depths).duplicate()

	for subtask_data in data.get("subtask_history", []):
		var subtask = Subtask.new(
			subtask_data.id,
			subtask_data.task,
			subtask_data.parent_id,
			subtask_data.depth,
			subtask_data.desperation_at_spawn
		)
		subtask.status = subtask_data.get("status", "pending")
		subtask.result = subtask_data.get("result", {})
		subtask.created_at = subtask_data.get("created_at", Time.get_ticks_msec())
		subtask.completed_at = subtask_data.get("completed_at", 0)
		ds.subtask_history.append(subtask)

	return ds

## Create delegation system with custom settings
static func create_with_settings(max_desp: int, max_d: int, success_thresh: int) -> Variant:
	var script = preload("res://addons/awr/cognitive/delegation.gd")
	var ds = script.new()
	ds.max_desperation = max_desp
	ds.max_depth = max_d
	ds.success_threshold = success_thresh
	return ds
