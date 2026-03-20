"""Abstract base class for AI CLI plugins."""
from abc import ABC, abstractmethod
from typing import AsyncIterator, Optional, Any
from dataclasses import dataclass


@dataclass
class StreamEvent:
    """Represents a streaming event from an AI CLI."""
    type: str  # thinking, text, tool_use, complete, error, prompt
    content: Optional[str] = None
    tool: Optional[str] = None
    path: Optional[str] = None
    prompt_type: Optional[str] = None
    prompt_id: Optional[str] = None
    raw_data: Optional[dict] = None


class AICLIPlugin(ABC):
    """Abstract base class for AI CLI plugins."""

    @abstractmethod
    def get_name(self) -> str:
        """Return the plugin name."""
        pass

    @abstractmethod
    def get_command(self, prompt: str, context: dict) -> str:
        """Build the command to execute the AI CLI.

        Args:
            prompt: The user's prompt/message
            context: Additional context (files, settings, etc.)

        Returns:
            The shell command to execute
        """
        pass

    @abstractmethod
    async def is_available(self, check_command_exists: callable) -> bool:
        """Check if this AI CLI is available on the server.

        Args:
            check_command_exists: Async function that checks if a command exists

        Returns:
            True if the CLI is available
        """
        pass

    @abstractmethod
    async def parse_output(self, line: str) -> Optional[StreamEvent]:
        """Parse a line of output from the AI CLI.

        Args:
            line: A line of output from the CLI

        Returns:
            A StreamEvent if the line contains parseable data, None otherwise
        """
        pass

    async def execute(
        self,
        run_streaming: callable,
        prompt: str,
        context: dict,
    ) -> AsyncIterator[StreamEvent]:
        """Execute the AI CLI and yield streaming events.

        Args:
            run_streaming: Async function that yields command output lines
            prompt: The user's prompt/message
            context: Additional context

        Yields:
            StreamEvent objects
        """
        command = self.get_command(prompt, context)

        async for line in run_streaming(command):
            event = await self.parse_output(line)
            if event:
                yield event

        # Yield completion event
        yield StreamEvent(type="complete")
