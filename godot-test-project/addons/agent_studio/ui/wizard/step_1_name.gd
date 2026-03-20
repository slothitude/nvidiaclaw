## Step1Name
## Step 1: Agent Name and Identity
extends "res://addons/agent_studio/ui/wizard/wizard_step.gd"

@onready var name_edit: LineEdit = $VBox/NameEdit
@onready var desc_edit: TextEdit = $VBox/DescEdit
@onready var icon_grid: GridContainer = $VBox/IconGrid

## Available icons
const ICONS := ["🤖", "🧙", "⚡", "📝", "🔧", "🎨", "🔍", "📊", "🚀", "💾", "🌐", "🔒"]

var selected_icon: String = "🤖"


func _ready() -> void:
	title = "Name & Identity"
	description = "Give your agent a name and choose an icon"
	_setup_icon_grid()


func _setup_icon_grid() -> void:
	for icon in ICONS:
		var btn := Button.new()
		btn.text = icon
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true
		btn.pressed.connect(_on_icon_pressed.bind(btn, icon))
		icon_grid.add_child(btn)

		if icon == selected_icon:
			btn.button_pressed = true


func _on_icon_pressed(btn: Button, icon: String) -> void:
	# Deselect all others
	for child in icon_grid.get_children():
		if child is Button:
			child.button_pressed = (child == btn)

	selected_icon = icon
	_validate()


func _validate() -> void:
	var is_valid := not name_edit.text.strip_edges().is_empty()
	step_completed.emit(is_valid)


func validate() -> bool:
	return not name_edit.text.strip_edges().is_empty()


func get_data() -> Dictionary:
	return {
		"name": name_edit.text.strip_edges(),
		"description": desc_edit.text,
		"icon": selected_icon,
	}


func set_data(data: Dictionary) -> void:
	name_edit.text = data.get("name", "")
	desc_edit.text = data.get("description", "")
	selected_icon = data.get("icon", "🤖")

	# Update icon selection
	for child in icon_grid.get_children():
		if child is Button:
			child.button_pressed = (child.text == selected_icon)
