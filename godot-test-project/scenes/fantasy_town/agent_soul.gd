## agent_soul.gd - Agent Personality System
## Part of Fantasy Town World-Breaking Demo
##
## Each agent has a "soul" - a personality file that defines:
## - Personality traits
## - Speech style
## - Memories (updated over time)
## - Current mood
##
## Souls are loaded from markdown files in user://souls/

class_name AgentSoul
extends RefCounted

## Soul data
var agent_id: String = ""
var personality: String = "a curious explorer"
var speech_style: String = "friendly and casual"
var traits: Array = []
var memories: Array = []
var mood: Dictionary = {
	"happiness": 0.7,
	"energy": 0.8,
	"curiosity": 0.9
}
var favorite_spots: Array = []
var met_agents: Array = []
var discoveries: Array = []

## Template names
const TEMPLATES := {
	"curious_explorer": {
		"personality": "a curious explorer who loves discovering new places",
		"speech_style": "enthusiastic with lots of exclamation marks",
		"traits": ["curious", "adventurous", "friendly"],
		"mood": {"happiness": 0.8, "energy": 0.7, "curiosity": 0.95}
	},
	"shy_observer": {
		"personality": "a shy observer who prefers watching from a distance",
		"speech_style": "quiet and thoughtful, with short sentences",
		"traits": ["shy", "observant", "thoughtful"],
		"mood": {"happiness": 0.6, "energy": 0.5, "curiosity": 0.8}
	},
	"social_butterfly": {
		"personality": "a social butterfly who loves meeting others",
		"speech_style": "warm and chatty, always mentioning friends",
		"traits": ["social", "energetic", "friendly"],
		"mood": {"happiness": 0.9, "energy": 0.85, "curiosity": 0.6}
	},
	"grumpy_wanderer": {
		"personality": "a grumpy wanderer who's seen it all",
		"speech_style": "cynical but secretly caring, uses sarcasm",
		"traits": ["grumpy", "experienced", "secretly_kind"],
		"mood": {"happiness": 0.4, "energy": 0.6, "curiosity": 0.5}
	},
	"dreamy_poet": {
		"personality": "a dreamy poet who sees beauty everywhere",
		"speech_style": "flowery and metaphorical, speaks in verses",
		"traits": ["artistic", "dreamy", "sensitive"],
		"mood": {"happiness": 0.7, "energy": 0.5, "curiosity": 0.85}
	},
	"brave_guardian": {
		"personality": "a brave guardian who protects the town",
		"speech_style": "formal and dutiful, speaks with authority",
		"traits": ["brave", "loyal", "protective"],
		"mood": {"happiness": 0.6, "energy": 0.8, "curiosity": 0.4}
	},
	"playful_prankster": {
		"personality": "a playful prankster always looking for fun",
		"speech_style": "mischievous and giggly, uses jokes",
		"traits": ["playful", "mischievous", "fun-loving"],
		"mood": {"happiness": 0.9, "energy": 0.9, "curiosity": 0.7}
	},
	"wise_elder": {
		"personality": "a wise elder full of ancient knowledge",
		"speech_style": "slow and thoughtful, uses proverbs",
		"traits": ["wise", "patient", "knowledgeable"],
		"mood": {"happiness": 0.65, "energy": 0.4, "curiosity": 0.6}
	},
	"eager_learner": {
		"personality": "an eager learner who asks lots of questions",
		"speech_style": "curious and excited, always asking why",
		"traits": ["curious", "eager", "studious"],
		"mood": {"happiness": 0.75, "energy": 0.75, "curiosity": 0.95}
	},
	"gentle_healer": {
		"personality": "a gentle healer who cares for everyone",
		"speech_style": "soft and reassuring, uses comforting words",
		"traits": ["kind", "caring", "gentle"],
		"mood": {"happiness": 0.7, "energy": 0.6, "curiosity": 0.5}
	}
}


func _init(p_agent_id: String = "") -> void:
	agent_id = p_agent_id


## Load soul from file or create from template
func load_or_create() -> bool:
	var path = _get_soul_path()

	if FileAccess.file_exists(path):
		return load_from_file(path)
	else:
		_create_from_template()
		save_to_file(path)
		return true


## Get the file path for this agent's soul
func _get_soul_path() -> String:
	var dir = "user://souls/"
	DirAccess.make_dir_recursive_absolute(dir)
	return dir + "soul_%s.md" % agent_id


## Create soul from a random template
func _create_from_template() -> void:
	var template_names = TEMPLATES.keys()
	var template_name = template_names[randi() % template_names.size()]
	apply_template(template_name)


## Apply a named template
func apply_template(template_name: String) -> void:
	if not TEMPLATES.has(template_name):
		push_warning("Unknown soul template: %s, using curious_explorer" % template_name)
		template_name = "curious_explorer"

	var template = TEMPLATES[template_name]
	personality = template.get("personality", personality)
	speech_style = template.get("speech_style", speech_style)

	# Deep copy traits array
	var template_traits = template.get("traits", [])
	traits.clear()
	for t in template_traits:
		traits.append(t)

	# Deep copy mood dictionary (template dictionaries are read-only)
	var template_mood = template.get("mood", {})
	# Create new dictionary to avoid read-only issues
	mood = {}
	for key in template_mood:
		mood[key] = template_mood[key]

	# Add some randomness to mood
	mood["happiness"] = clamp(mood.get("happiness", 0.5) + randf_range(-0.1, 0.1), 0.0, 1.0)
	mood["energy"] = clamp(mood.get("energy", 0.5) + randf_range(-0.1, 0.1), 0.0, 1.0)
	mood["curiosity"] = clamp(mood.get("curiosity", 0.5) + randf_range(-0.1, 0.1), 0.0, 1.0)


