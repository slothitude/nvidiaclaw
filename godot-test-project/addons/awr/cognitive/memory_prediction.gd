## Memory-Prediction - Learning from Prediction Errors
##
## Implements a predictive memory system that learns from discrepancies
## between predictions and observations. Based on Jeff Hawkins' Memory-Prediction
## framework and cortical learning algorithms.
##
## Usage:
##   var mp = MemoryPrediction.new()
##   mp.predict("next_position", 0.8)
##   mp.observe("next_position", actual_value)
##   var error = mp.get_prediction_error()
##   var lessons = mp.learn()
##
class_name MemoryPrediction
extends RefCounted

## Maximum predictions to store
var max_predictions: int = 100

## Maximum observations to store
var max_observations: int = 100

## Learning rate for adjusting future predictions
var learning_rate: float = 0.1

## Error threshold for significant learning events
var error_threshold: float = 0.3

## Current active predictions
var predictions: Array = []

## History of observations
var observations: Array = []

## Learned patterns (input -> expected output)
var patterns: Dictionary = {}

## Prediction errors for analysis
var error_history: Array = []
var max_error_history: int = 50

## Total prediction accuracy
var total_predictions: int = 0
var correct_predictions: int = 0

## Signal emitted when a significant prediction error occurs
signal prediction_error(what: String, expected: Variant, actual: Variant, error: float)
## Signal emitted when a new pattern is learned
signal pattern_learned(pattern_key: String, pattern_data: Dictionary)

## Internal prediction structure
class Prediction:
	var what: String
	var expected: Variant
	var confidence: float
	var timestamp: int
	var context: Dictionary
	var verified: bool = false
	var actual: Variant = null
	var error: float = -1.0

	func _init(w: String, e: Variant, c: float, ctx: Dictionary):
		what = w
		expected = e
		confidence = c
		timestamp = Time.get_ticks_msec()
		context = ctx

## Internal observation structure
class Observation:
	var what: String
	var value: Variant
	var timestamp: int
	var context: Dictionary

	func _init(w: String, v: Variant, ctx: Dictionary):
		what = w
		value = v
		timestamp = Time.get_ticks_msec()
		context = ctx

## Make a prediction about something
## @param what: What is being predicted (e.g., "next_position")
## @param confidence: How confident (0.0 to 1.0)
## @param context: Additional context for the prediction
func predict(what: String, confidence: float = 0.8, context: Dictionary = {}) -> void:
	# Check if we have learned patterns for this
	var expected = _get_pattern_prediction(what, context)

	var pred = Prediction.new(what, expected, confidence, context)
	predictions.append(pred)

	# Maintain limit
	if predictions.size() > max_predictions:
		predictions.pop_front()

## Make a specific prediction with an expected value
func predict_value(what: String, expected: Variant, confidence: float = 0.8, context: Dictionary = {}) -> void:
	var pred = Prediction.new(what, expected, confidence, context)
	predictions.append(pred)

	if predictions.size() > max_predictions:
		predictions.pop_front()

## Record an observation
## @param what: What was observed
## @param value: The observed value
## @param context: Additional context
func observe(what: String, value: Variant, context: Dictionary = {}) -> void:
	var obs = Observation.new(what, value, context)
	observations.append(obs)

	if observations.size() > max_observations:
		observations.pop_front()

	# Verify any matching predictions
	_verify_predictions(what, value, context)

## Verify predictions against observation
func _verify_predictions(what: String, value: Variant, context: Dictionary) -> void:
	for pred in predictions:
		if pred.what == what and not pred.verified:
			pred.verified = true
			pred.actual = value
			pred.error = _calculate_error(pred.expected, value)

			total_predictions += 1
			if pred.error < error_threshold:
				correct_predictions += 1

			# Record significant errors
			if pred.error >= error_threshold:
				error_history.append({
					"what": what,
					"expected": pred.expected,
					"actual": value,
					"error": pred.error,
					"timestamp": Time.get_ticks_msec()
				})
				if error_history.size() > max_error_history:
					error_history.pop_front()

				prediction_error.emit(what, pred.expected, value, pred.error)

## Calculate error between expected and actual values
func _calculate_error(expected: Variant, actual: Variant) -> float:
	# Handle different types
	if expected is Vector2 and actual is Vector2:
		var diff = expected.distance_to(actual)
		var max_val = max(expected.length(), actual.length(), 1.0)
		return min(diff / max_val, 1.0)

	elif expected is Vector3 and actual is Vector3:
		var diff = expected.distance_to(actual)
		var max_val = max(expected.length(), actual.length(), 1.0)
		return min(diff / max_val, 1.0)

	elif expected is float and actual is float:
		var diff = abs(expected - actual)
		var max_val = max(abs(expected), abs(actual), 1.0)
		return min(diff / max_val, 1.0)

	elif expected is int and actual is int:
		var diff = abs(expected - actual)
		var max_val = max(abs(expected), abs(actual), 1)
		return min(float(diff) / float(max_val), 1.0)

	elif expected is String and actual is String:
		return 0.0 if expected == actual else 1.0

	elif expected is Dictionary and actual is Dictionary:
		return _dict_error(expected, actual)

	elif expected is Array and actual is Array:
		return _array_error(expected, actual)

	# Fallback: exact match
	return 0.0 if str(expected) == str(actual) else 1.0

