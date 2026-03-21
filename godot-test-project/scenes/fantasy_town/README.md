# Fantasy Town - AI Agent World Demo

A procedurally generated fantasy town where physics-based AI agents live, think, and interact. Part of the AWR (Agent World Runtime) world-breaking demo targeting 1000+ agents with real physics simulation.

## Features

### AI Agents
- **10 autonomous agents** with unique personalities (souls)
- **Ollama llama3.2 integration** for AI-generated thoughts
- **BDI cognition** (Beliefs-Desires-Intentions) for goal-directed reasoning
- **Physics-based hopping movement** - creatures hop around the town
- **Speech bubbles** showing thoughts and conversations in real-time

### Interactive UI
- **Click any agent** to open their info panel
- **Bio section** - personality, job, workplace, speech style, traits
- **Mood bars** - happiness, energy, curiosity (updates in real-time)
- **Skills section** - learned skills with levels and XP
- **Todo list** - add/complete tasks for agents
- **Chat system** - talk directly with agents via Ollama

### Buildings & Services
- **Library** - Access SearXNG web search
- **University** - Learn new skills (MCPs, Python, APIs)
- **Market** - Trade and barter
- **Tavern** - Rest and hear rumors
- **Temple** - Meditation and healing
- **Workshop** - Crafting and creation
- **Guard Posts** - Patrol and protect
- **Gardens** - Relax and enjoy nature

### External Integrations
- **SearXNG web search** via library buildings
- **Bash execution** via SSH AI Bridge
- **Skill learning** - MCP-ready architecture

## Quick Start

### Requirements
- **Godot 4.6** (.NET version not required)
- **Ollama** running locally with llama3.2 model
- **Kenney assets** (fantasy-town, modular-buildings, cube-pets)

### Running the Demo

```bash
# Start Ollama (if not already running)
ollama serve

# Ensure llama3.2 is pulled
ollama pull llama3.2

# Run the demo
cd godot-test-project
godot --path .
```

### Controls
| Control | Action |
|---------|--------|
| Left-click agent | Select and show info panel |
| Right-drag | Rotate camera |
| Scroll wheel | Zoom in/out |
| F12 | Capture screenshot |
| Escape | Deselect agent |

## Architecture

### Agent Cognition Pipeline

```
Spatial Memory → BDI Beliefs → Desires → HTN Planner → Hopping Movement
      ↓              ↓           ↓            ↓              ↓
   World State   Perception   Goals      Actions        Physics
```

### Core Components

| Component | File | Description |
|-----------|------|-------------|
| **AgentBehavior** | `agent_behavior.gd` | BDI model, spatial memory, HTN planner, Ollama integration |
| **AgentSoul** | `agent_soul.gd` | Personality system with 10 templates, mood, memories |
| **OllamaClient** | `ollama_client.gd` | Batch AI thought generation with rate limiting |
| **SpeechBubble** | `speech_bubble.gd` | 3D billboard labels with typewriter effect |
| **AgentPanel** | `agent_panel.gd` | UI panel for agent interaction |
| **FantasyTown** | `fantasy_town.gd` | Procedural town generation, agent spawning |

### Soul System

Each agent has a unique "soul" stored as markdown in `user://souls/`:

```markdown
# Agent Soul: 0

## Personality
a curious explorer who loves discovering new places

## Personality Traits
- curious
- adventurous
- friendly

## Speech Style
- enthusiastic with lots of exclamation marks

## Current Mood
- happiness: 0.85
- energy: 0.75
- curiosity: 0.92

## Memories
- Met agent_1 at (12.5, 8.0)
- Discovered hidden garden at (-5.2, 3.1)
```

### Personality Templates

| Template | Personality | Speech Style | Job Assignment |
|----------|-------------|--------------|----------------|
| curious_explorer | Discovery lover | Enthusiastic! | Explorer @ Library |
| shy_observer | Quiet watcher | Soft, short sentences | Observer @ Garden |
| social_butterfly | Friend maker | Warm and chatty | Merchant @ Market |
| grumpy_wanderer | Experienced cynic | Sarcastic | Wanderer @ Garden |
| dreamy_poet | Beauty seeker | Flowery, metaphorical | Bard @ Tavern |
| brave_guardian | Town protector | Formal, authoritative | Guard @ Guard Post |
| playful_prankster | Fun lover | Mischievous, giggly | Entertainer @ Tavern |
| wise_elder | Ancient knowledge | Slow, proverbs | Scholar @ Library |
| eager_learner | Question asker | Excited, curious | Student @ University |
| gentle_healer | Caring soul | Soft, reassuring | Healer @ Temple |

### BDI Model

The Beliefs-Desires-Intentions model provides goal-directed reasoning:

```gdscript
# Beliefs (what the agent knows)
_bdi_model.believe("position", agent_body.position, 1.0, "perception")
_bdi_model.believe("nearby_objects_count", 5, 0.8, "spatial_memory")
_bdi_model.believe("energy", 0.7, 0.9, "internal")

# Desires (what the agent wants)
_bdi_model.desire("explore", 0.6)
_bdi_model.desire("socialize", 0.3)

# Intentions (what the agent will do)
# Formed from highest priority desire
```

### Spatial Memory

Each agent has both:
1. **Shared spatial memory** - Town layout from AWR
2. **Personal spatial memory** - Individual discoveries and visited locations

```gdscript
# Store a discovery
_personal_memory.store(
    "visited_12345",
    current_target,
    {"type": "visited_location", "goal": "explore"}
)

# Find path between locations
var path = spatial_memory.find_path("house_1", "agent_0")
```

