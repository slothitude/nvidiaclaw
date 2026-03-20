## MainMenu
## Main menu for Agent Studio application
extends Control

@onready var content: MarginContainer = $VBox/Content
@onready var status_label: Label = $VBox/StatusBar/StatusLabel
@onready var status_dot: ColorRect = $VBox/Header/StatusIndicator/StatusDot
@onready var status_text: Label = $VBox/Header/StatusIndicator/StatusText

@onready var agent_studio_btn: Button = $VBox/TabBar/AgentStudioBtn
@onready var chat_hub_btn: Button = $VBox/TabBar/ChatHubBtn
@onready var settings_btn: Button = $VBox/TabBar/SettingsBtn

# Current panel
var _current_panel: Control = null

# Preload scripts
const AgentConfigScript = preload("res://addons/agent_studio/agent_config.gd")

# Form inputs
var _name_input: LineEdit
var _desc_input: TextEdit
var _cli_buttons: Array[Button] = []

# Settings inputs
var _host_input: LineEdit
var _user_input: LineEdit
var _pass_input: LineEdit
var _ai_cli_option: OptionButton

# Chat Hub references
var _chat_input: TextEdit
var _chat_messages: VBoxContainer
var _agent_option: OptionButton

# Connection state
var _is_connected: bool = false


func _ready() -> void:
	_connect_buttons()
	_connect_aichat_signals()
	_show_agent_studio()


func _connect_aichat_signals() -> void:
	print("[MainMenu] _connect_aichat_signals called")
	if AIChat:
		print("[MainMenu] AIChat exists, connecting signals...")
		AIChat.connection_changed.connect(_on_aichat_connection_changed)
		AIChat.chat_error.connect(_on_aichat_error)
		AIChat.message_added.connect(_on_aichat_message_added)
		AIChat.stream_update.connect(_on_aichat_stream_update)
		print("[MainMenu] Signals connected successfully")
	else:
		print("[MainMenu] ERROR: AIChat is null!")


func _on_aichat_connection_changed(connected: bool) -> void:
	print("[MainMenu] _on_aichat_connection_changed called with: ", connected)
	_update_connection_status(connected)
	if connected:
		status_label.text = "Connected!"
	else:
		status_label.text = "Disconnected"


func _on_aichat_error(error: String) -> void:
	print("[MainMenu] _on_aichat_error called with: ", error)
	status_label.text = "Error: " + error
	_add_chat_message("system", "Error: " + error)


func _on_aichat_message_added(role: String, content: String) -> void:
	print("[MainMenu] _on_aichat_message_added - role: ", role)
	_add_chat_message(role, content)


func _on_aichat_stream_update(chunk: Dictionary) -> void:
	print("[MainMenu] _on_aichat_stream_update: ", chunk)
	var chunk_type = chunk.get("type", "")
	match chunk_type:
		"thinking":
			# Show thinking status
			if _chat_messages:
				_add_chat_message("assistant", "Thinking...")
		"text":
			var content = chunk.get("content", "")
			# Update last AI message
			if _chat_messages and _chat_messages.get_child_count() > 0:
				var last_child = _chat_messages.get_child(_chat_messages.get_child_count() - 1)
				if last_child is RichTextLabel:
					var current_text = last_child.text
					if "🤖 AI:" in current_text:
						last_child.text = "[color=#50fa7b]🤖 AI:[/color] " + content + "▌"
		"complete":
			status_label.text = "Response complete"
		"error":
			_add_chat_message("system", "Error: " + chunk.get("content", "Unknown error"))


func _on_send_message() -> void:
	print("[MainMenu] _on_send_message called")
	if not _chat_input:
		print("[MainMenu] No chat input!")
		return

	var message := _chat_input.text.strip_edges()
	if message.is_empty():
		return

	print("[MainMenu] Sending message: ", message)

	# Clear input
	_chat_input.text = ""

	# Send via AIChat (message_added signal will handle displaying)
	if AIChat and AIChat.is_connected:
		AIChat.send_message(message)
		status_label.text = "Waiting for response..."
	else:
		_add_chat_message("system", "Not connected. Go to Settings to connect.")
		status_label.text = "Not connected"


