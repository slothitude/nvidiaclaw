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
