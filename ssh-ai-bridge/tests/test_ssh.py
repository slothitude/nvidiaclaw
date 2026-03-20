"""Tests for SSH manager and executor."""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
import asyncssh

from ssh.manager import SSHManager, SSHConnection
from ssh.executor import CommandExecutor


class TestSSHManager:
    """Tests for SSH connection manager."""

    @pytest.mark.asyncio
    async def test_connect_success(self):
        """Test successful SSH connection."""
        manager = SSHManager()

        mock_conn = MagicMock()
        mock_conn.close = MagicMock()

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            result = await manager.connect(
                session_id="test-session",
                host="test.local",
                username="testuser",
                port=22,
            )

            assert result.session_id == "test-session"
            assert result.host == "test.local"
            assert result.username == "testuser"
            mock_connect.assert_called_once()

    @pytest.mark.asyncio
    async def test_connect_with_password(self):
        """Test SSH connection with password authentication."""
        manager = SSHManager()

        mock_conn = MagicMock()
        mock_conn.close = MagicMock()

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            result = await manager.connect(
                session_id="test-session",
                host="test.local",
                username="testuser",
                password="testpass",
            )

            assert result is not None
            call_kwargs = mock_connect.call_args[1]
            assert call_kwargs.get("password") == "testpass"

    @pytest.mark.asyncio
    async def test_connect_failure(self):
        """Test SSH connection failure."""
        manager = SSHManager()

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.side_effect = asyncssh.Error("Connection refused")

            with pytest.raises(ConnectionError):
                await manager.connect(
                    session_id="test-session",
                    host="invalid-host",
                    username="testuser",
                )

    @pytest.mark.asyncio
    async def test_disconnect(self):
        """Test SSH disconnection."""
        manager = SSHManager()

        mock_conn = MagicMock()
        mock_conn.close = MagicMock()

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            await manager.connect(
                session_id="test-session",
                host="test.local",
                username="testuser",
            )

            result = await manager.disconnect("test-session")
            assert result is True
            mock_conn.close.assert_called_once()

    @pytest.mark.asyncio
    async def test_disconnect_nonexistent(self):
        """Test disconnecting nonexistent session."""
        manager = SSHManager()
        result = await manager.disconnect("nonexistent")
        assert result is False

    @pytest.mark.asyncio
    async def test_max_sessions_limit(self):
        """Test that max sessions limit is enforced."""
        from config import settings

        manager = SSHManager()

        mock_conn = MagicMock()
        mock_conn.close = MagicMock()

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            # Create sessions up to the limit
            original_max = settings.max_sessions
            settings.max_sessions = 2

            try:
                await manager.connect("session-1", "host1", "user1")
                await manager.connect("session-2", "host2", "user2")
                # This should evict the oldest
                await manager.connect("session-3", "host3", "user3")

                assert len(manager.list_connections()) == 2
                assert manager.get_connection("session-1") is None
            finally:
                settings.max_sessions = original_max

    @pytest.mark.asyncio
    async def test_execute_command(self):
        """Test command execution."""
        manager = SSHManager()

        mock_conn = MagicMock()
        mock_conn.run = AsyncMock()
        mock_result = MagicMock()
        mock_result.exit_status = 0
        mock_result.stdout = "output"
        mock_result.stderr = ""
        mock_conn.run.return_value = mock_result

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            await manager.connect(
                session_id="test-session",
                host="test.local",
                username="testuser",
            )

            exit_code, stdout, stderr = await manager.execute_command(
                "test-session",
                "echo hello"
            )

            assert exit_code == 0
            assert stdout == "output"
            mock_conn.run.assert_called_once_with("echo hello")

    @pytest.mark.asyncio
    async def test_execute_command_no_session(self):
        """Test command execution without valid session."""
        manager = SSHManager()

        with pytest.raises(ValueError, match="No active connection"):
            await manager.execute_command("nonexistent", "echo hello")


class TestCommandExecutor:
    """Tests for command executor."""

    @pytest.mark.asyncio
    async def test_check_command_exists(self):
        """Test checking if command exists."""
        mock_manager = MagicMock()
        mock_manager.execute_command = AsyncMock(return_value=(0, "/usr/bin/ls", ""))

        executor = CommandExecutor(mock_manager)
        result = await executor.check_command_exists("test-session", "ls")

        assert result is True

    @pytest.mark.asyncio
    async def test_check_command_not_exists(self):
        """Test checking if command doesn't exist."""
        mock_manager = MagicMock()
        mock_manager.execute_command = AsyncMock(return_value=(1, "", "not found"))

        executor = CommandExecutor(mock_manager)
        result = await executor.check_command_exists("test-session", "nonexistent")

        assert result is False

    @pytest.mark.asyncio
    async def test_detect_ai_clis(self):
        """Test AI CLI detection."""
        mock_manager = MagicMock()

        async def mock_execute(session_id, cmd, timeout=None):
            if "claude" in cmd:
                return (0, "/usr/bin/claude", "")
            elif "goose" in cmd:
                return (1, "", "not found")
            elif "aider" in cmd:
                return (0, "/usr/bin/aider", "")
            return (1, "", "not found")

        mock_manager.execute_command = mock_execute

        executor = CommandExecutor(mock_manager)
        result = await executor.detect_ai_clis("test-session")

        assert result["claude"] is True
        assert result["goose"] is False
        assert result["aider"] is True

    @pytest.mark.asyncio
    async def test_get_server_info(self):
        """Test getting server info."""
        mock_manager = MagicMock()

        async def mock_execute(session_id, cmd, timeout=None):
            if "hostname" in cmd:
                return (0, "test-server\n", "")
            elif "os-release" in cmd:
                return (0, 'PRETTY_NAME="Ubuntu 22.04"\n', "")
            elif "pwd" in cmd:
                return (0, "/home/test\n", "")
            return (1, "", "")

        mock_manager.execute_command = mock_execute

        executor = CommandExecutor(mock_manager)
        result = await executor.get_server_info("test-session")

        assert result["hostname"] == "test-server"
        assert "Ubuntu" in result["os"]
        assert result["cwd"] == "/home/test"
