## The Crypt - Ancestral Wisdom Storage
##
## Central repository for storing and retrieving ancestral wisdom.
## Manages bloodlines (categorized wisdom) and death reports (lessons from failures).
##
## Usage:
##   var crypt = TheCrypt.new()
##   crypt.entomb("session_1", "navigate_to_goal", {"success": false, "reason": "hit_wall"})
##   var wisdom = crypt.inherit("navigation")
##   var lessons = crypt.extract_lesson(outcome)
##
class_name TheCrypt
extends RefCounted

## Preloaded Bloodline script
const BloodlineScript = preload("res://addons/awr/crypt/bloodline.gd")

## Bloodlines (categorized wisdom)
var bloodlines: Dictionary = {}

## Death reports (lessons from failures)
var deaths: Array = []

## Maximum death reports to store
var max_deaths: int = 100

## Innovation genealogy (track approach evolution)
var innovations: Dictionary = {}

## Session archive
var session_archive: Dictionary = {}

## Signal emitted when wisdom is entombed
signal wisdom_entombed(session_id: String, bloodline: String, lesson: String)
## Signal emitted when death is recorded
signal death_recorded(session_id: String, task: String, reason: String)
## Signal emitted when innovation is tracked
signal innovation_tracked(approach_id: String, parent_id: String)

func _init() -> void:
	# Initialize default bloodlines
	_initialize_default_bloodlines()

## Initialize default bloodlines
func _initialize_default_bloodlines() -> void:
	var defaults = BloodlineScript.create_default_bloodlines()
	for bloodline in defaults:
		bloodlines[bloodline.name] = bloodline

## Create a new bloodline
func create_bloodline(name: String, description: String = "") -> Variant:
	var bloodline = BloodlineScript.new(name, description)
	bloodlines[name] = bloodline
	return bloodline

## Get or create a bloodline
func get_bloodline(name: String) -> Variant:
	if not bloodlines.has(name):
		return create_bloodline(name)
	return bloodlines[name]

## Entomb a completed session/task
## @param session_id: Unique session identifier
## @param task: The task that was attempted
## @param outcome: Dictionary with success, reason, metadata
func entomb(session_id: String, task: String, outcome: Dictionary) -> void:
	# Store in session archive
	session_archive[session_id] = {
		"task": task,
		"outcome": outcome,
		"timestamp": Time.get_ticks_msec()
	}

	# Extract lesson and categorize
	var lesson = extract_lesson(outcome)

	# Determine bloodline from task type
	var bloodline_name = _categorize_task(task)
	var bloodline = get_bloodline(bloodline_name)

	# Add lesson to appropriate bloodline
	var lesson_id = "%s_%s" % [session_id, task]
	bloodline.add_lesson(lesson_id, lesson.wisdom, lesson.confidence, lesson.context)

	wisdom_entombed.emit(session_id, bloodline_name, lesson.wisdom)

	# Record death if failed
	if not outcome.get("success", true):
		record_death(session_id, task, outcome)

## Extract a lesson from an outcome
func extract_lesson(outcome: Dictionary) -> Dictionary:
	var success = outcome.get("success", true)
	var reason = outcome.get("reason", "")
	var attempts = outcome.get("attempts", 1)
	var tools = outcome.get("tools", [])
	var metadata = outcome.get("metadata", {})

	var wisdom: String
	var confidence: float
	var context: Dictionary = {}

	if success:
		# Extract success lesson
		wisdom = _generate_success_wisdom(outcome)
		confidence = 0.8
		context["attempts"] = attempts
		context["tools"] = tools
	else:
		# Extract failure lesson
		wisdom = _generate_failure_wisdom(outcome)
		confidence = 0.6  # Failures are less certain
		context["failure_reason"] = reason
		context["attempts"] = attempts
		context["tools"] = tools

	return {
		"wisdom": wisdom,
		"confidence": confidence,
		"context": context
	}

