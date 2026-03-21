## Strategy Generator - Propose Improvements
##
## Generates improvement strategies based on pattern analysis.
## Creates actionable suggestions for enhancing performance.
##
## Usage:
##   var generator = StrategyGenerator.new(pattern_analyzer)
##   var strategies = generator.generate()
##   var best = generator.get_best_strategy()
##
class_name StrategyGenerator
extends RefCounted

## Reference to pattern analyzer
var analyzer: Variant

## Maximum strategies to generate
var max_strategies: int = 10

## Minimum confidence for strategy adoption
var adoption_threshold: float = 0.6

## Generated strategies cache
var _strategies: Array = []
var _last_generation_time: int = 0

## Cache duration in ms
var cache_duration: int = 30000

## Signal emitted when a new strategy is generated
signal strategy_generated(strategy: Dictionary)
## Signal emitted when a strategy is adopted
signal strategy_adopted(strategy_id: String)

func _init(analyzer_ref: Variant) -> void:
	analyzer = analyzer_ref

## Generate improvement strategies
## @returns Array of strategy dictionaries
func generate() -> Array:
	var current_time = Time.get_ticks_msec()

	# Use cache if recent
	if current_time - _last_generation_time < cache_duration and not _strategies.is_empty():
		return _strategies

	_strategies.clear()
	var analysis = analyzer.analyze()

	# Generate strategies from different sources
	_generate_tool_strategies(analysis)
	_generate_pattern_strategies(analysis)
	_generate_sequence_strategies(analysis)
	_generate_parameter_strategies(analysis)

	# Sort by potential impact
	_strategies.sort_custom(func(a, b): return a.potential_impact > b.potential_impact)

	# Limit strategies
	if _strategies.size() > max_strategies:
		_strategies = _strategies.slice(0, max_strategies)

	_last_generation_time = current_time
	return _strategies

## Generate strategies based on tool effectiveness
func _generate_tool_strategies(analysis: Dictionary) -> void:
	var tool_patterns = analysis.get("tool_patterns", [])

	for tp in tool_patterns:
		if tp.effectiveness == "low" and tp.uses >= 5:
			# Suggest avoiding or replacing this tool
			_strategies.append({
				"id": "avoid_tool_%s" % tp.tool,
				"type": "tool_avoidance",
				"tool": tp.tool,
				"description": "Avoid using %s (success rate: %.1f%%)" % [tp.tool, tp.success_rate * 100],
				"rationale": "This tool has a low success rate over %d uses" % tp.uses,
				"potential_impact": (1.0 - tp.success_rate) * tp.uses,
				"confidence": min(float(tp.uses) / 10.0, 1.0),
				"actionable": true
			})

		elif tp.effectiveness == "high" and tp.uses >= 3:
			# Suggest preferring this tool
			_strategies.append({
				"id": "prefer_tool_%s" % tp.tool,
				"type": "tool_preference",
				"tool": tp.tool,
				"description": "Prefer using %s (success rate: %.1f%%)" % [tp.tool, tp.success_rate * 100],
				"rationale": "This tool has a high success rate",
				"potential_impact": tp.success_rate * 0.5,
				"confidence": min(float(tp.uses) / 5.0, 1.0),
				"actionable": true
			})

## Generate strategies based on success/failure patterns
func _generate_pattern_strategies(analysis: Dictionary) -> void:
	var failure_patterns = analysis.get("failure_patterns", [])
	var success_patterns = analysis.get("success_patterns", [])

	# Strategies to avoid failure patterns
	for fp in failure_patterns:
		_strategies.append({
			"id": "avoid_pattern_%d" % _strategies.size(),
			"type": "pattern_avoidance",
			"pattern": fp.signature,
			"description": "Avoid pattern: %s" % fp.signature,
			"rationale": "This pattern has %.1f%% failure rate (%d occurrences)" % [
				fp.failure_rate * 100, fp.count
			],
			"potential_impact": fp.failure_rate * fp.count,
			"confidence": min(float(fp.count) / 10.0, 1.0),
			"actionable": true,
			"alternative_actions": _suggest_alternatives(fp)
		})

	# Strategies to adopt success patterns
	for sp in success_patterns:
		_strategies.append({
			"id": "adopt_pattern_%d" % _strategies.size(),
			"type": "pattern_adoption",
			"pattern": sp.signature,
			"description": "Adopt pattern: %s" % sp.signature,
			"rationale": "This pattern has %.1f%% success rate" % [sp.success_rate * 100],
			"potential_impact": sp.success_rate * 0.3,
			"confidence": min(float(sp.count) / 5.0, 1.0),
			"actionable": true
		})

## Generate strategies based on sequence patterns
func _generate_sequence_strategies(analysis: Dictionary) -> void:
	var sequence_patterns = analysis.get("sequence_patterns", [])

	for seq in sequence_patterns:
		if seq.count >= 5:
			if seq.success_rate_after > 0.8:
				_strategies.append({
					"id": "sequence_%d" % _strategies.size(),
					"type": "sequence_recommendation",
					"transition": seq.transition,
					"description": "Prefer sequence: %s" % seq.transition,
					"rationale": "%.1f%% success rate after this transition" % [seq.success_rate_after * 100],
					"potential_impact": seq.success_rate_after * 0.2,
					"confidence": min(float(seq.count) / 10.0, 1.0),
					"actionable": true
				})
			elif seq.success_rate_after < 0.4:
				_strategies.append({
					"id": "avoid_sequence_%d" % _strategies.size(),
					"type": "sequence_avoidance",
					"transition": seq.transition,
					"description": "Avoid sequence: %s" % seq.transition,
					"rationale": "Only %.1f%% success rate after this transition" % [seq.success_rate_after * 100],
					"potential_impact": (1.0 - seq.success_rate_after) * 0.2,
					"confidence": min(float(seq.count) / 10.0, 1.0),
					"actionable": true
				})

