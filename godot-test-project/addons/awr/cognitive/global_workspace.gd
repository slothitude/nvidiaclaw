## Global Workspace - Attention and Competition Mechanism
##
## Implements Bernard Baars' Global Workspace Theory for consciousness/attention.
## Multiple modules compete for attention; the winner broadcasts globally.
##
## Usage:
##   var gw = GlobalWorkspace.new()
##   gw.add_content("threat_detected", 0.9, "perception")
##   gw.add_content("goal_nearby", 0.7, "navigation")
##   gw.compete()  # Run competition
##   var winner = gw.get_conscious_content()
##
class_name GlobalWorkspace
extends RefCounted

## Maximum workspace capacity (number of competing items)
var max_capacity: int = 7

## Activation threshold for content to be considered
var activation_threshold: float = 0.3

## Decay rate for activations (per step)
var decay_rate: float = 0.1

## Boost for recently active modules
var recency_boost: float = 0.1

## Content currently in the workspace competing for attention
var workspace: Array = []

## The current conscious content (winner of competition)
var conscious_content: Variant = null

## History of conscious content for analysis
var consciousness_history: Array = []
var max_history_size: int = 100

## Broadcast listeners (modules that receive global broadcasts)
var _broadcast_listeners: Array = []

## Signal emitted when new conscious content is selected
signal content_selected(content: Variant, module_type: String)
## Signal emitted when content is broadcast globally
signal content_broadcast(content: Variant)

## Internal structure for workspace content
class WorkspaceContent:
	var content: Variant
	var activation: float
	var module_type: String
	var timestamp: int
	var access_count: int = 0

	func _init(c: Variant, a: float, m: String):
		content = c
		activation = a
		module_type = m
		timestamp = Time.get_ticks_msec()

## Add content to the workspace
## @param content: The content to add (can be any type)
## @param activation: Initial activation strength (0.0 to 1.0)
## @param module_type: The module that produced this content
func add_content(content: Variant, activation: float, module_type: String) -> void:
	var wc = WorkspaceContent.new(content, clamp(activation, 0.0, 1.0), module_type)
	workspace.append(wc)

	# Maintain capacity limit
	if workspace.size() > max_capacity:
		# Remove lowest activation item
		workspace.sort_custom(func(a, b): return a.activation > b.activation)
		workspace = workspace.slice(0, max_capacity)

## Remove content from workspace
func remove_content(content: Variant) -> bool:
	for i in range(workspace.size()):
		if workspace[i].content == content:
			workspace.remove_at(i)
			return true
	return false

## Clear the workspace
func clear_workspace() -> void:
	workspace.clear()
	conscious_content = null

## Run the competition to select conscious content
## @returns The winning content
func compete() -> Variant:
	if workspace.is_empty():
		conscious_content = null
		return null

	# Apply decay and recency boost
	_apply_decay()
	_apply_recency_boost()

	# Filter by threshold
	var eligible: Array = []
	for wc in workspace:
		if wc.activation >= activation_threshold:
			eligible.append(wc)

	if eligible.is_empty():
		conscious_content = null
		return null

	# Sort by activation (highest first)
	eligible.sort_custom(func(a, b): return a.activation > b.activation)

	# Add small random noise to break ties (simulates neural noise)
	var top_activation = eligible[0].activation
	var top_candidates: Array = []
	for wc in eligible:
		if wc.activation >= top_activation - 0.05:  # Within 5% of top
			top_candidates.append(wc)

	# Random selection among top candidates
	var winner: WorkspaceContent
	if top_candidates.size() == 1:
		winner = top_candidates[0]
	else:
		var rng = RandomNumberGenerator.new()
		rng.seed = Time.get_ticks_msec()
		winner = top_candidates[rng.randi() % top_candidates.size()]

	# Set conscious content
	conscious_content = winner.content
	winner.access_count += 1

	# Add to history
	_add_to_history(winner)

	# Emit signal
	content_selected.emit(winner.content, winner.module_type)

	return winner.content

## Apply decay to all workspace items
func _apply_decay() -> void:
	var to_remove: Array = []
	for wc in workspace:
		wc.activation -= decay_rate
		if wc.activation <= 0:
			to_remove.append(wc)

	for wc in to_remove:
		workspace.erase(wc)

## Apply recency boost to recently accessed items
func _apply_recency_boost() -> void:
	var current_time = Time.get_ticks_msec()
	for wc in workspace:
		var age_ms = current_time - wc.timestamp
		var age_seconds = age_ms / 1000.0
		if age_seconds < 1.0:  # Recent items get boost
			wc.activation += recency_boost * (1.0 - age_seconds)

## Add winner to consciousness history
func _add_to_history(wc: WorkspaceContent) -> void:
	consciousness_history.append({
		"content": wc.content,
		"module_type": wc.module_type,
		"activation": wc.activation,
		"timestamp": Time.get_ticks_msec()
	})

	if consciousness_history.size() > max_history_size:
		consciousness_history.pop_front()

