## god_console.gd - The Console of GOD
## Part of Fantasy Town World-Breaking Demo
##
## This is how GOD (the user) commands agents to do projects.
##
## Usage:
## 1. Press 'G' key to open GOD console
## 2. Type your divine command
## 3. Press Enter to issue command
## 4. Agents receive task at next bell (or immediately if urgent)
##
## Commands:
## - "Build a REST API" → Agents with Python skill assigned
## - "Deploy to production" → Agents with Docker skill assigned
## - "Research AI trends" → Agents search web at library
## - "URGENT: Fix the bug" → Immediate bell ring, high priority

class_name GodConsole
extends Control

## Components (created dynamically)
var _panel: PanelContainer = null
var _cmd_input: LineEdit = null
var _output: RichTextLabel = null
var _status: Label = null
var _commandments: ItemList = null
var _active_tasks: ItemList = null
var _send_button: Button = null
var _urgent_button: Button = null
var _bell_button: Button = null

## References
var _divine_system: Node = null
var _task_economy: Node = null
var _mcp_client: Node = null
var _nanobot_orchestrator: Node = null

## State
var _command_history: Array = []
var _history_index: int = -1

## Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## Divine phrases for flavor
const DIVINE_PREFIXES := [
	"Let there be",
	"Thou shalt",
	"I command thee to",
	"By my divine will,",
	"Let it be written:",
	"So sayeth the User:",
	"Hear me, agents:",
]

const DIVINE_RESPONSES := [
	"Thy will be done, O User.",
	"The agents tremble before thy command.",
	"So it is written, so it shall be.",
	"Thy divine word echoes through the town.",
	"The temple bells shall ring with this message.",
	"Agents prostrate before thy wisdom.",
]


func _ready() -> void:
	visible = false
	_create_ui()
	_connect_signals()
	print("[GOD] Console ready. Press 'G' to open.")


func _create_ui() -> void:
	# Create main panel - make it fill most of the screen
	_panel = PanelContainer.new()
	_panel.name = "PanelContainer"
	_panel.custom_minimum_size = Vector2(800, 500)

	# Set anchors to center and fill
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0

	add_child(_panel)

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.7, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", style)

	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "⚖️ GOD CONSOLE ⚖️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	vbox.add_child(title)

	# Status label
	_status = Label.new()
	_status.name = "StatusLabel"
	_status.text = "Ready"
	vbox.add_child(_status)

	# HBox for lists
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	vbox.add_child(hbox)

	# Commandments list
	_commandments = ItemList.new()
	_commandments.name = "CommandmentsList"
	_commandments.custom_minimum_size = Vector2(200, 100)
	hbox.add_child(_commandments)

	# Active tasks list
	_active_tasks = ItemList.new()
	_active_tasks.name = "ActiveTasksList"
	_active_tasks.custom_minimum_size = Vector2(200, 100)
	hbox.add_child(_active_tasks)

	# Output log
	_output = RichTextLabel.new()
	_output.name = "OutputLog"
	_output.custom_minimum_size = Vector2(0, 150)
	_output.bbcode_enabled = true
	_output.scroll_following = true
	vbox.add_child(_output)

	# Input line
	_cmd_input = LineEdit.new()
	_cmd_input.name = "InputLine"
	_cmd_input.placeholder_text = "Enter divine command..."
	vbox.add_child(_cmd_input)

	# Button HBox
	var hbox2 = HBoxContainer.new()
	hbox2.name = "HBox2"
	vbox.add_child(hbox2)

	_send_button = Button.new()
	_send_button.name = "SendButton"
	_send_button.text = "Send"
	hbox2.add_child(_send_button)

	_urgent_button = Button.new()
	_urgent_button.name = "UrgentButton"
	_urgent_button.text = "⚡ Urgent"
	hbox2.add_child(_urgent_button)

	_bell_button = Button.new()
	_bell_button.name = "RingBellButton"
	_bell_button.text = "🔔 Ring Bell"
	hbox2.add_child(_bell_button)

	# Populate commandments
	_populate_commandments()


func _connect_signals() -> void:
	_cmd_input.text_submitted.connect(_on_command_submitted)
	_send_button.pressed.connect(_on_send_pressed)
	_urgent_button.pressed.connect(_on_urgent_pressed)
	_bell_button.pressed.connect(_on_ring_bell_pressed)


