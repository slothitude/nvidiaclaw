## WizardController
## Main wizard controller that orchestrates the step-by-step agent creation.
extends Control
class_name WizardController

## Emitted when wizard completes successfully
signal wizard_completed(agent_config: Resource)

## Emitted when user cancels
signal wizard_cancelled()

## Preload step scripts
const Step1Script = preload("res://addons/agent_studio/ui/wizard/step_1_name.gd")
const Step2Script = preload("res://addons/agent_studio/ui/wizard/step_2_cli.gd")
const Step3Script = preload("res://addons/agent_studio/ui/wizard/step_3_skills.gd")
const Step4Script = preload("res://addons/agent_studio/ui/wizard/step_4_tools.gd")
const Step5Script = preload("res://addons/agent_studio/ui/wizard/step_5_prompt.gd")
const Step6Script = preload("res://addons/agent_studio/ui/wizard/step_6_preview.gd")
const ConfigScript = preload("res://addons/agent_studio/agent_config.gd")

@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var desc_label: Label = $VBox/Header/DescLabel
@onready var step_container: Control = $VBox/StepContainer
@onready var step_indicator: HBoxContainer = $VBox/StepIndicator
@onready var back_btn: Button = $VBox/Footer/BackBtn
@onready var next_btn: Button = $VBox/Footer/NextBtn
@onready var create_btn: Button = $VBox/Footer/CreateBtn
@onready var cancel_btn: Button = $VBox/Footer/CancelBtn

## Current step index (0-based)
var current_step: int = 0

## Step titles
var step_titles: Array = [
	"Name & Identity",
	"CLI Type & Execution",
	"Select Skills",
	"Configure Tools",
	"System Prompt",
	"Preview & Create"
]

## Step descriptions
var step_descriptions: Array = [
	"Give your agent a name and choose an icon",
	"Choose your agent's brain",
	"Choose the skills your agent will have",
	"Toggle tools on/off for your agent",
	"Write custom instructions for your agent",
	"Review your agent before creation"
]

## Collected data from all steps
var wizard_data: Dictionary = {}

## Step scene paths
var step_scenes: Array = [
	"res://addons/agent_studio/ui/wizard/step_1_name.tscn",
	"res://addons/agent_studio/ui/wizard/step_2_cli.tscn",
	"res://addons/agent_studio/ui/wizard/step_3_skills.tscn",
	"res://addons/agent_studio/ui/wizard/step_4_tools.tscn",
	"res://addons/agent_studio/ui/wizard/step_5_prompt.tscn",
	"res://addons/agent_studio/ui/wizard/step_6_preview.tscn",
]

## Currently loaded step instance
var current_step_instance: Control = null


func _ready() -> void:
	_setup_step_indicator()
	_load_step(0)
	_connect_buttons()


func _setup_step_indicator() -> void:
	# Clear existing
	for child in step_indicator.get_children():
		child.queue_free()

	# Create step number buttons
	for i in range(step_titles.size()):
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(32, 32)
		btn.toggle_mode = true
		btn.disabled = true
		btn.pressed.connect(_go_to_step.bind(i))
		step_indicator.add_child(btn)

	_update_indicator()


func _update_indicator() -> void:
	for i in range(step_indicator.get_child_count()):
		var btn: Button = step_indicator.get_child(i)
		btn.button_pressed = (i == current_step)
		btn.disabled = (i > current_step + 1)  # Allow going back, not skipping ahead


func _connect_buttons() -> void:
	back_btn.pressed.connect(_on_back)
	next_btn.pressed.connect(_on_next)
	create_btn.pressed.connect(_on_create)
	cancel_btn.pressed.connect(_on_cancel)


func _load_step(step_index: int) -> void:
	# Save current step data
	if current_step_instance:
		var data = current_step_instance.get_data()
		for key in data:
			wizard_data[key] = data[key]

		# Clean up
		current_step_instance.queue_free()
		current_step_instance = null

	# Update index
	current_step = step_index

	# Update header
	title_label.text = step_titles[step_index]
	desc_label.text = step_descriptions[step_index]

	# Load step scene
	var scene_path: String = step_scenes[step_index]
	if ResourceLoader.exists(scene_path):
		var scene := load(scene_path)
		current_step_instance = scene.instantiate()
		step_container.add_child(current_step_instance)

		# Set existing data if going back
		current_step_instance.set_data(wizard_data)
		current_step_instance.on_enter()
	else:
		# Create step programmatically if scene doesn't exist
		current_step_instance = _create_step_placeholder(step_index)
		step_container.add_child(current_step_instance)

	# Update buttons
	_update_buttons()
	_update_indicator()


func _create_step_placeholder(step_index: int) -> Control:
	var container := VBoxContainer.new()
	container.name = "Step%dPlaceholder" % (step_index + 1)

	var label := Label.new()
	label.text = "Step %d: %s\n\n( Scene file needed: %s )" % [
		step_index + 1,
		step_titles[step_index],
		step_scenes[step_index]
	]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	container.add_child(label)

	return container


func _update_buttons() -> void:
	# Back button
	back_btn.visible = current_step > 0
	back_btn.disabled = current_step == 0

	# Next button
	next_btn.visible = current_step < step_titles.size() - 1

	# Create button (last step)
	create_btn.visible = current_step == step_titles.size() - 1

	# Cancel always visible
	cancel_btn.visible = true


func _go_to_step(step_index: int) -> void:
	if step_index <= current_step:
		_load_step(step_index)


func _on_back() -> void:
	if current_step > 0:
		_load_step(current_step - 1)


func _on_next() -> void:
	# Validate current step
	if current_step_instance and not current_step_instance.validate():
		print("[Wizard] Step validation failed")
		return

	if current_step < step_titles.size() - 1:
		_load_step(current_step + 1)


func _on_create() -> void:
	# Validate final step
	if current_step_instance and not current_step_instance.validate():
		print("[Wizard] Final step validation failed")
		return

	# Save final step data
	if current_step_instance:
		var data = current_step_instance.get_data()
		for key in data:
			wizard_data[key] = data[key]

	# Create agent config
	var config := ConfigScript.new()
	config.name = wizard_data.get("name", "New Agent")
	config.description = wizard_data.get("description", "")
	config.icon = wizard_data.get("icon", "🤖")
	config.ai_cli = wizard_data.get("ai_cli", "auto")
	config.execution_mode = wizard_data.get("execution_mode", "remote")
	config.skills = PackedStringArray(wizard_data.get("skills", []))
	config.tools = PackedStringArray(wizard_data.get("tools", []))
	config.system_prompt = wizard_data.get("system_prompt", "")
	config.temperature = wizard_data.get("temperature", 0.7)

	# Emit signal
	wizard_completed.emit(config)

	# Create via AgentStudio
	if AgentStudio:
		AgentStudio.create_agent(config)


func _on_cancel() -> void:
	wizard_cancelled.emit()
	hide()


## Reset wizard to start
func reset() -> void:
	current_step = 0
	wizard_data.clear()
	_load_step(0)


## Start wizard for editing existing agent
func edit_agent(agent: Resource) -> void:
	wizard_data = {
		"name": agent.name,
		"description": agent.description,
		"icon": agent.icon,
		"ai_cli": agent.ai_cli,
		"execution_mode": agent.execution_mode,
		"skills": Array(agent.skills),
		"tools": Array(agent.tools),
		"system_prompt": agent.system_prompt,
		"temperature": agent.temperature,
	}
	current_step = 0
	_load_step(0)
	show()
