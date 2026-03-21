## Pattern Analyzer - Identify Success and Failure Patterns
##
## Analyzes task history to identify patterns that lead to success or failure.
## Provides insights for the strategy generator.
##
## Usage:
##   var analyzer = PatternAnalyzer.new(performance_monitor)
##   var patterns = analyzer.analyze()
##   var failures = analyzer.get_failure_patterns()
##   var successes = analyzer.get_success_patterns()
##
class_name PatternAnalyzer
extends RefCounted

## Reference to performance monitor
var monitor: Variant

## Minimum sample size for pattern detection
var min_sample_size: int = 5

## Confidence threshold for patterns
var confidence_threshold: float = 0.7

## Detected patterns cache
var _patterns: Dictionary = {}
var _last_analysis_time: int = 0

## Analysis cache duration (ms)
var cache_duration: int = 10000

## Signal emitted when a new pattern is detected
signal pattern_detected(pattern_type: String, pattern_data: Dictionary)

func _init(monitor_ref: Variant) -> void:
	monitor = monitor_ref

## Run full pattern analysis
## @returns Dictionary of detected patterns
func analyze() -> Dictionary:
	var current_time = Time.get_ticks_msec()

	# Use cache if recent
	if current_time - _last_analysis_time < cache_duration and not _patterns.is_empty():
		return _patterns

	_patterns = {
		"success_patterns": _analyze_success_patterns(),
		"failure_patterns": _analyze_failure_patterns(),
		"tool_patterns": _analyze_tool_patterns(),
		"temporal_patterns": _analyze_temporal_patterns(),
		"sequence_patterns": _analyze_sequence_patterns()
	}

	_last_analysis_time = current_time
	return _patterns

## Analyze patterns that lead to success
func _analyze_success_patterns() -> Array:
	var patterns: Array = []
	var history = monitor.task_history

	if history.size() < min_sample_size:
		return patterns

	# Group successful tasks by characteristics
	var success_groups: Dictionary = {}

	for record in history:
		if not record.success:
			continue

		# Create a signature based on tools and attempts
		var sig = _create_signature(record)
		if not success_groups.has(sig):
			success_groups[sig] = []
		success_groups[sig].append(record)

	# Find patterns with high confidence
	for sig in success_groups:
		var group = success_groups[sig]
		if group.size() >= min_sample_size:
			var rate = float(group.size()) / float(_count_similar_tasks(sig, history))
			if rate >= confidence_threshold:
				var pattern = {
					"signature": sig,
					"count": group.size(),
					"success_rate": rate,
					"avg_attempts": _average_attempts(group),
					"avg_duration": _average_duration(group),
					"sample_records": group.slice(0, 3)
				}
				patterns.append(pattern)
				pattern_detected.emit("success", pattern)

	return patterns

## Analyze patterns that lead to failure
func _analyze_failure_patterns() -> Array:
	var patterns: Array = []
	var history = monitor.task_history

	if history.size() < min_sample_size:
		return patterns

	# Group failed tasks by characteristics
	var failure_groups: Dictionary = {}

	for record in history:
		if record.success:
			continue

		var sig = _create_signature(record)
		if not failure_groups.has(sig):
			failure_groups[sig] = []
		failure_groups[sig].append(record)

	# Find patterns with high failure rate
	for sig in failure_groups:
		var group = failure_groups[sig]
		if group.size() >= min_sample_size:
			var total_similar = _count_similar_tasks(sig, history)
			var failure_rate = float(group.size()) / float(total_similar)
			if failure_rate >= confidence_threshold:
				var pattern = {
					"signature": sig,
					"count": group.size(),
					"failure_rate": failure_rate,
					"avg_attempts": _average_attempts(group),
					"common_errors": _extract_common_errors(group),
					"sample_records": group.slice(0, 3)
				}
				patterns.append(pattern)
				pattern_detected.emit("failure", pattern)

	return patterns

## Analyze tool effectiveness
func _analyze_tool_patterns() -> Array:
	var patterns: Array = []
	var tool_stats = monitor.get_tool_stats()

	for tool in tool_stats:
		var stats = tool_stats[tool]
		if stats.uses >= min_sample_size:
			var pattern = {
				"tool": tool,
				"uses": stats.uses,
				"successes": stats.successes,
				"success_rate": stats.success_rate,
				"effectiveness": "high" if stats.success_rate > 0.8 else "medium" if stats.success_rate > 0.5 else "low"
			}
			patterns.append(pattern)

	# Sort by success rate
	patterns.sort_custom(func(a, b): return a.success_rate > b.success_rate)

	return patterns

## Analyze temporal patterns (time-based)
func _analyze_temporal_patterns() -> Array:
	var patterns: Array = []
	var history = monitor.task_history

	if history.size() < min_sample_size:
		return patterns

	# Analyze success rate by time of day (hour buckets)
	var hourly: Dictionary = {}
	for i in range(24):
		hourly[i] = {"successes": 0, "failures": 0}

	for record in history:
		var hour = Time.get_datetime_dict_from_unix_time(record.end_time / 1000).hour
		if record.success:
			hourly[hour].successes += 1
		else:
			hourly[hour].failures += 1

	# Find hours with notably high/low success rates
	for hour in hourly:
		var total = hourly[hour].successes + hourly[hour].failures
		if total >= min_sample_size:
			var rate = float(hourly[hour].successes) / float(total)
			if rate > 0.8 or rate < 0.5:
				patterns.append({
					"type": "temporal",
					"hour": hour,
					"total_tasks": total,
					"success_rate": rate,
					"trend": "high" if rate > 0.8 else "low"
				})

	return patterns

