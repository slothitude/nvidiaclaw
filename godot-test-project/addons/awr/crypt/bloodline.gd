## Bloodline - Categorized Wisdom
##
## Represents a category of ancestral wisdom (e.g., navigation, combat, social).
## Each bloodline contains lessons learned from past experiences.
##
## Usage:
##   var bloodline = Bloodline.new("navigation", "Spatial navigation wisdom")
##   bloodline.add_lesson("avoid_walls", "Never move directly toward walls", 0.9)
##   bloodline.add_lesson("follow_paths", "Use established paths when available", 0.7)
##   var lessons = bloodline.get_relevant_lessons(context)
##
class_name Bloodline
extends RefCounted

## Bloodline name
var name: String

## Description of this wisdom category
var description: String

## Lessons in this bloodline
var lessons: Array = []

## Maximum lessons to store
var max_lessons: int = 100

## Tags for categorization
var tags: Array = []

## Creation timestamp
var created_at: int

## Last updated timestamp
var updated_at: int

## Signal emitted when a lesson is added
signal lesson_added(lesson_id: String, wisdom: String, confidence: float)

## Internal lesson structure
class Lesson:
	var id: String
	var wisdom: String
	var confidence: float
	var context: Dictionary
	var success_count: int = 0
	var failure_count: int = 0
	var created_at: int
	var last_used: int

	func _init(i: String, w: String, c: float):
		id = i
		wisdom = w
		confidence = c
		created_at = Time.get_ticks_msec()
		last_used = created_at

## Create a new bloodline
func _init(bloodline_name: String, bloodline_desc: String = "") -> void:
	name = bloodline_name
	description = bloodline_desc
	created_at = Time.get_ticks_msec()
	updated_at = created_at

## Add a lesson to this bloodline
## @param lesson_id: Unique identifier for the lesson
## @param wisdom: The wisdom/advice text
## @param confidence: Initial confidence (0.0 to 1.0)
## @param context: Context where this lesson applies
func add_lesson(lesson_id: String, wisdom: String, confidence: float = 0.8, context: Dictionary = {}) -> void:
	# Check if lesson already exists
	for lesson in lessons:
		if lesson.id == lesson_id:
			# Update existing lesson
			lesson.wisdom = wisdom
			lesson.confidence = confidence
			lesson.context.merge(context)
			updated_at = Time.get_ticks_msec()
			return

	# Create new lesson
	var lesson = Lesson.new(lesson_id, wisdom, clamp(confidence, 0.0, 1.0))
	lesson.context = context
	lessons.append(lesson)

	# Maintain limit
	if lessons.size() > max_lessons:
		_remove_lowest_confidence_lesson()

	updated_at = Time.get_ticks_msec()
	lesson_added.emit(lesson_id, wisdom, confidence)

## Remove lowest confidence lesson
func _remove_lowest_confidence_lesson() -> void:
	if lessons.is_empty():
		return

	var lowest_idx = 0
	var lowest_conf = lessons[0].confidence

	for i in range(1, lessons.size()):
		if lessons[i].confidence < lowest_conf:
			lowest_conf = lessons[i].confidence
			lowest_idx = i

	lessons.remove_at(lowest_idx)

## Remove a lesson by ID
func remove_lesson(lesson_id: String) -> bool:
	for i in range(lessons.size()):
		if lessons[i].id == lesson_id:
			lessons.remove_at(i)
			updated_at = Time.get_ticks_msec()
			return true
	return false

## Get a lesson by ID
func get_lesson(lesson_id: String) -> Lesson:
	for lesson in lessons:
		if lesson.id == lesson_id:
			return lesson
	return null

## Record lesson success (increase confidence)
func record_success(lesson_id: String) -> void:
	var lesson = get_lesson(lesson_id)
	if lesson:
		lesson.success_count += 1
		lesson.last_used = Time.get_ticks_msec()
		# Adjust confidence upward
		lesson.confidence = min(lesson.confidence + 0.05, 1.0)
		updated_at = Time.get_ticks_msec()

## Record lesson failure (decrease confidence)
func record_failure(lesson_id: String) -> void:
	var lesson = get_lesson(lesson_id)
	if lesson:
		lesson.failure_count += 1
		# Adjust confidence downward
		lesson.confidence = max(lesson.confidence - 0.1, 0.0)
		updated_at = Time.get_ticks_msec()

## Get lessons sorted by confidence
func get_sorted_lessons() -> Array:
	var sorted = lessons.duplicate()
	sorted.sort_custom(func(a, b): return a.confidence > b.confidence)
	return sorted

## Get lessons relevant to a context
func get_relevant_lessons(context: Dictionary, min_confidence: float = 0.5) -> Array:
	var relevant: Array = []

	for lesson in lessons:
		if lesson.confidence < min_confidence:
			continue

		var relevance = _calculate_relevance(lesson, context)
		if relevance > 0.3:  # Relevance threshold
			relevant.append({
				"lesson": lesson,
				"relevance": relevance
			})

	# Sort by relevance * confidence
	relevant.sort_custom(func(a, b):
		var score_a = a.relevance * a.lesson.confidence
		var score_b = b.relevance * b.lesson.confidence
		return score_a > score_b
	)

	return relevant

