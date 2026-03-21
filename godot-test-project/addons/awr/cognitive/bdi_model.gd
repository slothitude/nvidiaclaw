## BDI Model - Beliefs, Desires, Intentions
##
## A cognitive architecture component that provides goal-directed reasoning.
## Based on the BDI (Beliefs-Desires-Intentions) model from AI research.
##
## Usage:
##   var bdi = BDIModel.new()
##   bdi.believe("player_position", Vector2(100, 200), 0.9)
##   bdi.desire("reach_goal", 1.0)
##   bdi.intend({"type": "move", "target": Vector2(300, 400)})
##
class_name BDIModel
extends RefCounted

## Preloaded dependencies
const MemoryPredictionClass = preload("res://addons/awr/cognitive/memory_prediction.gd")

## Current beliefs about the world (what the agent knows)
var beliefs: Dictionary = {}

## Goals with priorities (what the agent wants)
var desires: Dictionary = {}

## Committed plan of action (what the agent will do)
var intentions: Array = []

## Maximum number of intentions to maintain
var max_intentions: int = 10

## Belief decay rate per step (0 = no decay, 1 = instant decay)
var belief_decay: float = 0.0

## Signal emitted when beliefs change
signal belief_changed(fact: String, value: Variant, confidence: float)
## Signal emitted when a new desire is added
signal desire_added(goal: String, priority: float)
## Signal emitted when an intention is committed
signal intention_committed(action: Dictionary)

## Internal structure for beliefs
class Belief:
	var value: Variant
	var confidence: float
	var timestamp: int  # ticks when belief was added/updated
	var source: String  # where belief came from

	func _init(v: Variant, c: float, src: String = "unknown"):
		value = v
		confidence = c
		timestamp = Time.get_ticks_msec()
		source = src

## Internal structure for desires
class Desire:
	var goal: String
	var priority: float
	var deadline: float = -1.0  # -1 means no deadline
	var created_at: int
	var preconditions: Array = []  # conditions that must be met

	func _init(g: String, p: float):
		goal = g
		priority = p
		created_at = Time.get_ticks_msec()

## Add or update a belief
## @param fact: The name of the belief (e.g., "player_health")
## @param value: The value of the belief
## @param confidence: How confident the agent is (0.0 to 1.0)
## @param source: Where this belief came from
func believe(fact: String, value: Variant, confidence: float = 0.8, source: String = "unknown") -> void:
	var belief = Belief.new(value, clamp(confidence, 0.0, 1.0), source)
	beliefs[fact] = belief
	belief_changed.emit(fact, value, confidence)

## Remove a belief
func disbelieve(fact: String) -> bool:
	if beliefs.has(fact):
		beliefs.erase(fact)
		return true
	return false

## Check if a belief exists
func has_belief(fact: String) -> bool:
	return beliefs.has(fact)

## Get a belief's value (returns default if not found)
func get_belief(fact: String, default: Variant = null) -> Variant:
	if beliefs.has(fact):
		return beliefs[fact].value
	return default

## Get a belief's confidence
func get_belief_confidence(fact: String) -> float:
	if beliefs.has(fact):
		return beliefs[fact].confidence
	return 0.0

## Add a desire (goal) with priority
## @param goal: The goal name (e.g., "reach_exit")
## @param priority: Priority from 0.0 to 1.0 (higher = more important)
## @param deadline: Optional deadline in seconds (-1 = no deadline)
func desire(goal: String, priority: float, deadline: float = -1.0) -> void:
	var d = Desire.new(goal, clamp(priority, 0.0, 1.0))
	d.deadline = deadline
	desires[goal] = d
	desire_added.emit(goal, priority)

## Remove a desire
func undesire(goal: String) -> bool:
	if desires.has(goal):
		desires.erase(goal)
		return true
	return false

## Check if a desire exists
func has_desire(goal: String) -> bool:
	return desires.has(goal)

## Get the highest priority desire
func get_top_desire() -> String:
	var top_priority: float = -1.0
	var top_goal: String = ""

	for goal in desires:
		var d: Desire = desires[goal]
		# Check deadline
		if d.deadline > 0:
			var elapsed = (Time.get_ticks_msec() - d.created_at) / 1000.0
			if elapsed > d.deadline:
				continue  # Skip expired desires
		if d.priority > top_priority:
			top_priority = d.priority
			top_goal = goal

	return top_goal

## Get all desires sorted by priority
func get_sorted_desires() -> Array:
	var sorted: Array = []
	for goal in desires:
		sorted.append({"goal": goal, "desire": desires[goal]})
	sorted.sort_custom(func(a, b): return a.desire.priority > b.desire.priority)
	return sorted

## Commit to an action (add to intentions)
func intend(action: Dictionary) -> void:
	if intentions.size() >= max_intentions:
		intentions.pop_front()  # Remove oldest intention
	intentions.append(action)
	intention_committed.emit(action)

