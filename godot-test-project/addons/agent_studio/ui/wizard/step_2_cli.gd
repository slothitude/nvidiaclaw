## Step2CLI
## Step 2: AI CLI Type and Execution Mode
extends "res://addons/agent_studio/ui/wizard/wizard_step.gd"

@onready var claude_btn: Button = $VBox/CLIContainer/ClaudeBtn
@onready var goose_btn: Button = $VBox/CLIContainer/GooseBtn
@onready var auto_btn: Button = $VBox/CLIContainer/AutoBtn
@onready var remote_btn: CheckButton = $VBox/ExecutionContainer/RemoteBtn
@onready var local_btn: CheckButton = $VBox/ExecutionContainer/LocalBtn

var selected_cli: String = "auto"
var selected_mode: String = "remote"


func _ready() -> void:
	title = "CLI Type & Execution"
	description = "Choose your agent's brain"

	# Connect signals
	claude_btn.pressed.connect(_on_cli_pressed.bind("claude"))
	goose_btn.pressed.connect(_on_cli_pressed.bind("goose"))
	auto_btn.pressed.connect(_on_cli_pressed.bind("auto"))

	remote_btn.pressed.connect(_on_mode_pressed.bind("remote"))
	local_btn.pressed.connect(_on_mode_pressed.bind("local"))

	# Set defaults
	_on_cli_pressed("auto")


func _on_cli_pressed(cli: String) -> void:
	selected_cli = cli

	# Update button states
	claude_btn.button_pressed = (cli == "claude")
	goose_btn.button_pressed = (cli == "goose")
	auto_btn.button_pressed = (cli == "auto")

	step_completed.emit(true)


func _on_mode_pressed(mode: String) -> void:
	selected_mode = mode

	# Update button states
	remote_btn.button_pressed = (mode == "remote")
	local_btn.button_pressed = (mode == "local")

	# Local mode not yet supported
	if mode == "local":
		local_btn.disabled = true
		local_btn.text = "Local (Coming Soon)"
		_on_mode_pressed("remote")


func validate() -> bool:
	return true


func get_data() -> Dictionary:
	return {
		"ai_cli": selected_cli,
		"execution_mode": selected_mode,
	}


func set_data(data: Dictionary) -> void:
	selected_cli = data.get("ai_cli", "auto")
	selected_mode = data.get("execution_mode", "remote")

	_on_cli_pressed(selected_cli)
	_on_mode_pressed(selected_mode)