## Building System

### Building Types

| Type | Weight | Services | Color |
|------|--------|----------|-------|
| Home | 40 | rest, sleep, store | Green |
| Market | 10 | trade, buy, sell, barter | Yellow |
| Tavern | 8 | rest, chat, hear_rumors, drink | Brown |
| Workshop | 8 | craft, repair, build, invent | Tan |
| Garden | 7 | relax, gather, enjoy_nature | Green |
| Library | 5 | research, searxng_search, read, study | Blue |
| Temple | 5 | meditate, heal, bless, pray | White |
| Guard Post | 5 | patrol, watch, protect | Gray |
| University | 3 | learn_skill, learn_mcp, learn_python | Purple |

### University Skills

Agents can learn these skills at the university:

| Skill | Type | Cost | Description |
|-------|------|------|-------------|
| Web Search (SearXNG) | MCP | 10 | Search the web for information |
| Python Scripting | Skill | 15 | Write and execute Python code |
| Data Analysis | Skill | 12 | Analyze data and create visualizations |
| API Integration | Skill | 8 | Connect to external APIs |
| Memory Enhancement | Skill | 5 | Improve spatial memory recall |
| Communication Protocol | Skill | 7 | Learn new languages and protocols |

## External Integrations

### SSH AI Bridge (Bash Execution)

Agents can execute bash commands via the SSH AI Bridge:

```gdscript
# Agent executes a command
execute_bash("ls -la ~/projects")

# Response handled via HTTP
func _on_bash_response(result, response_code, headers, body):
    var output = json.data.get("output", "")
    soul.add_memory("Bash output: %s" % output)
```

### SearXNG Web Search

Agents at a library can search the web:

```gdscript
# Requires library access or web search skill
if _skills.has("Web Search (SearXNG)") or _current_building == "library":
    web_search("latest AI research papers")
```

## Asset Paths

```
res://assets/kenney/fantasy-town/         # Fantasy town parts (walls, roofs, props)
res://assets/kenney/modular-buildings/    # Complete houses and towers
res://assets/kenney/cube-pets/            # Agent models (animals)
```

### Scale Constants

| Element | Scale | Purpose |
|---------|-------|---------|
| HOUSE_SCALE | 2.0 | Buildings visible from camera |
| TREE_SCALE | 1.5 | Natural forest feel |
| PROP_SCALE | 1.2 | Fences, carts, decorations |
| AGENT_SCALE | 0.6 | Small cute creatures (~0.6m tall) |

## Configuration

### Agent Configuration

```gdscript
@export var agent_count := 10           # Number of agents
@export var town_size := 40             # Grid size
@export var building_density := 0.45    # Building probability
```

### Ollama Configuration

```gdscript
const OLLAMA_URL := "http://localhost:11434"
const DEFAULT_MODEL := "llama3.2"
const REQUEST_TIMEOUT := 30.0
const BATCH_SIZE := 10                  # Process 10 agents at a time
```

### Thought Generation

```gdscript
@export var thought_interval: float = 8.0   # Seconds between thoughts
@export var goal_update_interval: float = 5.0  # Seconds between goal changes
```

## Data Persistence

### Saved Data

| Data | Location | Format |
|------|----------|--------|
| Agent souls | `user://souls/soul_{id}.md` | Markdown |
| Personal memories | `user://agent_memories/agent_{id}_memory.json` | JSON |
| Screenshots | `user://fantasy_town_{timestamp}.png` | PNG |

### Auto-Save

Agent data is automatically saved:
- On application exit (`_exit_tree`)
- Periodically during gameplay
- When agent completes a task

## Extending the Demo

### Adding New Personality Templates

```gdscript
# In agent_soul.gd TEMPLATES dict
"my_custom_type": {
    "personality": "a custom personality description",
    "speech_style": "how they speak",
    "traits": ["trait1", "trait2", "trait3"],
    "mood": {"happiness": 0.7, "energy": 0.8, "curiosity": 0.6}
}
```

### Adding New Building Types

```gdscript
# In fantasy_town.gd BUILDING_TYPES dict
"my_building": {
    "description": "Building description",
    "services": ["service1", "service2"],
    "skills_available": [...],
    "color": Color(0.5, 0.5, 0.5)
}
```

### Adding New Skills

```gdscript
# In BUILDING_TYPES["university"]["skills_available"]
{
    "name": "My New Skill",
    "description": "What this skill does",
    "type": "skill",  # or "mcp"
    "cost": 10
}
```

## Performance Notes

- **10 agents** = ~60 FPS on modern hardware
- **Batch processing** for AI thoughts (10 at a time)
- **Rate limiting** prevents Ollama overload
- **Spatial hashing** for O(n) collision detection
- **Fallback thoughts** when Ollama unavailable

## Troubleshooting

### "Ollama server not available"
```bash
ollama serve
ollama pull llama3.2
```

### "Assets not found"
Ensure Kenney assets are in `res://assets/kenney/`:
- fantasy-town/
- modular-buildings/
- cube-pets/

### "Speech bubbles not showing"
- Check console for "[Agent X] Speech bubble not ready!"
- Bubbles take 1-2 frames to initialize after agent spawn

## Future Goals

Part of the AWR world-breaking roadmap:
- [ ] **1000+ agents** with physics
- [ ] **500,000 futures/sec** branching simulation
- [ ] **1M+ spatial memory nodes** (Wikipedia-scale)
- [ ] **1 year+ continuous simulation** (digital civilization)

## License

Part of the AWR project. See root LICENSE file.
