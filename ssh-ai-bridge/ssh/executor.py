"""Command execution utilities for SSH."""
import asyncio
import shlex
from typing import AsyncIterator, Optional
import logging

from .manager import SSHManager

logger = logging.getLogger(__name__)


class CommandExecutor:
    """High-level command execution on remote servers."""

    def __init__(self, ssh_manager: SSHManager):
        self.ssh_manager = ssh_manager

    async def run_command(
        self,
        session_id: str,
        command: str,
        timeout: Optional[int] = None,
    ) -> tuple[int, str, str]:
        """Run a command and return exit code, stdout, stderr."""
        return await self.ssh_manager.execute_command(session_id, command, timeout)

    async def run_streaming(
        self,
        session_id: str,
        command: str,
        timeout: Optional[int] = None,
    ) -> AsyncIterator[str]:
        """Run a command and yield output lines."""
        async for line in self.ssh_manager.execute_stream(session_id, command, timeout):
            yield line

    async def check_command_exists(self, session_id: str, command: str) -> bool:
        """Check if a command exists on the remote server."""
        exit_code, _, _ = await self.run_command(
            session_id,
            f"which {shlex.quote(command)}",
            timeout=10
        )
        return exit_code == 0

    async def get_server_info(self, session_id: str) -> dict:
        """Get basic server information."""
        info = {}

        # Get hostname
        _, hostname, _ = await self.run_command(session_id, "hostname", timeout=10)
        info["hostname"] = hostname.strip()

        # Get OS info
        _, os_info, _ = await self.run_command(
            session_id,
            "cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2",
            timeout=10
        )
        info["os"] = os_info.strip().strip('"')

        # Get current directory
        _, cwd, _ = await self.run_command(session_id, "pwd", timeout=10)
        info["cwd"] = cwd.strip()

        return info

    async def detect_ai_clis(self, session_id: str) -> dict[str, bool]:
        """Detect which AI CLIs are available on the server."""
        clis = {}

        # Check for claude
        clis["claude"] = await self.check_command_exists(session_id, "claude")

        # Check for goose (try PATH first, then common locations)
        goose_exists = await self.check_command_exists(session_id, "goose")
        if not goose_exists:
            # Check in ~/.local/bin
            exit_code, _, _ = await self.run_command(
                session_id,
                "test -x $HOME/.local/bin/goose",
                timeout=10
            )
            goose_exists = exit_code == 0
        clis["goose"] = goose_exists

        # Check for other common AI tools
        clis["aider"] = await self.check_command_exists(session_id, "aider")
        clis["cursor"] = await self.check_command_exists(session_id, "cursor")

        return clis


# Global executor instance
from .manager import ssh_manager
executor = CommandExecutor(ssh_manager)
