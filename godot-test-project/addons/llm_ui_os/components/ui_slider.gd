extends HSlider

var _bind_write_key: String = ""


func apply(spec: Dictionary) -> void:
	min_value = spec.get("min", 0.0)
	max_value = spec.get("max", 100.0)
	step      = spec.get("step", 1.0)

	var bind_key: String = spec.get("bind", "")
	if not bind_key.is_empty():
		var bound_val = StateManager.bind(bind_key)
		if bound_val != null:
			value = float(str(bound_val))
		StateManager.register_listener(bind_key, func(v): value = float(str(v)))

	_bind_write_key = spec.get("bind_write", "")
	if not _bind_write_key.is_empty():
		value = spec.get("value", min_value)
		# Disconnect old before connecting
		for conn in get_signal_connection_list("value_changed"):
			disconnect("value_changed", conn["callable"])
		value_changed.connect(_on_value_changed)
	else:
		value = spec.get("value", min_value)


func _on_value_changed(new_val: float) -> void:
	if not _bind_write_key.is_empty():
		StateManager.bind_write(_bind_write_key, new_val)


func reset() -> void:
	min_value = 0.0
	max_value = 100.0
	step = 1.0
	value = 0.0
	_bind_write_key = ""
	for conn in get_signal_connection_list("value_changed"):
		disconnect("value_changed", conn["callable"])
