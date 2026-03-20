## Chat Panel
## Main UI for the AI chat interface.
extends Control

# UI Elements
@onready var message_list: VBoxContainer = $VBox/ScrollContainer/MessageList
@onready var message_input: TextEdit = $VBox/InputArea/TextEdit
@onready var send_button: Button = $VBox/InputArea/SendButton
@onready var connect_button: Button = $VBox/Toolbar/ConnectButton
@onready var disconnect_button: Button = $VBox/Toolbar/DisconnectButton
@onready var clear_button: Button = $VBox/Toolbar/ClearButton
@onready var settings_button: Button = $VBox/Toolbar/SettingsButton
@onready var status_label: Label = $VBox/Toolbar/StatusLabel
@onready var typing_indicator: Control = $VBox/TypingIndicator

# Chat manager reference
var chat_manager: Node

# Message row scene
var message_row_scene: PackedScene

# Current streaming message reference
var _current_stream_label: RichTextLabel


func _ready() -> void:
	# Setup button connections
	send_button.pressed.connect(_on_send_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Setup signal connections from chat manager
	chat_manager.message_added.connect(_on_message_added)
	chat_manager.stream_update.connect(_on_stream_update)
	chat_manager.chat_error.connect(_on_chat_error)
	chat_manager.connection_changed.connect(_on_connection_changed)

	# Initial UI state
	_update_ui_state()


func setup(manager: Node) -> void:
	chat_manager = manager
	_ready()


func _on_send_pressed() -> void:
	var text = message_input.text.strip_edges()
	if text.is_empty():
		return

	message_input.clear()
	chat_manager.send_message(text)


func _on_connect_pressed() -> void:
	# This would typically open a connection dialog
	# For now, use defaults
	chat_manager.connect_with_defaults()


func _on_disconnect_pressed() -> void:
	chat_manager.disconnect_from_server()


func _on_clear_pressed() -> void:
	chat_manager.clear_history()
	_clear_message_list()


func _on_settings_pressed() -> void:
	# Open settings panel
	# This would be implemented with a separate scene
	pass


func _on_message_added(role: String, content: String) -> void:
	_add_message_row(role, content)
	_scroll_to_bottom()


func _on_stream_update(chunk: Dictionary) -> void:
	var chunk_type = chunk.get("type", "")

	match chunk_type:
		"thinking":
			_show_typing_indicator(true)
		"text":
			_show_typing_indicator(true)
			var content = chunk.get("content", "")
			_update_streaming_message(content)
		"tool_use":
			var tool = chunk.get("tool", "unknown")
			var path = chunk.get("path", "")
			_add_tool_row(tool, path)
		"complete":
			_show_typing_indicator(false)
			# Streaming message was already added via message_added
			_current_stream_label = null
		"error":
			_show_typing_indicator(false)
			var error_msg = chunk.get("content", "Error")
			_add_message_row("error", error_msg)


func _on_chat_error(message: String) -> void:
	_add_message_row("error", message)
	_show_typing_indicator(false)


func _on_connection_changed(connected: bool) -> void:
	_update_ui_state()


func _add_message_row(role: String, content: String) -> void:
	if message_row_scene == null:
		return

	var row = message_row_scene.instantiate()
	var role_label = row.get_node_or_null("RoleLabel") as Label
	var content_label = row.get_node_or_null("ContentLabel") as RichTextLabel

	if role_label:
		role_label.text = role.to_upper()
		_apply_role_style(role_label, role)

	if content_label:
		content_label.text = content
		# Track streaming messages
		if role == "assistant":
			_current_stream_label = content_label

	message_list.add_child(row)


func _add_tool_row(tool: String, path: String) -> void:
	var text = "[Tool: %s] %s" % [tool, path]
	_add_message_row("system", text)


func _update_streaming_message(content: String) -> void:
	if _current_stream_label:
		_current_stream_label.text = content


func _show_typing_indicator(show: bool) -> void:
	if typing_indicator:
		typing_indicator.visible = show


func _clear_message_list() -> void:
	for child in message_list.get_children():
		child.queue_free()


func _scroll_to_bottom() -> void:
	var scroll = get_node_or_null("VBox/ScrollContainer") as ScrollContainer
	if scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


func _update_ui_state() -> void:
	var connected = chat_manager.is_connected if chat_manager else false

	connect_button.visible = not connected
	disconnect_button.visible = connected
	send_button.disabled = not connected

	if connected:
		status_label.text = "Connected (%s)" % chat_manager.ai_cli
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "Disconnected"
		status_label.add_theme_color_override("font_color", Color.RED)


func _apply_role_style(label: Label, role: String) -> void:
	match role:
		"user":
			label.add_theme_color_override("font_color", Color.CYAN)
		"assistant":
			label.add_theme_color_override("font_color", Color.GREEN)
		"error":
			label.add_theme_color_override("font_color", Color.RED)
		"system":
			label.add_theme_color_override("font_color", Color.YELLOW)
