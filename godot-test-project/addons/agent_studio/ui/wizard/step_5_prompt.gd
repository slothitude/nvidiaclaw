## Step5Prompt
## Step 5: System Prompt - Write custom instructions for your agent
extends "res://addons/agent_studio/ui/wizard/wizard_step.gd"

@onready var prompt_edit: TextEdit = $VBox/PromptEdit
@onready var temp_slider: HSlider = $VBox/TempContainer/TempSlider
@onready var temp_label: Label = $VBox/TempContainer/TempLabel
@onready var ai_help_btn: Button = $VBox/HBox/AIHelpBtn


func _ready() -> void:
	title = "System Prompt"
	description = "Write custom instructions for your agent"

	# Set default prompt
	prompt_edit.placeholder_text = _get_default_prompt()
	temp_slider.value = 0.7
	_update_temp_label()

	# Connect signals
	temp_slider.value_changed.connect(_on_temp_changed)
	ai_help_btn.pressed.connect(_on_ai_help)


func _get_default_prompt() -> String:
	return """You are an expert developer assistant.

## Behaviors
- Always run tests before committing
- Use conventional commits
- Provide clear explanations
- Ask for clarification when needed
"""


func _on_temp_changed(value: float) -> void:
	_update_temp_label()
	step_completed.emit(true)


func _update_temp_label() -> void:
	temp_label.text = "Temperature: %.1f" % temp_slider.value


func _on_ai_help() -> void:
	# Generate a prompt based on selected skills
	var skills := AgentStudio.get_skills() if AgentStudio else []
	if skills.is_empty():
		return

	var prompt_lines := ["You are an expert developer with the following capabilities:", ""]

	for skill in skills:
		var skill_id: String = str(skill.get("id", ""))
		var skill_template: String = str(skill.get("prompt_template", ""))
		if not skill_template.is_empty():
			prompt_lines.append("## " + skill.get("name", skill_id))
			prompt_lines.append(skill_template)
			prompt_lines.append("")

	prompt_lines.append("## General Guidelines")
	prompt_lines.append("- Be helpful and precise")
	prompt_lines.append("- Ask for clarification when needed")
	prompt_lines.append("- Provide code examples when appropriate")

	prompt_edit.text = "\n".join(prompt_lines)
	step_completed.emit(true)


func validate() -> bool:
	# Prompt is optional, but if provided should not be empty
	return true


func get_data() -> Dictionary:
	return {
		"system_prompt": prompt_edit.text,
		"temperature": temp_slider.value,
	}


func set_data(data: Dictionary) -> void:
	prompt_edit.text = data.get("system_prompt", "")
	var temp: float = data.get("temperature", 0.7)
	temp_slider.value = temp
	_update_temp_label()
