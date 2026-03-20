"""Session storage and management."""
import uuid
from datetime import datetime
from typing import Optional, Dict, List, Any
from dataclasses import dataclass, field
import asyncio
import logging

from config import settings
from ai.base import AICLIPlugin

logger = logging.getLogger(__name__)


@dataclass
class Message:
    """A message in the conversation history."""
    role: str  # "user" or "assistant"
    content: str
    timestamp: datetime = field(default_factory=datetime.utcnow)
    metadata: dict = field(default_factory=dict)


@dataclass
class Session:
    """Represents an active AI session."""
    session_id: str
    host: str
    username: str
    ai_cli: str
    ai_plugin: Optional[AICLIPlugin] = None
    connected_at: datetime = field(default_factory=datetime.utcnow)
    last_activity: datetime = field(default_factory=datetime.utcnow)
    conversation_history: List[Message] = field(default_factory=list)
    pending_prompts: Dict[str, dict] = field(default_factory=dict)
    metadata: dict = field(default_factory=dict)

    def touch(self):
        """Update last activity timestamp."""
        self.last_activity = datetime.utcnow()

    def add_message(self, role: str, content: str, metadata: Optional[dict] = None):
        """Add a message to the conversation history."""
        self.conversation_history.append(Message(
            role=role,
            content=content,
            metadata=metadata or {}
        ))
        self.touch()

        # Trim history if too long
        if len(self.conversation_history) > settings.session_timeout:
            self.conversation_history = self.conversation_history[-settings.session_timeout:]

    def get_context_for_prompt(self) -> str:
        """Build context string from conversation history."""
        if not self.conversation_history:
            return ""

        lines = []
        for msg in self.conversation_history[-10:]:  # Last 10 messages
            lines.append(f"{msg.role}: {msg.content}")

        return "\n".join(lines)


class SessionStore:
    """Manages active sessions."""

    def __init__(self):
        self._sessions: Dict[str, Session] = {}
        self._lock = asyncio.Lock()

    def create_session(
        self,
        host: str,
        username: str,
        ai_cli: str,
        ai_plugin: Optional[AICLIPlugin] = None,
    ) -> Session:
        """Create a new session."""
        session_id = str(uuid.uuid4())
        session = Session(
            session_id=session_id,
            host=host,
            username=username,
            ai_cli=ai_cli,
            ai_plugin=ai_plugin,
        )
        self._sessions[session_id] = session
        logger.info(f"Created session: {session_id}")
        return session

    def get_session(self, session_id: str) -> Optional[Session]:
        """Get a session by ID."""
        session = self._sessions.get(session_id)
        if session:
            session.touch()
        return session

    def delete_session(self, session_id: str) -> bool:
        """Delete a session."""
        if session_id in self._sessions:
            del self._sessions[session_id]
            logger.info(f"Deleted session: {session_id}")
            return True
        return False

    def list_sessions(self) -> List[Session]:
        """List all active sessions."""
        return list(self._sessions.values())

    async def cleanup_expired(self):
        """Remove expired sessions."""
        async with self._lock:
            now = datetime.utcnow()
            expired = []

            for session_id, session in self._sessions.items():
                age = (now - session.last_activity).total_seconds()
                if age > settings.session_timeout:
                    expired.append(session_id)

            for session_id in expired:
                self.delete_session(session_id)
                logger.info(f"Cleaned up expired session: {session_id}")

    def get_session_count(self) -> int:
        """Get the number of active sessions."""
        return len(self._sessions)


# Global session store
session_store = SessionStore()