func _add_chat_message(role: String, content: String) -> void:
	print("[MainMenu] _add_chat_message called - role: ", role, " content: ", content.left(50))

	if not _chat_messages:
		print("[MainMenu] ERROR: _chat_messages is null!")
		return

	if not is_instance_valid(_chat_messages):
		print("[MainMenu] ERROR: _chat_messages is not valid!")
		return

	print("[MainMenu] _chat_messages is valid, child count: ", _chat_messages.get_child_count())

	# Remove welcome message if present
	if _chat_messages.get_child_count() == 1:
		var first = _chat_messages.get_child(0)
		if first is Label and "start chatting" in first.text.to_lower():
			print("[MainMenu] Removing welcome message")
			first.queue_free()

	# Use TextEdit for copyable text
	var msg_text := TextEdit.new()
	msg_text.editable = false
	msg_text.context_menu_enabled = true
	msg_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	msg_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_text.custom_minimum_size.y = 30
	msg_text.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1))
	msg_text.add_theme_color_override("background_color", Color(0.1, 0.12, 0.15, 1))
	msg_text.add_theme_stylebox_override("normal", _create_transparent_style())
	msg_text.add_theme_stylebox_override("focus", _create_transparent_style())
	msg_text.add_theme_stylebox_override("read_only", _create_transparent_style())

	var prefix := "🧑 You: "
	var text_color := Color(0.29, 0.62, 1.0)  # Blue
	match role:
		"assistant":
			prefix = "🤖 AI: "
			text_color = Color(0.31, 0.98, 0.48)  # Green
		"system":
			prefix = "⚙️ System: "
			text_color = Color(1.0, 0.47, 0.77)  # Pink

	# Use BBCode for colored prefix
	msg_text.text = prefix + content
	msg_text.add_theme_color_override("font_readonly_color", text_color)
	_chat_messages.add_child(msg_text)
	print("[MainMenu] Message added to chat, new child count: ", _chat_messages.get_child_count())


func _create_transparent_style() -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	return style


func _connect_buttons() -> void:
	agent_studio_btn.pressed.connect(_on_agent_studio_pressed)
	chat_hub_btn.pressed.connect(_on_chat_hub_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)


func _clear_content() -> void:
	if _current_panel:
		_current_panel.queue_free()
		_current_panel = null


func _update_connection_status(connected: bool) -> void:
	_is_connected = connected
	if connected:
		status_dot.color = Color(0.3, 0.8, 0.4, 1)
		status_text.text = "Connected"
	else:
		status_dot.color = Color(0.9, 0.3, 0.3, 1)
		status_text.text = "Disconnected"


# === Agent Studio Panel ===

func _show_agent_studio() -> void:
	_clear_content()
	status_label.text = "Create a new AI agent"

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 20)

	# Title
	var title := Label.new()
	title.text = "Create New Agent"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1))
	panel.add_child(title)

	# Step 1: Name
	var name_section := VBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Agent Name"
	name_label.add_theme_font_size_override("font_size", 14)
	name_section.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "e.g., Code Reviewer"
	_name_input.custom_minimum_size.y = 40
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_section.add_child(_name_input)
	panel.add_child(name_section)

	# Step 2: Description
	var desc_section := VBoxContainer.new()
	var desc_label := Label.new()
	desc_label.text = "Description"
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_section.add_child(desc_label)

	_desc_input = TextEdit.new()
	_desc_input.placeholder_text = "What does this agent do?"
	_desc_input.custom_minimum_size.y = 80
	_desc_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_section.add_child(_desc_input)
	panel.add_child(desc_section)

	# Step 3: AI CLI Selection
	var cli_section := VBoxContainer.new()
	var cli_label := Label.new()
	cli_label.text = "AI CLI Type"
	cli_label.add_theme_font_size_override("font_size", 14)
	cli_section.add_child(cli_label)

	var cli_hbox := HBoxContainer.new()
	cli_hbox.add_theme_constant_override("separation", 10)
	_cli_buttons.clear()

	var claude_btn := Button.new()
	claude_btn.text = "Claude Code"
	claude_btn.toggle_mode = true
	claude_btn.button_pressed = true
	claude_btn.custom_minimum_size = Vector2(120, 40)
	claude_btn.pressed.connect(_on_cli_selected.bind(claude_btn))
	cli_hbox.add_child(claude_btn)
	_cli_buttons.append(claude_btn)

	var goose_btn := Button.new()
	goose_btn.text = "Goose"
	goose_btn.toggle_mode = true
	goose_btn.custom_minimum_size = Vector2(120, 40)
	goose_btn.pressed.connect(_on_cli_selected.bind(goose_btn))
	cli_hbox.add_child(goose_btn)
	_cli_buttons.append(goose_btn)

	cli_section.add_child(cli_hbox)
	panel.add_child(cli_section)

	# Create button
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var create_btn := Button.new()
	create_btn.text = "Create Agent"
	create_btn.custom_minimum_size = Vector2(200, 50)
	create_btn.pressed.connect(_on_create_agent)
	btn_container.add_child(create_btn)
	panel.add_child(btn_container)

	content.add_child(panel)
	_current_panel = panel


