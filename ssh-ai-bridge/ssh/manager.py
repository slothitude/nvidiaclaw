"""SSH connection management with asyncssh."""
import asyncssh
import asyncio
import base64
from typing import Optional, Dict, Any
from datetime import datetime
from dataclasses import dataclass, field
import logging

from config import settings

logger = logging.getLogger(__name__)


@dataclass
class SSHConnection:
    """Represents an active SSH connection."""
    session_id: str
    host: str
    username: str
    port: int
    conn: asyncssh.SSHClientConnection
    connected_at: datetime = field(default_factory=datetime.utcnow)
    last_activity: datetime = field(default_factory=datetime.utcnow)

    def touch(self):
        """Update last activity timestamp."""
        self.last_activity = datetime.utcnow()


class SSHManager:
    """Manages SSH connections with pooling and reconnection logic."""

    def __init__(self):
        self._connections: Dict[str, SSHConnection] = {}
        self._lock = asyncio.Lock()

    async def connect(
        self,
        session_id: str,
        host: str,
        username: str,
        port: int = 22,
        ssh_key: Optional[str] = None,
        ssh_key_path: Optional[str] = None,
        password: Optional[str] = None,
    ) -> SSHConnection:
        """Establish a new SSH connection."""
        async with self._lock:
            if len(self._connections) >= settings.max_sessions:
                # Remove oldest inactive connection
                oldest = min(self._connections.values(), key=lambda c: c.last_activity)
                await self.disconnect(oldest.session_id)

            # Prepare authentication
            kwargs: Dict[str, Any] = {
                "host": host,
                "port": port,
                "username": username,
                "known_hosts": None,  # Disable host key checking for dev
            }

            if ssh_key:
                # Decode base64 key
                key_data = base64.b64decode(ssh_key)
                kwargs["client_keys"] = [asyncssh.import_private_key(key_data.decode())]
            elif ssh_key_path:
                kwargs["client_keys"] = [ssh_key_path]
            elif password:
                kwargs["password"] = password
            else:
                # Try default ssh-agent or default key
                kwargs["client_keys"] = None

            try:
                # Use asyncio.wait_for for connection timeout
                conn = await asyncio.wait_for(
                    asyncssh.connect(**kwargs),
                    timeout=settings.ssh_timeout
                )

                ssh_conn = SSHConnection(
                    session_id=session_id,
                    host=host,
                    username=username,
                    port=port,
                    conn=conn,
                )

                self._connections[session_id] = ssh_conn
                logger.info(f"SSH connection established: {session_id} -> {username}@{host}")
                return ssh_conn

            except asyncssh.Error as e:
                logger.error(f"SSH connection failed: {e}")
                raise ConnectionError(f"Failed to connect to {host}: {e}")

    async def disconnect(self, session_id: str) -> bool:
        """Close and remove an SSH connection."""
        async with self._lock:
            if session_id in self._connections:
                conn = self._connections.pop(session_id)
                conn.conn.close()
                logger.info(f"SSH connection closed: {session_id}")
                return True
            return False

    def get_connection(self, session_id: str) -> Optional[SSHConnection]:
        """Get an active connection by session ID."""
        conn = self._connections.get(session_id)
        if conn:
            conn.touch()
        return conn

    async def execute_command(
        self,
        session_id: str,
        command: str,
        timeout: Optional[int] = None,
    ) -> tuple[int, str, str]:
        """Execute a command on a connected server."""
        conn = self.get_connection(session_id)
        if not conn:
            raise ValueError(f"No active connection for session: {session_id}")

        timeout = timeout or settings.command_timeout

        try:
            result = await asyncio.wait_for(
                conn.conn.run(command),
                timeout=timeout
            )
            conn.touch()
            return result.exit_status, result.stdout, result.stderr
        except asyncio.TimeoutError:
            logger.error(f"Command timed out after {timeout}s: {command[:100]}")
            raise TimeoutError(f"Command timed out after {timeout} seconds")
        except asyncssh.Error as e:
            logger.error(f"Command execution failed: {e}")
            raise RuntimeError(f"Command execution failed: {e}")

    async def execute_stream(
        self,
        session_id: str,
        command: str,
        timeout: Optional[int] = None,
    ):
        """Execute a command and stream output line by line."""
        conn = self.get_connection(session_id)
        if not conn:
            raise ValueError(f"No active connection for session: {session_id}")

        timeout = timeout or settings.command_timeout

        try:
            # Create a process for streaming
            process = await asyncio.wait_for(
                conn.conn.create_process(command),
                timeout=timeout
            )
            conn.touch()

            # Stream stdout line by line
            while True:
                try:
                    line = await asyncio.wait_for(
                        process.stdout.readline(),
                        timeout=timeout
                    )
                    if not line:
                        break
                    yield line.rstrip('\n')
                except asyncio.TimeoutError:
                    break

            # Wait for process to complete
            await process.wait()
            conn.touch()

        except asyncssh.Error as e:
            logger.error(f"Stream execution failed: {e}")
            raise RuntimeError(f"Stream execution failed: {e}")

    def list_connections(self) -> list[SSHConnection]:
        """List all active connections."""
        return list(self._connections.values())

    async def close_all(self):
        """Close all connections."""
        async with self._lock:
            for session_id in list(self._connections.keys()):
                await self.disconnect(session_id)


# Global SSH manager instance
ssh_manager = SSHManager()
