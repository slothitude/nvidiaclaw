"""Integration tests for SSH AI Bridge."""
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch, MagicMock
import json

from main import app


@pytest.mark.integration
class TestFullFlow:
    """Full integration tests (require --run-integration flag)."""

    @pytest.mark.asyncio
    async def test_connect_chat_disconnect_flow(self, async_client: AsyncClient):
        """Test complete flow: connect, chat, disconnect."""
        # Mock SSH connection
        mock_conn = MagicMock()
        mock_conn.close = MagicMock()
        mock_conn.run = AsyncMock()
        mock_result = MagicMock()
        mock_result.exit_status = 0
        mock_result.stdout = json.dumps({"type": "text", "content": "Hello!"})
        mock_result.stderr = ""
        mock_conn.run.return_value = mock_result

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            # Step 1: Connect
            connect_response = await async_client.post(
                "/api/v1/connect",
                json={
                    "host": "test.local",
                    "username": "testuser",
                    "ai_cli": "auto",
                }
            )

            assert connect_response.status_code == 200
            connect_data = connect_response.json()
            session_id = connect_data["session_id"]
            assert session_id is not None

            # Step 2: Chat
            chat_response = await async_client.post(
                "/api/v1/chat",
                json={
                    "session_id": session_id,
                    "message": "Hello, AI!",
                }
            )

            assert chat_response.status_code == 200
            chat_data = chat_response.json()
            assert "response" in chat_data

            # Step 3: Disconnect
            disconnect_response = await async_client.post(
                f"/api/v1/disconnect?session_id={session_id}"
            )

            assert disconnect_response.status_code == 200
            disconnect_data = disconnect_response.json()
            assert disconnect_data["status"] == "disconnected"

    @pytest.mark.asyncio
    async def test_multiple_sessions(self, async_client: AsyncClient):
        """Test handling multiple concurrent sessions."""
        mock_conn = MagicMock()
        mock_conn.close = MagicMock()

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            # Create two sessions
            response1 = await async_client.post(
                "/api/v1/connect",
                json={"host": "server1.local", "username": "user1", "ai_cli": "auto"}
            )
            response2 = await async_client.post(
                "/api/v1/connect",
                json={"host": "server2.local", "username": "user2", "ai_cli": "auto"}
            )

            assert response1.status_code == 200
            assert response2.status_code == 200

            session1 = response1.json()["session_id"]
            session2 = response2.json()["session_id"]
            assert session1 != session2

            # List servers
            servers_response = await async_client.get("/api/v1/servers")
            servers = servers_response.json()
            assert len(servers) >= 2

            # Cleanup
            await async_client.post(f"/api/v1/disconnect?session_id={session1}")
            await async_client.post(f"/api/v1/disconnect?session_id={session2}")


@pytest.mark.integration
class TestStreamingFlow:
    """Tests for SSE streaming."""

    @pytest.mark.asyncio
    async def test_chat_streaming(self, async_client: AsyncClient):
        """Test streaming chat response."""
        mock_conn = MagicMock()
        mock_conn.close = MagicMock()

        # Mock streaming process
        mock_process = MagicMock()
        mock_process.wait = AsyncMock()

        # Create async generator for stdout
        async def mock_readline():
            lines = [
                json.dumps({"type": "thinking", "content": "Thinking..."}),
                json.dumps({"type": "text", "content": "Hello!"}),
                "",  # End
            ]
            for line in lines:
                yield line

        mock_process.stdout.readline = mock_readline().__anext__
        mock_conn.create_process = AsyncMock(return_value=mock_process)

        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            mock_connect.return_value = mock_conn

            # Connect first
            connect_response = await async_client.post(
                "/api/v1/connect",
                json={"host": "test.local", "username": "testuser", "ai_cli": "auto"}
            )
            session_id = connect_response.json()["session_id"]

            # Stream chat
            stream_response = await async_client.get(
                f"/api/v1/chat/stream?session_id={session_id}&message=Hello"
            )

            assert stream_response.status_code == 200
            # SSE content type
            assert "text/event-stream" in stream_response.headers.get("content-type", "")

            # Cleanup
            await async_client.post(f"/api/v1/disconnect?session_id={session_id}")


@pytest.mark.integration
class TestErrorHandling:
    """Tests for error handling."""

    @pytest.mark.asyncio
    async def test_connection_timeout(self, async_client: AsyncClient):
        """Test handling connection timeout."""
        with patch("asyncssh.connect", new_callable=AsyncMock) as mock_connect:
            import asyncio
            mock_connect.side_effect = asyncio.TimeoutError()

            response = await async_client.post(
                "/api/v1/connect",
                json={"host": "slow.local", "username": "testuser", "ai_cli": "auto"}
            )

            assert response.status_code == 503

    @pytest.mark.asyncio
    async def test_chat_without_session(self, async_client: AsyncClient):
        """Test chat without valid session."""
        response = await async_client.post(
            "/api/v1/chat",
            json={"session_id": "nonexistent", "message": "Hello"}
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_invalid_ai_cli(self, async_client: AsyncClient):
        """Test with invalid AI CLI choice."""
        response = await async_client.post(
            "/api/v1/connect",
            json={
                "host": "test.local",
                "username": "testuser",
                "ai_cli": "invalid_cli"  # Invalid
            }
        )

        # Should fail validation
        assert response.status_code == 422
