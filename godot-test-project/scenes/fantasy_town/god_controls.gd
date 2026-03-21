## god_controls.gd - Quick GOD Controls Panel
## Part of Fantasy Town World-Breaking Demo
##
## Provides quick access buttons for common divine actions:
## - Ring Bell
## - Bless Agents (give gold)
## - Quick Decree
## - Time display
## - Divine Favor bar

class_name GodControls
extends Control

## Signals
signal bell_rung()
signal agents_blessed(amount: int)
signal decree_issued(decree: String)

## References
var _divine_system: Node = null
var _nanobot_orchestrator: Node = null
var _task_economy: Node = null

## UI Elements
var _panel: PanelContainer = null
var _time_label: Label = null
var _favor_bar: ProgressBar = null
var _bell_button: Button = null
var _bless_button: Button = null
var _decree_input: LineEdit = null
var _send_decree_button: Button = null
var _agent_count_label: Label = null
var _gold_label: Label = null

## Blessing amount
var _bless_amount: int = 50


func _ready() -> void:
	_create_ui()
	print("[GOD] Controls panel ready")


func _create_ui() -> void:
	# Anchor to top-right corner
	anchor_left = 0.75
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_top = 10
	offset_bottom = 250
	offset_left = 10
	offset_right = -10

	# Create main panel
	_panel = PanelContainer.new()
	_panel.name = "GodControlsPanel"
	add_child(_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.7, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "GOD CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	vbox.add_child(title)

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Time display
	_time_label = Label.new()
	_time_label.text = "Day 1 - 06:00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_time_label)

	# Agent count
	_agent_count_label = Label.new()
	_agent_count_label.text = "Agents: 0"
	_agent_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_agent_count_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	vbox.add_child(_agent_count_label)

	# Gold display
	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	vbox.add_child(_gold_label)

	# Divine Favor bar
	var favor_label = Label.new()
	favor_label.text = "Divine Favor"
	favor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(favor_label)

	_favor_bar = ProgressBar.new()
	_favor_bar.min_value = 0
	_favor_bar.max_value = 100
	_favor_bar.value = 100
	_favor_bar.show_percentage = false
	vbox.add_child(_favor_bar)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Bell button
	_bell_button = Button.new()
	_bell_button.text = "Ring Bell"
	_bell_button.tooltip_text = "Ring the divine bell to gather agents at temples"
	_bell_button.pressed.connect(_on_ring_bell)
	vbox.add_child(_bell_button)

	# Bless button
	_bless_button = Button.new()
	_bless_button.text = "Bless Agents (+%d gold)" % _bless_amount
	_bless_button.tooltip_text = "Give gold to all agents"
	_bless_button.pressed.connect(_on_bless_agents)
	vbox.add_child(_bless_button)

	# Quick decree input
	_decree_input = LineEdit.new()
	_decree_input.placeholder_text = "Quick decree..."
	_decree_input.tooltip_text = "Enter a divine command"
	_decree_input.text_submitted.connect(_on_decree_submitted)
	vbox.add_child(_decree_input)

	_send_decree_button = Button.new()
	_send_decree_button.text = "Issue Decree"
	_send_decree_button.pressed.connect(_on_issue_decree)
	vbox.add_child(_send_decree_button)


func setup(divine_system: Node, nanobot_orchestrator: Node, task_economy: Node = null) -> void:
	_divine_system = divine_system
	_nanobot_orchestrator = nanobot_orchestrator
	_task_economy = task_economy


func _process(_delta: float) -> void:
	_update_display()


func _update_display() -> void:
	if _divine_system:
		var time = _divine_system.get_game_time()
		_time_label.text = "Day %d - %02d:%02d" % [time.day, time.hour, time.minute]

		var status = _divine_system.get_divine_status()
		_favor_bar.value = status.favor

	if _nanobot_orchestrator:
		var agent_ids = _nanobot_orchestrator.get_agent_ids()
		_agent_count_label.text = "Agents: %d" % agent_ids.size()

	if _task_economy:
		var stats = _task_economy.get_economy_stats()
		_gold_label.text = "Gold: %d" % stats.total_gold_in_circulation


func _on_ring_bell() -> void:
	if _divine_system:
		_divine_system._ring_bell("manual", "Divine Bell")
		print("[GOD] Bell rung!")
		bell_rung.emit()


func _on_bless_agents() -> void:
	print("[GOD] Blessing all agents with %d gold!" % _bless_amount)

	# Give gold to all agents via task economy
	if _task_economy:
		var agent_ids = []
		if _nanobot_orchestrator:
			agent_ids = _nanobot_orchestrator.get_agent_ids()

		for agent_id in agent_ids:
			# Create a blessing task that gives gold
			_task_economy.create_task("blessing", "Divine Blessing", 10, _bless_amount, agent_id)

	agents_blessed.emit(_bless_amount)


func _on_decree_submitted(text: String) -> void:
	_issue_decree(text)


func _on_issue_decree() -> void:
	_issue_decree(_decree_input.text)


func _issue_decree(text: String) -> void:
	var decree = text.strip_edges()
	if decree.is_empty():
		return

	if _divine_system:
		_divine_system.issue_divine_command(decree, 5, 50)

	# Also broadcast via nanobot orchestrator for immediate agent notification
	if _nanobot_orchestrator:
		_nanobot_orchestrator.broadcast_divine_command(decree)

	decree_issued.emit(decree)
	_decree_input.text = ""

	print("[GOD] Decree issued: %s" % decree)


## Set blessing amount
func set_bless_amount(amount: int) -> void:
	_bless_amount = amount
	_bless_button.text = "Bless Agents (+%d gold)" % _bless_amount


## Show/hide the panel
func toggle_visibility() -> void:
	visible = not visible
