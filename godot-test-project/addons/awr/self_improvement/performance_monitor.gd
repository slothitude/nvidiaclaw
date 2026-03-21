## Performance Monitor - Track Task Success Rates
##
## Monitors task execution and tracks success/failure patterns.
## Provides metrics for the self-improvement system.
##
## Usage:
##   var monitor = PerformanceMonitor.new()
##   monitor.record_task("task_1", true, 3, ["tool_a", "tool_b"])
##   var rate = monitor.get_success_rate(60000)  # Last 60 seconds
##   if monitor.detect_degradation():
##       print("Performance is declining!")
##
class_name PerformanceMonitor
extends RefCounted

## Maximum history size
var max_history: int = 1000

## Task execution history
var task_history: Array = []

## Current active tasks (for timing)
var active_tasks: Dictionary = {}

## Signal emitted when degradation is detected
signal degradation_detected(current_rate: float, previous_rate: float)
## Signal emitted when a task is recorded
signal task_recorded(task_id: String, success: bool, attempts: int)

## Internal task record structure
class TaskRecord:
	var task_id: String
	var success: bool
	var attempts: int
	var tools: Array
	var start_time: int
	var end_time: int
	var duration_ms: int
	var metadata: Dictionary

	func _init(tid: String, s: bool, a: int, t: Array):
		task_id = tid
		success = s
		attempts = a
		tools = t
		start_time = Time.get_ticks_msec()
		end_time = start_time
		duration_ms = 0
		metadata = {}

## Record a completed task
## @param task_id: Unique identifier for the task
## @param success: Whether the task succeeded
## @param attempts: Number of attempts made
## @param tools: Array of tool names used
## @param metadata: Additional metadata
func record_task(task_id: String, success: bool, attempts: int, tools: Array, metadata: Dictionary = {}) -> void:
	var record = TaskRecord.new(task_id, success, attempts, tools)
	record.metadata = metadata
	record.end_time = Time.get_ticks_msec()

	task_history.append(record)

	# Maintain history limit
	if task_history.size() > max_history:
		task_history.pop_front()

	task_recorded.emit(task_id, success, attempts)

## Start tracking a task (for duration measurement)
func start_task(task_id: String, metadata: Dictionary = {}) -> void:
	active_tasks[task_id] = {
		"start_time": Time.get_ticks_msec(),
		"metadata": metadata
	}

## End tracking a task
func end_task(task_id: String, success: bool, attempts: int = 1, tools: Array = []) -> void:
	if not active_tasks.has(task_id):
		record_task(task_id, success, attempts, tools)
		return

	var task_data = active_tasks[task_id]
	var start_time = task_data.start_time

	var record = TaskRecord.new(task_id, success, attempts, tools)
	record.start_time = start_time
	record.end_time = Time.get_ticks_msec()
	record.duration_ms = record.end_time - start_time
	record.metadata = task_data.metadata

	task_history.append(record)
	active_tasks.erase(task_id)

	if task_history.size() > max_history:
		task_history.pop_front()

	task_recorded.emit(task_id, success, attempts)

## Get success rate within a time window
## @param time_window_ms: Time window in milliseconds
## @returns Success rate (0.0 to 1.0)
func get_success_rate(time_window_ms: int = 60000) -> float:
	var cutoff = Time.get_ticks_msec() - time_window_ms
	var successes = 0
	var total = 0

	for record in task_history:
		if record.end_time >= cutoff:
			total += 1
			if record.success:
				successes += 1

	if total == 0:
		return 1.0  # No tasks = perfect rate

	return float(successes) / float(total)

## Get average attempts per task
func get_average_attempts(time_window_ms: int = 60000) -> float:
	var cutoff = Time.get_ticks_msec() - time_window_ms
	var total_attempts = 0
	var count = 0

	for record in task_history:
		if record.end_time >= cutoff:
			total_attempts += record.attempts
			count += 1

	if count == 0:
		return 1.0

	return float(total_attempts) / float(count)

## Get average task duration
func get_average_duration(time_window_ms: int = 60000) -> float:
	var cutoff = Time.get_ticks_msec() - time_window_ms
	var total_duration = 0
	var count = 0

	for record in task_history:
		if record.end_time >= cutoff and record.duration_ms > 0:
			total_duration += record.duration_ms
			count += 1

	if count == 0:
		return 0.0

	return float(total_duration) / float(count)

