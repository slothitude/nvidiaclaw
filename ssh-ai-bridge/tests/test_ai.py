"""Tests for AI CLI plugins."""
import pytest
import json
from unittest.mock import AsyncMock

from ai.base import StreamEvent
from ai.claude import ClaudeCodePlugin
from ai.goose import GoosePlugin


class TestClaudeCodePlugin:
    """Tests for Claude Code plugin."""

    def test_get_name(self):
        """Test plugin name."""
        plugin = ClaudeCodePlugin()
        assert plugin.get_name() == "claude"

    def test_get_command_basic(self):
        """Test basic command generation."""
        plugin = ClaudeCodePlugin()
        cmd = plugin.get_command("Hello, Claude!", {})

        assert "claude" in cmd
        assert "-p" in cmd
        assert "--output-format" in cmd
        assert "stream-json" in cmd
        assert "'Hello, Claude!'" in cmd or '"Hello, Claude!"' in cmd

    def test_get_command_with_context_files(self):
        """Test command with context files."""
        plugin = ClaudeCodePlugin()
        cmd = plugin.get_command(
            "Fix the bug",
            {"context_files": ["player.gd", "enemy.gd"]}
        )

        assert "claude" in cmd
        assert "--context" in cmd
        assert "player.gd" in cmd
        assert "enemy.gd" in cmd

    @pytest.mark.asyncio
    async def test_is_available_true(self):
        """Test availability check when command exists."""
        plugin = ClaudeCodePlugin()

        async def check_exists(cmd):
            return cmd == "claude"

        result = await plugin.is_available(check_exists)
        assert result is True

    @pytest.mark.asyncio
    async def test_is_available_false(self):
        """Test availability check when command doesn't exist."""
        plugin = ClaudeCodePlugin()

        async def check_exists(cmd):
            return False

        result = await plugin.is_available(check_exists)
        assert result is False

    @pytest.mark.asyncio
    async def test_parse_thinking_output(self):
        """Test parsing thinking output."""
        plugin = ClaudeCodePlugin()
        line = json.dumps({"type": "thinking", "content": "Analyzing code..."})

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "thinking"
        assert event.content == "Analyzing code..."

    @pytest.mark.asyncio
    async def test_parse_text_output(self):
        """Test parsing text output."""
        plugin = ClaudeCodePlugin()
        line = json.dumps({"type": "text", "content": "Hello, world!"})

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "text"
        assert event.content == "Hello, world!"

    @pytest.mark.asyncio
    async def test_parse_tool_use_output(self):
        """Test parsing tool use output."""
        plugin = ClaudeCodePlugin()
        line = json.dumps({
            "type": "tool_use",
            "tool": "read_file",
            "path": "test.gd",
            "content": "Reading file..."
        })

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "tool_use"
        assert event.tool == "read_file"
        assert event.path == "test.gd"

    @pytest.mark.asyncio
    async def test_parse_error_output(self):
        """Test parsing error output."""
        plugin = ClaudeCodePlugin()
        line = json.dumps({"type": "error", "content": "Something went wrong"})

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "error"
        assert "wrong" in event.content

    @pytest.mark.asyncio
    async def test_parse_plain_text(self):
        """Test parsing plain text (non-JSON) output."""
        plugin = ClaudeCodePlugin()
        line = "This is plain text output"

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "text"
        assert event.content == "This is plain text output"

    @pytest.mark.asyncio
    async def test_parse_empty_line(self):
        """Test parsing empty line."""
        plugin = ClaudeCodePlugin()

        event = await plugin.parse_output("")
        assert event is None

        event = await plugin.parse_output("   ")
        assert event is None


class TestGoosePlugin:
    """Tests for Goose plugin."""

    def test_get_name(self):
        """Test plugin name."""
        plugin = GoosePlugin()
        assert plugin.get_name() == "goose"

    def test_get_command_basic(self):
        """Test basic command generation."""
        plugin = GoosePlugin()
        cmd = plugin.get_command("Hello, Goose!", {})

        assert "goose" in cmd
        assert "run" in cmd
        assert "--prompt" in cmd

    @pytest.mark.asyncio
    async def test_is_available_true(self):
        """Test availability check when command exists."""
        plugin = GoosePlugin()

        async def check_exists(cmd):
            return cmd == "goose"

        result = await plugin.is_available(check_exists)
        assert result is True

    @pytest.mark.asyncio
    async def test_parse_json_output(self):
        """Test parsing JSON output."""
        plugin = GoosePlugin()
        line = json.dumps({"type": "text", "content": "Response from Goose"})

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "text"
        assert event.content == "Response from Goose"

    @pytest.mark.asyncio
    async def test_parse_plain_text(self):
        """Test parsing plain text output."""
        plugin = GoosePlugin()
        line = "Plain text response"

        event = await plugin.parse_output(line)

        assert event is not None
        assert event.type == "text"
        assert event.content == "Plain text response"


class TestStreamEvent:
    """Tests for StreamEvent dataclass."""

    def test_create_thinking_event(self):
        """Test creating a thinking event."""
        event = StreamEvent(type="thinking", content="Processing...")

        assert event.type == "thinking"
        assert event.content == "Processing"

    def test_create_tool_use_event(self):
        """Test creating a tool use event."""
        event = StreamEvent(
            type="tool_use",
            tool="read_file",
            path="test.gd"
        )

        assert event.type == "tool_use"
        assert event.tool == "read_file"
        assert event.path == "test.gd"

    def test_create_error_event(self):
        """Test creating an error event."""
        event = StreamEvent(type="error", content="Something failed")

        assert event.type == "error"
        assert event.content == "Something failed"