## Calculate error between dictionaries
func _dict_error(expected: Dictionary, actual: Dictionary) -> float:
	var all_keys: Array = []
	for k in expected:
		if not all_keys.has(k):
			all_keys.append(k)
	for k in actual:
		if not all_keys.has(k):
			all_keys.append(k)

	if all_keys.is_empty():
		return 0.0

	var total_error: float = 0.0
	for k in all_keys:
		if expected.has(k) and actual.has(k):
			total_error += _calculate_error(expected[k], actual[k])
		else:
			total_error += 1.0  # Missing key = full error

	return total_error / float(all_keys.size())

## Calculate error between arrays
func _array_error(expected: Array, actual: Array) -> float:
	var max_len = max(expected.size(), actual.size())
	if max_len == 0:
		return 0.0

	var total_error: float = 0.0
	for i in range(max_len):
		if i < expected.size() and i < actual.size():
			total_error += _calculate_error(expected[i], actual[i])
		else:
			total_error += 1.0  # Missing element = full error

	return total_error / float(max_len)

## Get prediction from learned patterns
func _get_pattern_prediction(what: String, context: Dictionary) -> Variant:
	# Find best matching pattern
	var best_match: String = ""
	var best_score: float = 0.0

	for pattern_key in patterns:
		var score = _pattern_match_score(pattern_key, what, context)
		if score > best_score:
			best_score = score
			best_match = pattern_key

	if best_match != "" and best_score > 0.5:
		return patterns[best_match].get("output", null)

	return null

## Calculate how well a pattern matches current context
func _pattern_match_score(pattern_key: String, what: String, context: Dictionary) -> float:
	if not patterns.has(pattern_key):
		return 0.0

	var pattern = patterns[pattern_key]
	var score: float = 0.0
	var factors: int = 0

	# Check if 'what' matches
	if pattern.get("what", "") == what:
		score += 1.0
	factors += 1

	# Check context similarity
	var pattern_context = pattern.get("context", {})
	for key in context:
		factors += 1
		if pattern_context.has(key):
			if pattern_context[key] == context[key]:
				score += 1.0
			elif pattern_context[key] is float and context[key] is float:
				# Allow numeric similarity
				var similarity = 1.0 - _calculate_error(pattern_context[key], context[key])
				score += similarity

	if factors == 0:
		return 0.0
	return score / float(factors)

## Get average prediction error
func get_prediction_error() -> float:
	if error_history.is_empty():
		return 0.0

	var total: float = 0.0
	for entry in error_history:
		total += entry.error
	return total / float(error_history.size())

## Get prediction accuracy (0.0 to 1.0)
func get_accuracy() -> float:
	if total_predictions == 0:
		return 1.0
	return float(correct_predictions) / float(total_predictions)

## Learn from prediction errors
## @returns Dictionary of learned patterns
func learn() -> Dictionary:
	var new_patterns: Dictionary = {}

	# Process unverified predictions that now have observations
	for pred in predictions:
		if pred.verified and pred.error >= error_threshold:
			# This is a learning opportunity
			var pattern_key = _create_pattern_key(pred.what, pred.context)
			var adjusted_output = _adjust_prediction(pred.expected, pred.actual, pred.error)

			new_patterns[pattern_key] = {
				"what": pred.what,
				"input": pred.context.duplicate(),
				"output": adjusted_output,
				"previous_output": pred.expected,
				"error": pred.error,
				"learned_at": Time.get_ticks_msec()
			}

			# Store in patterns
			patterns[pattern_key] = new_patterns[pattern_key]
			pattern_learned.emit(pattern_key, new_patterns[pattern_key])

	return new_patterns

## Create a pattern key from what and context
func _create_pattern_key(what: String, context: Dictionary) -> String:
	var key_parts: Array = [what]
	var sorted_keys = context.keys()
	sorted_keys.sort()
	for k in sorted_keys:
		key_parts.append("%s=%s" % [k, str(context[k])])
	return "|".join(key_parts)

## Adjust prediction based on error
func _adjust_prediction(expected: Variant, actual: Variant, error: float) -> Variant:
	if expected is Vector2 and actual is Vector2:
		return expected.lerp(actual, learning_rate)

	elif expected is Vector3 and actual is Vector3:
		return expected.lerp(actual, learning_rate)

	elif expected is float and actual is float:
		return expected + (actual - expected) * learning_rate

	elif expected is int and actual is int:
		return int(float(expected) + (float(actual) - float(expected)) * learning_rate)

	# For other types, just return actual (we learned the correct value)
	return actual

