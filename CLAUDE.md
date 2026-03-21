# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains two major systems:

### SSH AI Bridge

Enables Godot 4.6 applications to interact with remote AI CLIs (Claude Code, Goose) via SSH:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Godot 4.6     │────▶│   HTTP API      │────▶│  Remote Server  │
│  (Editor/Game)  │◀────│   (FastAPI)     │◀────│  (AI CLIs)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### AWR - Agent World Runtime

A new compute substrate that uses physics as reasoning: `State → Simulate → Evaluate → Commit`

- CPU-only world simulation (no GPU required)
- Deterministic branching for hypothetical action evaluation
- ~519 branches/second performance
- 6 primitives: WorldState, SimLoop, Evaluator, CausalBus, Collision2D, PerceptionLayer
- See `godot-test-project/addons/awr/README.md` for full documentation

## Commands

### Python Backend (ssh-ai-bridge/)

```bash
# Install dependencies
pip install -r requirements.txt

# Run development server
uvicorn main:app --reload

# Run with custom host/port
uvicorn main:app --host 0.0.0.0 --port 8000

# Run all tests
pytest

# Run specific test file
pytest tests/test_api.py -v

# Run with coverage
pytest --cov=. --cov-report=html
```

### Godot Project (godot-test-project/)

```bash
# Run headless tests (from godot-test-project directory)
godot --headless --path . -s tests/test_ai_client.gd

# Run main scene (requires GUI) - currently Fantasy Town demo
godot --path .

# Open editor to import new assets
godot --editor --path .
```

### AWR Tests (godot-test-project/addons/awr/)

```bash
# Run all AWR tests
godot --headless --path godot-test-project -s addons/awr/tests/run_all_tests.gd

# Run specific test suites
godot --headless --path godot-test-project -s addons/awr/tests/test_sim_loop.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_collision.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_gravity_slingshot.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_cognitive.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_spatial_memory.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_spatial_agents.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_self_improvement.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_causal_bus.gd
godot --headless --path godot-test-project -s addons/awr/tests/test_perception.gd
```

## Architecture

### Backend Structure

```
ssh-ai-bridge/
├── main.py             # FastAPI app entry, includes both routers
├── config.py           # Pydantic settings
├── api/                # SSH/chat routes
├── agents/             # Agent CRUD, skills/tools registry
├── providers/          # AI provider abstraction (for future local use)
├── ssh/                # SSH connection management (asyncssh)
├── ai/                 # AI CLI plugin system
├── session/            # Session storage
└── tests/
```

### API Endpoints

**Core (api/routes.py):**
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/connect` | POST | Connect to SSH server, auto-detect AI CLIs |
| `/api/v1/disconnect` | POST | Close SSH connection |
| `/api/v1/chat` | POST | Send message, get response |
| `/api/v1/chat/stream` | GET | SSE streaming for real-time responses |
| `/api/v1/execute` | POST | Run raw command (testing) |
| `/api/v1/health` | GET | Health check |

**Agents (agents/routes.py):**
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/agents` | GET/POST | List or create agents |
| `/api/v1/agents/{id}` | GET/PATCH/DELETE | CRUD for specific agent |
| `/api/v1/agents/{id}/export` | GET | Export agent config as markdown |
| `/api/v1/agents/registry/skills` | GET | List available skills |
| `/api/v1/agents/registry/tools` | GET | List available tools |

### AI CLI Plugin System

AI CLI integrations follow a plugin pattern defined in `ai/base.py`:

```python
class AICLIPlugin(ABC):
    def get_command(self, prompt: str, context: dict) -> str  # Build shell command
    async def is_available(self, check_command_exists) -> bool  # Check if CLI exists
    async def parse_output(self, line: str) -> StreamEvent  # Parse JSON output
```

Plugins are registered in `ai/__init__.py` and auto-detected on SSH connection. To add a new AI CLI:
1. Create `ai/newcli.py` extending `AICLIPlugin`
2. Register in `PLUGINS` dict in `ai/__init__.py`
3. Add detection logic in `ssh/executor.py`

