extends Node

# Op types: insert, update, remove, reorder
# Each op: { type, id, data, index }


static func diff(old_spec: Dictionary, new_spec: Dictionary) -> Array[Dictionary]:
	if old_spec.is_empty():
		# First render — everything is an insert
		var ops: Array[Dictionary] = []
		var elements: Array = new_spec.get("elements", [])
		for i in range(elements.size()):
			ops.append({ "type": "insert", "id": elements[i].get("id",""), "data": elements[i], "index": i })
		return ops

	return _diff_elements(
		old_spec.get("elements", []),
		new_spec.get("elements", [])
	)


static func _diff_elements(old_els: Array, new_els: Array) -> Array[Dictionary]:
	var ops: Array[Dictionary] = []

	# Build keyed maps
	var old_map: Dictionary = {}
	var old_order: Array[String] = []
	for el in old_els:
		var id: String = el.get("id", "")
		if not id.is_empty():
			old_map[id] = el
			old_order.append(id)

	var new_map: Dictionary = {}
	var new_order: Array[String] = []
	for el in new_els:
		var id: String = el.get("id", "")
		if not id.is_empty():
			new_map[id] = el
			new_order.append(id)

	# Removes: in old but not in new
	for id in old_order:
		if not new_map.has(id):
			ops.append({ "type": "remove", "id": id, "data": {}, "index": -1 })

	# Inserts and updates
	for i in range(new_order.size()):
		var id: String = new_order[i]
		var new_el: Dictionary = new_map[id]

		if not old_map.has(id):
			ops.append({ "type": "insert", "id": id, "data": new_el, "index": i })
		else:
			var old_el: Dictionary = old_map[id]
			if not _deep_equal(old_el, new_el):
				var delta := _compute_delta(old_el, new_el)
				ops.append({ "type": "update", "id": id, "data": delta, "index": i })

			# Recurse into children
			if new_el.has("children") or old_el.has("children"):
				var child_ops := _diff_elements(
					old_el.get("children", []),
					new_el.get("children", [])
				)
				ops.append_array(child_ops)

	# Reorder: check if surviving elements changed position
	var surviving_old: Array[String] = []
	for id in old_order:
		if new_map.has(id):
			surviving_old.append(id)

	var surviving_new: Array[String] = []
	for id in new_order:
		if old_map.has(id):
			surviving_new.append(id)

	if surviving_old != surviving_new:
		for i in range(surviving_new.size()):
			ops.append({ "type": "reorder", "id": surviving_new[i], "data": {}, "index": i })

	return ops


static func _compute_delta(old_el: Dictionary, new_el: Dictionary) -> Dictionary:
	# Returns only the changed keys
	var delta: Dictionary = {}
	for key in new_el:
		if not old_el.has(key) or old_el[key] != new_el[key]:
			delta[key] = new_el[key]
	return delta


static func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false

	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _deep_equal(a[key], b[key]):
				return false
		return true

	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _deep_equal(a[i], b[i]):
				return false
		return true

	return a == b