func setup(divine_system: Node, task_economy: Node, mcp_client: Node = null, nanobot_orchestrator: Node = null) -> void:
	_divine_system = divine_system
	_task_economy = task_economy
	_mcp_client = mcp_client
	_nanobot_orchestrator = nanobot_orchestrator

	if _divine_system:
		_divine_system.divine_command_issued.connect(_on_divine_command_issued)
		_divine_system.task_distributed_to_agent.connect(_on_task_distributed)

	# Connect to nanobot orchestrator
	if _nanobot_orchestrator:
		_nanobot_orchestrator.agent_response.connect(_on_nanobot_response)
		print("[GOD] Nanobot Orchestrator connected")

	_update_status()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_G:
				print("[GOD] G key pressed, toggling console...")
				toggle_console()
				get_viewport().set_input_as_handled()
			KEY_UP:
				if visible:
					_navigate_history(-1)
					get_viewport().set_cmd_input_as_handled()
			KEY_DOWN:
				if visible:
					_navigate_history(1)
					get_viewport().set_cmd_input_as_handled()
			KEY_ESCAPE:
				if visible:
					visible = false
					get_viewport().set_cmd_input_as_handled()


## Handle dragging
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start drag if clicking on title area (top 40 pixels)
			var local_pos = event.position
			if local_pos.y < 40:
				_dragging = true
				_drag_offset = event.position
				accept_event()
		else:
			_dragging = false
			accept_event()

	if event is InputEventMouseMotion and _dragging:
		# Move the panel
		var parent = _panel.get_parent()
		if parent == self:
			# Move the panel within the control
			_panel.position += event.relative
		else:
			# Move the whole control
			position += event.relative
		accept_event()


func toggle_console() -> void:
	visible = not visible
	if visible:
		_cmd_input.grab_focus()
		_update_status()
		_refresh_task_list()


func _on_command_submitted(text: String) -> void:
	_process_command(text)


func _on_send_pressed() -> void:
	_process_command(_cmd_input.text)


func _on_urgent_pressed() -> void:
	_process_command(_cmd_input.text, true)


func _on_ring_bell_pressed() -> void:
	if _divine_system:
		_divine_system._ring_bell("manual", "Divine Bell")
		_log("🔔 You rang the divine bell!")


func _process_command(text: String, urgent: bool = false) -> void:
	if text.strip_edges().is_empty():
		return

	# Add to history
	_command_history.append(text)
	_history_index = _command_history.size()

	# Log with divine flavor
	var prefix = DIVINE_PREFIXES[randi() % DIVINE_PREFIXES.size()]
	_log("\n[color=gold]⚖️ %s %s[/color]" % [prefix, text])

	# Parse and execute
	var command = text.strip_edges()
	var priority = 8 if urgent else 5
	var reward = 100 if urgent else 50

	# Check for special commands
	if _handle_special_command(command):
		_cmd_input.text = ""
		return

	# Issue as divine command
	if _divine_system:
		_divine_system.issue_divine_command(command, priority, reward)

		# If urgent, ring bell immediately
		if urgent:
			_divine_system._ring_bell("urgent", "Urgent Bell")

	# Also create task in economy
	if _task_economy:
		var category = _guess_category(command)
		_task_economy.create_task(category, command, priority, reward)

	_cmd_input.text = ""
	_update_status()
	_refresh_task_list()


func _handle_special_command(command: String) -> bool:
	var cmd_lower = command.to_lower()

	# Help
	if cmd_lower in ["help", "?", "commands"]:
		_show_help()
		return true

	# Status
	if cmd_lower in ["status", "stats", "divine status"]:
		_show_status()
		return true

	# List agents
	if "agents" in cmd_lower or "show agents" in cmd_lower:
		_list_agents()
		return true

	# Time
	if cmd_lower in ["time", "what time", "what time is it"]:
		_show_time()
		return true

	# Bell
	if "bell" in cmd_lower or "ring" in cmd_lower:
		if _divine_system:
			_divine_system._ring_bell("manual", "Divine Bell")
			_log("🔔 The divine bell rings!")
		return true

	# Money / gold
	if "gold" in cmd_lower or "money" in cmd_lower:
		_show_economy()
		return true

	# MCP
	if cmd_lower.begins_with("mcp "):
		_handle_mcp_command(command.substr(4))
		return true

	# Give gold to all
	if "bless" in cmd_lower and "gold" in cmd_lower:
		_bless_agents_with_gold(50)
		return true

	# Nanobot commands
	if cmd_lower.begins_with("nanobot ") or cmd_lower.begins_with("nb "):
		_handle_nanobot_command(command.split(" ", false, 1)[1] if " " in command else "")
		return true

	# Send to specific agent
	if cmd_lower.begins_with("tell agent "):
		_handle_tell_agent(command)
		return true

	# Grand Computer (Claude) commands
	if cmd_lower.begins_with("claude ") or cmd_lower.begins_with("grand computer ") or cmd_lower.begins_with("ai "):
		_handle_grand_computer_command(command)
		return true

	# Broadcast to all agents
	if cmd_lower.begins_with("broadcast ") or cmd_lower.begins_with("announce "):
		_handle_broadcast(command)
		return true

	return false


