# AI Chat Test Project

Test project for the SSH AI Bridge integration with Godot 4.6.

## Setup

1. Ensure the SSH AI Bridge is running:
   ```bash
   cd ../ssh-ai-bridge
   uvicorn main:app --reload
   ```

2. Open this project in Godot 4.6

3. Run the main scene (F5) or run tests

## Usage

### Main Scene

The main scene provides a simple UI to:
- Connect to SSH servers
- Send chat messages to AI CLIs (Claude Code or Goose)
- View responses

### Connection Settings

- **Host**: SSH server IP (e.g., 192.168.0.237)
- **Username**: SSH username
- **Password**: SSH password
- **AI CLI**: Select Auto, Claude, or Goose

### API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/connect` | POST | Connect to SSH server |
| `/api/v1/disconnect` | POST | Disconnect from server |
| `/api/v1/chat` | POST | Send message to AI |
| `/api/v1/health` | GET | Check bridge health |

## Running Tests

### Headless Test
```bash
godot --headless --path . -s tests/test_ai_client.gd
```

### In Editor
1. Open `tests/test_ai_client.gd`
2. Click "Run" button or press F5

## Project Structure

```
godot-test-project/
├── project.godot          # Project settings
├── main.tscn              # Main scene
├── main.gd                # Main script
├── addons/
│   └── ai_chat/           # AI Chat addon
│       ├── ai_chat.gd      # Autoload singleton
│       ├── ai_client.gd    # HTTP client
│       ├── ai_settings.gd  # Settings
│       └── chat_history.gd # History
└── tests/
    └── test_ai_client.gd  # Test script
```

## Configuration

Settings are saved to `user://ai_settings.tres` and include:
- Bridge URL
- Default server credentials
- Preferred AI CLI

## Troubleshooting

### Connection Failed
- Ensure the bridge is running on `http://localhost:8000`
- Check SSH credentials are correct
- Verify network connectivity to remote server

### No AI CLI Detected
- Install Claude Code or Goose on the remote server
- Check if the AI CLI is in PATH

### Timeout Errors
- Increase `request_timeout` in settings
- Check network latency