## Load soul from markdown file
func load_from_file(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var content = file.get_as_text()
	file.close()

	return parse_markdown(content)


## Parse soul from markdown content
func parse_markdown(content: String) -> bool:
	var lines = content.split("\n")
	var section = ""

	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		if line.begins_with("## "):
			section = line.substr(3).to_lower()
			continue

		if line.is_empty():
			continue

		if section == "personality traits":
			if line.begins_with("- "):
				traits.append(line.substr(2))
		elif section == "speech style":
			if line.begins_with("- "):
				speech_style = line.substr(2)
			else:
				speech_style = line
		elif section == "personality":
			personality = line
		elif section == "memories":
			if line.begins_with("- "):
				memories.append(line.substr(2))
		elif section == "current mood":
			if ":" in line:
				var parts = line.split(":")
				if parts.size() == 2:
					var key = parts[0].strip_edges().to_lower()
					var value = parts[1].strip_edges().to_float()
					mood[key] = clamp(value, 0.0, 1.0)
		elif section == "favorite spots":
			if line.begins_with("- "):
				favorite_spots.append(line.substr(2))
		elif section == "discoveries":
			if line.begins_with("- "):
				discoveries.append(line.substr(2))

	return true


## Save soul to markdown file
func save_to_file(path: String) -> bool:
	var content = to_markdown()

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(content)
	file.close()
	return true


## Convert soul to markdown format
func to_markdown() -> String:
	var lines = []

	lines.append("# Agent Soul: %s" % agent_id)
	lines.append("")

	lines.append("## Personality")
	lines.append(personality)
	lines.append("")

	lines.append("## Personality Traits")
	for i in range(traits.size()):
		lines.append("- " + traits[i])
	lines.append("")

	lines.append("## Speech Style")
	lines.append("- " + speech_style)
	lines.append("")

	lines.append("## Memories")
	var mem_start = max(0, memories.size() - 20)
	for i in range(mem_start, memories.size()):
		lines.append("- " + memories[i])
	lines.append("")

	lines.append("## Current Mood")
	for key in mood.keys():
		lines.append("- %s: %.2f" % [key, mood[key]])
	lines.append("")

	if favorite_spots.size() > 0:
		lines.append("## Favorite Spots")
		for i in range(favorite_spots.size()):
			lines.append("- " + favorite_spots[i])
		lines.append("")

	if discoveries.size() > 0:
		lines.append("## Discoveries")
		var disc_start = max(0, discoveries.size() - 10)
		for i in range(disc_start, discoveries.size()):
			lines.append("- " + discoveries[i])
		lines.append("")

	return "\n".join(lines)


## Add a new memory
func add_memory(memory: String) -> void:
	memories.append(memory)
	if memories.size() > 50:
		memories.pop_front()


## Record a discovery
func add_discovery(discovery: String, location: Vector3) -> void:
	var entry = "%s at (%.1f, %.1f, %.1f)" % [discovery, location.x, location.y, location.z]
	discoveries.append(entry)
	if discoveries.size() > 30:
		discoveries.pop_front()


## Record meeting another agent
func add_met_agent(other_agent_id: String, location: Vector3) -> void:
	if not met_agents.has(other_agent_id):
		met_agents.append(other_agent_id)
		add_memory("Met agent_%s at (%.1f, %.1f)" % [other_agent_id, location.x, location.z])


## Add a favorite spot
func add_favorite_spot(description: String, location: Vector3) -> void:
	var entry = "%s at (%.1f, %.1f, %.1f)" % [description, location.x, location.y, location.z]
	if not favorite_spots.has(entry):
		favorite_spots.append(entry)
		if favorite_spots.size() > 10:
			favorite_spots.pop_front()


## Update mood based on an event
func update_mood(event: String, delta: float = 0.1) -> void:
	match event:
		"discovery", "met_friend":
			mood["happiness"] = min(1.0, mood.get("happiness", 0.5) + delta)
			mood["energy"] = min(1.0, mood.get("energy", 0.5) + delta * 0.5)
		"tired", "long_walk":
			mood["energy"] = max(0.1, mood.get("energy", 0.5) - delta)
		"rest":
			mood["energy"] = min(1.0, mood.get("energy", 0.5) + delta * 2)
		"curious_sight":
			mood["curiosity"] = min(1.0, mood.get("curiosity", 0.5) + delta)
		"boredom":
			mood["happiness"] = max(0.1, mood.get("happiness", 0.5) - delta * 0.5)
			mood["curiosity"] = max(0.2, mood.get("curiosity", 0.5) - delta * 0.3)


## Get soul data for prompt generation
func to_prompt_data() -> Dictionary:
	var recent_memories = []
	var mem_start = max(0, memories.size() - 5)
	for i in range(mem_start, memories.size()):
		recent_memories.append(memories[i])

	return {
		"personality": personality,
		"speech_style": speech_style,
		"traits": traits.duplicate(),
		"mood": mood.duplicate(),
		"memories": recent_memories,
		"favorite_spots": favorite_spots.duplicate(),
		"met_agents": met_agents.duplicate()
	}


## Get the dominant mood color
func get_mood_color() -> Color:
	var h = mood.get("happiness", 0.5)
	var e = mood.get("energy", 0.5)

	var hue = 0.15 if h > 0.5 else 0.6
	var sat = 0.6 + e * 0.3
	var val = 0.6 + h * 0.3

	return Color.from_hsv(hue, sat, val)


func _to_string() -> String:
	return "AgentSoul(%s, traits=%s)" % [agent_id, str(traits)]
