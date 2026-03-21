## Validator - Test Improvements Safely
##
## Validates proposed strategies before full adoption.
## Runs tests in simulation to verify improvements.
##
## Usage:
##   var validator = Validator.new(performance_monitor)
##   var result = validator.validate_strategy(strategy, test_cases)
##   if result.valid:
##       validator.approve(strategy.id)
##
class_name Validator
extends RefCounted

## Reference to performance monitor for baseline comparison
var monitor: Variant

## Number of test iterations per strategy
var test_iterations: int = 10

## Minimum improvement threshold to consider valid
var improvement_threshold: float = 0.1

## Validation results cache
var _validation_results: Dictionary = {}

## Approved strategies
var _approved: Dictionary = {}

## Rejected strategies
var _rejected: Dictionary = {}

## Signal emitted when validation completes
signal validation_complete(strategy_id: String, result: Dictionary)
## Signal emitted when strategy is approved
signal strategy_approved(strategy_id: String, improvement: float)
## Signal emitted when strategy is rejected
signal strategy_rejected(strategy_id: String, reason: String)

func _init(monitor_ref: Variant) -> void:
	monitor = monitor_ref

## Validate a strategy
## @param strategy: Strategy dictionary to validate
## @param test_func: Callable that executes the strategy and returns success bool
## @returns Validation result dictionary
func validate_strategy(strategy: Dictionary, test_func: Callable) -> Dictionary:
	var strategy_id = strategy.get("id", "unknown")

	# Check cache
	if _validation_results.has(strategy_id):
		return _validation_results[strategy_id]

	var baseline_rate = monitor.get_success_rate(60000)
	var successes = 0
	var total_attempts = 0

	for i in range(test_iterations):
		var result = test_func.call(strategy)
		total_attempts += 1
		if result:
			successes += 1

	var test_success_rate = float(successes) / float(total_attempts) if total_attempts > 0 else 0.0
	var improvement = test_success_rate - baseline_rate

	var result = {
		"strategy_id": strategy_id,
		"valid": improvement >= improvement_threshold,
		"baseline_rate": baseline_rate,
		"test_rate": test_success_rate,
		"improvement": improvement,
		"iterations": test_iterations,
		"confidence": _calculate_confidence(total_attempts, successes),
		"timestamp": Time.get_ticks_msec()
	}

	_validation_results[strategy_id] = result
	validation_complete.emit(strategy_id, result)

	return result

## Validate strategy with simulation
## @param strategy: Strategy to validate
## @param sim_loop: SimLoop instance for testing
## @param world_state: Initial world state
## @returns Validation result
func validate_with_simulation(strategy: Dictionary, sim_loop: Variant, world_state: Variant) -> Dictionary:
	var strategy_id = strategy.get("id", "unknown")
	var baseline_rate = monitor.get_success_rate(60000)

	var test_scores: Array = []

	for i in range(test_iterations):
		# Clone world state for testing
		var test_world = world_state.clone() if world_state.has_method("clone") else world_state

		# Apply strategy-specific modifications
		var modified_world = _apply_strategy_to_world(strategy, test_world)

		# Run simulation
		var result = sim_loop.run(modified_world, [])
		if result.has("score"):
			test_scores.append(result.score)

	var avg_test_score = _average(test_scores) if test_scores.size() > 0 else 0.0
	var improvement = avg_test_score - baseline_rate

	var result = {
		"strategy_id": strategy_id,
		"valid": improvement >= improvement_threshold,
		"baseline_rate": baseline_rate,
		"test_score": avg_test_score,
		"improvement": improvement,
		"iterations": test_iterations,
		"scores": test_scores,
		"timestamp": Time.get_ticks_msec()
	}

	_validation_results[strategy_id] = result
	validation_complete.emit(strategy_id, result)

	return result

## Quick validation without full simulation
func quick_validate(strategy: Dictionary) -> Dictionary:
	var strategy_id = strategy.get("id", "unknown")

	# Check if strategy type is known to be safe
	var safe_types = ["tool_preference", "parameter_tuning", "pattern_adoption"]
	var risky_types = ["tool_avoidance", "pattern_avoidance"]

	var confidence = strategy.get("confidence", 0.0)
	var type = strategy.get("type", "")

	var is_safe = type in safe_types
	var is_risky = type in risky_types

	var result = {
		"strategy_id": strategy_id,
		"valid": confidence >= 0.7 or (is_safe and confidence >= 0.5),
		"needs_full_validation": is_risky or confidence < 0.7,
		"risk_level": "low" if is_safe else "medium" if not is_risky else "high",
		"confidence": confidence,
		"timestamp": Time.get_ticks_msec()
	}

	return result

