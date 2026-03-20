"""Goose AI CLI adapter."""
import json
import shlex
from typing import Optional
import logging

from .base import AICLIPlugin, StreamEvent

logger = logging.getLogger(__name__)


class GoosePlugin(AICLIPlugin):
    """Adapter for Goose CLI."""

    def get_name(self) -> str:
        return "goose"

    def get_command(self, prompt: str, context: dict) -> str:
        """Build Goose command with NVIDIA API."""
        escaped_prompt = shlex.quote(prompt)

        # Use full path to goose wrapper
        cmd_parts = [
            "$HOME/.local/bin/goose",
            "-p", escaped_prompt,
        ]

        return " ".join(cmd_parts)

    async def is_available(self, check_command_exists: callable) -> bool:
        """Check if goose command exists."""
        # Check both goose in PATH and full path
        exists = await check_command_exists("goose")
        if not exists:
            # Try full path
            result = await check_command_exists("$HOME/.local/bin/goose")
            return result
        return True

    async def parse_output(self, line: str) -> Optional[StreamEvent]:
        """Parse Goose output.

        This is a placeholder implementation.
        Adjust based on actual Goose CLI output format.
        """
        if not line.strip():
            return None

        # Try to parse as JSON
        try:
            data = json.loads(line)
            event_type = data.get("type", "text")

            if event_type == "result":
                return StreamEvent(
                    type="complete",
                    content=data.get("result", ""),
                    raw_data=data
                )
            elif event_type == "assistant":
                message = data.get("message", {})
                content_list = message.get("content", [])
                for item in content_list:
                    if item.get("type") == "text":
                        return StreamEvent(
                            type="text",
                            content=item.get("text", ""),
                            raw_data=data
                        )
            return None
        except json.JSONDecodeError:
            # Plain text output
            return StreamEvent(type="text", content=line)

    def get_version_command(self) -> str:
        """Get command to check Goose version."""
        return "goose --version"
