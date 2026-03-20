extends Node

# ─── Signals ────────────────────────────────────────────────────────────────
signal element_ready(element: Dictionary)
signal spec_ready(spec: Dictionary)
signal state_changed(new_state: String)
signal error(code: String, msg: String)

# ─── State machine ───────────────────────────────────────────────────────────
enum State { IDLE, REQUESTING, STREAMING, VALIDATING, DIFFING, RENDERING, ERROR, TIMEOUT }

var _state: State = State.IDLE
var _state_name: String = "IDLE"  # for DebugOverlay

# ─── Config ──────────────────────────────────────────────────────────────────
const RATE_LIMIT_MS: int       = 500
const STREAM_TIMEOUT_MS: int   = 30_000  # Increased for remote AI
const MAX_RETRIES: int         = 3

# ─── Runtime state ───────────────────────────────────────────────────────────
var _last_request_ms: int      = 0
var _retry_count: int          = 0
var _stream_timer: float       = 0.0
var _is_streaming: bool        = false
var _ndjson_buffer: String     = ""
var _current_spec_elements: Array[Dictionary] = []
var _current_spec_meta: Dictionary = {}
var _pending_context: String   = ""

# public for DebugOverlay
var last_request_time: String  = "never"
var last_status: String        = "idle"


func _ready() -> void:
	# Connect to AIChat signals for integration
	if AIChat:
		AIChat.stream_update.connect(_on_aichat_stream_update)
		AIChat.message_added.connect(_on_aichat_message_added)
		AIChat.connection_changed.connect(_on_aichat_connection_changed)


func _process(delta: float) -> void:
	if _is_streaming:
		_stream_timer += delta
		if _stream_timer * 1000.0 > STREAM_TIMEOUT_MS:
			_transition(State.TIMEOUT)
			_handle_timeout()


# ─── Public API ──────────────────────────────────────────────────────────────

