"""FastAPI routes for SSH AI Bridge."""
import asyncio
import json
from datetime import datetime
from typing import Optional
import logging

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from sse_starlette.sse import EventSourceResponse

from config import settings
from .schemas import (
    ConnectRequest,
    ConnectResponse,
    ChatRequest,
    ChatResponse,
    ConfirmRequest,
    ServerInfo,
    HealthResponse,
    StreamChunk,
    AICLIType,
)
from ssh.manager import ssh_manager
from ssh.executor import executor
from ai import get_plugin, PLUGINS
from session.store import session_store

logger = logging.getLogger(__name__)

router = APIRouter()

# Track server start time
_start_time = datetime.utcnow()


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    uptime = (datetime.utcnow() - _start_time).total_seconds()
    return HealthResponse(
        status="healthy",
        active_sessions=session_store.get_session_count(),
        uptime_seconds=uptime,
    )


@router.get("/servers", response_model=list[ServerInfo])
async def list_servers():
    """List all connected servers."""
    sessions = session_store.list_sessions()
    return [
        ServerInfo(
            session_id=s.session_id,
            host=s.host,
            username=s.username,
            ai_cli=s.ai_cli,
            connected_at=s.connected_at,
            last_activity=s.last_activity,
        )
        for s in sessions
    ]


@router.post("/connect", response_model=ConnectResponse)
async def connect_to_server(request: ConnectRequest):
    """Establish SSH connection to a server."""
    try:
        # Create session first
        session = session_store.create_session(
            host=request.host,
            username=request.username,
            ai_cli=request.ai_cli.value,
        )

        # Establish SSH connection
        await ssh_manager.connect(
            session_id=session.session_id,
            host=request.host,
            username=request.username,
            port=request.port,
            ssh_key=request.ssh_key,
            ssh_key_path=request.ssh_key_path,
            password=request.password,
        )

        # Detect available AI CLIs
        available_clis = await executor.detect_ai_clis(session.session_id)

        # Determine which CLI to use
        detected_cli = None
        if request.ai_cli == AICLIType.AUTO:
            # Auto-detect: prefer Claude, then Goose
            for cli_name in ["claude", "goose"]:
                if available_clis.get(cli_name):
                    detected_cli = cli_name
                    break
            # If no AI CLI found, still allow connection for basic commands
            if not detected_cli:
                detected_cli = "none"
        else:
            cli_name = request.ai_cli.value
            if available_clis.get(cli_name):
                detected_cli = cli_name
            else:
                await ssh_manager.disconnect(session.session_id)
                session_store.delete_session(session.session_id)
                raise HTTPException(
                    status_code=400,
                    detail=f"Requested AI CLI '{cli_name}' not found on server. Available: {available_clis}"
                )

        if not detected_cli:
            detected_cli = "none"

        # Initialize the AI plugin (if available)
        if detected_cli != "none":
            plugin_class = get_plugin(detected_cli)
            session.ai_plugin = plugin_class()
        session.ai_cli = detected_cli

        # Get server info
        server_info = await executor.get_server_info(session.session_id)

        return ConnectResponse(
            session_id=session.session_id,
            ai_cli_detected=detected_cli,
            server_info=f"{server_info.get('hostname', request.host)} ({server_info.get('os', 'unknown')})",
        )

    except ConnectionError as e:
        logger.error(f"Connection failed: {e}")
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error during connection: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/execute")
async def execute_command(session_id: str = Query(...), command: str = Query(...)):
    """Execute a raw command on the remote server (for testing)."""
    session = session_store.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    try:
        exit_code, stdout, stderr = await ssh_manager.execute_command(session_id, command)
        return {
            "exit_code": exit_code,
            "stdout": stdout,
            "stderr": stderr,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/disconnect")
async def disconnect_from_server(session_id: str = Query(...)):
    """Close SSH connection."""
    await ssh_manager.disconnect(session_id)
    session_store.delete_session(session_id)
    return {"status": "disconnected", "session_id": session_id}


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Send a message to the AI and get a response (non-streaming)."""
    session = session_store.get_session(request.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if not session.ai_plugin:
        raise HTTPException(status_code=400, detail="No AI CLI configured for this session")

    # Add user message to history
    session.add_message("user", request.message)

    try:
        # Build and execute command
        context = {"context_files": request.context_files or []}
        command = session.ai_plugin.get_command(request.message, context)

        exit_code, stdout, stderr = await ssh_manager.execute_command(
            request.session_id,
            command,
        )

        # Parse response
        response_text = stdout.strip()

        # Try to extract text from JSON if applicable
        try:
            lines = stdout.strip().split('\n')
            final_result = None
            for line in lines:
                if line.strip():
                    try:
                        data = json.loads(line)
                        # The "result" type contains the final response
                        if data.get("type") == "result":
                            final_result = data.get("result", "")
                    except json.JSONDecodeError:
                        pass

            if final_result:
                response_text = final_result
        except Exception:
            pass

        # Add response to history
        session.add_message("assistant", response_text)

        return ChatResponse(
            response=response_text,
            status="complete" if exit_code == 0 else "error",
            session_id=request.session_id,
        )

    except TimeoutError as e:
        raise HTTPException(status_code=504, detail=str(e))
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/chat/stream")
async def chat_stream(
    session_id: str = Query(...),
    message: str = Query(...),
    context_files: Optional[str] = Query(None),
):
    """Stream AI response via Server-Sent Events."""
    session = session_store.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if not session.ai_plugin:
        raise HTTPException(status_code=400, detail="No AI CLI configured for this session")

    # Parse context files
    files = context_files.split(",") if context_files else []

    async def event_generator():
        """Generate SSE events from AI output."""
        try:
            # Add user message to history
            session.add_message("user", message)

            context = {"context_files": files}
            command = session.ai_plugin.get_command(message, context)

            full_response = []

            async for line in ssh_manager.execute_stream(session_id, command):
                event = await session.ai_plugin.parse_output(line)
                if event:
                    chunk = StreamChunk(
                        type=event.type,
                        content=event.content,
                        tool=event.tool,
                        path=event.path,
                        prompt_type=event.prompt_type,
                        prompt_id=event.prompt_id,
                    )

                    if event.content:
                        full_response.append(event.content)

                    yield {"data": chunk.model_dump_json(exclude_none=True)}

            # Add response to history
            session.add_message("assistant", "\n".join(full_response))

            # Send completion
            yield {"data": StreamChunk(type="complete").model_dump_json()}

        except TimeoutError:
            yield {"data": StreamChunk(type="error", content="Request timed out").model_dump_json()}
        except Exception as e:
            logger.error(f"Stream error: {e}")
            yield {"data": StreamChunk(type="error", content=str(e)).model_dump_json()}

    return EventSourceResponse(event_generator())


@router.post("/chat/confirm")
async def confirm_prompt(request: ConfirmRequest):
    """Respond to an interactive prompt from the AI."""
    session = session_store.get_session(request.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # For now, this is a placeholder - full implementation would need
    # to integrate with the streaming process to inject responses
    # This would require more complex state management

    pending = session.pending_prompts.get(request.prompt_id)
    if not pending:
        raise HTTPException(status_code=404, detail="Prompt not found or expired")

    # Store the response for the streaming handler to pick up
    pending["response"] = request.response
    pending["resolved"] = True

    return {"status": "confirmed", "prompt_id": request.prompt_id}
