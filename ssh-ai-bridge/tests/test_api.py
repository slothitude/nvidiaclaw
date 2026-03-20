"""Tests for API endpoints."""
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch, MagicMock

from main import app


class TestHealthEndpoint:
    """Tests for /health endpoint."""

    @pytest.mark.asyncio
    async def test_health_check_returns_healthy(self, async_client: AsyncClient):
        """Health check should return healthy status."""
        response = await async_client.get("/api/v1/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "active_sessions" in data
        assert "uptime_seconds" in data


class TestConnectEndpoint:
    """Tests for /connect endpoint."""

    @pytest.mark.asyncio
    async def test_connect_success(self, async_client: AsyncClient, mock_ssh_manager, mock_executor):
        """Test successful connection to server."""
        with patch("api.routes.ssh_manager", mock_ssh_manager), \
             patch("api.routes.executor", mock_executor):

            mock_ssh_manager.connect = AsyncMock()
            mock_ssh_manager.disconnect = AsyncMock()

            response = await async_client.post(
                "/api/v1/connect",
                json={
                    "host": "192.168.1.100",
                    "username": "testuser",
                    "ssh_key_path": "/home/user/.ssh/id_rsa",
                    "ai_cli": "auto",
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert "session_id" in data
            assert "ai_cli_detected" in data

    @pytest.mark.asyncio
    async def test_connect_invalid_host(self, async_client: AsyncClient, mock_ssh_manager):
        """Test connection failure with invalid host."""
        with patch("api.routes.ssh_manager", mock_ssh_manager):
            mock_ssh_manager.connect = AsyncMock(
                side_effect=ConnectionError("Failed to connect")
            )

            response = await async_client.post(
                "/api/v1/connect",
                json={
                    "host": "invalid-host",
                    "username": "testuser",
                    "ai_cli": "claude",
                }
            )

            assert response.status_code == 503


class TestChatEndpoint:
    """Tests for /chat endpoint."""

    @pytest.mark.asyncio
    async def test_chat_requires_session(self, async_client: AsyncClient):
        """Chat should fail without valid session."""
        response = await async_client.post(
            "/api/v1/chat",
            json={
                "session_id": "nonexistent",
                "message": "Hello",
            }
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_chat_with_valid_session(self, async_client: AsyncClient, mock_ssh_manager):
        """Test chat with valid session."""
        from session.store import session_store
        from ai.claude import ClaudeCodePlugin

        # Create a mock session
        session = session_store.create_session(
            host="test.local",
            username="test",
            ai_cli="claude",
        )
        session.ai_plugin = ClaudeCodePlugin()

        with patch("api.routes.ssh_manager", mock_ssh_manager):
            mock_ssh_manager.execute_command = AsyncMock(
                return_value=(0, '{"type": "text", "content": "Hello!"}', "")
            )

            response = await async_client.post(
                "/api/v1/chat",
                json={
                    "session_id": session.session_id,
                    "message": "Hello",
                }
            )

            assert response.status_code == 200
            data = response.json()
            assert "response" in data
            assert data["status"] == "complete"

        # Cleanup
        session_store.delete_session(session.session_id)


class TestDisconnectEndpoint:
    """Tests for /disconnect endpoint."""

    @pytest.mark.asyncio
    async def test_disconnect_success(self, async_client: AsyncClient, mock_ssh_manager):
        """Test successful disconnect."""
        with patch("api.routes.ssh_manager", mock_ssh_manager):
            response = await async_client.post(
                "/api/v1/disconnect?session_id=test-session-id"
            )

            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "disconnected"


class TestServersEndpoint:
    """Tests for /servers endpoint."""

    @pytest.mark.asyncio
    async def test_list_servers_empty(self, async_client: AsyncClient):
        """Test listing servers when none connected."""
        response = await async_client.get("/api/v1/servers")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
