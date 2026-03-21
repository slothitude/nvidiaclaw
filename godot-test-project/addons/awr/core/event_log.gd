## EventLog - High-level event recording for WorldState
##
## Provides convenience functions for recording semantic events
## during simulation. Works with CausalBus to maintain audit trail.
class_name EventLog
extends RefCounted

## The causal bus to record to
var bus: Variant = null

## Create a new event log attached to a causal bus
func _init(causal_bus: Variant = null):
	bus = causal_bus

## Set the causal bus
func set_bus(causal_bus: Variant) -> void:
	bus = causal_bus

## Record a body spawn event
func body_spawned(body_id: String, initial_state: Dictionary) -> String:
	if bus == null:
		return ""
	return bus.record("body_spawned", {
		"target": body_id,
		"initial_state": initial_state
	})

## Record a body destruction event
func body_destroyed(body_id: String, final_state: Dictionary, cause: String = "") -> String:
	if bus == null:
		return ""
	return bus.record("body_destroyed", {
		"target": body_id,
		"final_state": final_state,
		"cause": cause
	})

## Record a position change
func position_changed(body_id: String, old_pos: Vector2, new_pos: Vector2, cause: String = "") -> String:
	if bus == null:
		return ""
	return bus.record_state_change(body_id, "position", old_pos, new_pos, cause)

## Record a velocity change
func velocity_changed(body_id: String, old_vel: Vector2, new_vel: Vector2, cause: String = "") -> String:
	if bus == null:
		return ""
	return bus.record_state_change(body_id, "velocity", old_vel, new_vel, cause)

## Record a goal reached event
func goal_reached(body_id: String, goal_pos: Vector2, time_taken: float) -> String:
	if bus == null:
		return ""
	return bus.record("goal_reached", {
		"target": body_id,
		"goal_position": goal_pos,
		"time_taken": time_taken
	})

## Record a simulation branch started
func branch_started(branch_id: String, action: Dictionary) -> String:
	if bus == null:
		return ""
	bus.begin_context(branch_id)
	return bus.record("branch_started", {
		"branch_id": branch_id,
		"action": action
	})

## Record a simulation branch completed
func branch_completed(branch_id: String, score: float, final_state_hash: int) -> String:
	if bus == null:
		return ""
	var event_id = bus.record("branch_completed", {
		"branch_id": branch_id,
		"score": score,
		"state_hash": final_state_hash
	})
	bus.end_context()
	return event_id

## Record a branch committed (chosen as best)
func branch_committed(branch_id: String, action: Dictionary, score: float) -> String:
	if bus == null:
		return ""
	return bus.record("branch_committed", {
		"branch_id": branch_id,
		"action": action,
		"score": score
	})

## Record an evaluation event
func evaluation_performed(state_hash: int, score: float, evaluator: String) -> String:
	if bus == null:
		return ""
	return bus.record("evaluation", {
		"state_hash": state_hash,
		"score": score,
		"evaluator": evaluator
	})

## Record a perception event
func perception_received(source: String, objects_detected: int, confidence: float) -> String:
	if bus == null:
		return ""
	return bus.record("perception", {
		"source": source,
		"objects_detected": objects_detected,
		"confidence": confidence
	})

## Record a world state snapshot
func world_snapshot(state_hash: int, body_count: int, time: float) -> String:
	if bus == null:
		return ""
	return bus.record("world_snapshot", {
		"state_hash": state_hash,
		"body_count": body_count,
		"sim_time": time
	})

## Record an error/warning event
func error_occurred(error_type: String, message: String, context: Dictionary = {}) -> String:
	if bus == null:
		return ""
	return bus.record("error", {
		"error_type": error_type,
		"message": message,
		"context": context
	})

## Record a custom event
func custom(event_type: String, data: Dictionary = {}) -> String:
	if bus == null:
		return ""
	return bus.record(event_type, data)

## Begin a named context for grouping events
func begin_context(context_id: String) -> void:
	if bus != null:
		bus.begin_context(context_id)

## End the current context
func end_context() -> String:
	if bus == null:
		return ""
	return bus.end_context()

## Static helper to create a full audit log from world state changes
static func create_audit_entry(bus: Variant, action: Dictionary, old_state: Variant, new_state: Variant) -> String:
	if bus == null:
		return ""

	var action_id = bus.record_action(action, "simloop")

	# Record state changes for each body
	for new_body in new_state.bodies:
		var body_id = new_body.id
		var old_body = {}
		for ob in old_state.bodies:
			if ob.id == body_id:
				old_body = ob
				break

		if old_body.is_empty():
			# Body was spawned
			bus.record("body_spawned", {"target": body_id, "initial_state": new_body, "cause": action_id})
		else:
			# Check for changes
			if old_body.pos.x != new_body.pos.x or old_body.pos.y != new_body.pos.y:
				bus.record_state_change(
					body_id, "position",
					Vector2(old_body.pos.x, old_body.pos.y),
					Vector2(new_body.pos.x, new_body.pos.y),
					action_id
				)
			if old_body.vel.x != new_body.vel.x or old_body.vel.y != new_body.vel.y:
				bus.record_state_change(
					body_id, "velocity",
					Vector2(old_body.vel.x, old_body.vel.y),
					Vector2(new_body.vel.x, new_body.vel.y),
					action_id
				)

	# Check for destroyed bodies
	for old_body in old_state.bodies:
		var found = false
		for new_body in new_state.bodies:
			if new_body.id == old_body.id:
				found = true
				break
		if not found:
			bus.record("body_destroyed", {"target": old_body.id, "final_state": old_body, "cause": action_id})

	return action_id
