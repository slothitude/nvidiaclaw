"""Pytest fixtures and configuration."""
import pytest
import asyncio
from typing import AsyncGenerator
from unittest.mock import AsyncMock, MagicMock, patch
import json

# Configure pytest-asyncio
pytest_plugins = ('pytest_asyncio',)


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def mock_ssh_connection():
    """Mock SSH connection."""
    mock_conn = MagicMock()
    mock_conn.run = AsyncMock()
    mock_conn.create_process = AsyncMock()
    mock_conn.close = MagicMock()
    return mock_conn


@pytest.fixture
def mock_ssh_manager(mock_ssh_connection):
    """Mock SSH manager."""
    with patch("ssh.manager.ssh_manager") as mock_manager:
        mock_manager.connect = AsyncMock()
        mock_manager.disconnect = AsyncMock()
        mock_manager.get_connection = MagicMock(return_value=None)
        mock_manager.execute_command = AsyncMock(return_value=(0, "output", ""))
        mock_manager.execute_stream = AsyncMock()
        mock_manager.list_connections = MagicMock(return_value=[])
        mock_manager.close_all = AsyncMock()
        yield mock_manager


@pytest.fixture
def mock_executor():
    """Mock command executor."""
    with patch("ssh.executor.executor") as mock_exec:
        mock_exec.run_command = AsyncMock(return_value=(0, "output", ""))
        mock_exec.check_command_exists = AsyncMock(return_value=True)
        mock_exec.get_server_info = AsyncMock(return_value={
            "hostname": "test-server",
            "os": "Ubuntu 22.04",
            "cwd": "/home/user",
        })
        mock_exec.detect_ai_clis = AsyncMock(return_value={
            "claude": True,
            "goose": False,
            "aider": False,
            "cursor": False,
        })
        yield mock_exec


@pytest.fixture
def sample_claude_output():
    """Sample Claude Code stream-json output."""
    return [
        json.dumps({"type": "thinking", "content": "Analyzing the code..."}),
        json.dumps({"type": "text", "content": "I found the issue in your code."}),
        json.dumps({"type": "tool_use", "tool": "read_file", "path": "test.gd"}),
        json.dumps({"type": "text", "content": "The bug is on line 10."}),
    ]


@pytest.fixture
def test_client():
    """FastAPI test client."""
    from httpx import AsyncClient
    from main import app

    return AsyncClient(app=app, base_url="http://test")


@pytest.fixture
async def async_client():
    """Async FastAPI test client."""
    from httpx import AsyncClient, ASGITransport
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test"
    ) as client:
        yield client
