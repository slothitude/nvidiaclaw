extends Label

func apply(spec: Dictionary) -> void:
	text = spec.get("text", "")
	match spec.get("align", "left"):
		"center": horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"right":  horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:         horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var bind_key: String = spec.get("bind", "")
	if not bind_key.is_empty():
		var bound_val = StateManager.bind(bind_key)
		if bound_val != null:
			text = str(bound_val)
		StateManager.register_listener(bind_key, func(v): text = str(v))


func reset() -> void:
	text = ""
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