## Generate wisdom text from successful outcome
func _generate_success_wisdom(outcome: Dictionary) -> String:
	var attempts = outcome.get("attempts", 1)
	var tools = outcome.get("tools", [])
	var strategy = outcome.get("strategy", "")

	if attempts == 1:
		if tools.size() == 1:
			return "Use %s for immediate success in similar situations" % tools[0]
		else:
			return "Direct approach works well - minimal iteration needed"
	else:
		if strategy != "":
			return "Strategy '%s' succeeded after %d attempts" % [strategy, attempts]
		else:
			return "Persistence pays off - succeeded after %d attempts" % attempts

## Generate wisdom text from failed outcome
func _generate_failure_wisdom(outcome: Dictionary) -> String:
	var reason = outcome.get("reason", "unknown")
	var attempts = outcome.get("attempts", 1)
	var tools = outcome.get("tools", [])

	match reason:
		"timeout":
			return "Allow more time or use faster approach"
		"resource_exhausted":
			return "Conserve resources or find alternative approach"
		"invalid_action":
			return "Validate actions before execution"
		"blocked":
			return "Clear obstacles before proceeding"
		"collision":
			return "Check for collisions before committing to path"
		_:
			if tools.size() > 0:
				return "Approach using %s failed - try alternative" % ", ".join(tools)
			return "Avoid this approach - failed after %d attempts" % attempts

## Categorize a task into a bloodline
func _categorize_task(task: String) -> String:
	task = task.to_lower()

	if "nav" in task or "mov" in task or "path" in task or "goal" in task:
		return "navigation"
	elif "phys" in task or "coll" in task or "force" in task or "impulse" in task:
		return "physics"
	elif "plan" in task or "strat" in task or "decid" in task or "eval" in task:
		return "strategy"
	elif "percept" in task or "observ" in task or "detect" in task:
		return "perception"
	elif "learn" in task or "adapt" in task or "improv" in task:
		return "learning"
	else:
		return "general"

## Record a death (failure)
func record_death(session_id: String, task: String, outcome: Dictionary) -> void:
	var death = {
		"session_id": session_id,
		"task": task,
		"reason": outcome.get("reason", "unknown"),
		"attempts": outcome.get("attempts", 1),
		"tools": outcome.get("tools", []),
		"timestamp": Time.get_ticks_msec(),
		"metadata": outcome.get("metadata", {})
	}

	deaths.append(death)

	# Maintain limit
	if deaths.size() > max_deaths:
		deaths.pop_front()

	death_recorded.emit(session_id, task, death.reason)

## Inherit wisdom from a bloodline
## @param bloodline_name: Name of the bloodline to inherit from
## @param context: Current context for relevance filtering
## @returns Array of relevant lessons
func inherit(bloodline_name: String, context: Dictionary = {}) -> Array:
	if not bloodlines.has(bloodline_name):
		return []

	var bloodline = bloodlines[bloodline_name]
	return bloodline.get_relevant_lessons(context)

## Inherit from all bloodlines
func inherit_all(context: Dictionary = {}) -> Dictionary:
	var all_wisdom: Dictionary = {}

	for name in bloodlines:
		var lessons = inherit(name, context)
		if not lessons.is_empty():
			all_wisdom[name] = lessons

	return all_wisdom

## Track an innovation (approach genealogy)
## @param approach_id: Unique ID for this approach
## @param parent_id: ID of the parent approach (empty if original)
## @param description: Description of the innovation
func track_innovation(approach_id: String, parent_id: String, description: String) -> void:
	innovations[approach_id] = {
		"parent": parent_id,
		"description": description,
		"created_at": Time.get_ticks_msec(),
		"success_count": 0,
		"failure_count": 0
	}

	innovation_tracked.emit(approach_id, parent_id)

## Record innovation success
func record_innovation_success(approach_id: String) -> void:
	if innovations.has(approach_id):
		innovations[approach_id].success_count += 1

## Record innovation failure
func record_innovation_failure(approach_id: String) -> void:
	if innovations.has(approach_id):
		innovations[approach_id].failure_count += 1

## Get innovation genealogy
func get_innovation_genealogy(approach_id: String) -> Array:
	var genealogy: Array = []
	var current = approach_id

	while current != "" and innovations.has(current):
		genealogy.append({
			"id": current,
			"data": innovations[current]
		})
		current = innovations[current].parent

	return genealogy

## Get recent deaths
func get_recent_deaths(count: int = 10) -> Array:
	var start = max(0, deaths.size() - count)
	return deaths.slice(start)

