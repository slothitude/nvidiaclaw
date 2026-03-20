extends Node

# ─── Signals ────────────────────────────────────────────────────────────────
signal render_complete(ui_id: String)

# ─── Config ──────────────────────────────────────────────────────────────────
const MAX_ELEMENTS: int = 50

# ─── Runtime ─────────────────────────────────────────────────────────────────
var _root_container: Control       = null  # current live UI root
var _staging_container: Control    = null  # built during streaming before swap
var _current_spec: Dictionary      = {}
var _ui_parent: Node               = null  # set by scene to receive UI nodes

# Public for DebugOverlay
var last_spec_id: String           = ""
var last_element_count: int        = 0
var last_diff_ops_count: int       = 0


func _ready() -> void:
	AgentBridge.element_ready.connect(_on_element_ready)
	AgentBridge.spec_ready.connect(_on_spec_ready)


# Call from your main scene to tell UIManager where to attach rendered UI
func set_ui_parent(parent: Node) -> void:
	_ui_parent = parent


# ─── Streaming path (incremental) ────────────────────────────────────────────

func _on_element_ready(element: Dictionary) -> void:
	# Build into staging container during stream
	if _staging_container == null:
		_staging_container = VBoxContainer.new()
		_staging_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if _staging_container.get_child_count() >= MAX_ELEMENTS:
		push_warning("UIManager: MAX_ELEMENTS reached, dropping element %s" % element.get("id","?"))
		return

	var node := _create_component(element)
	if node != null:
		_staging_container.add_child(node)


# ─── Full spec path ──────────────────────────────────────────────────────────

func _on_spec_ready(spec: Dictionary) -> void:
	last_spec_id = spec.get("id", "?")
	last_element_count = spec.get("elements", []).size()

	var ops := DiffEngine.diff(_current_spec, spec)
	last_diff_ops_count = ops.size()

	if ops.is_empty():
		# No change needed
		_staging_container = null
		return

	# If we built a staging container during streaming, use it
	# Otherwise build fresh from spec
	var new_root: Control
	if _staging_container != null:
		new_root = _staging_container
		_staging_container = null
	else:
		new_root = _build_from_spec(spec)

	if new_root == null:
		return

	if _ui_parent != null:
		_ui_parent.add_child(new_root)

	var transition_type: String = spec.get("transition", "fade_scale")
	TransitionManager.transition(_root_container, new_root, transition_type)
	TransitionManager.transition_complete.connect(_on_transition_complete.bind(spec.get("id","")), CONNECT_ONE_SHOT)

	_current_spec = spec


func _on_transition_complete(ui_id: String) -> void:
	_root_container = _get_active_root()
	StateManager.current_ui_id = ui_id
	emit_signal("render_complete", ui_id)


func _get_active_root() -> Control:
	if _ui_parent == null:
		return null
	for child in _ui_parent.get_children():
		if child is Control and child.visible:
			return child
	return null


# ─── Build from spec (non-streaming path) ────────────────────────────────────

func _build_from_spec(spec: Dictionary) -> Control:
	var layout: String = spec.get("layout", "vbox")
	var root: Control

	match layout:
		"hbox":
			root = HBoxContainer.new()
		"grid":
			root = GridContainer.new()
		_:
			root = VBoxContainer.new()

	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var elements: Array = spec.get("elements", [])
	var count := 0
	for el in elements:
		if count >= MAX_ELEMENTS:
			push_warning("UIManager: MAX_ELEMENTS hit, truncating spec")
			break
		var node := _create_component(el)
		if node != null:
			root.add_child(node)
			count += 1

	return root


# ─── Component Creation (inlined to avoid circular deps) ─────────────────────

func _create_component(spec: Dictionary) -> Control:
	var type: String = spec.get("type", "")
	var node: Control

	match type:
		"label":
			node = NodePool.checkout("UILabel")
		"button":
			node = NodePool.checkout("UIButton")
		"slider":
			node = NodePool.checkout("UISlider")
		"input":
			node = NodePool.checkout("UIInput")
		"container":
			node = NodePool.checkout("UIContainer")
		_:
			push_warning("UIManager: unknown type '%s'" % type)
			return null

	if node == null:
		push_error("UIManager: NodePool returned null for type '%s'" % type)
		return null

	if node.has_method("apply"):
		node.apply(spec)

	return node


# ─── Public API ──────────────────────────────────────────────────────────────

func clear() -> void:
	if _root_container != null:
		NodePool.checkin_children(_root_container)
		_root_container.queue_free()
		_root_container = null
	_current_spec = {}
	last_spec_id = ""
	last_element_count = 0
