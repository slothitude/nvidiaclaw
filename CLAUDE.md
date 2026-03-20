# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SSH AI Bridge is a two-part system that enables Godot 4.6 applications to interact with remote AI CLIs (Claude Code, Goose) via SSH:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Godot 4.6     │────▶│   HTTP API      │────▶│  Remote Server  │
│  (Editor/Game)  │◀────│   (FastAPI)     │◀────│  (AI CLIs)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Repository Structure

```
014_nvidiaclaw/
├── ssh-ai-bridge/          # Python FastAPI backend
│   ├── main.py             # App entry point
│   ├── config.py           # Pydantic settings
│   ├── api/                # HTTP routes and schemas
│   ├── ssh/                # SSH connection management (asyncssh)
│   ├── ai/                 # AI CLI plugin system
│   ├── session/            # Session storage
│   └── tests/              # pytest tests
│
└── godot-test-project/     # Godot 4.6 test application
    ├── main.tscn           # Main UI scene
    ├── main.gd             # Main scene controller
    ├── addons/ai_chat/     # AI Chat addon (autoload singleton)
    └── tests/              # GDScript tests
```

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

# Run main scene (requires GUI)
godot --path .
```

## Architecture

### Backend: Plugin System for AI CLIs

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

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/connect` | POST | Connect to SSH server, auto-detect AI CLIs |
| `/api/v1/disconnect` | POST | Close SSH connection |
| `/api/v1/chat` | POST | Send message, get response |
| `/api/v1/chat/stream` | GET | SSE streaming for real-time responses |
| `/api/v1/execute` | POST | Run raw command (testing) |
| `/api/v1/health` | GET | Health check |

### Godot Addon: ai_chat

The addon uses explicit preloading (not `class_name`) to avoid circular dependency issues:

```gdscript
const AISettingsScript = preload("res://addons/ai_chat/ai_settings.gd")
const AIClientScript = preload("res://addons/ai_chat/ai_client.gd")
```

Key classes:
- **AIChat** (autoload): Singleton managing connection state, history, and client
- **AIClient**: HTTP client for bridge API communication
- **AISettings**: Resource for persisting user preferences
- **ChatHistory**: Ring buffer for conversation history

### Session Management

Sessions are stored in-memory in `session/store.py`. Each session tracks:
- SSH connection reference
- AI CLI type and plugin instance
- Conversation history
- Connection metadata

## Testing Notes

- Python tests use `pytest-asyncio` for async test support
- Godot tests extend `SceneTree` (not GutTest) to avoid external dependencies
- Integration tests require a running bridge server and accessible SSH target

## Configuration

Backend settings via environment variables or `config.py`:
- `DEBUG=true` - Enable debug logging
- `HOST` / `PORT` - Server bind address

Godot settings persist to `user://ai_settings.tres` including:
- Bridge URL (default: `http://localhost:8000`)
- Default SSH credentials
- Preferred AI CLI
