"""Claude Code AI CLI adapter."""
import json
import shlex
from typing import Optional
import logging

from .base import AICLIPlugin, StreamEvent

logger = logging.getLogger(__name__)


class ClaudeCodePlugin(AICLIPlugin):
    """Adapter for Claude Code CLI (claude)."""

    def get_name(self) -> str:
        return "claude"

    def get_command(self, prompt: str, context: dict) -> str:
        """Build Claude Code command with streaming JSON output."""
        # Escape the prompt for shell
        escaped_prompt = shlex.quote(prompt)

        # Build base command
        cmd_parts = [
            "claude",
            "-p",  # Print mode (non-interactive)
            escaped_prompt,
            "--verbose",  # Required for stream-json output
            "--output-format", "stream-json",
        ]

        # Add context files if provided
        context_files = context.get("context_files", [])
        for file_path in context_files:
            cmd_parts.extend(["--context", shlex.quote(file_path)])

        return " ".join(cmd_parts)

    async def is_available(self, check_command_exists: callable) -> bool:
        """Check if claude command exists."""
        return await check_command_exists("claude")

    async def parse_output(self, line: str) -> Optional[StreamEvent]:
        """Parse Claude Code stream-json output.

        Expected JSON format:
        {
            "type": "system" | "assistant" | "result" | "error",
            "message": {"content": [{"type": "text", "text": "..."}]},
            "result": "final result text"
        }
        """
        if not line.strip():
            return None

        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            # Not JSON, treat as plain text
            return StreamEvent(type="text", content=line)

        event_type = data.get("type", "")

        if event_type == "system":
            # System init message, skip
            return None

        elif event_type == "assistant":
            # Assistant message with content array
            message = data.get("message", {})
            content_list = message.get("content", [])
            for content_item in content_list:
                item_type = content_item.get("type", "")
                if item_type == "thinking":
                    return StreamEvent(
                        type="thinking",
                        content=content_item.get("thinking", ""),
                        raw_data=data
                    )
                elif item_type == "text":
                    return StreamEvent(
                        type="text",
                        content=content_item.get("text", ""),
                        raw_data=data
                    )
            return None

        elif event_type == "result":
            # Final result
            return StreamEvent(
                type="complete",
                content=data.get("result", ""),
                raw_data=data
            )

        elif event_type == "error":
            return StreamEvent(
                type="error",
                content=data.get("message", data.get("content", "Unknown error")),
                raw_data=data
            )

        # Unknown type, skip
        return None

    def get_version_command(self) -> str:
        """Get command to check Claude Code version."""
        return "claude --version"
