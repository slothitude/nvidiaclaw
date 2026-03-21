## CausalBus - Traceable event system for AWR
##
## Every state change is linked to the action that caused it.
## Makes the system fully auditable - you can trace "why did X happen?"
##
## The causal chain forms a directed acyclic graph (DAG):
##   Action A → State Change S1 → Action B → State Change S2
class_name CausalBus
extends RefCounted

## Signal emitted when an event is recorded
signal event_recorded(event: Dictionary)

## Unique ID counter
var _next_id: int = 1

## All recorded events
var _events: Array = []

## Event index by ID for fast lookup
var _event_index: Dictionary = {}

## Event index by target (body_id) for fast causal queries
var _target_index: Dictionary = {}

## Current causal context (stack of action IDs)
var _context_stack: Array = []

## Configuration
var config: Dictionary = {
	"max_events": 10000,  # Maximum events to store
	"index_by_target": true
}

## Begin a causal context (e.g., starting an action)
func begin_context(action_id: String) -> void:
	_context_stack.append(action_id)

## End the current causal context
func end_context() -> String:
	if _context_stack.is_empty():
		return ""
	return _context_stack.pop_back()

## Get the current context (top of stack)
func get_current_context() -> String:
	if _context_stack.is_empty():
		return "root"
	return _context_stack.back()

## Record an event with automatic causal linking
func record(event_type: String, data: Dictionary = {}) -> String:
	var event_id = "evt_%d" % _next_id
	_next_id += 1

	var event: Dictionary = {
		"id": event_id,
		"type": event_type,
		"timestamp": Time.get_ticks_usec(),
		"context": get_current_context(),
		"parent": _context_stack[-1] if _context_stack.size() > 0 else "",
		"data": data
	}

	# Add target to data if present
	if data.has("target"):
		event.target = data.target

	_events.append(event)
	_event_index[event_id] = event

	# Index by target for queries
	if config.index_by_target and event.has("target"):
		var target = event.target
		if not _target_index.has(target):
			_target_index[target] = []
		_target_index[target].append(event_id)

	# Enforce max events
	if _events.size() > config.max_events:
		var removed = _events.pop_front()
		_event_index.erase(removed.id)
		if removed.has("target"):
			var target_events = _target_index.get(removed.target, [])
			target_events.erase(removed.id)

	event_recorded.emit(event)
	return event_id

## Record an action event
func record_action(action: Dictionary, source: String = "agent") -> String:
	return record("action", {
		"action_type": action.get("type", "unknown"),
		"action": action,
		"source": source,
		"target": action.get("target", "")
	})

## Record a state change event
func record_state_change(target: String, property: String, old_value, new_value, cause_id: String = "") -> String:
	return record("state_change", {
		"target": target,
		"property": property,
		"old_value": old_value,
		"new_value": new_value,
		"cause": cause_id
	})

## Record a collision event
func record_collision(body_a: String, body_b: String, impact_velocity: float, cause_id: String = "") -> String:
	return record("collision", {
		"body_a": body_a,
		"body_b": body_b,
		"impact_velocity": impact_velocity,
		"cause": cause_id
	})

## Record a simulation step
func record_step(dt: float, cause_id: String = "") -> String:
	return record("step", {
		"dt": dt,
		"cause": cause_id
	})

## Get event by ID
func get_event(event_id: String) -> Dictionary:
	return _event_index.get(event_id, {})

## Get all events for a target (body ID)
func get_events_for_target(target: String) -> Array:
	var event_ids = _target_index.get(target, [])
	var result: Array = []
	for eid in event_ids:
		result.append(_event_index.get(eid, {}))
	return result

## Get the causal chain leading to an event
func get_causal_chain(event_id: String) -> Array:
	var chain: Array = []
	var current_id: String = event_id

	while not current_id.is_empty():
		var event = _event_index.get(current_id, {})
		if event.is_empty():
			break
		chain.append(event)

		# Follow parent context first, then explicit cause
		if event.has("parent") and not event.parent.is_empty():
			current_id = event.parent
		elif event.data.has("cause") and not event.data.cause.is_empty():
			current_id = event.data.cause
		else:
			break

	return chain

## Get all events of a specific type
func get_events_by_type(event_type: String) -> Array:
	var result: Array = []
	for event in _events:
		if event.type == event_type:
			result.append(event)
	return result

## Get all events in a time range
func get_events_in_range(start_time: int, end_time: int) -> Array:
	var result: Array = []
	for event in _events:
		if event.timestamp >= start_time and event.timestamp <= end_time:
			result.append(event)
	return result

## Query: "what caused target to have property X?"
func trace_cause(target: String, property: String) -> Array:
	var chain: Array = []
	var target_events = get_events_for_target(target)

	# Find state changes for this property
	for event in target_events:
		if event.type == "state_change" and event.data.get("property") == property:
			chain.append(event)
			# Follow the cause chain
			var cause_id = event.data.get("cause", "")
			while not cause_id.is_empty():
				var cause_event = get_event(cause_id)
				if cause_event.is_empty():
					break
				chain.append(cause_event)
				cause_id = cause_event.data.get("cause", "")

	return chain

## Clear all events
func clear() -> void:
	_events.clear()
	_event_index.clear()
	_target_index.clear()
	_context_stack.clear()
	_next_id = 1

## Get statistics
func get_stats() -> Dictionary:
	return {
		"total_events": _events.size(),
		"unique_targets": _target_index.size(),
		"context_depth": _context_stack.size()
	}

## Export events as JSON-serializable array
func export_events() -> Array:
	return _events.duplicate(true)

## Import events from array (for replay)
func import_events(events: Array) -> void:
	clear()
	for event in events:
		_events.append(event)
		_event_index[event.id] = event
		if event.has("target"):
			if not _target_index.has(event.target):
				_target_index[event.target] = []
			_target_index[event.target].append(event.id)
		# Update next_id to be higher than any imported
		var id_num = event.id.split("_")[1].to_int() if event.id.begins_with("evt_") else 0
		if id_num >= _next_id:
			_next_id = id_num + 1

## Replay events to reconstruct state (returns event log)
func replay_to_time(target_time: int) -> Array:
	var result: Array = []
	for event in _events:
		if event.timestamp <= target_time:
			result.append(event)
		else:
			break
	return result
