extends Button


func apply(spec: Dictionary) -> void:
	text = spec.get("text", "")
	tooltip_text = spec.get("tooltip", "")
	disabled = spec.get("disabled", false)

	# Disconnect old pressed connections to prevent accumulation
	for conn in get_signal_connection_list("pressed"):
		disconnect("pressed", conn["callable"])

	var action: String = spec.get("action", "")
	var payload: Dictionary = spec.get("payload", {})
	if not action.is_empty():
		pressed.connect(ActionRouter.handle.bind(action, payload))

	var bind_key: String = spec.get("bind", "")
	if not bind_key.is_empty():
		var bound_val = StateManager.bind(bind_key)
		if bound_val != null:
			text = str(bound_val)
		StateManager.register_listener(bind_key, func(v): text = str(v))


func reset() -> void:
	text = ""
	tooltip_text = ""
	disabled = false
	for conn in get_signal_connection_list("pressed"):
		disconnect("pressed", conn["callable"])