## Apply strategy to world state (for simulation)
func _apply_strategy_to_world(strategy: Dictionary, world_state: Variant) -> Variant:
	var type = strategy.get("type", "")

	match type:
		"tool_preference":
			# Mark preferred tool in world state metadata
			if world_state.has_method("set_metadata"):
				world_state.set_metadata("preferred_tool", strategy.get("tool", ""))

		"parameter_tuning":
			# Apply parameter changes
			if world_state.has_method("set_parameter"):
				world_state.set_parameter(
					strategy.get("parameter", ""),
					strategy.get("recommended_value", null)
				)

		"pattern_adoption":
			# Add pattern to world state behavior
			if world_state.has_method("add_pattern"):
				world_state.add_pattern(strategy.get("pattern", ""))

	return world_state

## Calculate confidence from test results
func _calculate_confidence(total: int, successes: int) -> float:
	if total == 0:
		return 0.0
	# Wilson score interval lower bound (simplified)
	var p = float(successes) / float(total)
	var n = float(total)
	var z = 1.96  # 95% confidence

	var denominator = 1.0 + z * z / n
	var center = p + z * z / (2.0 * n)
	var spread = z * sqrt((p * (1.0 - p) + z * z / (4.0 * n)) / n)

	var lower = (center - spread) / denominator
	return max(0.0, lower)

## Calculate average of array
func _average(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for v in arr:
		total += float(v)
	return total / float(arr.size())

## Approve a validated strategy
func approve(strategy_id: String) -> bool:
	if not _validation_results.has(strategy_id):
		return false

	var result = _validation_results[strategy_id]
	if not result.valid:
		return false

	_approved[strategy_id] = {
		"result": result,
		"approved_at": Time.get_ticks_msec()
	}

	strategy_approved.emit(strategy_id, result.improvement)
	return true

## Reject a strategy
func reject(strategy_id: String, reason: String = "") -> void:
	_rejected[strategy_id] = {
		"reason": reason,
		"rejected_at": Time.get_ticks_msec()
	}

	strategy_rejected.emit(strategy_id, reason)

## Check if strategy is approved
func is_approved(strategy_id: String) -> bool:
	return _approved.has(strategy_id)

## Check if strategy is rejected
func is_rejected(strategy_id: String) -> bool:
	return _rejected.has(strategy_id)

## Get validation result
func get_result(strategy_id: String) -> Dictionary:
	return _validation_results.get(strategy_id, {})

## Get all approved strategies
func get_approved() -> Dictionary:
	return _approved.duplicate()

## Get all rejected strategies
func get_rejected() -> Dictionary:
	return _rejected.duplicate()

## Clear validation cache
func clear_cache() -> void:
	_validation_results.clear()

## Get validation summary
func get_summary() -> Dictionary:
	return {
		"total_validated": _validation_results.size(),
		"approved": _approved.size(),
		"rejected": _rejected.size(),
		"pending": _validation_results.size() - _approved.size() - _rejected.size()
	}

## Batch validate multiple strategies
func batch_validate(strategies: Array, test_func: Callable) -> Dictionary:
	var results: Dictionary = {}

	for strategy in strategies:
		var strategy_id = strategy.get("id", "unknown")
		results[strategy_id] = validate_strategy(strategy, test_func)

	return {
		"results": results,
		"valid_count": _count_valid(results),
		"total_count": strategies.size()
	}

## Count valid results
func _count_valid(results: Dictionary) -> int:
	var count = 0
	for id in results:
		if results[id].get("valid", false):
			count += 1
	return count

## Convert to prompt block for AI
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== VALIDATION STATUS ===")

	var summary = get_summary()
	lines.append("Summary: %d validated, %d approved, %d rejected" % [
		summary.total_validated, summary.approved, summary.rejected
	])

	if not _approved.is_empty():
		lines.append("")
		lines.append("APPROVED:")
		for id in _approved:
			var data = _approved[id]
			lines.append("  %s - improvement: %.2f" % [id, data.result.improvement])

	if not _rejected.is_empty():
		lines.append("")
		lines.append("REJECTED:")
		for id in _rejected:
			var data = _rejected[id]
			lines.append("  %s - %s" % [id, data.reason if data.reason else "failed validation"])

	return "\n".join(lines)

## Export to dictionary
func to_dict() -> Dictionary:
	return {
		"test_iterations": test_iterations,
		"improvement_threshold": improvement_threshold,
		"validation_results": _validation_results.duplicate(true),
		"approved": _approved.duplicate(true),
		"rejected": _rejected.duplicate(true)
	}

## Load from dictionary
static func from_dict(data: Dictionary, monitor_ref: Variant) -> Variant:
	var script = preload("res://addons/awr/self_improvement/validator.gd")
	var v = script.new(monitor_ref)
	v.test_iterations = data.get("test_iterations", 10)
	v.improvement_threshold = data.get("improvement_threshold", 0.1)
	v._validation_results = data.get("validation_results", {}).duplicate(true)
	v._approved = data.get("approved", {}).duplicate(true)
	v._rejected = data.get("rejected", {}).duplicate(true)
	return v
