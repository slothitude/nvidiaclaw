## AgentStudioPanel
## Main panel that combines Wizard, Builder, and Chat Hub.
extends Control
class_name AgentStudioPanel

## Preload components
const WizardControllerScript = preload("res://addons/agent_studio/ui/wizard/wizard_controller.gd")
const ChatHubScript = preload("res://addons/agent_studio/ui/chat/chat_hub.gd")

@onready var tab_container: TabContainer = $VBox/TabContainer
@onready var wizard_tab: Control = $VBox/TabContainer/WizardTab
@onready var chat_tab: Control = $VBox/TabContainer/ChatTab
@onready var status_bar: HBoxContainer = $VBox/StatusBar

@onready var connection_status: Label = $VBox/StatusBar/ConnectionStatus
@onready var agent_status: Label = $VBox/StatusBar/AgentStatus

## Wizard instance
var wizard: Control = null

## Chat hub instance
var chat_hub: Control = null


func _ready() -> void:
	_setup_tabs()
	_connect_signals()


func _setup_tabs() -> void:
	# Create wizard tab
	wizard = WizardControllerScript.new()
	wizard.name = "Wizard"
	wizard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wizard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wizard.wizard_completed.connect(_on_wizard_completed)
	wizard.wizard_cancelled.connect(_on_wizard_cancelled)
	tab_container.add_child(wizard)

	# Create chat tab
	chat_hub = ChatHubScript.new()
	chat_hub.name = "Chat Hub"
	chat_hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(chat_hub)

	# Set initial tab
	tab_container.current_tab = 0


func _connect_signals() -> void:
	if AgentStudio:
		AgentStudio.agents_changed.connect(_on_agents_changed)
		AgentStudio.agent_selected.connect(_on_agent_selected)
		AgentStudio.ssh_connected.connect(_on_ssh_connected)
		AgentStudio.ssh_disconnected.connect(_on_ssh_disconnected)
		AgentStudio.studio_error.connect(_on_studio_error)


func _on_wizard_completed(config: Resource) -> void:
	print("[AgentStudioPanel] Agent created: ", config.name)
	# Switch to chat tab
	tab_container.current_tab = 1
	# Select the new agent
	if AgentStudio:
		AgentStudio.select_agent(config.id)


func _on_wizard_cancelled() -> void:
	print("[AgentStudioPanel] Wizard cancelled")
	# Switch to chat tab if there are agents
	if AgentStudio and AgentStudio.get_agents().size() > 0:
		tab_container.current_tab = 1


func _on_agents_changed() -> void:
	_update_status()


func _on_agent_selected(agent: Resource) -> void:
	agent_status.text = "%s %s" % [agent.icon, agent.name]
	_update_status()


func _on_ssh_connected(session_id: String) -> void:
	connection_status.text = "🟢 Connected"
	connection_status.add_theme_color_override("font_color", Color.GREEN)
	_update_status()


func _on_ssh_disconnected() -> void:
	connection_status.text = "🔴 Disconnected"
	connection_status.add_theme_color_override("font_color", Color.RED)
	_update_status()


func _on_studio_error(message: String) -> void:
	print("[AgentStudioPanel] Error: ", message)


func _update_status() -> void:
	if AgentStudio:
		if AgentStudio.is_connected:
			connection_status.text = "🟢 Connected"
			connection_status.add_theme_color_override("font_color", Color.GREEN)
		else:
			connection_status.text = "🔴 Disconnected"
			connection_status.add_theme_color_override("font_color", Color.RED)

		if AgentStudio.current_agent:
			agent_status.text = "%s %s" % [AgentStudio.current_agent.icon, AgentStudio.current_agent.name]
		else:
			agent_status.text = "No agent selected"


## Open wizard for new agent
func create_new_agent() -> void:
	wizard.reset()
	tab_container.current_tab = 0


## Open wizard for editing agent
func edit_agent(agent_id: String) -> void:
	if AgentStudio:
		var agent = AgentStudio.client.get_agent_by_id(agent_id)
		if agent:
			wizard.edit_agent(agent)
			tab_container.current_tab = 0


## Switch to chat
func show_chat() -> void:
	tab_container.current_tab = 1


## Connect to SSH server
func connect_ssh(host: String, username: String, ssh_key: String = "", password: String = "") -> void:
	if AgentStudio:
		AgentStudio.connect_ssh(host, username, ssh_key, password)
