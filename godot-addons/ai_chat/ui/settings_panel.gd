## Settings Panel
## UI for configuring AI chat settings.
extends Control

# UI Elements
@onready var bridge_url_input: LineEdit = $VBox/ServerGroup/BridgeUrlInput
@onready var host_input: LineEdit = $VBox/ServerGroup/HostInput
@onready var username_input: LineEdit = $VBox/ServerGroup/UsernameInput
@onready var ssh_key_path_input: LineEdit = $VBox/ServerGroup/SSHKeyPathInput
@onready var browse_key_button: Button = $VBox/ServerGroup/BrowseKeyButton
@onready var ai_cli_option: OptionButton = $VBox/ServerGroup/AICLIOption
@onready var streaming_check: CheckBox = $VBox/OptionsGroup/StreamingCheck
@onready var max_history_spin: SpinBox = $VBox/OptionsGroup/MaxHistorySpin
@onready var save_button: Button = $VBox/Buttons/SaveButton
@onready var cancel_button: Button = $VBox/Buttons/CancelButton
@onready var test_connection_button: Button = $VBox/Buttons/TestConnectionButton
@onready var status_label: Label = $VBox/Status/StatusLabel

# Settings reference
var settings: AISettings

# Signal for when settings are saved
signal settings_saved()


func _ready() -> void:
	# Setup button connections
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	browse_key_button.pressed.connect(_on_browse_key_pressed)
	test_connection_button.pressed.connect(_on_test_connection_pressed)

	# Load current settings
	_load_settings()


func setup(p_settings: AISettings) -> void:
	settings = p_settings
	_load_settings()


func _load_settings() -> void:
	if settings == null:
		settings = AISettings.new()

	bridge_url_input.text = settings.bridge_url
	host_input.text = settings.default_host
	username_input.text = settings.default_username
	ssh_key_path_input.text = settings.ssh_key_path

	# Set AI CLI option
	var cli_index = 0
	match settings.preferred_ai_cli:
		"claude": cli_index = 1
		"goose": cli_index = 2
		_: cli_index = 0  # auto
	ai_cli_option.selected = cli_index

	streaming_check.button_pressed = settings.stream_responses
	max_history_spin.value = settings.max_history_messages


func _on_save_pressed() -> void:
	# Update settings from UI
	settings.bridge_url = bridge_url_input.text.strip_edges()
	settings.default_host = host_input.text.strip_edges()
	settings.default_username = username_input.text.strip_edges()
	settings.ssh_key_path = ssh_key_path_input.text.strip_edges()

	match ai_cli_option.selected:
		0: settings.preferred_ai_cli = "auto"
		1: settings.preferred_ai_cli = "claude"
		2: settings.preferred_ai_cli = "goose"

	settings.stream_responses = streaming_check.button_pressed
	settings.max_history_messages = int(max_history_spin.value)

	# Save to disk
	var err = settings.save_settings()
	if err == OK:
		status_label.text = "Settings saved!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
		settings_saved.emit()
	else:
		status_label.text = "Failed to save settings: %d" % err
		status_label.add_theme_color_override("font_color", Color.RED)


func _on_cancel_pressed() -> void:
	# Reload settings (discard changes)
	_load_settings()
	hide()


func _on_browse_key_pressed() -> void:
	# Open file dialog for SSH key
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.pem", "*.key", "*"])
	dialog.file_selected.connect(_on_key_file_selected)
	add_child(dialog)
	dialog.popup_centered()


func _on_key_file_selected(path: String) -> void:
	ssh_key_path_input.text = path


func _on_test_connection_pressed() -> void:
	status_label.text = "Testing connection..."
	status_label.add_theme_color_override("font_color", Color.YELLOW)

	# Create temporary client to test
	var test_settings = AISettings.new()
	test_settings.bridge_url = bridge_url_input.text.strip_edges()

	var test_client = AIClient.new(test_settings)
	test_client.error_occurred.connect(_on_test_error)
	test_client.server_info_received.connect(_on_test_success)

	test_client.check_health(func(result: bool): void:
		if result:
			_on_test_success({})
		else:
			_on_test_error("Health check failed")


func _on_test_success(info: Dictionary) -> void:
	status_label.text = "Connection successful!"
	status_label.add_theme_color_override("font_color", Color.GREEN)


func _on_test_error(error: String) -> void:
	status_label.text = "Connection failed: %s" % error
	status_label.add_theme_color_override("font_color", Color.RED)


func show() -> void:
	visible = true


func hide() -> void:
	visible = false
