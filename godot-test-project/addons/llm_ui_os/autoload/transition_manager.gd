extends Node

signal transition_complete(type: String)

const FADE_OUT_DURATION: float  = 0.25
const FADE_IN_DURATION: float   = 0.30
const SCALE_OUT: Vector2        = Vector2(0.85, 0.85)
const SCALE_IN_START: Vector2   = Vector2(0.92, 0.92)
const SLIDE_DISTANCE: float     = 80.0


func transition(old_node: Control, new_node: Control, type: String) -> void:
	if new_node == null:
		push_error("TransitionManager: new_node is null")
		return

	# Prepare new node
	new_node.modulate.a = 0.0
	new_node.scale = SCALE_IN_START

	match type:
		"fade":
			_fade(old_node, new_node)
		"scale":
			_scale(old_node, new_node)
		"slide_left":
			_slide(old_node, new_node, Vector2(-SLIDE_DISTANCE, 0), Vector2(SLIDE_DISTANCE, 0))
		"slide_right":
			_slide(old_node, new_node, Vector2(SLIDE_DISTANCE, 0), Vector2(-SLIDE_DISTANCE, 0))
		"fade_scale":
			_fade_scale(old_node, new_node)
		"instant":
			_instant(old_node, new_node)
		_:
			_fade_scale(old_node, new_node)


func _fade_scale(old_node: Control, new_node: Control) -> void:
	var tween := create_tween().set_parallel(true)

	if old_node != null:
		tween.tween_property(old_node, "scale", SCALE_OUT, FADE_OUT_DURATION)
		tween.tween_property(old_node, "modulate:a", 0.0, FADE_OUT_DURATION)

	tween.tween_property(new_node, "scale", Vector2.ONE, FADE_IN_DURATION)
	tween.tween_property(new_node, "modulate:a", 1.0, FADE_IN_DURATION)

	tween.chain().tween_callback(_cleanup.bind(old_node, "fade_scale"))


func _fade(old_node: Control, new_node: Control) -> void:
	new_node.scale = Vector2.ONE
	var tween := create_tween().set_parallel(true)

	if old_node != null:
		tween.tween_property(old_node, "modulate:a", 0.0, FADE_OUT_DURATION)

	tween.tween_property(new_node, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.chain().tween_callback(_cleanup.bind(old_node, "fade"))


func _scale(old_node: Control, new_node: Control) -> void:
	var tween := create_tween().set_parallel(true)

	if old_node != null:
		tween.tween_property(old_node, "scale", Vector2.ZERO, FADE_OUT_DURATION)
		tween.tween_property(old_node, "modulate:a", 0.0, FADE_OUT_DURATION)

	tween.tween_property(new_node, "scale", Vector2.ONE, FADE_IN_DURATION)
	tween.tween_property(new_node, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.chain().tween_callback(_cleanup.bind(old_node, "scale"))


func _slide(old_node: Control, new_node: Control, old_offset: Vector2, new_start: Vector2) -> void:
	new_node.scale = Vector2.ONE
	new_node.position += new_start

	var tween := create_tween().set_parallel(true)

	if old_node != null:
		tween.tween_property(old_node, "position", old_node.position + old_offset, FADE_OUT_DURATION)
		tween.tween_property(old_node, "modulate:a", 0.0, FADE_OUT_DURATION)

	tween.tween_property(new_node, "position", new_node.position - new_start, FADE_IN_DURATION)
	tween.tween_property(new_node, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.chain().tween_callback(_cleanup.bind(old_node, "slide"))


func _instant(old_node: Control, new_node: Control) -> void:
	if old_node != null:
		NodePool.checkin_children(old_node)
		old_node.queue_free()
	new_node.modulate.a = 1.0
	new_node.scale = Vector2.ONE
	emit_signal("transition_complete", "instant")


func _cleanup(old_node: Control, type: String) -> void:
	if old_node != null:
		NodePool.checkin_children(old_node)
		old_node.queue_free()
	emit_signal("transition_complete", type)