## Generate strategies based on parameter tuning
func _generate_parameter_strategies(analysis: Dictionary) -> void:
	# Analyze if certain parameters lead to better outcomes
	var tool_patterns = analysis.get("tool_patterns", [])

	# Group tools by type to find parameter patterns
	var tool_groups: Dictionary = {}
	for tp in tool_patterns:
		var base_name = tp.tool.split("_")[0]
		if not tool_groups.has(base_name):
			tool_groups[base_name] = []
		tool_groups[base_name].append(tp)

	for base in tool_groups:
		var variants = tool_groups[base]
		if variants.size() >= 2:
			# Find best variant
			var best = variants[0]
			for v in variants:
				if v.success_rate > best.success_rate:
					best = v

			if best.success_rate > 0.7:
				_strategies.append({
					"id": "param_%s_%s" % [base, best.tool.split("_")[1] if "_" in best.tool else "default"],
					"type": "parameter_tuning",
					"tool_family": base,
					"recommended_variant": best.tool,
					"description": "Use %s variant for %s operations" % [best.tool.split("_")[1] if "_" in best.tool else "default", base],
					"rationale": "%.1f%% success rate vs average of %.1f%%" % [
						best.success_rate * 100,
						_average_success_rate(variants) * 100
					],
					"potential_impact": best.success_rate - _average_success_rate(variants),
					"confidence": 0.5,
					"actionable": true
				})

## Calculate average success rate
func _average_success_rate(variants: Array) -> float:
	var total: float = 0.0
	for v in variants:
		total += v.success_rate
	return total / float(variants.size())

## Suggest alternatives to a failure pattern
func _suggest_alternatives(failure_pattern: Dictionary) -> Array:
	var alternatives: Array = []

	# Check success patterns for similar tasks
	var analysis = analyzer.analyze()
	var success_patterns = analysis.get("success_patterns", [])

	for sp in success_patterns:
		# Look for patterns with similar tools but different approaches
		if _pattern_similarity(failure_pattern.signature, sp.signature) > 0.3:
			alternatives.append({
				"pattern": sp.signature,
				"success_rate": sp.success_rate,
				"description": "Try pattern: %s" % sp.signature
			})

	return alternatives

## Calculate pattern similarity
func _pattern_similarity(sig1: String, sig2: String) -> float:
	var parts1 = sig1.split("|")
	var parts2 = sig2.split("|")

	var common = 0
	var total = max(parts1.size(), parts2.size())

	for p in parts1:
		if p in parts2:
			common += 1

	return float(common) / float(total) if total > 0 else 0.0

## Get the best strategy (highest potential impact)
func get_best_strategy() -> Dictionary:
	var strategies = generate()
	if strategies.is_empty():
		return {}
	return strategies[0]

## Get strategies above adoption threshold
func get_adoptable_strategies() -> Array:
	var strategies = generate()
	var adoptable: Array = []
	for s in strategies:
		if s.confidence >= adoption_threshold:
			adoptable.append(s)
	return adoptable

## Adopt a strategy (mark as accepted)
func adopt_strategy(strategy_id: String) -> bool:
	for s in _strategies:
		if s.id == strategy_id:
			s.adopted = true
			strategy_adopted.emit(strategy_id)
			return true
	return false

## Get strategies by type
func get_strategies_by_type(type: String) -> Array:
	var strategies = generate()
	var filtered: Array = []
	for s in strategies:
		if s.type == type:
			filtered.append(s)
	return filtered

## Convert strategies to prompt block for AI
func to_prompt_block() -> String:
	var strategies = generate()
	var lines: Array = []
	lines.append("=== STRATEGY RECOMMENDATIONS ===")

	if strategies.is_empty():
		lines.append("(no strategies generated)")
		return "\n".join(lines)

	for i in range(strategies.size()):
		var s = strategies[i]
		var marker = "*" if s.get("adopted", false) else " "
		lines.append("%s %d. [%s] %s" % [marker, i + 1, s.type, s.description])
		lines.append("    Impact: %.2f, Confidence: %.0f%%" % [s.potential_impact, s.confidence * 100])
		lines.append("    Rationale: %s" % s.rationale)

	return "\n".join(lines)

## Export to dictionary
func to_dict() -> Dictionary:
	return {
		"max_strategies": max_strategies,
		"adoption_threshold": adoption_threshold,
		"strategies": _strategies.duplicate(true),
		"last_generation_time": _last_generation_time
	}

## Load from dictionary
static func from_dict(data: Dictionary, analyzer_ref: Variant) -> Variant:
	var script = preload("res://addons/awr/self_improvement/strategy_generator.gd")
	var sg = script.new(analyzer_ref)
	sg.max_strategies = data.get("max_strategies", 10)
	sg.adoption_threshold = data.get("adoption_threshold", 0.6)
	sg._strategies = data.get("strategies", []).duplicate(true)
	sg._last_generation_time = data.get("last_generation_time", 0)
	return sg
