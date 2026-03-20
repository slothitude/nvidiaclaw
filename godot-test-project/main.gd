extends Control

# Main test scene for SSH AI Bridge
# Preload addon scripts
const AISettingsScript = preload("res://addons/ai_chat/ai_settings.gd")
const AIClientScript = preload("res://addons/ai_chat/ai_client.gd")

var client: RefCounted
var settings: Resource

# Updated paths for new UI structure
@onready var host_input: LineEdit = $MainContainer/VBox/Connection/Margin/VBox/Row1/HostSection/HostInput
@onready var username_input: LineEdit = $MainContainer/VBox/Connection/Margin/VBox/Row1/UserSection/UsernameInput
@onready var password_input: LineEdit = $MainContainer/VBox/Connection/Margin/VBox/Row1/PassSection/PasswordInput
@onready var ai_cli_option: OptionButton = $MainContainer/VBox/Connection/Margin/VBox/Row2/AISection/AICLIOption
@onready var connect_btn: Button = $MainContainer/VBox/Connection/Margin/VBox/Row2/ButtonSection/ButtonRow/ConnectBtn
@onready var disconnect_btn: Button = $MainContainer/VBox/Connection/Margin/VBox/Row2/ButtonSection/ButtonRow/DisconnectBtn

@onready var message_input: TextEdit = $MainContainer/VBox/Chat/Margin/VBox/InputArea/MessageInput
@onready var send_btn: Button = $MainContainer/VBox/Chat/Margin/VBox/InputArea/SendBtn
@onready var message_list: VBoxContainer = $MainContainer/VBox/Chat/Margin/VBox/ScrollContainer/MessageList
@onready var scroll_container: ScrollContainer = $MainContainer/VBox/Chat/Margin/VBox/ScrollContainer
@onready var status_label: Label = $MainContainer/VBox/StatusBar/HBox/StatusLabel
@onready var status_dot: ColorRect = $MainContainer/VBox/Header/HBox/StatusIndicator/StatusDot
@onready var status_text: Label = $MainContainer/VBox/Header/HBox/StatusIndicator/StatusText

var is_connected := false


func _ready():
	print("[DEBUG] main.gd _ready() called")
	print("[DEBUG] self: ", self)

	settings = AISettingsScript.load_settings()
	print("[DEBUG] settings loaded, bridge_url: ", settings.bridge_url)

	client = AIClientScript.new(settings, self)  # Pass self as parent for HTTP requests
	print("[DEBUG] client created")

	# Connect client signals
	client.connected.connect(_on_connected)
	client.disconnected.connect(_on_disconnected)
	client.message_received.connect(_on_message_received)
	client.stream_chunk.connect(_on_stream_chunk)
	client.error_occurred.connect(_on_error)

	# Connect button signals
	if connect_btn:
		connect_btn.pressed.connect(_on_connect_btn_pressed)
		print("[DEBUG] connect_btn connected")
	else:
		print("[DEBUG] connect_btn is null!")

	if disconnect_btn:
		disconnect_btn.pressed.connect(_on_disconnect_btn_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_btn_pressed)

	# Load saved settings
	if host_input and settings.default_host:
		host_input.text = settings.default_host
	if username_input and settings.default_username:
		username_input.text = settings.default_username

	# Setup AI CLI options
	if ai_cli_option:
		ai_cli_option.add_item("Auto", 0)
		ai_cli_option.add_item("Claude", 1)
		ai_cli_option.add_item("Goose", 2)

	_update_ui_state()
	add_message("system", "Welcome to SSH AI Bridge. Connect to a server to start.")