### Agent System

The `agents/` module provides a configuration layer for AI agents with:
- **AgentConfig**: Name, icon, AI CLI preference, skills, tools, system prompt
- **AgentSkill**: Predefined skills with prompt templates (code-review, debugging, testing, etc.)
- **AgentTool**: Tools agents can use (file_read, shell_execute, etc.)

Skills and tools are defined in `agents/models.py` with registries (`SkillRegistry`, `ToolRegistry`).

### Godot Addons

**ai_chat/** - SSH connection and chat:
- **AIChat** (autoload): Connection state, history, client
- **AIClient**: HTTP client for bridge API
- **AISettings**: Persisted user preferences
- **ChatHistory**: Ring buffer for messages

**agent_studio/** - Agent management:
- **AgentStudio** (autoload): Manages agent configs, skills, tools
- **AgentClient**: HTTP client for /agents endpoints
- **AgentConfig**: Resource for agent configuration
- Wizard UI for creating agents step-by-step

**llm_ui_os/** - Dynamic AI-generated UI:
- **AgentBridge** (autoload): Requests UI from AI, parses NDJSON responses
- **UIManager**: Renders UI specs, handles diffing
- **StateManager**: Application state for UI binding
- **ActionRouter**: Routes UI actions (sys:navigate, agent:send_message)
- **SchemaValidator**: Validates NDJSON UI specs
- **DiffEngine**: Efficient UI updates
- **NodePool**: Object pooling for UI nodes

**BackendManager** (autoload at project root): Manages SSH AI Bridge process from Godot (start/stop/restart, health checks).

**awr/** - Agent World Runtime:
- **AWR** (autoload): Main entry point for world simulation
- **WorldState**: Deterministic scene graph with clone/apply/step/hash
- **SimLoop**: Branching simulation engine (core primitive)
- **Evaluator**: Scoring functions for branch comparison
- **CausalBus**: Traceable event system
- **Collision2D**: 2D rigid body physics
- **Broadphase**: Spatial hashing for O(n) collision detection
- **PerceptionBridge**: Viewport capture → VLM → WorldState pipeline

### Autoload Order

Dependencies matter in `project.godot`:
```
AIChat → AgentStudio → BackendManager → llm_ui_os autoloads → AgentBridge → UIManager
```

### Fantasy Town Demo (scenes/fantasy_town/)

The main scene (`fantasy_town.tscn`) is a world-breaking demo with:
- 100+ physics-based agents with BDI cognition
- Procedural town generation with Kenney assets
- Spatial Memory integration for agent navigation

**Asset paths:**
```
res://assets/kenney/fantasy-town/         # Fantasy town parts (walls, roofs, props)
res://assets/kenney/modular-buildings/    # Complete houses and towers
res://assets/kenney/cube-pets/            # Agent models (animals)
```

**Scale constants** (in fantasy_town.gd):
| Element | Scale | Purpose |
|---------|-------|---------|
| HOUSE_SCALE | 2.0 | Buildings visible from camera |
| TREE_SCALE | 1.5 | Natural forest feel |
| PROP_SCALE | 1.2 | Fences, carts, decorations |
| AGENT_SCALE | 0.6 | Small cute creatures |

**Agent cognition pipeline:**
```
Spatial Memory → BDI Beliefs → Desires → HTN Planner → Hopping Movement
```

**Controls:**
- F12: Screenshot capture
- Right-drag: Rotate camera
- Scroll: Zoom

### AWR Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWR Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│  Perception ──▶ WorldState ◀── WorldGen                         │
│                      │                                          │
│                      ▼                                          │
│                 SimLoop (Branching)                             │
│                      │                                          │
│                      ▼                                          │
│  RealBridge ◀── CausalBus ──▶ Agent Interface                  │
└─────────────────────────────────────────────────────────────────┘
```

Key interfaces:
- `WorldState.clone()` - Deep copy for branch simulation
- `WorldState.apply(action)` - Apply action to state
- `WorldState.step(dt)` - Advance physics by dt seconds
- `SimLoop.search_best(actions)` - Find optimal action via simulation
- `Evaluator.*` - Scoring functions (goal_distance, collision_free, etc.)

### Ingesting Documents into Spatial Memory

Use `tools/book_to_spatial_memory.py` to convert text into navigable 3D concept space:

```bash
# Install dependencies
pip install requests numpy scikit-learn

# Ensure Ollama is running with embedding model
ollama pull nomic-embed-text

# Ingest a book
python tools/book_to_spatial_memory.py book.txt --output memory.json

# Ingest a directory (e.g., Godot docs)
python tools/book_to_spatial_memory.py tools/godot-docs \
    --output godot_docs_memory.json \
    --extensions .rst,.md,.txt \
    --chunk-size 500
```

Load in Godot:
```gdscript
var memory = SpatialMemory.load_from("res://godot_docs_memory.json")
var path = memory.find_path("player", "animation")
```

### Session Management

Sessions are stored in-memory in `session/store.py`. Each session tracks:
- SSH connection reference
- AI CLI type and plugin instance
- Conversation history
- Connection metadata

## Testing

- Python tests use `pytest-asyncio` for async support
- Godot tests extend `SceneTree` (not GutTest) to avoid external dependencies
- Integration tests require running bridge server and accessible SSH target

## Configuration

Backend via environment variables or `config.py`:
- `DEBUG=true` - Enable debug logging
- `HOST` / `PORT` - Server bind address

Godot settings persist to `user://ai_settings.tres`:
- Bridge URL (default: `http://localhost:8000`)
- Default SSH credentials
- Preferred AI CLI

## Self-Organizing Agent Systems

This section documents research patterns for autonomous agents that can create their own systems to perform real work.

### Autonomous Task Decomposition

Agents break high-level goals into executable subtasks:

```
Goal: "Build a web scraper"
  ↓ Decomposition
├── Subtask: Research scraping libraries
├── Subtask: Install dependencies
├── Subtask: Write scraper code
├── Subtask: Test and debug
└── Subtask: Deploy to production
```

**Implementation in Fantasy Town:**
- HTN Planner decomposes goals into actions
- BDI model tracks belief state for each subtask
- Delegation system (Meeseeks pattern) spawns subtasks when stuck

### Emergent Collaboration

Agents form teams without explicit programming:

1. **Proximity-based**: Agents near each other discover shared goals
2. **Skill-based**: Agents with complementary skills find each other
3. **Task-based**: Complex tasks require multiple agents

**Example workflow:**
```
Agent A (has Python skill) meets Agent B (has API skill)
→ Both need to fetch data
→ A writes scraper, B handles API auth
→ Emergent team formation
```

### Self-Improvement Loops

Agents enhance their own capabilities:

| Loop | Mechanism | Example |
|------|-----------|---------|
| Learning | Visit university → acquire skill | "Learn Python Scripting" |
| Practice | Use skill → gain XP | Execute bash commands |
| Teaching | Share knowledge with other agents | Agent teaches skill to another |
| Tool Creation | Write code → add to toolkit | Agent creates helper script |

**Implementation:**
```gdscript
# Skill learning loop
func learn_skill(skill_name: String) -> void:
    if not _skills.has(skill_name):
        _skills[skill_name] = {"level": 1, "experience": 10}
    else:
        _skills[skill_name]["experience"] += 10
        if _skills[skill_name]["experience"] >= 100:
            _skills[skill_name]["level"] += 1
```

### MCP as Building Blocks

Model Context Protocol (MCP) enables real work:

| MCP Server | Capability | Fantasy Town Building |
|------------|------------|----------------------|
| SearXNG | Web search | Library |
| Filesystem | Read/write files | Workshop |
| GitHub | Code management | University |
| PostgreSQL | Database queries | Market |

**Integration pattern:**
1. Agent visits appropriate building
2. Building provides MCP access
3. Agent uses MCP to perform real work
4. Results stored in agent memory

### Memory-Driven Behavior

Spatial memory enables intelligent decision-making:

```
┌─────────────────────────────────────────┐
│           SPATIAL MEMORY                 │
├─────────────────────────────────────────┤
│  Concepts ←→ Locations ←→ Metadata      │
│     ↓           ↓            ↓          │
│  Navigation   Goals      Context        │
│     ↓           ↓            ↓          │
│  "Where's    "Visit      "Library       │
│   library?"  building"   has search"    │
└─────────────────────────────────────────┘
```

**Memory queries:**
- `find_path("self", "library")` - Navigation
- `neighbors(position, radius)` - Nearby objects
- `retrieve_by_concept("market")` - Known locations

### Economic Systems

Agents trade skills and resources:

| Resource | Source | Use |
|----------|--------|-----|
| Energy | Rest at tavern | Powers movement |
| Knowledge | Visit library | Enables search |
| Skills | Visit university | Unlocks capabilities |
| Gold | Trade at market | Buy services |

**Trade protocol:**
```
Agent A offers: Python Scripting (Level 3)
Agent B offers: API Integration (Level 2)
→ Fair trade if levels match
→ Both agents gain new capability access
```

### Code Generation

Agents write their own tools:

1. **Template-based**: Fill in parameters
2. **LLM-generated**: Use Ollama for code
3. **Iterative refinement**: Test and improve

**Example - Agent creates a helper:**
```gdscript
# Agent requests code generation
thought = "I need a function to parse JSON data"

# Ollama generates:
func parse_json_data(raw_text: String) -> Dictionary:
    var json = JSON.new()
    if json.parse(raw_text) == OK:
        return json.data
    return {}
```

### API Integration

Agents connect to external services:

| Service | Endpoint | Agent Skill Required |
|---------|----------|---------------------|
| SSH Bridge | `/api/v1/execute` | Bash execution |
| SearXNG | `/search` | Web Search |
| Ollama | `/api/generate` | (built-in) |
| Custom APIs | Any HTTP | API Integration |

**Request pattern:**
```gdscript
func call_api(endpoint: String, params: Dictionary) -> void:
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_api_response)
    http.request(endpoint, ["Content-Type: application/json"],
                 HTTPClient.METHOD_POST, JSON.stringify(params))
```

### Real Job Skills

Agents can learn skills for actual work:

| Skill Category | Skills | Real Application |
|----------------|--------|------------------|
| **Development** | Python, Git, Testing | Write and test code |
| **Data** | Analysis, Visualization | Process datasets |
| **DevOps** | Docker, CI/CD, Monitoring | Deploy services |
| **Research** | Web Search, Summarization | Gather information |
| **Communication** | APIs, Protocols | Integrate systems |
| **Memory** | Enhancement, Recall | Long-term knowledge |

**Learning path:**
```
1. Agent visits University
2. Selects skill to learn
3. Gains level through practice
4. Uses skill for real work
5. Earns rewards (XP, resources)
6. Can teach other agents
```

### Autonomous Agent Checklist

For agents to do real work independently:

- [x] **Perception** - Sense environment via spatial memory
- [x] **Reasoning** - BDI model for goal-directed behavior
- [x] **Learning** - Skill acquisition at university
- [x] **Memory** - Personal and shared spatial memory
- [x] **Communication** - Speech bubbles and chat
- [x] **Tool Use** - Bash execution, web search
- [ ] **Planning** - Long-term goal decomposition
- [ ] **Collaboration** - Multi-agent task sharing
- [ ] **Reflection** - Self-evaluation and improvement
- [ ] **Creativity** - Novel solution generation

### Scaling to 1000+ Agents

Key optimizations for massive scale:

| Challenge | Solution |
|-----------|----------|
| AI generation | Batch requests (10 at a time) |
| Physics | Spatial hashing O(n) collisions |
| Memory | Hierarchical LOD for distant agents |
| Rendering | GPU instancing for similar models |
| State sync | Delta compression for networking |
