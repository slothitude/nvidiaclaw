extends Node
# Autoload for creating UI components from specs


func create(el: Dictionary) -> Control:
	var type: String = el.get("type", "")
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
			push_warning("ComponentFactory: unknown type '%s'" % type)
			return null

	if node == null:
		push_error("ComponentFactory: NodePool returned null for type '%s'" % type)
		return null

	if node.has_method("apply"):
		node.apply(el)

	return node
