"""Pydantic models for API request/response schemas."""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class AICLIType(str, Enum):
    """Supported AI CLI types."""
    CLAUDE = "claude"
    GOOSE = "goose"
    AUTO = "auto"


class ConnectRequest(BaseModel):
    """Request to establish SSH connection."""
    host: str = Field(..., description="SSH server hostname or IP")
    username: str = Field(..., description="SSH username")
    ssh_key: Optional[str] = Field(None, description="Base64-encoded SSH private key")
    ssh_key_path: Optional[str] = Field(None, description="Path to SSH key file")
    password: Optional[str] = Field(None, description="SSH password (if not using key)")
    ai_cli: AICLIType = Field(AICLIType.AUTO, description="Preferred AI CLI")
    port: int = Field(22, description="SSH port")


class ConnectResponse(BaseModel):
    """Response after successful connection."""
    session_id: str = Field(..., description="Unique session identifier")
    ai_cli_detected: str = Field(..., description="Detected AI CLI on server")
    server_info: Optional[str] = Field(None, description="Server information")


class ChatRequest(BaseModel):
    """Request to send a chat message."""
    session_id: str = Field(..., description="Session identifier")
    message: str = Field(..., description="User message to AI")
    context_files: Optional[List[str]] = Field(default_factory=list, description="Optional context files")


class ChatResponse(BaseModel):
    """Response from chat endpoint."""
    response: str = Field(..., description="AI response text")
    status: str = Field(..., description="Response status (complete, error)")
    session_id: str = Field(..., description="Session identifier")


class ConfirmRequest(BaseModel):
    """Request to respond to an interactive prompt."""
    session_id: str = Field(..., description="Session identifier")
    prompt_id: str = Field(..., description="Prompt identifier")
    response: str = Field(..., description="User's response to prompt")


class ServerInfo(BaseModel):
    """Information about a connected server."""
    session_id: str
    host: str
    username: str
    ai_cli: str
    connected_at: datetime
    last_activity: datetime


class HealthResponse(BaseModel):
    """Health check response."""
    status: str = "healthy"
    active_sessions: int = 0
    uptime_seconds: float = 0.0


class StreamChunk(BaseModel):
    """A chunk of streaming response."""
    type: str = Field(..., description="Chunk type: thinking, text, tool_use, complete, error, prompt")
    content: Optional[str] = Field(None, description="Text content")
    tool: Optional[str] = Field(None, description="Tool name if type is tool_use")
    path: Optional[str] = Field(None, description="File path if applicable")
    prompt_type: Optional[str] = Field(None, description="Prompt type if type is prompt")
    prompt_id: Optional[str] = Field(None, description="Prompt ID for response")
    message: Optional[str] = Field(None, description="Message for prompts/errors")
