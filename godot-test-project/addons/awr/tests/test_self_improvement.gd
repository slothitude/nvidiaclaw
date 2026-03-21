## Test Self-Improvement System and The Crypt
##
## Tests for Performance Monitor, Pattern Analyzer, Strategy Generator, Validator, and Crypt
##
extends SceneTree

const PerformanceMonitorScript = preload("res://addons/awr/self_improvement/performance_monitor.gd")
const PatternAnalyzerScript = preload("res://addons/awr/self_improvement/pattern_analyzer.gd")
const StrategyGeneratorScript = preload("res://addons/awr/self_improvement/strategy_generator.gd")
const ValidatorScript = preload("res://addons/awr/self_improvement/validator.gd")
const TheCryptScript = preload("res://addons/awr/crypt/crypt.gd")
const BloodlineScript = preload("res://addons/awr/crypt/bloodline.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func _init() -> void:
	print("=== Testing Self-Improvement System and Crypt ===")
	print("")

	# Performance Monitor tests
	test_performance_monitor()

	# Pattern Analyzer tests
	test_pattern_analyzer()

	# Strategy Generator tests
	test_strategy_generator()

	# Validator tests
	test_validator()

	# Bloodline tests
	test_bloodline()

	# Crypt tests
	test_crypt()

	print("")
	print("=== Self-Improvement Tests Complete ===")
	print("Passed: %d, Failed: %d" % [tests_passed, tests_failed])

	quit(0 if tests_failed == 0 else 1)

# ============================================================
# PERFORMANCE MONITOR TESTS
# ============================================================

func test_performance_monitor() -> void:
	print("--- Testing Performance Monitor ---")

	# Test creation
	var pm = PerformanceMonitorScript.new()
	assert_true(pm != null, "Performance monitor creation")

	# Test record task
	pm.record_task("task_1", true, 1, ["tool_a"])
	pm.record_task("task_2", false, 3, ["tool_b", "tool_c"])
	pm.record_task("task_3", true, 1, ["tool_a"])
	assert_equal(pm.task_history.size(), 3, "Tasks recorded")

	# Test success rate
	var rate = pm.get_success_rate(60000)
	assert_true(rate > 0.5, "Success rate calculated: %.2f" % rate)

	# Test average attempts
	var avg_attempts = pm.get_average_attempts(60000)
	assert_true(avg_attempts >= 1.0, "Average attempts calculated: %.2f" % avg_attempts)

	# Test start/end task (no await - just record directly)
	pm.start_task("timed_task")
	pm.end_task("timed_task", true, 1, ["tool_d"])
	assert_equal(pm.task_history.size(), 4, "Timed task recorded")

	# Test tool stats
	var stats = pm.get_tool_stats(60000)
	assert_true(stats.has("tool_a"), "Tool stats tracked")
	assert_equal(stats.tool_a.uses, 2, "Tool uses counted")

	# Test recent failures
	var failures = pm.get_recent_failures()
	assert_equal(failures.size(), 1, "Failures tracked")

	# Test degradation detection (need more data)
	for i in range(20):
		pm.record_task("task_%d" % i, i < 10, 1, ["tool_a"])

	# Test serialization
	var data = pm.to_dict()
	var loaded = PerformanceMonitorScript.from_dict(data)
	assert_equal(loaded.task_history.size(), pm.task_history.size(), "Serialization preserves history")

	print("  Performance Monitor: PASS")

# ============================================================
# PATTERN ANALYZER TESTS
# ============================================================

func test_pattern_analyzer() -> void:
	print("--- Testing Pattern Analyzer ---")

	# Create monitor with data
	var pm = PerformanceMonitorScript.new()
	for i in range(30):
		var success = i % 3 != 0  # 66% success rate
		pm.record_task("task_%d" % i, success, 1 + (i % 3), ["tool_%s" % ("a" if i % 2 == 0 else "b")])

	# Test creation
	var pa = PatternAnalyzerScript.new(pm)
	assert_true(pa != null, "Pattern analyzer creation")

	# Test analysis
	var analysis = pa.analyze()
	assert_true(analysis.has("success_patterns"), "Analysis has success patterns")
	assert_true(analysis.has("failure_patterns"), "Analysis has failure patterns")
	assert_true(analysis.has("tool_patterns"), "Analysis has tool patterns")

	# Test tool patterns
	var tool_patterns = analysis.tool_patterns
	assert_true(tool_patterns.size() > 0, "Tool patterns found")

	# Test get methods
	var success = pa.get_success_patterns()
	var failure = pa.get_failure_patterns()
	assert_true(success is Array, "Success patterns retrievable")
	assert_true(failure is Array, "Failure patterns retrievable")

	# Test recommendations
	var recommendations = pa.get_recommendations()
	assert_true(recommendations is Array, "Recommendations generated")

	# Test prompt block
	var prompt = pa.to_prompt_block()
	assert_true(prompt.contains("PATTERN ANALYSIS"), "Prompt block contains header")

	# Test serialization
	var data = pa.to_dict()
	assert_true(data.has("patterns"), "Serialization preserves patterns")

	print("  Pattern Analyzer: PASS")

# ============================================================
# STRATEGY GENERATOR TESTS
# ============================================================

func test_strategy_generator() -> void:
	print("--- Testing Strategy Generator ---")

	# Create dependencies
	var pm = PerformanceMonitorScript.new()
	for i in range(20):
		pm.record_task("task_%d" % i, i % 2 == 0, 1, ["tool_a" if i % 2 == 0 else "tool_b"])

	var pa = PatternAnalyzerScript.new(pm)

	# Test creation
	var sg = StrategyGeneratorScript.new(pa)
	assert_true(sg != null, "Strategy generator creation")

	# Test generate
	var strategies = sg.generate()
	assert_true(strategies is Array, "Strategies generated")

	# Test best strategy
	var best = sg.get_best_strategy()
	if not best.is_empty():
		assert_true(best.has("type"), "Best strategy has type")
		assert_true(best.has("description"), "Best strategy has description")

	# Test adoptable strategies
	var adoptable = sg.get_adoptable_strategies()
	assert_true(adoptable is Array, "Adoptable strategies filtered")

	# Test get by type
	if strategies.size() > 0:
		var by_type = sg.get_strategies_by_type(strategies[0].type)
		assert_true(by_type.size() > 0, "Strategies filterable by type")

	# Test prompt block
	var prompt = sg.to_prompt_block()
	assert_true(prompt.contains("STRATEGY"), "Prompt block contains header")

	# Test serialization
	var data = sg.to_dict()
	assert_true(data.has("strategies"), "Serialization preserves strategies")

	print("  Strategy Generator: PASS")

# ============================================================
# VALIDATOR TESTS
# ============================================================

func test_validator() -> void:
	print("--- Testing Validator ---")

	# Create dependencies
	var pm = PerformanceMonitorScript.new()
	for i in range(10):
		pm.record_task("task_%d" % i, true, 1, ["tool_a"])

	# Test creation
	var v = ValidatorScript.new(pm)
	assert_true(v != null, "Validator creation")

	# Test quick validate
	var strategy = {"id": "test_strategy", "type": "tool_preference", "confidence": 0.8}
	var quick_result = v.quick_validate(strategy)
	assert_true(quick_result.has("valid"), "Quick validation works")
	assert_true(quick_result.has("risk_level"), "Risk level assessed")

	# Test full validation with mock test function
	var test_func = func(s): return true  # Always succeeds
	var result = v.validate_strategy(strategy, test_func)
	assert_true(result.has("valid"), "Validation has valid field")
	assert_true(result.has("improvement"), "Validation has improvement field")

	# Test approve
	if result.valid:
		var approved = v.approve(strategy.id)
		assert_true(approved, "Strategy approved")
		assert_true(v.is_approved(strategy.id), "Approval tracked")

	# Test reject
	v.reject("bad_strategy", "Test rejection")
	assert_true(v.is_rejected("bad_strategy"), "Rejection tracked")

	# Test summary
	var summary = v.get_summary()
	assert_true(summary.has("total_validated"), "Summary has total")
	assert_true(summary.has("approved"), "Summary has approved")

	# Test prompt block
	var prompt = v.to_prompt_block()
	assert_true(prompt.contains("VALIDATION"), "Prompt block contains header")

	# Test serialization
	var data = v.to_dict()
	assert_true(data.has("approved"), "Serialization preserves approved")

	print("  Validator: PASS")

# ============================================================
# BLOODLINE TESTS
# ============================================================

func test_bloodline() -> void:
	print("--- Testing Bloodline ---")

	# Test creation
	var b = BloodlineScript.new("test_bloodline", "Test bloodline description")
	assert_true(b != null, "Bloodline creation")
	assert_equal(b.name, "test_bloodline", "Name set correctly")
	assert_equal(b.description, "Test bloodline description", "Description set correctly")

	# Test add lesson
	b.add_lesson("lesson_1", "Always check for obstacles", 0.9)
	b.add_lesson("lesson_2", "Prefer shorter paths", 0.8)
	b.add_lesson("lesson_3", "Avoid dead ends", 0.7)
	assert_equal(b.lessons.size(), 3, "Lessons added")

	# Test get lesson
	var lesson = b.get_lesson("lesson_1")
	assert_true(lesson != null, "Lesson retrieved")
	assert_equal(lesson.wisdom, "Always check for obstacles", "Lesson wisdom correct")

	# Test sorted lessons
	var sorted = b.get_sorted_lessons()
	assert_equal(sorted[0].confidence >= sorted[sorted.size() - 1].confidence, true, "Lessons sorted by confidence")

	# Test record success/failure
	b.record_success("lesson_1")
	assert_true(b.get_lesson("lesson_1").success_count > 0, "Success recorded")

	b.record_failure("lesson_3")
	assert_true(b.get_lesson("lesson_3").failure_count > 0, "Failure recorded")
	assert_true(b.get_lesson("lesson_3").confidence < 0.7, "Failure reduces confidence")

	# Test relevant lessons
	var relevant = b.get_relevant_lessons({"lesson_1": "value"}, 0.5)
	assert_true(relevant is Array, "Relevant lessons retrieved")

	# Test tags
	b.add_tag("navigation")
	b.add_tag("movement")
	assert_true(b.has_tag("navigation"), "Tag added")
	b.remove_tag("movement")
	assert_false(b.has_tag("movement"), "Tag removed")

	# Test stats
	var stats = b.get_stats()
	assert_equal(stats.name, "test_bloodline", "Stats name correct")
	assert_equal(stats.lesson_count, 3, "Stats lesson count correct")

	# Test prompt block
	var prompt = b.to_prompt_block()
	assert_true(prompt.contains("test_bloodline".to_upper()), "Prompt block contains name")
	assert_true(prompt.contains("TOP LESSONS"), "Prompt block has lessons")

	# Test serialization
	var data = b.to_dict()
	var loaded = BloodlineScript.from_dict(data)
	assert_equal(loaded.name, b.name, "Serialization preserves name")
	assert_equal(loaded.lessons.size(), b.lessons.size(), "Serialization preserves lessons")

	print("  Bloodline: PASS")

# ============================================================
# CRYPT TESTS
# ============================================================

func test_crypt() -> void:
	print("--- Testing The Crypt ---")

	# Test creation
	var crypt = TheCryptScript.new()
	assert_true(crypt != null, "Crypt creation")

	# Test default bloodlines
	assert_true(crypt.bloodlines.has("navigation"), "Navigation bloodline exists")
	assert_true(crypt.bloodlines.has("physics"), "Physics bloodline exists")
	assert_true(crypt.bloodlines.has("strategy"), "Strategy bloodline exists")

	# Test create bloodline
	var custom = crypt.create_bloodline("custom", "Custom bloodline")
	assert_true(crypt.bloodlines.has("custom"), "Custom bloodline created")

	# Test entomb
	crypt.entomb("session_1", "navigate_to_goal", {"success": true, "attempts": 1, "tools": ["path_finder"]})
	assert_true(crypt.session_archive.has("session_1"), "Session archived")

	# Test extract lesson
	var lesson = crypt.extract_lesson({"success": true, "attempts": 1, "tools": ["tool_a"]})
	assert_true(lesson.has("wisdom"), "Lesson has wisdom")
	assert_true(lesson.has("confidence"), "Lesson has confidence")

	# Test record death
	crypt.record_death("session_2", "navigate_to_goal", {"success": false, "reason": "collision", "attempts": 3})
	assert_equal(crypt.deaths.size(), 1, "Death recorded")

	# Test inherit
	var wisdom = crypt.inherit("navigation")
	assert_true(wisdom is Array, "Wisdom inherited")

	# Test inherit all
	var all_wisdom = crypt.inherit_all()
	assert_true(all_wisdom is Dictionary, "All wisdom inherited")

	# Test track innovation
	crypt.track_innovation("approach_1", "", "Original approach")
	crypt.track_innovation("approach_2", "approach_1", "Improved approach")
	assert_true(crypt.innovations.has("approach_1"), "Innovation tracked")

	# Test innovation genealogy
	var genealogy = crypt.get_innovation_genealogy("approach_2")
	assert_equal(genealogy.size(), 2, "Genealogy traced")

	# Test death patterns
	crypt.record_death("session_3", "task_1", {"success": false, "reason": "timeout"})
	crypt.record_death("session_4", "task_2", {"success": false, "reason": "timeout"})
	var patterns = crypt.analyze_death_patterns()
	assert_true(patterns.has("timeout"), "Death patterns analyzed")

	# Test get guidance
	var guidance = crypt.get_guidance("navigate_to_goal")
	assert_true(guidance is Array, "Guidance retrieved")

	# Test stats
	var stats = crypt.get_stats()
	assert_true(stats.has("bloodline_count"), "Stats has bloodline count")
	assert_true(stats.has("death_count"), "Stats has death count")

	# Test prompt block
	var prompt = crypt.to_prompt_block()
	assert_true(prompt.contains("THE CRYPT"), "Prompt block contains header")
	assert_true(prompt.contains("BLOODLINES"), "Prompt block has bloodlines")

	# Test serialization
	var data = crypt.to_dict()
	var loaded = TheCryptScript.from_dict(data)
	assert_equal(loaded.bloodlines.size(), crypt.bloodlines.size(), "Serialization preserves bloodlines")
	assert_equal(loaded.deaths.size(), crypt.deaths.size(), "Serialization preserves deaths")

	print("  The Crypt: PASS")

# ============================================================
# ASSERTION HELPERS
# ============================================================

func assert_true(condition: bool, message: String) -> void:
	if condition:
		tests_passed += 1
	else:
		tests_failed += 1
		print("    FAILED: %s" % message)

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		tests_passed += 1
	else:
		tests_failed += 1
		print("    FAILED: %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])

func assert_not_equal(actual, expected, message: String) -> void:
	if actual != expected:
		tests_passed += 1
	else:
		tests_failed += 1
		print("    FAILED: %s (values were equal: %s)" % [message, str(actual)])
