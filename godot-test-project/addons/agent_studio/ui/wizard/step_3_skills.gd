## Step3Skills
## Step 3: Select Skills (Drag & Drop)
extends "res://addons/agent_studio/ui/wizard/wizard_step.gd"

@onready var available_list: VBoxContainer = $VBox/HBox/AvailablePanel/Scroll/AvailableList
@onready var selected_list: VBoxContainer = $VBox/HBox/SelectedPanel/Scroll/SelectedList

var selected_skills: PackedStringArray = []


func _ready() -> void:
	title = "Select Skills"
	description = "Choose the skills your agent will have"

	# Wait for skills to load
	if AgentStudio:
		_populate_available()
		AgentStudio.skills_loaded.connect(_populate_available)


func _populate_available(_skills: Array = []) -> void:
	# Clear existing
	for child in available_list.get_children():
		child.queue_free()

	var skills := _skills if _skills.size() > 0 else AgentStudio.get_skills()

	for skill in skills:
		var skill_id: String = str(skill.get("id", ""))
		var skill_name: String = str(skill.get("name", skill_id))
		var skill_icon: String = str(skill.get("icon", "🔧"))
		var skill_desc: String = str(skill.get("description", ""))

		var item := _create_skill_item(skill_id, skill_icon, skill_name, skill_desc, false)
		available_list.add_child(item)


func _create_skill_item(skill_id: String, icon: String, name: String, desc: String, is_selected: bool) -> Control:
	var container := HBoxContainer.new()

	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.custom_minimum_size.x = 32
	container.add_child(icon_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 16)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_color_override("font_color", Color.GRAY)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	container.add_child(info)

	var btn := Button.new()
	btn.text = "✓" if is_selected else "+"
	btn.custom_minimum_size = Vector2(40, 40)
	btn.pressed.connect(_toggle_skill.bind(skill_id))
	container.add_child(btn)

	return container


func _toggle_skill(skill_id: String) -> void:
	var idx := selected_skills.find(skill_id)
	if idx >= 0:
		selected_skills.remove_at(idx)
	else:
		selected_skills.append(skill_id)

	_refresh_selected()
	step_completed.emit(true)


func _refresh_selected() -> void:
	# Clear selected list
	for child in selected_list.get_children():
		child.queue_free()

	# Populate selected
	for skill_id in selected_skills:
		var skill := AgentStudio.get_skill(skill_id) if AgentStudio else {}
		if skill.is_empty():
			continue

		var item := _create_skill_item(
			skill_id,
			skill.get("icon", "🔧"),
			skill.get("name", skill_id),
			skill.get("description", ""),
			true
		)
		selected_list.add_child(item)


func validate() -> bool:
	# Skills are optional
	return true


func get_data() -> Dictionary:
	return {
		"skills": selected_skills,
	}


func set_data(data: Dictionary) -> void:
	var skills: Array = data.get("skills", [])
	selected_skills = PackedStringArray(skills)
	_refresh_selected()
