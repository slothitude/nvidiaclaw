## Step4Tools
## Step 4: Configure Tools
extends "res://addons/agent_studio/ui/wizard/wizard_step.gd"

@onready var tools_list: VBoxContainer = $VBox/Scroll/ToolsList

var selected_tools: PackedStringArray = []


func _ready() -> void:
	title = "Configure Tools"
	description = "Toggle tools on/off for your agent"

	# Wait for tools to load
	if AgentStudio:
		_populate_tools()
		AgentStudio.tools_loaded.connect(_populate_tools)


func _populate_tools(_tools: Array = []) -> void:
	# Clear existing
	for child in tools_list.get_children():
		child.queue_free()

	var tools := _tools if _tools.size() > 0 else AgentStudio.get_available_tools()

	for tool in tools:
		var tool_id: String = str(tool.get("id", ""))
		var tool_name: String = str(tool.get("name", tool_id))
		var tool_icon: String = str(tool.get("icon", "⚡"))
		var tool_desc: String = str(tool.get("description", ""))
		var enabled: bool = bool(tool.get("enabled", true))
		var requires_confirm: bool = bool(tool.get("requires_confirmation", false))

		var item := _create_tool_item(
			tool_id, tool_icon, tool_name, tool_desc,
			enabled, requires_confirm
		)
		tools_list.add_child(item)


func _create_tool_item(
	tool_id: String,
	icon: String,
	name: String,
	desc: String,
	enabled: bool,
	requires_confirm: bool
) -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)

	# Checkbox
	var check := CheckBox.new()
	check.button_pressed = selected_tools.has(tool_id)
	check.disabled = not enabled
	check.toggled.connect(_toggle_tool.bind(tool_id))
	container.add_child(check)

	# Icon
	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.custom_minimum_size.x = 32
	container.add_child(icon_label)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var desc_text := desc
	if requires_confirm:
		desc_text += " (requires confirmation)"
	if not enabled:
		desc_text += " [disabled by default]"

	var desc_label := Label.new()
	desc_label.text = desc_text
	desc_label.add_theme_color_override("font_color", Color.GRAY)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	container.add_child(info)

	return container


func _toggle_tool(tool_id: String, is_on: bool) -> void:
	var idx := selected_tools.find(tool_id)
	if is_on and idx < 0:
		selected_tools.append(tool_id)
	elif not is_on and idx >= 0:
		selected_tools.remove_at(idx)

	step_completed.emit(true)


func validate() -> bool:
	# Tools are optional
	return true


func get_data() -> Dictionary:
	return {
		"tools": selected_tools,
	}


func set_data(data: Dictionary) -> void:
	var tools: Array = data.get("tools", [])
	selected_tools = PackedStringArray(tools)
	_populate_tools()
