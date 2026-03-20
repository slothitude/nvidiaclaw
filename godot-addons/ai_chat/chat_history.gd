## Chat History
## Manages conversation history for the AI chat.
class_name ChatHistory
extends Resource

## A single message in the chat history
class Message:
	var role: String  # "user" or "assistant"
	var content: String
	var timestamp: Dictionary  # Time dict from Time.get_datetime_dict_from_system()
	var metadata: Dictionary = {}

	func _init(p_role: String, p_content: String, p_metadata: Dictionary = {}) -> void:
		role = p_role
		content = p_content
		timestamp = Time.get_datetime_dict_from_system()
		metadata = p_metadata

	func to_dict() -> Dictionary:
		return {
			"role": role,
			"content": content,
			"timestamp": timestamp,
			"metadata": metadata
		}

	static func from_dict(data: Dictionary) -> Message:
		var msg = Message.new(data.role, data.content, data.get("metadata", {}))
		if data.has("timestamp"):
			msg.timestamp = data.timestamp
		return msg


## List of messages in the conversation
@export var messages: Array[Dictionary] = []

## Maximum number of messages to keep
@export var max_messages: int = 100


## Add a user message to history
func add_user_message(content: String, metadata: Dictionary = {}) -> void:
	var msg = Message.new("user", content, metadata)
	_add_message(msg)


## Add an assistant message to history
func add_assistant_message(content: String, metadata: Dictionary = {}) -> void:
	var msg = Message.new("assistant", content, metadata)
	_add_message(msg)


## Get all messages
func get_messages() -> Array[Message]:
	var result: Array[Message] = []
	for msg_dict in messages:
		result.append(Message.from_dict(msg_dict))
	return result


## Get messages as formatted context string
func get_context_string(max_count: int = 10) -> String:
	var lines: Array[String] = []
	var start_idx = max(0, messages.size() - max_count)

	for i in range(start_idx, messages.size()):
		var msg = messages[i]
		var role = msg.get("role", "unknown")
		var content = msg.get("content", "")
		lines.append("%s: %s" % [role.capitalize(), content])

	return "\n".join(lines)


## Get the last N messages
func get_last_messages(count: int) -> Array[Message]:
	var result: Array[Message] = []
	var start_idx = max(0, messages.size() - count)

	for i in range(start_idx, messages.size()):
		result.append(Message.from_dict(messages[i]))

	return result


## Clear all messages
func clear() -> void:
	messages.clear()


## Save history to file
func save_to_file(path: String) -> int:
	var data := {
		"messages": messages,
		"max_messages": max_messages
	}
	var json = JSON.stringify(data, "  ")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		return OK
	return ERR_CANT_CREATE


## Load history from file
static func load_from_file(path: String) -> ChatHistory:
	if not FileAccess.file_exists(path):
		return ChatHistory.new()

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ChatHistory.new()

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return ChatHistory.new()

	var data = json.data
	var history = ChatHistory.new()
	history.messages = data.get("messages", [])
	history.max_messages = data.get("max_messages", 100)
	return history


## Get message count
func get_message_count() -> int:
	return messages.size()


## Check if history is empty
func is_empty() -> bool:
	return messages.is_empty()


# === Private Methods ===


func _add_message(msg: Message) -> void:
	messages.append(msg.to_dict())

	# Trim if over limit
	while messages.size() > max_messages:
		messages.pop_front()
