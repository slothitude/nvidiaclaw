extends Node

# ─── Signals ────────────────────────────────────────────────────────────────
signal state_changed(key: String, value: Variant)

# ─── Public tracked state ────────────────────────────────────────────────────
var current_ui_id: String        = ""
var focused_element_id: String   = ""
var last_action: String          = ""
var scroll_position: Vector2     = Vector2.ZERO

# ─── Binding registry ────────────────────────────────────────────────────────
# _bindings[key] = { value: Variant, listeners: Array[Callable] }
var _bindings: Dictionary        = {}

# Debounce for context refresh
var _refresh_pending: bool       = false
const REFRESH_DEBOUNCE_MS: int   = 200
var _last_write_ms: int          = 0


func _process(_delta: float) -> void:
	if _refresh_pending:
		var now := Time.get_ticks_msec()
		if now - _last_write_ms >= REFRESH_DEBOUNCE_MS:
			_refresh_pending = false
			# Notify AgentBridge that context has changed (it can decide whether to re-request)
			AgentBridge.emit_signal("state_changed", "state_manager_updated")


# ─── Binding API ─────────────────────────────────────────────────────────────

func bind(key: String) -> Variant:
	if not _bindings.has(key):
		return null
	return _bindings[key].value


func bind_write(key: String, value: Variant) -> void:
	if not _bindings.has(key):
		_bindings[key] = { "value": null, "listeners": [] }
	_bindings[key].value = value
	_last_write_ms = Time.get_ticks_msec()
	_refresh_pending = true

	for cb: Callable in _bindings[key].listeners:
		cb.call(value)

	emit_signal("state_changed", key, value)


func register_listener(key: String, cb: Callable) -> void:
	if not _bindings.has(key):
		_bindings[key] = { "value": null, "listeners": [] }
	if not _bindings[key].listeners.has(cb):
		_bindings[key].listeners.append(cb)


func unregister_listener(key: String, cb: Callable) -> void:
	if _bindings.has(key):
		_bindings[key].listeners.erase(cb)


# ─── Snapshot for LLM context ────────────────────────────────────────────────

func snapshot() -> Dictionary:
	var values: Dictionary = {}
	for key in _bindings:
		values[key] = _bindings[key].value

	return {
		"current_ui": current_ui_id,
		"focused": focused_element_id,
		"last_action": last_action,
		"scroll": { "x": scroll_position.x, "y": scroll_position.y },
		"bindings": values,
	}


# ─── Convenience ─────────────────────────────────────────────────────────────

func set_focus(element_id: String) -> void:
	focused_element_id = element_id


func record_action(action: String) -> void:
	last_action = action
