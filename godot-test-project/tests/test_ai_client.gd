extends SceneTree
# Standalone test script for AI Chat addon

const AISettingsScript = preload("res://addons/ai_chat/ai_settings.gd")
const ChatHistoryScript = preload("res://addons/ai_chat/chat_history.gd")
const AIClientScript = preload("res://addons/ai_chat/ai_client.gd")

var tests_passed := 0
var tests_failed := 0


func _init():
	print("=== AI Client Unit Tests ===\n")
	_run_tests()
	quit()


func _run_tests():
	_test_settings()
	_test_chat_history()
	_test_client_creation()
	_print_results()


func _test_settings():
	print("[Test] Settings save/load...")

	# Create test settings
	var settings = AISettingsScript.new()
	settings.bridge_url = "http://test:9999"
	settings.default_host = "test.server"
	settings.default_username = "testuser"
	settings.preferred_ai_cli = "claude"
	settings.max_history_messages = 50

	# Save
	var err = settings.save_settings()
	if err != OK:
		print("  FAILED: Could not save settings (error %d)" % err)
		tests_failed += 1
		return

	# Load
	var loaded = AISettingsScript.load_settings()

	# Verify
	var passed = true
	if loaded.bridge_url != "http://test:9999":
		print("  FAILED: bridge_url mismatch")
		passed = false
	if loaded.default_host != "test.server":
		print("  FAILED: default_host mismatch")
		passed = false
	if loaded.default_username != "testuser":
		print("  FAILED: default_username mismatch")
		passed = false
	if loaded.preferred_ai_cli != "claude":
		print("  FAILED: preferred_ai_cli mismatch")
		passed = false
	if loaded.max_history_messages != 50:
		print("  FAILED: max_history_messages mismatch")
		passed = false

	if passed:
		print("  PASSED: Settings saved and loaded correctly")
		tests_passed += 1
	else:
		tests_failed += 1


func _test_chat_history():
	print("\n[Test] Chat history management...")

	var history = ChatHistoryScript.new()
	history.max_messages = 5

	# Add messages
	for i in range(10):
		history.add_user_message("User message %d" % i)
		history.add_assistant_message("Assistant message %d" % i)

	# Check history size
	var hist = history.get_history()
	if hist.size() != 5:
		print("  FAILED: Expected 5 messages, got %d" % hist.size())
		tests_failed += 1
		return

	# Check message order (should keep most recent)
	var last_msg = hist[hist.size() - 1]
	if not last_msg.content.contains("message 9"):
		print("  FAILED: Last message should be 'message 9'")
		tests_failed += 1
		return

	# Test clear
	history.clear()
	if history.get_history().size() != 0:
		print("  FAILED: History should be empty after clear")
		tests_failed += 1
		return

	print("  PASSED: Chat history works correctly")
	tests_passed += 1


func _test_client_creation():
	print("\n[Test] AIClient creation...")

	# Create with settings
	var settings = AISettingsScript.new()
	settings.bridge_url = "http://localhost:8000"
	settings.request_timeout = 60.0

	var client = AIClientScript.new(settings)

	# Verify properties
	if client.base_url != "http://localhost:8000":
		print("  FAILED: base_url not set from settings")
		tests_failed += 1
		return

	if client.session_id != "":
		print("  FAILED: session_id should be empty initially")
		tests_failed += 1
		return

	# Create without settings (should use defaults)
	var client2 = AIClientScript.new()
	if client2.base_url != "http://localhost:8000":
		print("  FAILED: default base_url incorrect")
		tests_failed += 1
		return

	print("  PASSED: AIClient created successfully")
	tests_passed += 1


func _print_results():
	print("\n" + "=".repeat(40))
	print("Results: %d passed, %d failed" % [tests_passed, tests_failed])
	if tests_failed == 0:
		print("ALL TESTS PASSED!")
	else:
		print("SOME TESTS FAILED")
	print("=".repeat(40))
