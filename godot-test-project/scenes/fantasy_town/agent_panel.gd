## agent_panel.gd - Agent Bio and Chat Panel
## Part of Fantasy Town World-Breaking Demo
##
## Shows agent personality, mood, skills, todo list, and allows user to chat with them.
## Uses Ollama for AI responses. Supports web search via SearXNG and bash execution.

class_name AgentPanel
extends PanelContainer

## Signals
signal closed
signal chat_sent(agent_id: String, message: String)
signal action_requested(agent_id: String, action: String, params: Dictionary)

## Components
@onready var _name_label: Label = $VBox/Header/AgentName
@onready var _close_button: Button = $VBox/Header/CloseButton
@onready var _personality_text: TextEdit = $VBox/BioSection/PersonalityText
@onready var _happiness_bar: ProgressBar = $VBox/BioSection/MoodBars/HappinessBar
@onready var _energy_bar: ProgressBar = $VBox/BioSection/MoodBars/EnergyBar
@onready var _curiosity_bar: ProgressBar = $VBox/BioSection/MoodBars/CuriosityBar
@onready var _todo_list: ItemList = $VBox/TodoSection/TodoList
@onready var _todo_input: LineEdit = $VBox/TodoSection/TodoInput
@onready var _add_todo_button: Button = $VBox/TodoSection/TodoHeader/AddTodoButton
@onready var _skills_label: Label = $VBox/SkillsSection/SkillsList
@onready var _web_search_button: Button = $VBox/ActionsSection/ActionsButtons/WebSearchButton
@onready var _bash_button: Button = $VBox/ActionsSection/ActionsButtons/BashButton
@onready var _visit_lib_button: Button = $VBox/ActionsSection/ActionsButtons/VisitLibButton
@onready var _visit_uni_button: Button = $VBox/ActionsSection/ActionsButtons/VisitUniButton
@onready var _action_input: LineEdit = $VBox/ActionsSection/ActionInput
@onready var _chat_history: RichTextLabel = $VBox/ChatSection/ChatHistory
@onready var _chat_input: LineEdit = $VBox/ChatSection/InputSection/ChatInput
@onready var _send_button: Button = $VBox/ChatSection/InputSection/SendButton
@onready var _status_label: Label = $VBox/Status

## State
var _current_agent_id: String = ""
var _current_agent_behavior = null  # AgentBehavior
var _ollama_client = null  # OllamaClient
var _pending_chat: bool = false
var _current_action_mode: String = ""  # "search", "bash", or ""

## Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## Mood bar colors
const HAPPY_COLOR := Color(0.2, 0.8, 0.3)
const SAD_COLOR := Color(0.8, 0.3, 0.2)
const ENERGY_COLOR := Color(0.9, 0.7, 0.2)
const CURIOSITY_COLOR := Color(0.3, 0.6, 0.9)


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_send_button.pressed.connect(_on_send_pressed)
	_chat_input.text_submitted.connect(_on_text_submitted)
	_add_todo_button.pressed.connect(_on_add_todo_pressed)
	_todo_input.text_submitted.connect(_on_todo_submitted)
	_web_search_button.pressed.connect(_on_web_search_pressed)
	_bash_button.pressed.connect(_on_bash_pressed)
	_visit_lib_button.pressed.connect(_on_visit_lib_pressed)
	_visit_uni_button.pressed.connect(_on_visit_uni_pressed)
	_action_input.text_submitted.connect(_on_action_submitted)

	# Style mood bars
	_style_progress_bar(_happiness_bar, HAPPY_COLOR, SAD_COLOR)
	_style_progress_bar(_energy_bar, ENERGY_COLOR, ENERGY_COLOR)
	_style_progress_bar(_curiosity_bar, CURIOSITY_COLOR, CURIOSITY_COLOR)

	_chat_history.text = "[i]Click on an agent to start chatting...[/i]"
	hide()


