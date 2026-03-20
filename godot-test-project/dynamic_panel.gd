## DynamicPanel
## Standalone window for LLM-generated dynamic UI
extends Control

@onready var container: PanelContainer = $VBox/ScrollContainer/PanelContainer
@onready var status_label: Label = $VBox/StatusBar/StatusLabel
@onready var state_label: Label = $VBox/StateBar/StateLabel


func _ready() -> void:
	# Set up UIManager to render into our container
	UIManager.set_ui_parent(container)

	# Connect to AgentBridge signals
	AgentBridge.state_changed.connect(_on_agent_state_changed)
	AgentBridge.error.connect(_on_agent_error)
	UIManager.render_complete.connect(_on_render_complete)

	_update_state_display()


func _update_state_display() -> void:
	state_label.text = "State: " + JSON.stringify(StateManager.snapshot()).left(80)


func _on_agent_state_changed(new_state: String) -> void:
	status_label.text = "Agent: " + new_state


func _on_agent_error(code: String, msg: String) -> void:
	status_label.text = "Error: " + code


func _on_render_complete(ui_id: String) -> void:
	status_label.text = "Rendered: " + ui_id
	_update_state_display()


func _on_mock_btn_pressed() -> void:
	status_label.text = "Generating mock UI..."
	AgentBridge.mock_response()


func _on_clear_btn_pressed() -> void:
	UIManager.clear()
	status_label.text = "Panel cleared"
	_update_state_display()


func _on_request_btn_pressed() -> void:
	if AIChat and AIChat.is_connected:
		status_label.text = "Requesting AI UI..."
		AgentBridge.request_ui("control_panel")
	else:
		status_label.text = "Not connected to AI - go to Settings"