func _show_help() -> void:
	var help_text = """
[center][color=gold]⚖️ DIVINE COMMAND REFERENCE ⚖️[/color][/center]

[color=cyan]PROJECT COMMANDS:[/color]
• Build a REST API - Assigns to Python agents
• Deploy to production - Assigns to DevOps agents
• Research AI trends - Assigns to library agents
• Write tests for X - Assigns to QA agents
• Analyze the data - Assigns to Data agents

[color=purple]GRAND COMPUTER (CLAUDE) COMMANDS:[/color]
• claude speak <message> - Claude speaks to agents
• claude broadcast <message> - Broadcast to all agents
• claude task generate - Generate AI task
• claude task <agent_id> <task> - Assign task to agent
• claude quest - Issue a daily quest
• claude wisdom - Analyze town and guide agents
• claude decree <decree> - Issue AI decree
• claude status - Show Grand Computer status
• broadcast <message> - Broadcast to all agents

[color=cyan]URGENT (press Urgent button):[/color]
• Instantly rings bell, high priority task

[color=cyan]SPECIAL COMMANDS:[/color]
• help - Show this help
• status - Show divine status
• agents - List all agents
• time - Show game time
• gold - Show economy stats
• bell - Ring the divine bell
• bless gold - Give 50 gold to all agents
• mcp <server> <action> - Call MCP directly
• nanobot <cmd> - Nanobot orchestrator commands
• tell agent <id> <msg> - Send message to agent

[color=cyan]SHORTCUTS:[/color]
• G - Toggle console
• Up/Down - Command history
• Escape - Close console
"""
	_log(help_text)


func _show_status() -> void:
	if not _divine_system:
		return

	var status = _divine_system.get_divine_status()
	var next_bell = _divine_system.get_next_bell()

	var status_text = """
[color=gold]⚖️ DIVINE STATUS[/color]

[color=cyan]Time:[/color] Day %d, %s, %02d:%02d
[color=cyan]Divine Favor:[/color] %d
[color=cyan]Offerings:[/color] %d gold
[color=cyan]Prayers Answered:[/color] %d

[color=cyan]Pending Commands:[/color] %d
[color=cyan]Active Tasks:[/color] %d
[color=cyan]Completed:[/color] %d

[color=cyan]Next Bell:[/color] %s (in %d min)
""" % [
		status.time.day,
		status.time.day_name,
		status.time.hour,
		status.time.minute,
		status.favor,
		status.offerings,
		status.prayers_answered,
		status.pending_commands,
		status.active_tasks,
		status.completed_tasks,
		next_bell.name,
		next_bell.minutes_until
	]
	_log(status_text)


func _list_agents() -> void:
	_log("\n[color=gold]👥 AGENTS IN THE TOWN[/color]\n")
	# This would query the agents - placeholder
	_log("Use the agent panel (click an agent) to see details.")


func _show_time() -> void:
	if _divine_system:
		var time = _divine_system.get_game_time()
		_log("\n[color=gold]🕐 %s, Day %d - %02d:%02d[/color]" % [
			time.day_name, time.day, time.hour, time.minute
		])


func _show_economy() -> void:
	if not _task_economy:
		return

	var stats = _task_economy.get_economy_stats()
	_log("""
[color=gold]💰 ECONOMY STATUS[/color]

[color=cyan]Gold in Circulation:[/color] %d
[color=cyan]Total Earned:[/color] %d
[color=cyan]Total Spent:[/color] %d
[color=cyan]Pending Tasks:[/color] %d
[color=cyan]Completed Tasks:[/color] %d
""" % [
		stats.total_gold_in_circulation,
		stats.total_earned,
		stats.total_spent,
		stats.pending_tasks,
		stats.completed_tasks
	])