## Clear all intentions
func clear_intentions() -> void:
	intentions.clear()

## Get the current intention (first in queue)
func get_current_intention() -> Dictionary:
	if intentions.size() > 0:
		return intentions[0]
	return {}

## Pop the current intention (mark as completed)
func complete_intention() -> Dictionary:
	if intentions.size() > 0:
		return intentions.pop_front()
	return {}

## Check if beliefs satisfy a condition
## @param condition: Dictionary of required beliefs
func satisfies(condition: Dictionary) -> bool:
	for fact in condition:
		if not beliefs.has(fact):
			return false
		if beliefs[fact].value != condition[fact]:
			return false
	return true

## Apply belief decay (call each step)
func step() -> void:
	if belief_decay <= 0.0:
		return

	var to_remove: Array = []
	for fact in beliefs:
		var b: Belief = beliefs[fact]
		b.confidence -= belief_decay
		if b.confidence <= 0.0:
			to_remove.append(fact)

	for fact in to_remove:
		beliefs.erase(fact)

## Convert to a prompt block for AI context
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== BDI STATE ===")

	# Beliefs
	lines.append("BELIEFS:")
	for fact in beliefs:
		var b: Belief = beliefs[fact]
		lines.append("  %s = %s (confidence: %.2f, source: %s)" % [
			fact, str(b.value), b.confidence, b.source
		])

	# Desires
	lines.append("DESIRES:")
	var sorted_desires = get_sorted_desires()
	for entry in sorted_desires:
		var d: Desire = entry.desire
		var deadline_str = ""
		if d.deadline > 0:
			deadline_str = " (deadline: %.1fs)" % d.deadline
		lines.append("  %s [priority: %.2f]%s" % [entry.goal, d.priority, deadline_str])

	# Intentions
	lines.append("INTENTIONS:")
	if intentions.is_empty():
		lines.append("  (none)")
	else:
		for i in range(intentions.size()):
			lines.append("  %d. %s" % [i + 1, JSON.stringify(intentions[i])])

	return "\n".join(lines)

## Serialize to dictionary
func to_dict() -> Dictionary:
	var b_data: Dictionary = {}
	for fact in beliefs:
		var b: Belief = beliefs[fact]
		b_data[fact] = {
			"value": b.value,
			"confidence": b.confidence,
			"timestamp": b.timestamp,
			"source": b.source
		}

	var d_data: Dictionary = {}
	for goal in desires:
		var d: Desire = desires[goal]
		d_data[goal] = {
			"priority": d.priority,
			"deadline": d.deadline,
			"created_at": d.created_at
		}

	return {
		"beliefs": b_data,
		"desires": d_data,
		"intentions": intentions.duplicate(),
		"max_intentions": max_intentions,
		"belief_decay": belief_decay
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/cognitive/bdi_model.gd")
	var model = script.new()
	model.max_intentions = data.get("max_intentions", 10)
	model.belief_decay = data.get("belief_decay", 0.0)

	for fact in data.get("beliefs", {}):
		var b_data = data.beliefs[fact]
		var b = Belief.new(b_data.value, b_data.confidence, b_data.get("source", "unknown"))
		b.timestamp = b_data.get("timestamp", Time.get_ticks_msec())
		model.beliefs[fact] = b

	for goal in data.get("desires", {}):
		var d_data = data.desires[goal]
		var d = Desire.new(goal, d_data.priority)
		d.deadline = d_data.get("deadline", -1.0)
		d.created_at = d_data.get("created_at", Time.get_ticks_msec())
		model.desires[goal] = d

	model.intentions = data.get("intentions", []).duplicate()

	return model

## Create a BDI model from world state (extract relevant beliefs)
static func from_world_state(world_state: Variant, agent_id: String = "") -> Variant:
	var script = preload("res://addons/awr/cognitive/bdi_model.gd")
	var model = script.new()

	if world_state == null:
		return model

	# Extract bodies as beliefs
	var bodies: Dictionary = {}
	if world_state.has_method("get_bodies"):
		bodies = world_state.get_bodies()
		for body_id in bodies:
			var body = bodies[body_id]
			model.believe("body_%s_position" % body_id, body.get("position", Vector2.ZERO), 1.0, "world_state")
			model.believe("body_%s_velocity" % body_id, body.get("velocity", Vector2.ZERO), 1.0, "world_state")
			if body.has("mass"):
				model.believe("body_%s_mass" % body_id, body.mass, 1.0, "world_state")

	# Agent-specific beliefs
	if agent_id != "" and bodies.has(agent_id):
		var agent_body = bodies[agent_id]
		model.believe("self_position", agent_body.get("position", Vector2.ZERO), 1.0, "self")
		model.believe("self_velocity", agent_body.get("velocity", Vector2.ZERO), 1.0, "self")

	return model