## Clear old predictions
func clear_predictions() -> void:
	predictions.clear()

## Clear all observations
func clear_observations() -> void:
	observations.clear()

## Reset the entire system
func reset() -> void:
	predictions.clear()
	observations.clear()
	patterns.clear()
	error_history.clear()
	total_predictions = 0
	correct_predictions = 0

## Get recent errors for debugging
func get_recent_errors(count: int = 10) -> Array:
	var start = max(0, error_history.size() - count)
	return error_history.slice(start)

## Get patterns for a specific 'what'
func get_patterns_for(what: String) -> Array:
	var result: Array = []
	for key in patterns:
		if patterns[key].get("what", "") == what:
			result.append({"key": key, "data": patterns[key]})
	return result

## Convert to prompt block for AI
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== MEMORY-PREDICTION ===")

	lines.append("STATISTICS:")
	lines.append("  Accuracy: %.1f%% (%d/%d predictions)" % [
		get_accuracy() * 100, correct_predictions, total_predictions
	])
	lines.append("  Average error: %.2f" % get_prediction_error())
	lines.append("  Patterns learned: %d" % patterns.size())

	if not error_history.is_empty():
		lines.append("")
		lines.append("RECENT ERRORS:")
		for entry in error_history.slice(-5):
			lines.append("  %s: expected %s, got %s (error: %.2f)" % [
				entry.what, str(entry.expected), str(entry.actual), entry.error
			])

	return "\n".join(lines)

## Serialize to dictionary
func to_dict() -> Dictionary:
	var predictions_data: Array = []
	for pred in predictions:
		predictions_data.append({
			"what": pred.what,
			"expected": pred.expected,
			"confidence": pred.confidence,
			"timestamp": pred.timestamp,
			"context": pred.context,
			"verified": pred.verified,
			"actual": pred.actual,
			"error": pred.error
		})

	var observations_data: Array = []
	for obs in observations:
		observations_data.append({
			"what": obs.what,
			"value": obs.value,
			"timestamp": obs.timestamp,
			"context": obs.context
		})

	return {
		"max_predictions": max_predictions,
		"max_observations": max_observations,
		"learning_rate": learning_rate,
		"error_threshold": error_threshold,
		"predictions": predictions_data,
		"observations": observations_data,
		"patterns": patterns.duplicate(),
		"error_history": error_history.duplicate(),
		"total_predictions": total_predictions,
		"correct_predictions": correct_predictions
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/cognitive/memory_prediction.gd")
	var mp = script.new()
	mp.max_predictions = data.get("max_predictions", 100)
	mp.max_observations = data.get("max_observations", 100)
	mp.learning_rate = data.get("learning_rate", 0.1)
	mp.error_threshold = data.get("error_threshold", 0.3)
	mp.patterns = data.get("patterns", {}).duplicate()
	mp.error_history = data.get("error_history", []).duplicate()
	mp.total_predictions = data.get("total_predictions", 0)
	mp.correct_predictions = data.get("correct_predictions", 0)

	for pred_data in data.get("predictions", []):
		var pred = Prediction.new(
			pred_data.what,
			pred_data.expected,
			pred_data.confidence,
			pred_data.get("context", {})
		)
		pred.timestamp = pred_data.get("timestamp", Time.get_ticks_msec())
		pred.verified = pred_data.get("verified", false)
		pred.actual = pred_data.get("actual", null)
		pred.error = pred_data.get("error", -1.0)
		mp.predictions.append(pred)

	for obs_data in data.get("observations", []):
		var obs = Observation.new(
			obs_data.what,
			obs_data.value,
			obs_data.get("context", {})
		)
		obs.timestamp = obs_data.get("timestamp", Time.get_ticks_msec())
		mp.observations.append(obs)

	return mp

## Integrate with Spatial Memory for spatial predictions
func integrate_with_spatial_memory(spatial_memory: Variant, agent_location: Vector3) -> Dictionary:
	var spatial_predictions: Dictionary = {}

	# Get nearby concepts from spatial memory
	if spatial_memory.has_method("neighborhood"):
		var neighbors = spatial_memory.neighborhood(agent_location, 50.0)
		for node in neighbors:
			if node is Dictionary:
				var concept = node.get("concept", "")
				var location = node.get("location", Vector3.ZERO)

				# Predict what we might find at nearby locations
				predict_value("spatial_%s" % concept, location, 0.7, {
					"agent_location": agent_location,
					"distance": agent_location.distance_to(location)
				})
				spatial_predictions[concept] = location

	return spatial_predictions