func _style_progress_bar(bar: ProgressBar, high_color: Color, low_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	bar.add_theme_stylebox_override("background", style)


func setup(ollama_client) -> void:
	_ollama_client = ollama_client
	if _ollama_client:
		_ollama_client.thought_generated.connect(_on_ollama_response)


func show_agent(agent_behavior) -> void:
	_current_agent_behavior = agent_behavior
	_current_agent_id = agent_behavior.agent_id

	# Update UI with agent info - access _soul directly
	var soul = agent_behavior._soul
	if soul:
		var personality = soul.personality
		var speech_style = soul.speech_style
		var traits = soul.traits
		var mood = soul.mood

		# Get job and workplace directly
		var job = str(agent_behavior._job) if agent_behavior._job else "None"
		var workplace = str(agent_behavior._workplace) if agent_behavior._workplace else "None"

		_name_label.text = "Agent %s" % _current_agent_id
		_personality_text.text = "%s\n\nJob: %s at %s\nSpeech: %s\nTraits: %s" % [personality, job, workplace, speech_style, ", ".join(traits)]

		# Update mood bars
		_happiness_bar.value = mood.get("happiness", 0.5) * 100
		_energy_bar.value = mood.get("energy", 0.5) * 100
		_curiosity_bar.value = mood.get("curiosity", 0.5) * 100
	else:
		_name_label.text = "Agent %s" % _current_agent_id
		_personality_text.text = "No soul data available"

	# Update todo list
	_update_todo_list()

	# Update skills
	_update_skills()

	# Clear chat history for new agent
	_chat_history.clear()
	_chat_history.append_text("[color=aqua][b]You selected Agent %s[/b][/color]\n" % _current_agent_id)
	_chat_history.append_text("[i]Say hello to start a conversation![/i]\n")

	show()
	_chat_input.grab_focus()


func _update_todo_list() -> void:
	_todo_list.clear()
	if _current_agent_behavior:
		for todo in _current_agent_behavior._todo_list:
			var status_icon = "○" if todo.status == "pending" else "✓"
			var priority_stars = "*".repeat(clamp(todo.priority / 2, 1, 5))
			_todo_list.add_item("%s [%s] %s" % [status_icon, priority_stars, todo.task])


func _update_skills() -> void:
	if not _current_agent_behavior or _current_agent_behavior._skills.is_empty():
		_skills_label.text = "No skills learned yet - visit University!"
		return

	var skills_text = ""
	for skill_name in _current_agent_behavior._skills.keys():
		var skill = _current_agent_behavior._skills[skill_name]
		skills_text += "• %s (Lv.%d, XP: %d)\n" % [skill_name, skill.get("level", 1), skill.get("experience", 0)]

	_skills_label.text = skills_text.strip_edges()


func _on_close_pressed() -> void:
	_current_agent_behavior = null
	_current_agent_id = ""
	hide()
	closed.emit()


func _on_text_submitted(text: String) -> void:
	_send_message()


func _on_send_pressed() -> void:
	_send_message()


func _send_message() -> void:
	var message = _chat_input.text.strip_edges()
	if message.is_empty() or _pending_chat:
		return

	_chat_input.text = ""

	# Show user message
	_chat_history.append_text("\n[color=white][b]You:[/b] %s[/color]\n" % message)

	# Request AI response
	if _ollama_client and _current_agent_behavior and _current_agent_behavior._soul:
		_pending_chat = true
		_status_label.text = "Thinking..."
		_send_button.disabled = true

		# Build context for chat
		var context = {
			"current_goal": _current_agent_behavior._current_goal,
			"position": _current_agent_behavior._agent_body.position if _current_agent_behavior._agent_body else Vector3.ZERO,
			"is_wandering": _current_agent_behavior._is_wandering,
			"nearby_objects": [],
			"user_message": message
		}

		# Build a chat-specific prompt
		var prompt = _build_chat_prompt(message)

		# Send to Ollama with a special ID for chat responses
		_ollama_client.generate_thought("chat_%s" % _current_agent_id, _current_agent_behavior._soul.to_prompt_data(), context)
	else:
		# Fallback response
		_show_fallback_response(message)


func _build_chat_prompt(user_message: String) -> String:
	var soul = _current_agent_behavior._soul
	if not soul:
		return user_message

	var personality = soul.personality
	var speech_style = soul.speech_style

	# Get current todo list for context
	var todos = []
	for todo in _current_agent_behavior._todo_list:
		if todo.status == "pending":
			todos.append(todo.task)

	var todos_str = ""
	if todos.size() > 0:
		todos_str = "\nMy current tasks: " + ", ".join(todos.slice(0, 3))

	var prompt = """You are %s. You speak %s.%s

A human visitor has approached you and says: "%s"

Respond in character, keeping your response brief (1-3 sentences). Be engaging and true to your personality.

Response:""" % [personality, speech_style, todos_str, user_message]

	return prompt


func _on_ollama_response(agent_id: String, thought: String) -> void:
	# Check if this is a chat response for our current agent
	if not agent_id.begins_with("chat_%s" % _current_agent_id):
		return

	_pending_chat = false
	_send_button.disabled = false
	_status_label.text = ""

	# Show AI response
	_chat_history.append_text("\n[color=#90EE90][b]%s:[/b] %s[/color]\n" % [_name_label.text.split(" - ")[0], thought])


func _show_fallback_response(user_message: String) -> void:
	var responses = [
		"Oh, hello there! Nice to meet you!",
		"Interesting question! Let me think about that...",
		"I'm glad you stopped by to chat!",
		"That's a wonderful thing to ask!",
		"Hmm, I'm not sure, but I appreciate you asking!"
	]

	var response = responses[randi() % responses.size()]
	_chat_history.append_text("\n[color=#90EE90][b]%s:[/b] %s[/color]\n" % [_name_label.text.split(" - ")[0], response])
	_status_label.text = ""


## Todo List Actions
func _on_add_todo_pressed() -> void:
	_todo_input.visible = not _todo_input.visible
	if _todo_input.visible:
		_todo_input.grab_focus()


func _on_todo_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	if _current_agent_behavior:
		_current_agent_behavior.add_todo(text.strip_edges(), 5)
		_update_todo_list()
		_chat_history.append_text("\n[color=yellow][i]Added task: %s[/i][/color]\n" % text)

	_todo_input.text = ""
	_todo_input.visible = false


## Action Buttons
func _on_web_search_pressed() -> void:
	_current_action_mode = "search"
	_action_input.placeholder_text = "Enter search query..."
	_action_input.visible = true
	_action_input.grab_focus()
	_status_label.text = "Web Search (SearXNG)"


func _on_bash_pressed() -> void:
	_current_action_mode = "bash"
	_action_input.placeholder_text = "Enter bash command..."
	_action_input.visible = true
	_action_input.grab_focus()
	_status_label.text = "Bash Command"


func _on_visit_lib_pressed() -> void:
	if _current_agent_behavior:
		_current_agent_behavior.add_todo("Visit library for research", 7)
		_update_todo_list()
		_chat_history.append_text("\n[color=cyan][i]Added goal: Visit the library[/i][/color]\n")
		_status_label.text = "Library visit added to todo list"


func _on_visit_uni_pressed() -> void:
	if _current_agent_behavior:
		_current_agent_behavior.add_todo("Visit university to learn a skill", 8)
		_update_todo_list()
		_chat_history.append_text("\n[color=purple][i]Added goal: Visit the university[/i][/color]\n")
		_status_label.text = "University visit added to todo list"


func _on_action_submitted(text: String) -> void:
	var command = text.strip_edges()
	if command.is_empty():
		return

	_action_input.text = ""
	_action_input.visible = false

	if _current_action_mode == "search":
		_perform_web_search(command)
	elif _current_action_mode == "bash":
		_execute_bash(command)

	_current_action_mode = ""


func _perform_web_search(query: String) -> void:
	_chat_history.append_text("\n[color=blue][b]Searching web:[/b] %s[/color]\n" % query)
	_status_label.text = "Searching..."

	if _current_agent_behavior:
		# Check if agent has web search skill or is at library
		if _current_agent_behavior._skills.has("Web Search (SearXNG)") or _current_agent_behavior._current_building == "library":
			_current_agent_behavior.web_search(query)
			_chat_history.append_text("[color=green][i]Search initiated via SearXNG...[/i][/color]\n")
		else:
			_chat_history.append_text("[color=orange][i]Agent needs to learn web search at the library first![/i][/color]\n")
			_status_label.text = "Need library access for web search"
			return

	_status_label.text = ""


func _execute_bash(command: String) -> void:
	_chat_history.append_text("\n[color=red][b]Executing bash:[/b] %s[/color]\n" % command)
	_status_label.text = "Running command..."

	if _current_agent_behavior:
		# Check if agent has bash skill
		if _current_agent_behavior._skills.has("Python Scripting") or _current_agent_behavior._skills.has("API Integration"):
			_current_agent_behavior.execute_bash(command)
			_chat_history.append_text("[color=green][i]Command sent to SSH bridge...[/i][/color]\n")
		else:
			_chat_history.append_text("[color=orange][i]Agent needs to learn scripting at the university first![/i][/color]\n")
			# Still execute but with a warning
			_current_agent_behavior.execute_bash(command)

	_status_label.text = ""


func add_thought_to_chat(thought: String) -> void:
	if is_visible() and _current_agent_behavior:
		_chat_history.append_text("\n[color=gray][i]%s thinks: %s[/i][/color]\n" % [_name_label.text.split(" - ")[0], thought])


func update_mood_display() -> void:
	if _current_agent_behavior and _current_agent_behavior._soul:
		var mood = _current_agent_behavior._soul.mood
		_happiness_bar.value = mood.get("happiness", 0.5) * 100
		_energy_bar.value = mood.get("energy", 0.5) * 100
		_curiosity_bar.value = mood.get("curiosity", 0.5) * 100


func _process(_delta: float) -> void:
	if is_visible():
		update_mood_display()
		# Periodically update todo and skills
		if Engine.get_frames_drawn() % 60 == 0:  # Every ~1 second
			_update_todo_list()
			_update_skills()


## Handle dragging
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start drag if clicking on header area (VBox/Header)
			var local_pos = event.position
			if local_pos.y < 50:  # Header is roughly top 50 pixels
				_dragging = true
				_drag_offset = event.position
				accept_event()
		else:
			_dragging = false
			accept_event()

	if event is InputEventMouseMotion and _dragging:
		# Move the panel
		position += event.relative
		accept_event()
