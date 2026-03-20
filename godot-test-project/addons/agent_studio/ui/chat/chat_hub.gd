## ChatHub
## Main chat interface with agent selector.
extends Control
class_name ChatHub

## Preload dependencies
const ConfigScript = preload("res://addons/agent_studio/agent_config.gd")

@onready var agent_selector: OptionButton = $VBox/Header/AgentSelector
@onready var settings_btn: Button = $VBox/Header/SettingsBtn
@onready var messages_container: ScrollContainer = $VBox/MessagesContainer
@onready var messages_list: VBoxContainer = $VBox/MessagesContainer/MessagesList
@onready var thinking_indicator: Label = $VBox/MessagesContainer/ThinkingIndicator
@onready var input_field: TextEdit = $VBox/InputContainer/InputField
@onready var send_btn: Button = $VBox/InputContainer/SendBtn
@onready var attach_btn: Button = $VBox/InputContainer/AttachBtn

## Current messages
var messages: Array = []

## Current streaming content
var stream_content: String = ""

## Is currently streaming
var is_streaming: bool = false


func _ready() -> void:
	_connect_signals()
	_refresh_agents()
	_hide_thinking()


func _connect_signals() -> void:
	agent_selector.item_selected.connect(_on_agent_selected)
	send_btn.pressed.connect(_on_send)
	settings_btn.pressed.connect(_on_settings)
	attach_btn.pressed.connect(_on_attach)

	if AgentStudio:
		AgentStudio.agents_changed.connect(_refresh_agents)
		AgentStudio.agent_selected.connect(_on_agent_changed)
		AgentStudio.message_added.connect(_on_message_added)
		AgentStudio.stream_update.connect(_on_stream_update)
		AgentStudio.studio_error.connect(_on_error)


func _refresh_agents() -> void:
	agent_selector.clear()

	if not AgentStudio:
		agent_selector.add_item("No AgentStudio", 0)
		return

	var agents := AgentStudio.get_agents()
	if agents.is_empty():
		agent_selector.add_item("No agents - create one first", 0)
		send_btn.disabled = true
		return

	for i in range(agents.size()):
		var agent: Resource = agents[i]
		agent_selector.add_item("%s %s" % [agent.icon, agent.name], i)
		agent_selector.set_item_metadata(i, agent.id)

	send_btn.disabled = false


func _on_agent_selected(index: int) -> void:
	var agent_id: String = agent_selector.get_item_metadata(index)
	if not agent_id.is_empty() and AgentStudio:
		AgentStudio.select_agent(agent_id)


func _on_agent_changed(agent: Resource) -> void:
	# Update selector to match
	for i in range(agent_selector.item_count):
		if agent_selector.get_item_metadata(i) == agent.id:
			agent_selector.select(i)
			break


func _on_send() -> void:
	var text := input_field.text.strip_edges()
	if text.is_empty() or is_streaming:
		return

	# Add user message
	_add_message("user", text)
	input_field.clear()

	# Send via AgentStudio (integrates with ai_chat)
	if AgentStudio and AgentStudio.current_agent:
		_send_to_agent(text)
	else:
		_add_message("system", "Error: No agent selected")


func _send_to_agent(text: String) -> void:
	# This integrates with the existing ai_chat system
	# For now, show placeholder
	_show_thinking("Connecting to %s..." % AgentStudio.current_agent.name)

	# TODO: Integrate with AIChat for actual SSH communication
	# The message will come back via message_added signal


func _on_message_added(role: String, content: String) -> void:
	_hide_thinking()
	_add_message(role, content)


func _on_stream_update(chunk: Dictionary) -> void:
	var chunk_type: String = chunk.get("type", "")

	match chunk_type:
		"thinking":
			_show_thinking(chunk.get("content", "Thinking..."))
		"text":
			_hide_thinking()
			stream_content += chunk.get("content", "")
			_update_streaming_message()
		"complete":
			_hide_thinking()
			if not stream_content.is_empty():
				_finalize_streaming_message()
		"error":
			_hide_thinking()
			_add_message("system", "Error: " + chunk.get("content", "Unknown error"))
		"tool_use":
			var tool: String = chunk.get("tool", "unknown")
			_add_message("system", "Using tool: " + tool)


func _on_error(message: String) -> void:
	_hide_thinking()
	_add_message("system", "Error: " + message)


func _add_message(role: String, content: String) -> void:
	messages.append({"role": role, "content": content})
	_render_messages()


func _update_streaming_message() -> void:
	# Find or create streaming message
	var stream_msg: Control = null
	for child in messages_list.get_children():
		if child.has_meta("is_streaming") and child.get_meta("is_streaming"):
			stream_msg = child
			break

	if stream_msg:
		# Update existing
		var label: RichTextLabel = stream_msg.get_node("Content")
		if label:
			label.text = stream_content
	else:
		# Create new streaming message
		_add_message("assistant", stream_content)
		# Mark as streaming
		var last_child = messages_list.get_child(-1)
		last_child.set_meta("is_streaming", true)


func _finalize_streaming_message() -> void:
	# Find streaming message and finalize it
	for child in messages_list.get_children():
		if child.has_meta("is_streaming"):
			child.set_meta("is_streaming", false)
			break
	stream_content = ""


func _render_messages() -> void:
	# Clear existing
	for child in messages_list.get_children():
		child.queue_free()

	# Render all messages
	for msg in messages:
		var msg_control := _create_message_control(msg["role"], msg["content"])
		messages_list.add_child(msg_control)

	# Scroll to bottom
	await get_tree().process_frame
	messages_container.scroll_vertical = messages_container.get_v_scroll_bar().max_value


func _create_message_control(role: String, content: String) -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# Role icon
	var icon := Label.new()
	icon.custom_minimum_size.x = 32
	match role:
		"user":
			icon.text = "🧑"
		"assistant":
			icon.text = "🤖"
		"system":
			icon.text = "⚙️"
		_:
			icon.text = "💬"
	container.add_child(icon)

	# Content
	var content_label := RichTextLabel.new()
	content_label.bbcode_enabled = true
	content_label.fit_content = true
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.text = content
	content_label.name = "Content"
	container.add_child(content_label)

	return container


func _show_thinking(text: String = "Thinking...") -> void:
	thinking_indicator.text = "🧠 " + text
	thinking_indicator.visible = true
	is_streaming = true
	send_btn.disabled = true


func _hide_thinking() -> void:
	thinking_indicator.visible = false
	is_streaming = false
	send_btn.disabled = false


func _on_settings() -> void:
	# Open settings panel
	print("[ChatHub] Settings button pressed")


func _on_attach() -> void:
	# File attachment
	print("[ChatHub] Attach button pressed")


## Clear chat history
func clear_chat() -> void:
	messages.clear()
	stream_content = ""
	_render_messages()
