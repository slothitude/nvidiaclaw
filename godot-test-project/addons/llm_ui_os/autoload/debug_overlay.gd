extends CanvasLayer

const REFRESH_INTERVAL: float = 0.5

var _panel: PanelContainer
var _labels: Dictionary = {}
var _timer: float = 0.0
var _visible: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	layer = 100
	_build_panel()
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_visible = not _visible
			if _visible:
				show()
			else:
				hide()


func _process(delta: float) -> void:
	if not _visible:
		return
	_timer += delta
	if _timer >= REFRESH_INTERVAL:
		_timer = 0.0
		_refresh()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_right = 360
	_panel.offset_bottom = 520
	_panel.offset_left = 8
	_panel.offset_top = 8
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	var heading := Label.new()
	heading.text = "LLM UI OS — Debug [F12]"
	heading.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(heading)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var label_keys := [
		"agent_state",
		"last_request",
		"last_spec",
		"diff_ops",
		"pool_stats",
		"audit_tail",
		"state_snap",
	]
	for key in label_keys:
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.custom_minimum_size.x = 340
		vbox.add_child(lbl)
		_labels[key] = lbl

	var btn_clear := Button.new()
	btn_clear.text = "Clear pool"
	btn_clear.pressed.connect(func(): NodePool.clear_all())
	vbox.add_child(btn_clear)

	var btn_mock := Button.new()
	btn_mock.text = "Mock UI Response"
	btn_mock.pressed.connect(func(): AgentBridge.mock_response())
	vbox.add_child(btn_mock)

	var btn_dump := Button.new()
	btn_dump.text = "Dump log to user://debug_dump.json"
	btn_dump.pressed.connect(_dump_log)
	vbox.add_child(btn_dump)


func _refresh() -> void:
	_labels["agent_state"].text = "Agent: %s | %s" % [
		AgentBridge._state_name,
		AgentBridge.last_status,
	]
	_labels["last_request"].text = "Last req: %s" % AgentBridge.last_request_time
	_labels["last_spec"].text = "Spec: %s  (%d elements)" % [
		UIManager.last_spec_id,
		UIManager.last_element_count,
	]
	_labels["diff_ops"].text = "Diff ops last render: %d" % UIManager.last_diff_ops_count

	var stats := NodePool.get_stats()
	var stats_str := ""
	for t in stats:
		stats_str += "%s: pool=%d out=%d  " % [t, stats[t].pool_size, stats[t].total_checked_out]
	_labels["pool_stats"].text = "Pool: " + stats_str

	var audit := ActionRouter.get_audit_log()
	var tail := audit.slice(max(0, audit.size() - 3))
	var audit_str := ""
	for entry in tail:
		audit_str += "%s %s\n" % [entry.get("timestamp","?").right(8), entry.get("action","?")]
	_labels["audit_tail"].text = "Actions:\n" + audit_str.strip_edges()

	var snap_str := JSON.stringify(StateManager.snapshot())
	_labels["state_snap"].text = "State: " + snap_str.left(180)


func _dump_log() -> void:
	var data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"audit_log": ActionRouter.get_audit_log(),
		"state_snapshot": StateManager.snapshot(),
		"last_spec_id": UIManager.last_spec_id,
		"pool_stats": NodePool.get_stats(),
	}
	var f := FileAccess.open("user://debug_dump.json", FileAccess.WRITE)
	if f == null:
		push_error("DebugOverlay: could not open debug_dump.json for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	push_warning("DebugOverlay: dumped to user://debug_dump.json")