func _handle_mcp_command(args: String) -> void:
	if not _mcp_client:
		_log("[color=red]MCP client not available[/color]")
		return

	var parts = args.split(" ", false, 2)
	if parts.size() < 2:
		_log("[color=red]Usage: mcp <server> <action> [params][/color]")
		_log("Servers: filesystem, github, postgres, searxng")
		return

	var server = parts[0]
	var action = parts[1]
	var params = parts[2] if parts.size() > 2 else ""

	_log("[color=cyan]Calling MCP: %s.%s(%s)...[/color]" % [server, action, params])

	# Route to appropriate MCP call
	match server:
		"searxng":
			_mcp_client.searxng_search(action, "general", "god")
		"filesystem":
			if action == "read":
				_mcp_client.filessystem_read_file(params, "god")
			elif action == "write":
				_mcp_client.filesystem_write_file(params, "", "god")
			elif action == "list":
				_mcp_client.filesystem_list_directory(params, "god")
		"github":
			if action == "issues":
				var repo_parts = params.split("/")
				if repo_parts.size() >= 2:
					_mcp_client.github_list_issues(repo_parts[0], repo_parts[1], "open", "god")
		_:
			_log("[color=red]Unknown MCP server: %s[/color]" % server)


func _bless_agents_with_gold(amount: int) -> void:
	_log("\n[color=gold]✨ You bless all agents with %d gold![/color]" % amount)
	# This would add gold to all agents via task_economy


func _guess_category(command: String) -> String:
	var cmd = command.to_lower()

	if "deploy" in cmd or "docker" in cmd or "kubernetes" in cmd:
		return "devops"
	if "test" in cmd or "qa" in cmd or "bug" in cmd:
		return "development"
	if "data" in cmd or "analyze" in cmd or "ml" in cmd:
		return "data"
	if "security" in cmd or "audit" in cmd or "vuln" in cmd:
		return "security"
	if "search" in cmd or "research" in cmd or "find" in cmd:
		return "research"
	if "buy" in cmd or "sell" in cmd or "trade" in cmd:
		return "trading"
	if "teach" in cmd or "learn" in cmd:
		return "teaching"

	return "development"


func _navigate_history(direction: int) -> void:
	_history_index = clamp(_history_index + direction, 0, _command_history.size() - 1)
	if _command_history.size() > 0:
		_cmd_input.text = _command_history[_history_index]


func _log(text: String) -> void:
	_output.append_text(text + "\n")
	_output.scroll_to_line(_output.get_line_count())


func _update_status() -> void:
	if _divine_system:
		var time = _divine_system.get_game_time()
		var status = _divine_system.get_divine_status()
		_status.text = "Day %d | %s | %02d:%02d | Tasks: %d | Favor: %d" % [
			time.day, time.day_name, time.hour, time.minute,
			status.active_tasks, status.favor
		]


func _refresh_task_list() -> void:
	_active_tasks.clear()

	if not _task_economy:
		return

	var pending = _task_economy.get_pending_tasks()
	for task in pending.slice(0, 10):  # Show max 10
		var priority_stars = "*".repeat(clamp(task.priority / 2, 1, 5))
		_active_tasks.add_item("%s [%s] %s" % [
			"⭐" if task.priority >= 7 else "○",
			priority_stars,
			task.description.left(30)
		])


func _populate_commandments() -> void:
	_commandments.clear()
	if _divine_system:
		for cmd in _divine_system.get_commandments():
			_commandments.add_item(cmd.left(25))


func _on_divine_command_issued(command: String, priority: int) -> void:
	var response = DIVINE_RESPONSES[randi() % DIVINE_RESPONSES.size()]
	_log("[color=yellow]%s[/color]" % response)
	_refresh_task_list()


func _on_task_distributed(agent_id: String, task: Dictionary) -> void:
	_log("[color=green]→ Agent %s received: '%s'[/color]" % [agent_id, task.task])