func request_ui(context: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_request_ms < RATE_LIMIT_MS:
		push_warning("AgentBridge: rate limited, ignoring request")
		return
	if _state != State.IDLE and _state != State.ERROR:
		push_warning("AgentBridge: busy (state=%s), ignoring request" % _state_name)
		return

	_last_request_ms = now
	last_request_time = Time.get_datetime_string_from_system()
	_transition(State.REQUESTING)
	_send_request(context)


func mock_response() -> void:
	# For offline testing — inject a valid NDJSON response directly
	var mock_ndjson := (
		'{"id":"mock_menu","dsl_version":"1.0","layout":"vbox","transition":"fade_scale"}\n'
		+ '{"type":"label","id":"title","text":"Dynamic Panel"}\n'
		+ '{"type":"label","id":"subtitle","text":"AI-generated UI controls"}\n'
		+ '{"type":"button","id":"btn_start","text":"Send Chat","action":"agent:send_message","payload":{"message":"Hello from dynamic panel!"}}\n'
		+ '{"type":"slider","id":"vol","text":"Volume","min":0,"max":100,"bind_write":"volume"}\n'
		+ '{"type":"button","id":"btn_refresh","text":"Refresh","action":"sys:refresh"}\n'
		+ '{"__end__":true}\n'
	)
	_transition(State.STREAMING)
	_process_ndjson_chunk(mock_ndjson)


# ─── Internal ────────────────────────────────────────────────────────────────

func _send_request(context: String) -> void:
	if not AIChat or not AIChat.is_connected:
		_handle_error("NOT_CONNECTED", "AIChat is not connected to SSH server")
		return

	_pending_context = context
	var prompt := _build_prompt(context)

	# Clear stream buffer for new request
	_ndjson_buffer = ""
	_current_spec_elements.clear()
	_current_spec_meta.clear()

	_transition(State.STREAMING)
	_is_streaming = true
	_stream_timer = 0.0
	last_status = "streaming"

	# Send prompt via AIChat
	AIChat.send_message(prompt)


func _build_prompt(context: String) -> String:
	var snapshot := StateManager.snapshot()
	return UI_PROMPT_TEMPLATE % [context, JSON.stringify(snapshot)]


const UI_PROMPT_TEMPLATE := """
You are a UI generator for a chat application.
Respond with NDJSON (one JSON object per line) to define the UI.

Line 1: spec header { id, dsl_version: "1.0", layout, transition }
Lines 2-N: elements { type, id, text, action?, bind?, bind_write? }
Final line: {"__end__": true}

Available types: label, button, slider, input, container
Available actions:
- sys:navigate - Navigate to a context (payload: {target})
- sys:refresh - Refresh current UI
- sys:clear - Clear the UI
- agent:send_message - Send a chat message (payload: {message})
- agent:action - Trigger agent action (payload: {action, params})

Context: %s
Current state: %s

Rules: max 50 elements, all ids must be unique, actions must start with sys: or agent:
Generate a useful UI panel now:
"""


func _on_aichat_connection_changed(connected: bool) -> void:
	if not connected and _is_streaming:
		_handle_error("DISCONNECTED", "Lost connection during streaming")
		_is_streaming = false


func _on_aichat_message_added(role: String, content: String) -> void:
	# We handle responses via stream_update, but this is a fallback
	if role == "assistant" and _is_streaming:
		# Check if content contains NDJSON
		if "{" in content and "__end__" in content:
			_process_ndjson_chunk(content)


func _on_aichat_stream_update(chunk: Dictionary) -> void:
	if not _is_streaming:
		return

	var chunk_type = chunk.get("type", "")

	match chunk_type:
		"text":
			var content = chunk.get("content", "")
			_process_ndjson_chunk(content)
		"complete":
			# Stream finished - try to finalize
			_try_finalize_spec()
		"error":
			_handle_error("STREAM_ERROR", chunk.get("content", "Unknown stream error"))


func _process_ndjson_chunk(chunk: String) -> void:
	_ndjson_buffer += chunk
	var lines := _ndjson_buffer.split("\n")
	# Keep last incomplete line in buffer
	_ndjson_buffer = lines[-1]

	for i in range(lines.size() - 1):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		_process_ndjson_line(line)


func _process_ndjson_line(line: String) -> void:
	var parsed := SchemaValidator.parse_ndjson_line(line)
	if not parsed.ok:
		# Don't warn on every line - could be regular text response
		return

	var data: Dictionary = parsed.data

	# End sentinel
	if data.get("__end__", false):
		_finalise_spec()
		return

	# Spec header line (has id + dsl_version, no type)
	if data.has("id") and data.has("dsl_version") and not data.has("type"):
		_current_spec_meta = data
		# Migrate if needed
		if data.get("dsl_version", "1.0") != SchemaValidator.CURRENT_VERSION:
			_current_spec_meta = SchemaValidator.migrate(_current_spec_meta)
		return

	# Element line
	_transition(State.VALIDATING)
	var validation := SchemaValidator.validate_element(data)
	if not validation.valid:
		push_warning("AgentBridge: invalid element %s: %s" % [data.get("id","?"), str(validation.errors)])
		_transition(State.STREAMING)
		return

	_current_spec_elements.append(data)
	emit_signal("element_ready", data)
	_transition(State.STREAMING)


func _try_finalize_spec() -> void:
	# Try to finalize if we have some elements
	if _current_spec_elements.size() > 0 or not _current_spec_meta.is_empty():
		_finalise_spec()
	else:
		# No valid spec found, load fallback
		_handle_error("NO_SPEC", "No valid NDJSON UI spec in response")


func _finalise_spec() -> void:
	_is_streaming = false

	if _current_spec_meta.is_empty():
		# Create a default spec header
		_current_spec_meta = {
			"id": "generated_%s" % Time.get_ticks_msec(),
			"dsl_version": "1.0",
			"layout": "vbox",
			"transition": "fade_scale"
		}

	var full_spec := _current_spec_meta.duplicate()
	full_spec["elements"] = _current_spec_elements.duplicate()

	var validation := SchemaValidator.validate_spec(full_spec)
	if not validation.valid:
		push_warning("AgentBridge: spec validation issues: %s" % str(validation.errors))
		# Continue anyway with partial spec

	_retry_count = 0
	last_status = "ok"
	_current_spec_elements.clear()
	_current_spec_meta.clear()
	_ndjson_buffer = ""

	_transition(State.DIFFING)
	emit_signal("spec_ready", full_spec)
	_transition(State.IDLE)


func _handle_error(code: String, msg: String) -> void:
	push_error("AgentBridge ERROR [%s]: %s" % [code, msg])
	_is_streaming = false
	last_status = "error: %s" % code
	_transition(State.ERROR)
	emit_signal("error", code, msg)

	if _retry_count < MAX_RETRIES:
		_retry_count += 1
		# Don't auto-retry - let caller decide
	else:
		_retry_count = 0
		# Load fallback UI
		var fallback := _load_fallback()
		if not fallback.is_empty():
			emit_signal("spec_ready", fallback)
		_transition(State.IDLE)


func _handle_timeout() -> void:
	_is_streaming = false
	_ndjson_buffer = ""
	_current_spec_elements.clear()
	_current_spec_meta.clear()
	_handle_error("TIMEOUT", "Stream exceeded %dms" % STREAM_TIMEOUT_MS)


func _load_fallback() -> Dictionary:
	var f := FileAccess.open("res://addons/llm_ui_os/data/fallback_ui.json", FileAccess.READ)
	if f == null:
		push_error("AgentBridge: could not load fallback_ui.json")
		return {}
	var text := f.get_as_text()
	f.close()
	var result := JSON.parse_string(text)
	if result == null:
		push_error("AgentBridge: fallback_ui.json is invalid JSON")
		return {}
	return result


func _transition(new_state: State) -> void:
	_state = new_state
	_state_name = State.keys()[new_state]
	emit_signal("state_changed", _state_name)
