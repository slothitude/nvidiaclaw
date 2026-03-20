extends LineEdit

var _bind_write_key: String = ""


func apply(spec: Dictionary) -> void:
	placeholder_text = spec.get("placeholder", "")
	text = spec.get("text", "")
	max_length = spec.get("max_length", 0)

	_bind_write_key = spec.get("bind_write", "")
	for conn in get_signal_connection_list("text_changed"):
		disconnect("text_changed", conn["callable"])
	if not _bind_write_key.is_empty():
		text_changed.connect(_on_text_changed)

	var bind_key: String = spec.get("bind", "")
	if not bind_key.is_empty():
		var bound_val = StateManager.bind(bind_key)
		if bound_val != null:
			text = str(bound_val)
		StateManager.register_listener(bind_key, func(v): text = str(v))


func _on_text_changed(new_text: String) -> void:
	if not _bind_write_key.is_empty():
		StateManager.bind_write(_bind_write_key, new_text)


func reset() -> void:
	placeholder_text = ""
	text = ""
	max_length = 0
	_bind_write_key = ""
	for conn in get_signal_connection_list("text_changed"):
		disconnect("text_changed", conn["callable"])