## Handle nanobot-specific commands
func _handle_nanobot_command(args: String) -> void:
	if not _nanobot_orchestrator:
		_log("[color=red]Nanobot Orchestrator not available[/color]")
		return

	var parts = args.split(" ", false, 1)
	var subcommand = parts[0].to_lower()
	var params = parts[1] if parts.size() > 1 else ""

	match subcommand:
		"status":
			_show_nanobot_status()
		"list":
			_list_nanobot_agents()
		"broadcast":
			if params.is_empty():
				_log("[color=red]Usage: nanobot broadcast <message>[/color]")
			else:
				_nanobot_orchestrator.broadcast_divine_command(params)
				_log("[color=cyan]Broadcasting to all agents: %s[/color]" % params)
		"tool":
			_handle_nanobot_tool(params)
		"memory":
			_show_nanobot_memory()
		_:
			_log("[color=red]Unknown nanobot command: %s[/color]" % subcommand)
			_log("Available: status, list, broadcast, tool, memory")


func _handle_tell_agent(command: String) -> void:
	if not _nanobot_orchestrator:
		_log("[color=red]Nanobot Orchestrator not available[/color]")
		return

	# Parse: "tell agent 0 do something"
	var parts = command.split(" ", false)
	if parts.size() < 4:
		_log("[color=red]Usage: tell agent <id> <message>[/color]")
		return

	var agent_id = parts[2]
	var message = " ".join(parts.slice(3))

	_nanobot_orchestrator.send_message(agent_id, message)
	_log("[color=cyan]→ Agent %s: %s[/color]" % [agent_id, message])


func _show_nanobot_status() -> void:
	if not _nanobot_orchestrator:
		return

	var agent_ids = _nanobot_orchestrator.get_agent_ids()
	_log("""
[color=gold]🤖 NANOBOT STATUS[/color]

[color=cyan]Active Agents:[/color] %d
[color=cyan]Ollama Host:[/color] %s
[color=cyan]Ollama Model:[/color] %s
""" % [agent_ids.size(), _nanobot_orchestrator.ollama_host, _nanobot_orchestrator.ollama_model])


func _list_nanobot_agents() -> void:
	if not _nanobot_orchestrator:
		return

	var agent_ids = _nanobot_orchestrator.get_agent_ids()
	_log("\n[color=gold]🤖 NANOBOT AGENTS[/color]\n")

	for agent_id in agent_ids:
		var status = _nanobot_orchestrator.get_agent_status(agent_id)
		_log("  Agent %s [%s] - %d pending" % [
			agent_id,
			status.get("status", "unknown"),
			status.get("pending_requests", 0)
		])


func _handle_nanobot_tool(params: String) -> void:
	if not _nanobot_orchestrator:
		return

	var parts = params.split(" ", false, 2)
	if parts.size() < 2:
		_log("[color=red]Usage: nanobot tool <agent_id> <tool_name> [json_params][/color]")
		return

	var agent_id = parts[0]
	var tool_name = parts[1]
	var tool_params = {}

	if parts.size() > 2:
		var json = JSON.new()
		if json.parse(parts[2]) == OK:
			tool_params = json.data
		else:
			_log("[color=red]Invalid JSON params[/color]")
			return

	_nanobot_orchestrator.execute_tool(agent_id, tool_name, tool_params)
	_log("[color=cyan]→ Agent %s execute: %s(%s)[/color]" % [agent_id, tool_name, JSON.stringify(tool_params)])


func _show_nanobot_memory() -> void:
	if not _nanobot_orchestrator:
		return

	var memory = _nanobot_orchestrator._shared_memory
	_log("\n[color=gold]🧠 SHARED TOWN MEMORY[/color]\n")
	_log(JSON.stringify(memory, "  "))


func _on_nanobot_response(agent_id: String, response: String) -> void:
	_log("[color=green]← Agent %s:[/color] %s" % [agent_id, response.left(200)])