## Broadcast conscious content to all listeners
## @returns Array of responses from listeners
func broadcast() -> Array:
	if conscious_content == null:
		return []

	var responses: Array = []
	for listener in _broadcast_listeners:
		if listener is Callable:
			var response = listener.call(conscious_content)
			responses.append(response)
		elif listener.has_method("receive_broadcast"):
			var response = listener.receive_broadcast(conscious_content)
			responses.append(response)

	content_broadcast.emit(conscious_content)
	return responses

## Register a listener for global broadcasts
func register_listener(listener: Variant) -> void:
	_broadcast_listeners.append(listener)

## Unregister a listener
func unregister_listener(listener: Variant) -> bool:
	var idx = _broadcast_listeners.find(listener)
	if idx >= 0:
		_broadcast_listeners.remove_at(idx)
		return true
	return false

## Get current conscious content
func get_conscious_content() -> Variant:
	return conscious_content

## Check if workspace has content above threshold
func has_eligible_content() -> bool:
	for wc in workspace:
		if wc.activation >= activation_threshold:
			return true
	return false

## Get workspace summary (for debugging)
func get_workspace_summary() -> Array:
	var summary: Array = []
	for wc in workspace:
		summary.append({
			"content": str(wc.content),
			"activation": wc.activation,
			"module_type": wc.module_type,
			"access_count": wc.access_count
		})
	summary.sort_custom(func(a, b): return a.activation > b.activation)
	return summary

## Get consciousness history
func get_history() -> Array:
	return consciousness_history.duplicate()

## Step the workspace (apply decay, optionally auto-compete)
func step(auto_compete: bool = false) -> void:
	_apply_decay()
	_apply_recency_boost()

	if auto_compete:
		compete()

## Boost content by module type
func boost_module(module_type: String, boost_amount: float = 0.2) -> void:
	for wc in workspace:
		if wc.module_type == module_type:
			wc.activation = min(wc.activation + boost_amount, 1.0)

## Inhibit content by module type
func inhibit_module(module_type: String, inhibit_amount: float = 0.2) -> void:
	for wc in workspace:
		if wc.module_type == module_type:
			wc.activation = max(wc.activation - inhibit_amount, 0.0)

## Convert to prompt block for AI context
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== GLOBAL WORKSPACE ===")

	lines.append("CONSCIOUS CONTENT:")
	if conscious_content != null:
		lines.append("  %s" % str(conscious_content))
	else:
		lines.append("  (no conscious content)")

	lines.append("COMPETING CONTENT:")
	if workspace.is_empty():
		lines.append("  (empty)")
	else:
		var summary = get_workspace_summary()
		for entry in summary:
			var marker = "*" if entry.content == conscious_content else " "
			lines.append(" %s [%s] %.2f - %s" % [
				marker, entry.module_type, entry.activation, entry.content
			])

	return "\n".join(lines)

## Serialize to dictionary
func to_dict() -> Dictionary:
	var ws_data: Array = []
	for wc in workspace:
		ws_data.append({
			"content": wc.content,
			"activation": wc.activation,
			"module_type": wc.module_type,
			"timestamp": wc.timestamp,
			"access_count": wc.access_count
		})

	return {
		"max_capacity": max_capacity,
		"activation_threshold": activation_threshold,
		"decay_rate": decay_rate,
		"recency_boost": recency_boost,
		"workspace": ws_data,
		"conscious_content": conscious_content,
		"history": consciousness_history.slice(-20)  # Last 20 entries
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/cognitive/global_workspace.gd")
	var gw = script.new()
	gw.max_capacity = data.get("max_capacity", 7)
	gw.activation_threshold = data.get("activation_threshold", 0.3)
	gw.decay_rate = data.get("decay_rate", 0.1)
	gw.recency_boost = data.get("recency_boost", 0.1)

	for wc_data in data.get("workspace", []):
		var wc = WorkspaceContent.new(
			wc_data.content,
			wc_data.activation,
			wc_data.module_type
		)
		wc.timestamp = wc_data.get("timestamp", Time.get_ticks_msec())
		wc.access_count = wc_data.get("access_count", 0)
		gw.workspace.append(wc)

	gw.conscious_content = data.get("conscious_content", null)
	gw.consciousness_history = data.get("history", [])

	return gw

## Create Global Workspace from BDI model
static func from_bdi(bdi: Variant) -> Variant:
	var script = preload("res://addons/awr/cognitive/global_workspace.gd")
	var gw = script.new()

	# Add top desires as competing content
	var sorted_desires = bdi.get_sorted_desires()
	for entry in sorted_desires:
		var d = entry.desire
		gw.add_content("desire:%s" % entry.goal, d.priority, "bdi_desires")

	# Add intentions as competing content
	for i in range(bdi.intentions.size()):
		var priority = 0.8 - (i * 0.1)  # Earlier intentions have higher priority
		gw.add_content(bdi.intentions[i], priority, "bdi_intentions")

	# Add high-confidence beliefs
	for fact in bdi.beliefs:
		var b = bdi.beliefs[fact]
		if b.confidence > 0.7:
			gw.add_content("belief:%s=%s" % [fact, str(b.value)], b.confidence * 0.5, "bdi_beliefs")

	return gw
