extends BoxContainer

# Tracks children we checked out so we can return them
var _managed_children: Array[Node] = []


func apply(spec: Dictionary) -> void:
	var layout: String = spec.get("layout", "vbox")
	vertical = (layout != "hbox")

	var children: Array = spec.get("children", [])
	for child_spec in children:
		if not child_spec is Dictionary:
			continue
		var node := _create_child(child_spec)
		if node != null:
			add_child(node)
			_managed_children.append(node)


func _create_child(spec: Dictionary) -> Control:
	# Inline component creation to avoid circular dependency with ComponentFactory
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
			push_warning("UIContainer: unknown type '%s'" % type)
			return null

	if node == null:
		push_error("UIContainer: NodePool returned null for type '%s'" % type)
		return null

	if node.has_method("apply"):
		node.apply(spec)

	return node


func reset() -> void:
	# Return all managed children to pool
	for node in _managed_children:
		if is_instance_valid(node):
			NodePool.checkin(node)
	_managed_children.clear()
	# Clear any remaining children
	for child in get_children():
		child.queue_free()