## Analyze task sequences
func _analyze_sequence_patterns() -> Array:
	var patterns: Array = []
	var history = monitor.task_history

	if history.size() < min_sample_size * 2:
		return patterns

	# Look for sequences: what task typically follows another
	var transitions: Dictionary = {}

	for i in range(1, history.size()):
		var prev = history[i - 1]
		var curr = history[i]

		var key = "%s -> %s" % [prev.task_id.split("_")[0], curr.task_id.split("_")[0]]
		if not transitions.has(key):
			transitions[key] = {"count": 0, "success_after": 0}

		transitions[key].count += 1
		if curr.success:
			transitions[key].success_after += 1

	# Find common transitions
	for key in transitions:
		var t = transitions[key]
		if t.count >= min_sample_size:
			var rate = float(t.success_after) / float(t.count)
			patterns.append({
				"transition": key,
				"count": t.count,
				"success_rate_after": rate
			})

	# Sort by count
	patterns.sort_custom(func(a, b): return a.count > b.count)

	return patterns

## Create a signature for a task record
func _create_signature(record) -> String:
	var parts: Array = []
	parts.append(str(record.attempts))
	parts.append("|".join(record.tools))
	return "|".join(parts)

## Count tasks with similar signature
func _count_similar_tasks(signature: String, history: Array) -> int:
	var count = 0
	for record in history:
		if _create_signature(record) == signature:
			count += 1
	return count

## Calculate average attempts for a group
func _average_attempts(records: Array) -> float:
	if records.is_empty():
		return 0.0
	var total = 0
	for r in records:
		total += r.attempts
	return float(total) / float(records.size())

## Calculate average duration for a group
func _average_duration(records: Array) -> float:
	if records.is_empty():
		return 0.0
	var total = 0
	for r in records:
		total += r.duration_ms
	return float(total) / float(records.size())

## Extract common error patterns from failed records
func _extract_common_errors(records: Array) -> Array:
	var errors: Array = []
	for r in records:
		if r.metadata.has("error"):
			errors.append(r.metadata.error)
		elif r.metadata.has("reason"):
			errors.append(r.metadata.reason)
	return errors

## Get failure patterns (convenience method)
func get_failure_patterns() -> Array:
	var analysis = analyze()
	return analysis.get("failure_patterns", [])

## Get success patterns (convenience method)
func get_success_patterns() -> Array:
	var analysis = analyze()
	return analysis.get("success_patterns", [])

## Get tool patterns (convenience method)
func get_tool_patterns() -> Array:
	var analysis = analyze()
	return analysis.get("tool_patterns", [])

## Get recommendations based on analysis
func get_recommendations() -> Array:
	var recommendations: Array = []
	var analysis = analyze()

	# Tool recommendations
	for tp in analysis.get("tool_patterns", []):
		if tp.effectiveness == "low" and tp.uses > 10:
			recommendations.append({
				"type": "tool_avoid",
				"tool": tp.tool,
				"reason": "Low success rate (%.1f%%) over %d uses" % [tp.success_rate * 100, tp.uses]
			})
		elif tp.effectiveness == "high" and tp.uses > 5:
			recommendations.append({
				"type": "tool_prefer",
				"tool": tp.tool,
				"reason": "High success rate (%.1f%%) over %d uses" % [tp.success_rate * 100, tp.uses]
			})

	# Failure pattern recommendations
	for fp in analysis.get("failure_patterns", []):
		recommendations.append({
			"type": "pattern_avoid",
			"pattern": fp.signature,
			"reason": "High failure rate (%.1f%%) - %d failures" % [fp.failure_rate * 100, fp.count]
		})

	return recommendations

## Convert analysis to prompt block for AI
func to_prompt_block() -> String:
	var analysis = analyze()
	var lines: Array = []
	lines.append("=== PATTERN ANALYSIS ===")

	# Success patterns
	lines.append("SUCCESS PATTERNS:")
	var sp = analysis.get("success_patterns", [])
	if sp.is_empty():
		lines.append("  (none detected)")
	else:
		for p in sp.slice(0, 5):
			lines.append("  %s - %.1f%% success (%d samples)" % [
				p.signature, p.success_rate * 100, p.count
			])

	# Failure patterns
	lines.append("")
	lines.append("FAILURE PATTERNS:")
	var fp = analysis.get("failure_patterns", [])
	if fp.is_empty():
		lines.append("  (none detected)")
	else:
		for p in fp.slice(0, 5):
			lines.append("  %s - %.1f%% failure (%d samples)" % [
				p.signature, p.failure_rate * 100, p.count
			])

	# Tool effectiveness
	lines.append("")
	lines.append("TOOL EFFECTIVENESS:")
	var tp = analysis.get("tool_patterns", [])
	if tp.is_empty():
		lines.append("  (no data)")
	else:
		for p in tp.slice(0, 5):
			lines.append("  %s: %.1f%% (%s) - %d uses" % [
				p.tool, p.success_rate * 100, p.effectiveness, p.uses
			])

	return "\n".join(lines)

## Export to dictionary
func to_dict() -> Dictionary:
	return {
		"min_sample_size": min_sample_size,
		"confidence_threshold": confidence_threshold,
		"patterns": _patterns.duplicate(true),
		"last_analysis_time": _last_analysis_time
	}

## Load from dictionary
static func from_dict(data: Dictionary, monitor_ref: Variant) -> Variant:
	var script = preload("res://addons/awr/self_improvement/pattern_analyzer.gd")
	var pa = script.new(monitor_ref)
	pa.min_sample_size = data.get("min_sample_size", 5)
	pa.confidence_threshold = data.get("confidence_threshold", 0.7)
	pa._patterns = data.get("patterns", {}).duplicate(true)
	pa._last_analysis_time = data.get("last_analysis_time", 0)
	return pa