func _update_ui_state():
	if connect_btn:
		connect_btn.visible = not is_connected
	if disconnect_btn:
		disconnect_btn.visible = is_connected
	if send_btn:
		send_btn.disabled = not is_connected

	if host_input:
		host_input.editable = not is_connected
	if username_input:
		username_input.editable = not is_connected
	if password_input:
		password_input.editable = not is_connected
	if ai_cli_option:
		ai_cli_option.disabled = is_connected

	if is_connected:
		if status_label:
			status_label.text = "Connected"
		if status_dot:
			status_dot.color = Color(0.3, 0.8, 0.4, 1)  # Green
		if status_text:
			status_text.text = "Connected"
	else:
		if status_label:
			status_label.text = "Ready"
		if status_dot:
			status_dot.color = Color(0.9, 0.3, 0.3, 1)  # Red
		if status_text:
			status_text.text = "Disconnected"


func add_message(role: String, content: String):
	"""Add a message to the chat list with styling."""
	if not message_list:
		return

	var msg_label = RichTextLabel.new()
	msg_label.bbcode_enabled = true
	msg_label.fit_content = true
	msg_label.scroll_active = false
	msg_label.custom_minimum_size = Vector2(0, 40)

	var color = "#5a6070"  # Default gray
	var prefix = "[SYSTEM]"
	match role:
		"user":
			color = "#6a9fd4"
			prefix = "[YOU]"
		"assistant":
			color = "#8fd4a8"
			prefix = "[AI]"
		"error":
			color = "#d46a6a"
			prefix = "[ERROR]"

	msg_label.text = "[color=%s]%s[/color] %s" % [color, prefix, content]
	message_list.add_child(msg_label)

	# Scroll to bottom
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value


func _on_connect_btn_pressed():
	print("[Main] ========== CONNECT BUTTON PRESSED ==========")
	if not host_input or not username_input or not password_input:
		print("[Main] ERROR: Missing input nodes!")
		return

	var host = host_input.text.strip_edges()
	var username = username_input.text.strip_edges()
	var password = password_input.text

	print("[Main] host: ", host)
	print("[Main] username: ", username)

	if host.is_empty() or username.is_empty():
		add_message("error", "Host and username are required")
		return

	var ai_cli = "auto"
	if ai_cli_option:
		match ai_cli_option.selected:
			1: ai_cli = "claude"
			2: ai_cli = "goose"
	print("[Main] ai_cli: ", ai_cli)

	add_message("system", "Connecting to %s as %s..." % [host, username])
	if status_label:
		status_label.text = "Connecting..."
	if status_dot:
		status_dot.color = Color(0.9, 0.7, 0.2, 1)  # Yellow

	print("[Main] Calling client.connect_to_server...")
	print("[Main] client is valid: ", is_instance_valid(client))
	client.connect_to_server(host, username, "", password, ai_cli)
	print("[Main] connect_to_server call returned")


func _on_disconnect_btn_pressed():
	client.disconnect_from_server()
	is_connected = false
	_update_ui_state()
	add_message("system", "Disconnected")


func _on_send_btn_pressed():
	if not message_input:
		return

	var message = message_input.text.strip_edges()
	if message.is_empty():
		return

	add_message("user", message)
	message_input.clear()

	if status_label:
		status_label.text = "Waiting for response..."

	client.send_message(message)


func _on_connected(session_id: String, ai_cli: String):
	is_connected = true
	add_message("system", "Connected! Session: %s, AI CLI: %s" % [session_id.left(8) + "...", ai_cli])
	_update_ui_state()


func _on_disconnected():
	is_connected = false
	add_message("system", "Disconnected")
	_update_ui_state()


func _on_message_received(data: Dictionary):
	var response = data.get("response", "")
	if not response.is_empty():
		add_message("assistant", response)
	if status_label:
		status_label.text = "Ready"


func _on_stream_chunk(chunk: Dictionary):
	var chunk_type = chunk.get("type", "")
	match chunk_type:
		"thinking":
			if status_label:
				status_label.text = "Thinking..."
		"text":
			pass  # Could append to current message
		"complete":
			_update_ui_state()
		"error":
			add_message("error", chunk.get("content", "Unknown error"))


func _on_error(error: String):
	add_message("error", error)
	if status_label:
		status_label.text = "Error"
	_update_ui_state()