func _on_cli_selected(btn: Button) -> void:
	for child in _cli_buttons:
		child.button_pressed = (child == btn)


func _get_selected_cli() -> String:
	for btn in _cli_buttons:
		if btn.button_pressed:
			if "claude" in btn.text.to_lower():
				return "claude"
			elif "goose" in btn.text.to_lower():
				return "goose"
	return "auto"


func _on_create_agent() -> void:
	var name := _name_input.text.strip_edges() if _name_input else ""
	var desc := _desc_input.text.strip_edges() if _desc_input else ""
	var cli := _get_selected_cli()

	if name.is_empty():
		status_label.text = "Error: Name is required!"
		return

	if AgentStudio:
		var config: Resource = AgentConfigScript.new()
		config.name = name
		config.description = desc
		config.ai_cli = cli
		AgentStudio.create_agent(config)
		status_label.text = "Creating agent: " + name + "..."
		await get_tree().create_timer(0.5).timeout
		_on_chat_hub_pressed()
	else:
		status_label.text = "Error: AgentStudio not loaded"


# === Chat Hub Panel ===

func _show_chat_hub() -> void:
	_clear_content()
	status_label.text = "Chat with your agents"

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 15)

	# Agent selector
	var selector_section := HBoxContainer.new()
	selector_section.add_theme_constant_override("separation", 10)

	var selector_label := Label.new()
	selector_label.text = "Active Agent:"
	selector_section.add_child(selector_label)

	_agent_option = OptionButton.new()
	_agent_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agent_option.custom_minimum_size.y = 40
	selector_section.add_child(_agent_option)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size.x = 80
	refresh_btn.pressed.connect(_refresh_agents.bind(_agent_option))
	selector_section.add_child(refresh_btn)

	panel.add_child(selector_section)

	# Messages area - need a PanelContainer for proper sizing
	var messages_panel := PanelContainer.new()
	messages_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var messages_scroll := ScrollContainer.new()
	messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_chat_messages = VBoxContainer.new()
	_chat_messages.add_theme_constant_override("separation", 10)
	_chat_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var welcome := Label.new()
	welcome.text = "Connect via Settings, then start chatting!"
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_messages.add_child(welcome)
	messages_scroll.add_child(_chat_messages)
	messages_panel.add_child(messages_scroll)
	panel.add_child(messages_panel)

	# Input area
	var input_section := HBoxContainer.new()
	input_section.add_theme_constant_override("separation", 10)

	_chat_input = TextEdit.new()
	_chat_input.placeholder_text = "Type a message..."
	_chat_input.custom_minimum_size.y = 60
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_section.add_child(_chat_input)

	var send_btn := Button.new()
	send_btn.text = "Send"
	send_btn.custom_minimum_size = Vector2(80, 60)
	send_btn.pressed.connect(_on_send_message)
	input_section.add_child(send_btn)
	panel.add_child(input_section)

	content.add_child(panel)
	_current_panel = panel
	_refresh_agents(_agent_option)


func _refresh_agents(option_btn: OptionButton) -> void:
	option_btn.clear()
	if AgentStudio:
		var agents: Array = AgentStudio.get_agents()
		for agent in agents:
			option_btn.add_item(agent.name)
		if agents.size() > 0:
			status_label.text = "Loaded %d agents" % agents.size()
		else:
			option_btn.add_item("No agents - create one first!")
	else:
		option_btn.add_item("AgentStudio not loaded")


# === Settings Panel ===