## Handle Grand Computer (Claude) commands - THIS IS THE AI SPEAKING TO AGENTS
func _handle_grand_computer_command(command: String) -> void:
	var grand_computer = get_node_or_null("GrandComputer")
	if not grand_computer:
		# Try to find in scene
		grand_computer = _find_grand_computer()

	if not grand_computer:
		_log("[color=red]Grand Computer not available[/color]")
		return

	# Parse the command
	var parts = command.split(" ", false, 2)
	var subcommand = parts[1].to_lower() if parts.size() > 1 else ""
	var args = parts[2] if parts.size() > 2 else ""

	match subcommand:
		"speak", "say", "announce":
			if args.is_empty():
				_log("[color=red]Usage: claude speak <message>[/color]")
			else:
				grand_computer.speak(args)
				_log("[color=purple]Grand Computer speaks: '%s'[/color]" % args.left(100))

		"broadcast", "tell":
			if args.is_empty():
				_log("[color=red]Usage: claude broadcast <message>[/color]")
			else:
				grand_computer.broadcast_to_agents(args, "ai_message")
				_log("[color=purple]Grand Computer broadcasts to all agents: '%s'[/color]" % args.left(100))

		"task", "assign":
			_handle_grand_computer_task(args, grand_computer)

		"quest", "challenge":
			if args.is_empty():
				# Generate a random quest
				var quest = grand_computer.issue_quest("daily_challenge")
				_log("[color=purple]Grand Computer issued quest: %s[/color]" % quest.name)
			else:
				var quest = grand_computer.issue_quest(args)
				_log("[color=purple]Grand Computer issued quest: %s[/color]" % quest.name)

		"wisdom", "guide":
			grand_computer.analyze_and_guide()
			_log("[color=purple]Grand Computer is analyzing the town and providing guidance...[/color]")

		"generate":
			var count = 5
			if args.is_valid_int():
				count = args.to_int()
			grand_computer.generate_daily_tasks(count)
			_log("[color=purple]Grand Computer generated %d new tasks[/color]" % count)

		"status":
			var status = grand_computer.get_status()
			_log("""
[color=purple]═════════════════════════════════════════
[color=purple]      GRAND COMPUTER STATUS[/color]
[color=purple]═════════════════════════════════════════[/color]
[color=cyan]Awake:[/color] %s
[color=cyan]Pending Questions:[/color] %d
[color=cyan]Generated Tasks:[/color] %d
[color=cyan]Available Tasks:[/color] %d
[color=cyan]Active Quests:[/color] %d
""" % [
				"Yes" if status.is_awake else "No",
				status.pending_questions,
				status.generated_tasks,
				status.available_tasks,
				status.active_quests
			])

		"decree":
			if args.is_empty():
				_log("[color=red]Usage: claude decree <decree text>[/color]")
			else:
				grand_computer.issue_ai_decree(args)
				_log("[color=purple]Grand Computer issued AI decree: '%s'[/color]" % args.left(100))

		_:
			_log("[color=red]Unknown Grand Computer command: %s[/color]" % subcommand)
			_log("Available: speak, broadcast, task, quest, wisdom, generate, status, decree")


func _handle_grand_computer_task(args: String, grand_computer: Node) -> void:
	# Parse: "claude task <agent_id> <task_description>" or "claude task generate"
	if args.is_empty():
		# Generate a task
		var task = grand_computer.generate_ai_task({})
		_log("[color=purple]Grand Computer generated task: '%s' (Reward: %d)[/color]" % [task.task.left(80), task.reward])
		return

	var parts = args.split(" ", false, 1)
	if parts.size() < 2:
		# Check if it's "generate"
		if parts[0].to_lower() == "generate":
			var task = grand_computer.generate_ai_task({})
			_log("[color=purple]Grand Computer generated task: '%s'[/color]" % task.task.left(80))
		else:
			_log("[color=red]Usage: claude task <agent_id> <task> OR claude task generate[/color]")
		return

	var agent_id = parts[0]
	var task_description = parts[1]

	grand_computer.assign_task_to_agent(agent_id, task_description, 5, 50)
	_log("[color=purple]Grand Computer assigned task to Agent %s: '%s'[/color]" % [agent_id, task_description.left(80)])


func _handle_broadcast(command: String) -> void:
	var grand_computer = _find_grand_computer()
	if not grand_computer:
		_log("[color=red]Grand Computer not available for broadcast[/color]")
		return

	var message = command.split(" ", false, 1)[1] if " " in command else ""
	if message.is_empty():
		_log("[color=red]Usage: broadcast <message>[/color]")
		return

	grand_computer.broadcast_to_agents(message, "god_broadcast")
	_log("[color=gold]Broadcasted to all agents: '%s'[/color]" % message.left(100))


func _find_grand_computer() -> Node:
	var grand_computer = get_node_or_null("GrandComputer")
	if not grand_computer:
		grand_computer = get_tree().root.find_child("GrandComputer", true, false)
	return grand_computer
