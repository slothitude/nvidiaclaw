extends SceneTree

## Test that simulates the main scene connection flow
## Uses callback pattern like test_connect.gd

var _main: Control = null
var _timeout_seconds: float = 45.0

func _init():
	print("=== Main Connect Test ===")

func _initialize():
	# Load the main scene
	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()

	# Add to tree
	root.add_child(_main)

	print("[Test] Main scene loaded")

	# Use deferred call to wait for scene to be ready
	_do_test.call_deferred()

func _do_test():
	print("[Test] _do_test executing (deferred)")
	print("[Test] Checking client...")

	# Populate input fields with test values
	print("[Test] Setting input values...")
	_main.host_input.text = "192.168.0.237"
	_main.username_input.text = "az"
	_main.password_input.text = "7243"
	# Set AI CLI to goose (index 2)
	_main.ai_cli_option.selected = 2
	print("[Test] Input values set")

	# Connect to client signals to track response
	if _main.client:
		_main.client.connected.connect(_on_connected)
		_main.client.error_occurred.connect(_on_error)
		print("[Test] Connected to client signals")
		print("[Test] Client parent_node: ", _main.client._parent_node)
		print("[Test] Client is valid: ", is_instance_valid(_main.client))
	else:
		print("[Test] ERROR: No client found!")
		quit()
		return

	# Simulate button press
	print("[Test] Simulating connect button press...")
	_main._on_connect_btn_pressed()
	print("[Test] Button press complete, waiting for response...")
	print("[Test] (Timeout: ", _timeout_seconds, "s)")

	# Set up timeout using a timer node
	var timer = Timer.new()
	timer.wait_time = _timeout_seconds
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	root.add_child(timer)
	timer.start()

func _on_connected(session_id: String, ai_cli: String):
	print("[Test] ========== CONNECTED ==========")
	print("[Test] Session ID: ", session_id)
	print("[Test] AI CLI: ", ai_cli)
	print("[Test] Test complete - SUCCESS!")
	quit()

func _on_error(error: String):
	print("[Test] ========== ERROR ==========")
	print("[Test] Error: ", error)
	print("[Test] Test complete - FAILED!")
	quit()

func _on_timeout():
	print("[Test] ========== TIMEOUT ==========")
	print("[Test] No response received within ", _timeout_seconds, " seconds")
	print("[Test] Test complete - TIMEOUT!")
	quit()