## Calculate relevance of a lesson to a context
func _calculate_relevance(lesson: Lesson, context: Dictionary) -> float:
	if lesson.context.is_empty():
		return 0.5  # Default relevance for lessons without context

	var matching_keys = 0
	var total_keys = 0

	for key in context:
		total_keys += 1
		if lesson.context.has(key):
			if lesson.context[key] == context[key]:
				matching_keys += 1
			elif lesson.context[key] is float and context[key] is float:
				# Numeric similarity
				var diff = abs(lesson.context[key] - context[key])
				var max_val = max(abs(lesson.context[key]), abs(context[key]), 1.0)
				matching_keys += max(0, 1.0 - diff / max_val)

	if total_keys == 0:
		return 0.5

	return float(matching_keys) / float(total_keys)

## Add a tag
func add_tag(tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)
		updated_at = Time.get_ticks_msec()

## Remove a tag
func remove_tag(tag: String) -> bool:
	var idx = tags.find(tag)
	if idx >= 0:
		tags.remove_at(idx)
		updated_at = Time.get_ticks_msec()
		return true
	return false

## Check if has tag
func has_tag(tag: String) -> bool:
	return tags.has(tag)

## Get top N lessons
func get_top_lessons(count: int = 5) -> Array:
	var sorted = get_sorted_lessons()
	return sorted.slice(0, min(count, sorted.size()))

## Get bloodline statistics
func get_stats() -> Dictionary:
	var total_success = 0
	var total_failure = 0
	var total_confidence: float = 0.0

	for lesson in lessons:
		total_success += lesson.success_count
		total_failure += lesson.failure_count
		total_confidence += lesson.confidence

	return {
		"name": name,
		"lesson_count": lessons.size(),
		"total_success": total_success,
		"total_failure": total_failure,
		"avg_confidence": total_confidence / float(lessons.size()) if lessons.size() > 0 else 0.0,
		"tags": tags.duplicate()
	}

## Convert to prompt block for AI
func to_prompt_block() -> String:
	var lines: Array = []
	lines.append("=== BLOODLINE: %s ===" % name.to_upper())
	lines.append(description)
	lines.append("")

	var top = get_top_lessons(10)
	if top.is_empty():
		lines.append("(no lessons yet)")
	else:
		lines.append("TOP LESSONS:")
		for i in range(top.size()):
			var lesson = top[i]
			lines.append("%d. [%d%%] %s" % [
				i + 1,
				int(lesson.confidence * 100),
				lesson.wisdom
			])

	return "\n".join(lines)

## Export to dictionary
func to_dict() -> Dictionary:
	var lessons_data: Array = []
	for lesson in lessons:
		lessons_data.append({
			"id": lesson.id,
			"wisdom": lesson.wisdom,
			"confidence": lesson.confidence,
			"context": lesson.context,
			"success_count": lesson.success_count,
			"failure_count": lesson.failure_count,
			"created_at": lesson.created_at,
			"last_used": lesson.last_used
		})

	return {
		"name": name,
		"description": description,
		"max_lessons": max_lessons,
		"lessons": lessons_data,
		"tags": tags,
		"created_at": created_at,
		"updated_at": updated_at
	}

## Load from dictionary
static func from_dict(data: Dictionary) -> Variant:
	var script = preload("res://addons/awr/crypt/bloodline.gd")
	var b = script.new(data.name, data.get("description", ""))
	b.max_lessons = data.get("max_lessons", 100)
	b.tags = data.get("tags", []).duplicate()
	b.created_at = data.get("created_at", Time.get_ticks_msec())
	b.updated_at = data.get("updated_at", b.created_at)

	for lesson_data in data.get("lessons", []):
		var lesson = Lesson.new(
			lesson_data.id,
			lesson_data.wisdom,
			lesson_data.confidence
		)
		lesson.context = lesson_data.get("context", {})
		lesson.success_count = lesson_data.get("success_count", 0)
		lesson.failure_count = lesson_data.get("failure_count", 0)
		lesson.created_at = lesson_data.get("created_at", Time.get_ticks_msec())
		lesson.last_used = lesson_data.get("last_used", lesson.created_at)
		b.lessons.append(lesson)

	return b

## Create default bloodlines
static func create_default_bloodlines() -> Array:
	var bloodlines: Array = []
	var script = preload("res://addons/awr/crypt/bloodline.gd")

	# Navigation bloodline
	var nav = script.new("navigation", "Wisdom about spatial navigation")
	nav.add_lesson("avoid_obstacles", "Check for obstacles before moving", 0.9)
	nav.add_lesson("path_efficiency", "Prefer shorter paths when available", 0.8)
	nav.add_lesson("explore_systematically", "Explore unknown areas systematically", 0.7)
	nav.add_tag("spatial")
	nav.add_tag("movement")
	bloodlines.append(nav)

	# Physics bloodline
	var physics = script.new("physics", "Wisdom about physical interactions")
	physics.add_lesson("momentum_conservation", "Account for momentum in predictions", 0.9)
	physics.add_lesson("collision_timing", "Time collisions for maximum effect", 0.7)
	physics.add_lesson("force_modulation", "Modulate force based on distance to goal", 0.8)
	physics.add_tag("physics")
	physics.add_tag("simulation")
	bloodlines.append(physics)

	# Strategy bloodline
	var strategy = script.new("strategy", "Wisdom about strategic planning")
	strategy.add_lesson("evaluate_alternatives", "Always evaluate multiple options", 0.9)
	strategy.add_lesson("commit_to_best", "Commit to the best evaluated option", 0.8)
	strategy.add_lesson("adapt_to_failure", "Adapt strategy when encountering failure", 0.85)
	strategy.add_tag("planning")
	strategy.add_tag("decision")
	bloodlines.append(strategy)

	return bloodlines
