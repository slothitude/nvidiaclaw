## AWR Test Runner - Run all tests
##
## Run with: godot --headless --path . -s addons/awr/tests/run_all_tests.gd
extends SceneTree

var _total_passed: int = 0
var _total_failed: int = 0

func _init():
	print("\n" + "=".repeat(70))
	print("AWR COMPLETE TEST SUITE")
	print("=".repeat(70) + "\n")

	var test_files = [
		"res://addons/awr/tests/test_sim_loop.gd",
		"res://addons/awr/tests/test_collision.gd",
		"res://addons/awr/tests/test_causal_bus.gd",
		"res://addons/awr/tests/test_perception.gd"
	]

	for test_file in test_files:
		var script = load(test_file)
		if script:
			print("\n--- Running %s ---" % test_file.get_file())
			var instance = script.new()
			# Tests run in _init, so we just need to load it
		else:
			print("  [ERROR] Could not load %s" % test_file)
			_total_failed += 1

	# Run ultimate test separately (it takes longer)
	print("\n--- Running test_gravity_slingshot.gd ---")
	var gravity_script = load("res://addons/awr/tests/test_gravity_slingshot.gd")
	if gravity_script:
		var gravity_instance = gravity_script.new()

	print("\n" + "=".repeat(70))
	print("ALL TESTS COMPLETE")
	print("=".repeat(70))

	quit(0 if _total_failed == 0 else 1)