## Detect performance degradation
## @param threshold: Minimum drop to consider degradation (default 0.2 = 20%)
## @returns True if performance is declining
func detect_degradation(threshold: float = 0.2) -> bool:
	if task_history.size() < 10:
		return false

	# Compare first half vs second half
	var mid = task_history.size() / 2
	var first_half_success = 0
	var first_half_total = 0
	var second_half_success = 0
	var second_half_total = 0

	for i in range(task_history.size()):
		var record: TaskRecord = task_history[i]
		if i < mid:
			first_half_total += 1
			if record.success:
				first_half_success += 1
		else:
			second_half_total += 1
			if record.success:
				second_half_success += 1

	if first_half_total == 0 or second_half_total == 0:
		return false

	var first_rate = float(first_half_success) / float(first_half_total)
	var second_rate = float(second_half_success) / float(second_half_total)

	if second_rate < first_rate - threshold:
		# Check if we haven't already emitted for this degradation
		degradation_detected.emit(second_rate, first_rate)
		return true

	return false

## Get tool usage statistics
func get_tool_stats(time_window_ms: int = 60000) -> Dictionary:
	var cutoff = Time.get_ticks_msec() - time_window_ms
	var stats: Dictionary = {}

	for record in task_history:
		if record.end_time >= cutoff:
			for tool in record.tools:
				if not stats.has(tool):
					stats[tool] = {"uses": 0, "successes": 0}
				stats[tool].uses += 1
				if record.success:
					stats[tool].successes += 1

	# Calculate success rates
	for tool in stats:
		stats[tool].success_rate = float(stats[tool].successes) / float(stats[tool].uses)

	return stats

## Get recent failures
func get_recent_failures(count: int = 10, time_window_ms: int = 300000) -> Array:
	var cutoff = Time.get_ticks_msec() - time_window_ms
	var failures: Array = []

	for record in task_history:
		if record.end_time >= cutoff and not record.success:
			failures.append({
				"task_id": record.task_id,
				"attempts": record.attempts,
				"tools": record.tools,
				"timestamp": record.end_time,
				"metadata": record.metadata
			})

	# Sort by timestamp (most recent first)
	failures.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	# Limit count
	if failures.size() > count:
		failures = failures.slice(0, count)

	return failures

## Get metrics summary
func get_metrics(time_window_ms: int = 60000) -> Dictionary:
	return {
		"success_rate": get_success_rate(time_window_ms),
		"average_attempts": get_average_attempts(time_window_ms),
		"average_duration_ms": get_average_duration(time_window_ms),
		"total_tasks": _count_tasks(time_window_ms),
		"tool_stats": get_tool_stats(time_window_ms),
		"is_degrading": detect_degradation()
	}

## Count tasks in time window
func _count_tasks(time_window_ms: int) -> int:
	var cutoff = Time.get_ticks_msec() - time_window_ms
	var count = 0
	for record in task_history:
		if record.end_time >= cutoff:
			count += 1
	return count

## Clear history
func clear_history() -> void:
	task_history.clear()
	active_tasks.clear()

## Export to dictionary
func to_dict() -> Dictionary:
	var history_data: Array = []
	for record in task_history:
		history_data.append({
			"task_id": record.task_id,
			"success": record.success,
			"attempts": record.attempts,
			"tools": record.tools,
			"start_time": record.start_time,
			"end_time": record.end_time,
			"duration_ms": record.duration_ms,
			"metadata": record.metadata
		})

	return {
		"max_history": max_history,
		"task_history": history_data
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/self_improvement/performance_monitor.gd")
	var pm = script.new()
	pm.max_history = data.get("max_history", 1000)

	for record_data in data.get("task_history", []):
		var record = TaskRecord.new(
			record_data.task_id,
			record_data.success,
			record_data.attempts,
			record_data.tools
		)
		record.start_time = record_data.get("start_time", Time.get_ticks_msec())
		record.end_time = record_data.get("end_time", record.start_time)
		record.duration_ms = record_data.get("duration_ms", 0)
		record.metadata = record_data.get("metadata", {})
		pm.task_history.append(record)

	return pm
