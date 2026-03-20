extends Node

# ─── Signals ────────────────────────────────────────────────────────────────
signal action_handled(action: String, payload: Dictionary)

# ─── Config ──────────────────────────────────────────────────────────────────
const DEBOUNCE_MS: int     = 300
const AUDIT_MAX: int       = 100

# ─── Runtime ─────────────────────────────────────────────────────────────────
var _debounce_table: Dictionary  = {}   # action_id -> last_ms
var _audit_log: Array            = []   # ring buffer of Dictionaries


# ─── Public API ──────────────────────────────────────────────────────────────

func handle(action: String, payload: Dictionary = {}) -> void:
	if action.is_empty():
		return

	if not _can_run(action):
		return

	StateManager.record_action(action)
	_audit(action, payload)

	if action.begins_with("sys:"):
		_handle_system(action.substr(4), payload)
	elif action.begins_with("agent:"):
		_handle_agent(action.substr(6), payload)
	else:
		# Bare actions treated as system
		_handle_system(action, payload)

	emit_signal("action_handled", action, payload)


func get_audit_log() -> Array:
	return _audit_log.duplicate()


# ─── System actions ──────────────────────────────────────────────────────────

func _handle_system(action: String, payload: Dictionary) -> void:
	match action:
		"navigate":
			var target: String = payload.get("target", "")
			if not target.is_empty():
				AgentBridge.request_ui(target)

		"refresh":
			AgentBridge.request_ui(StateManager.current_ui_id)

		"close":
			UIManager.clear()

		"emit_signal":
			# payload: { signal_name: String, args: Array }
			var sig: String = payload.get("signal_name", "")
			if not sig.is_empty():
				var args: Array = payload.get("args", [])
				get_tree().root.propagate_call("emit_signal", [sig] + args, false)

		"set_state":
			# payload: { key: String, value: Variant }
			var key: String = payload.get("key", "")
			if not key.is_empty():
				StateManager.bind_write(key, payload.get("value"))

		"send_chat":
			# Integration with SSH AI Bridge - send message to chat
			var msg: String = payload.get("message", "")
			if not msg.is_empty() and AIChat:
				AIChat.send_message(msg)

		"clear_chat":
			# Clear chat history
			if AIChat:
				AIChat.clear_history()

		_:
			push_warning("ActionRouter: unknown system action '%s'" % action)


# ─── Agent actions ───────────────────────────────────────────────────────────

func _handle_agent(action: String, payload: Dictionary) -> void:
	match action:
		"send_message":
			# Send message to AI via chat
			var msg: String = payload.get("message", "")
			if not msg.is_empty() and AIChat:
				AIChat.send_message(msg)

		"action":
			# Generic agent action - request new UI with context
			var context := "action:%s payload:%s" % [action, JSON.stringify(payload)]
			AgentBridge.request_ui(context)

		"save_settings":
			# Save current settings
			if AIChat:
				AIChat.save_settings()

		_:
			# Default: request UI with action context
			var context := "action:%s payload:%s" % [action, JSON.stringify(payload)]
			AgentBridge.request_ui(context)


# ─── Internals ───────────────────────────────────────────────────────────────

func _can_run(action: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - _debounce_table.get(action, 0) < DEBOUNCE_MS:
		return false
	_debounce_table[action] = now
	return true


func _audit(action: String, payload: Dictionary) -> void:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(),
		"action": action,
		"payload": payload,
	}
	_audit_log.append(entry)
	if _audit_log.size() > AUDIT_MAX:
		_audit_log.pop_front()
