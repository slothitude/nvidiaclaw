## Step6Preview
## Step 6: Preview and Create the agent
extends "res://addons/agent_studio/ui/wizard/wizard_step.gd"

@onready var preview_container: VBoxContainer = $VBox/Scroll/PreviewContainer
@onready var preview_label: RichTextLabel = $VBox/Scroll/PreviewContainer/PreviewLabel
@onready var test_btn: Button = $VBox/HBox/TestBtn
@onready var create_btn: Button = $VBox/HBox/CreateBtn

## Collected data from all steps
var wizard_data: Dictionary = {}


func _ready() -> void:
	title = "Preview & Create"
	description = "Review your agent before creation"

	test_btn.pressed.connect(_on_test)
	create_btn.pressed.connect(_on_create)


func on_enter() -> void:
	_update_preview()


func _update_preview() -> void:
	if preview_label == null:
		return

	var text := """
[font_size=24]%s %s[/font_size]

[b]Description:[/b] %s

[b]Configuration:[/b]
• AI CLI: %s
• Execution: %s
• Temperature: %.1f

[b]Skills:[/b] %s

[b]Tools:[/b] %s

[b]System Prompt:[/b]
[i]%s[/i]
""" % [
		wizard_data.get("icon", "🤖"),
		wizard_data.get("name", "New Agent"),
		wizard_data.get("description", "No description"),
		wizard_data.get("ai_cli", "auto"),
		wizard_data.get("execution_mode", "remote"),
		wizard_data.get("temperature", 0.7),
		", ".join(wizard_data.get("skills", [])),
		", ".join(wizard_data.get("tools", [])),
		wizard_data.get("system_prompt", "No custom prompt").left(100) + "...",
	]

	preview_label.text = text


func _on_test() -> void:
	# Test with a sample prompt
	# This would open a test chat window
	print("[Wizard] Test button pressed - would open test chat")


func _on_create() -> void:
	# Create the agent
	var config_script = preload("res://addons/agent_studio/agent_config.gd")
	var config := config_script.new()

	config.name = wizard_data.get("name", "New Agent")
	config.description = wizard_data.get("description", "")
	config.icon = wizard_data.get("icon", "🤖")
	config.ai_cli = wizard_data.get("ai_cli", "auto")
	config.execution_mode = wizard_data.get("execution_mode", "remote")
	config.skills = PackedStringArray(wizard_data.get("skills", []))
	config.tools = PackedStringArray(wizard_data.get("tools", []))
	config.system_prompt = wizard_data.get("system_prompt", "")
	config.temperature = wizard_data.get("temperature", 0.7)

	if AgentStudio:
		AgentStudio.create_agent(config)
		print("[Wizard] Creating agent: ", config.name)


func validate() -> bool:
	return not wizard_data.get("name", "").is_empty()


func get_data() -> Dictionary:
	return wizard_data


func set_data(data: Dictionary) -> void:
	wizard_data = data
	_update_preview()
