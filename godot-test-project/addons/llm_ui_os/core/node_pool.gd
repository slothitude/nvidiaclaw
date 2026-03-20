extends Node

const PREALLOC_COUNT: int = 5
const POOL_TYPES: Array[String] = [
	"UILabel", "UIButton", "UISlider", "UIInput", "UIContainer"
]

# _pools[type] = Array of Node
var _pools: Dictionary = {}
# _stats[type] = { pool_size: int, total_checked_out: int }
var _stats: Dictionary = {}

# Script paths for each type - updated for addon path
const SCRIPTS: Dictionary = {
	"UILabel":     "res://addons/llm_ui_os/components/ui_label.gd",
	"UIButton":    "res://addons/llm_ui_os/components/ui_button.gd",
	"UISlider":    "res://addons/llm_ui_os/components/ui_slider.gd",
	"UIInput":     "res://addons/llm_ui_os/components/ui_input.gd",
	"UIContainer": "res://addons/llm_ui_os/components/ui_container.gd",
}


func _ready() -> void:
	for type in POOL_TYPES:
		_pools[type] = []
		_stats[type] = { "pool_size": 0, "total_checked_out": 0 }
		_preallocate(type, PREALLOC_COUNT)


func checkout(type: String) -> Node:
	if not _pools.has(type):
		push_error("NodePool: unknown type '%s'" % type)
		return null

	var node: Node
	if _pools[type].size() > 0:
		node = _pools[type].pop_back()
	else:
		node = _instantiate(type)

	if node != null:
		node.show()
		_stats[type].pool_size = _pools[type].size()
		_stats[type].total_checked_out += 1

	return node


func checkin(node: Node) -> void:
	if node == null:
		return
	var type := _node_type(node)
	if type.is_empty() or not _pools.has(type):
		node.queue_free()
		return

	_reset_node(node)
	_pools[type].append(node)
	_stats[type].pool_size = _pools[type].size()
	_stats[type].total_checked_out = max(0, _stats[type].total_checked_out - 1)


func checkin_children(parent: Node) -> void:
	# Check in all component children of a container back to pool
	for child in parent.get_children():
		if child.has_method("reset"):
			checkin(child)
		elif child is Control:
			checkin_children(child)
			child.queue_free()


func get_stats() -> Dictionary:
	return _stats.duplicate(true)


func clear_all() -> void:
	for type in _pools:
		for node in _pools[type]:
			node.queue_free()
		_pools[type].clear()
		_stats[type] = { "pool_size": 0, "total_checked_out": 0 }
	# Rebuild preallocs
	for type in POOL_TYPES:
		_preallocate(type, PREALLOC_COUNT)


# ─── Internals ───────────────────────────────────────────────────────────────

func _preallocate(type: String, count: int) -> void:
	for i in range(count):
		var node := _instantiate(type)
		if node != null:
			node.hide()
			_pools[type].append(node)
	_stats[type].pool_size = _pools[type].size()


func _instantiate(type: String) -> Node:
	if not SCRIPTS.has(type):
		push_error("NodePool: no script for type '%s'" % type)
		return null
	var script: Script = load(SCRIPTS[type])
	if script == null:
		push_error("NodePool: could not load script %s" % SCRIPTS[type])
		return null
	var node: Node = script.new()
	add_child(node)  # pool owns all nodes
	return node


func _reset_node(node: Node) -> void:
	if node.has_method("reset"):
		node.reset()
	node.hide()
	if node is Control:
		node.modulate = Color.WHITE
		node.scale = Vector2.ONE


func _node_type(node: Node) -> String:
	for type in SCRIPTS:
		# Match by script class
		if node.get_script() != null:
			var path: String = node.get_script().resource_path
			if SCRIPTS[type] == path:
				return type
	return ""
