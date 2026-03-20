extends Node

const CURRENT_VERSION: String        = "1.0"
const MAX_ELEMENTS: int               = 50
const MAX_DEPTH: int                  = 3
const VALID_LAYOUTS: Array[String]    = ["vbox", "hbox", "grid", "free"]
const VALID_TYPES: Array[String]      = ["label", "button", "slider", "input", "container", "image", "progress", "list"]
const VALID_TRANSITIONS: Array[String] = ["fade", "scale", "slide_left", "slide_right", "fade_scale", "instant"]


# ─── Spec-level validation ────────────────────────────────────────────────────

static func validate_spec(spec: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if not spec.has("id") or not spec["id"] is String or spec["id"].is_empty():
		errors.append("Missing or empty 'id'")

	if not spec.has("dsl_version") or not spec["dsl_version"] is String:
		errors.append("Missing 'dsl_version'")

	if not spec.has("elements") or not spec["elements"] is Array:
		errors.append("Missing or non-array 'elements'")
	elif spec["elements"].size() > MAX_ELEMENTS:
		errors.append("Too many elements: %d (max %d)" % [spec["elements"].size(), MAX_ELEMENTS])

	var layout: String = spec.get("layout", "vbox")
	if layout not in VALID_LAYOUTS:
		errors.append("Invalid layout '%s'" % layout)

	var transition: String = spec.get("transition", "fade_scale")
	if transition not in VALID_TRANSITIONS:
		errors.append("Invalid transition '%s'" % transition)

	# Validate each element
	if spec.has("elements") and spec["elements"] is Array:
		var seen_ids: Dictionary = {}
		for el in spec["elements"]:
			if el is Dictionary:
				var el_result := validate_element(el)
				errors.append_array(el_result.errors)
				var el_id: String = el.get("id", "")
				if not el_id.is_empty():
					if seen_ids.has(el_id):
						errors.append("Duplicate element id '%s'" % el_id)
					seen_ids[el_id] = true

	return { "valid": errors.is_empty(), "errors": errors }


# ─── Element-level validation ─────────────────────────────────────────────────

static func validate_element(el: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if not el.has("id") or not el["id"] is String or el["id"].is_empty():
		errors.append("Element missing 'id'")

	if not el.has("type") or not el["type"] is String:
		errors.append("Element '%s' missing 'type'" % el.get("id","?"))
	elif el["type"] not in VALID_TYPES:
		errors.append("Element '%s' has unknown type '%s'" % [el.get("id","?"), el["type"]])

	var action: String = el.get("action", "")
	if not action.is_empty():
		if not (action.begins_with("sys:") or action.begins_with("agent:")):
			errors.append("Element '%s' action '%s' must start with sys: or agent:" % [el.get("id","?"), action])

	var bind_val = el.get("bind", null)
	if bind_val != null and (not bind_val is String or bind_val.is_empty()):
		errors.append("Element '%s' bind must be a non-empty string" % el.get("id","?"))

	var bind_write_val = el.get("bind_write", null)
	if bind_write_val != null and (not bind_write_val is String or bind_write_val.is_empty()):
		errors.append("Element '%s' bind_write must be a non-empty string" % el.get("id","?"))

	return { "valid": errors.is_empty(), "errors": errors }


# ─── NDJSON line parsing ──────────────────────────────────────────────────────

static func parse_ndjson_line(line: String) -> Dictionary:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return { "ok": false, "data": {}, "error": "empty line" }

	var result := JSON.parse_string(trimmed)
	if result == null:
		return { "ok": false, "data": {}, "error": "JSON parse failed" }

	if not result is Dictionary:
		return { "ok": false, "data": {}, "error": "Expected JSON object, got " + type_string(typeof(result)) }

	return { "ok": true, "data": result, "error": "" }


# ─── Migration ────────────────────────────────────────────────────────────────

static func migrate(spec: Dictionary) -> Dictionary:
	var version: String = spec.get("dsl_version", "0.9")
	var migrated := spec.duplicate(true)

	# v0.9 -> v1.0: rename "components" to "elements"
	if version == "0.9":
		if migrated.has("components") and not migrated.has("elements"):
			migrated["elements"] = migrated["components"]
			migrated.erase("components")
		migrated["dsl_version"] = "1.0"
		version = "1.0"

	# Future migrations: add here as elif version == "1.0": ...

	return migrated