func _show_settings() -> void:
	_clear_content()
	status_label.text = "Configure SSH connection"

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 15)

	# Title
	var title := Label.new()
	title.text = "Connection Settings"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1))
	panel.add_child(title)

	# Host
	var host_section := VBoxContainer.new()
	var host_label := Label.new()
	host_label.text = "SSH Host"
	host_label.add_theme_font_size_override("font_size", 14)
	host_section.add_child(host_label)

	_host_input = LineEdit.new()
	_host_input.placeholder_text = "192.168.0.237"
	_host_input.text = "192.168.0.237"
	_host_input.custom_minimum_size.y = 40
	_host_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_section.add_child(_host_input)
	panel.add_child(host_section)

	# Username
	var user_section := VBoxContainer.new()
	var user_label := Label.new()
	user_label.text = "Username"
	user_label.add_theme_font_size_override("font_size", 14)
	user_section.add_child(user_label)

	_user_input = LineEdit.new()
	_user_input.placeholder_text = "az"
	_user_input.text = "az"
	_user_input.custom_minimum_size.y = 40
	_user_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_section.add_child(_user_input)
	panel.add_child(user_section)

	# Password
	var pwd_section := VBoxContainer.new()
	var pwd_label := Label.new()
	pwd_label.text = "Password"
	pwd_label.add_theme_font_size_override("font_size", 14)
	pwd_section.add_child(pwd_label)

	_pass_input = LineEdit.new()
	_pass_input.placeholder_text = "Enter password..."
	_pass_input.secret = true
	_pass_input.custom_minimum_size.y = 40
	_pass_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pwd_section.add_child(_pass_input)
	panel.add_child(pwd_section)

	# AI CLI Option
	var cli_section := VBoxContainer.new()
	var cli_label := Label.new()
	cli_label.text = "Preferred AI CLI"
	cli_label.add_theme_font_size_override("font_size", 14)
	cli_section.add_child(cli_label)

	_ai_cli_option = OptionButton.new()
	_ai_cli_option.add_item("Auto Detect", 0)
	_ai_cli_option.add_item("Claude Code", 1)
	_ai_cli_option.add_item("Goose", 2)
	_ai_cli_option.custom_minimum_size.y = 40
	_ai_cli_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cli_section.add_child(_ai_cli_option)
	panel.add_child(cli_section)

	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 20)

	var connect_btn := Button.new()
	connect_btn.text = "Connect"
	connect_btn.custom_minimum_size = Vector2(150, 50)
	connect_btn.pressed.connect(_on_connect)
	btn_container.add_child(connect_btn)

	var disconnect_btn := Button.new()
	disconnect_btn.text = "Disconnect"
	disconnect_btn.custom_minimum_size = Vector2(150, 50)
	disconnect_btn.pressed.connect(_on_disconnect)
	btn_container.add_child(disconnect_btn)

	panel.add_child(btn_container)

	content.add_child(panel)
	_current_panel = panel


func _on_connect() -> void:
	print("[MainMenu] _on_connect called")
	var host := _host_input.text.strip_edges()
	var user := _user_input.text.strip_edges()
	var pwd := _pass_input.text

	print("[MainMenu] host: ", host, " user: ", user)

	if host.is_empty() or user.is_empty():
		status_label.text = "Error: Host and username required!"
		return

	status_label.text = "Connecting to " + host + "..."

	# Connect via AIChat autoload
	if AIChat:
		print("[MainMenu] Calling AIChat.connect_to_server...")
		AIChat.connect_to_server(host, user, "", pwd)
		print("[MainMenu] connect_to_server called, waiting for response...")
	else:
		status_label.text = "Error: AIChat not loaded"


func _on_disconnect() -> void:
	if AIChat:
		AIChat.disconnect_from_server()
	_update_connection_status(false)
	status_label.text = "Disconnected"


# === Tab Button Handlers ===

func _on_agent_studio_pressed() -> void:
	agent_studio_btn.button_pressed = true
	chat_hub_btn.button_pressed = false
	settings_btn.button_pressed = false
	_show_agent_studio()


func _on_chat_hub_pressed() -> void:
	agent_studio_btn.button_pressed = false
	chat_hub_btn.button_pressed = true
	settings_btn.button_pressed = false
	_show_chat_hub()


func _on_settings_pressed() -> void:
	agent_studio_btn.button_pressed = false
	chat_hub_btn.button_pressed = false
	settings_btn.button_pressed = true
	_show_settings()