## Get death patterns
func analyze_death_patterns() -> Dictionary:
	var patterns: Dictionary = {}

	for death in deaths:
		var reason = death.reason
		if not patterns.has(reason):
			patterns[reason] = {"count": 0, "tasks": []}
		patterns[reason].count += 1
		if death.task not in patterns[reason].tasks:
			patterns[reason].tasks.append(death.task)

	return patterns

## Get crypt statistics
func get_stats() -> Dictionary:
	var bloodline_stats: Dictionary = {}
	for name in bloodlines:
		bloodline_stats[name] = bloodlines[name].get_stats()

	return {
		"bloodline_count": bloodlines.size(),
		"bloodlines": bloodline_stats,
		"death_count": deaths.size(),
		"innovation_count": innovations.size(),
		"session_count": session_archive.size()
	}

## Convert to prompt block for AI
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== THE CRYPT (Ancestral Wisdom) ===")

	# Bloodline summary
	lines.append("")
	lines.append("BLOODLINES:")
	for name in bloodlines:
		var b = bloodlines[name]
		var stats = b.get_stats()
		lines.append("  %s: %d lessons, avg confidence %.0f%%" % [
			name, stats.lesson_count, stats.avg_confidence * 100
		])

	# Recent deaths
	if not deaths.is_empty():
		lines.append("")
		lines.append("RECENT DEATHS:")
		for death in get_recent_deaths(5):
			lines.append("  %s: %s (%d attempts)" % [
				death.task, death.reason, death.attempts
			])

	# Top lessons from each bloodline
	lines.append("")
	lines.append("TOP WISDOM:")
	for name in bloodlines:
		var b = bloodlines[name]
		var top = b.get_top_lessons(1)
		if not top.is_empty():
			lines.append("  [%s] %s" % [name, top[0].wisdom])

	return "\n".join(lines)

## Get guidance for a task
func get_guidance(task: String, context: Dictionary = {}) -> Array:
	var bloodline_name = _categorize_task(task)
	var guidance: Array = []

	# Get wisdom from relevant bloodline
	var relevant = inherit(bloodline_name, context)
	for entry in relevant.slice(0, 3):
		guidance.append({
			"source": bloodline_name,
			"wisdom": entry.lesson.wisdom,
			"confidence": entry.lesson.confidence,
			"relevance": entry.relevance
		})

	# Check death patterns for warnings
	var death_patterns = analyze_death_patterns()
	for reason in death_patterns:
		if death_patterns[reason].count >= 3:
			guidance.append({
				"source": "death_reports",
				"wisdom": "Avoid: %s (occurred %d times)" % [reason, death_patterns[reason].count],
				"confidence": 0.9,
				"relevance": 1.0
			})

	return guidance

## Export to dictionary
func to_dict() -> Dictionary:
	var bloodlines_data: Dictionary = {}
	for name in bloodlines:
		bloodlines_data[name] = bloodlines[name].to_dict()

	return {
		"bloodlines": bloodlines_data,
		"deaths": deaths.duplicate(),
		"max_deaths": max_deaths,
		"innovations": innovations.duplicate(),
		"session_archive": session_archive.duplicate()
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/crypt/crypt.gd")
	var crypt = script.new()
	crypt.bloodlines.clear()

	for name in data.get("bloodlines", {}):
		crypt.bloodlines[name] = BloodlineScript.from_dict(data.bloodlines[name])

	crypt.deaths = data.get("deaths", []).duplicate()
	crypt.max_deaths = data.get("max_deaths", 100)
	crypt.innovations = data.get("innovations", {}).duplicate()
	crypt.session_archive = data.get("session_archive", {}).duplicate()

	return crypt

## Save to file
func save(path: String) -> int:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var data = to_dict()
	var json = JSON.new()
	var json_str = json.stringify(data)

	file.store_string(json_str)
	file.close()
	return OK

## Load from file
static func load_from(path: String) -> Variant:
	var script = preload("res://addons/awr/crypt/crypt.gd")
	if not FileAccess.file_exists(path):
		return script.new()

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return script.new()

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return script.new()

	return from_dict(json.data)
