"""Base provider interface for AI backends."""
from abc import ABC, abstractmethod
from typing import AsyncIterator, Optional
from pydantic import BaseModel


class ProviderConfig(BaseModel):
    """Base configuration for providers."""
    api_key: str = ""
    base_url: str = ""
    default_model: str = ""
    timeout: float = 60.0


class ChatMessage(BaseModel):
    """Chat message structure."""
    role: str  # system, user, assistant
    content: str


class StreamChunk(BaseModel):
    """Streaming response chunk."""
    type: str  # text, thinking, tool_use, complete, error
    content: str = ""
    tool: Optional[str] = None
    path: Optional[str] = None


class BaseProvider(ABC):
    """Abstract base class for AI providers."""

    def __init__(self, config: ProviderConfig):
        self.config = config

    @abstractmethod
    async def chat(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> str:
        """Non-streaming chat completion."""
        pass

    @abstractmethod
    async def chat_stream(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> AsyncIterator[StreamChunk]:
        """Streaming chat completion."""
        pass

    @abstractmethod
    async def is_available(self) -> bool:
        """Check if provider is available."""
        pass
