"""Agent storage and management."""
import json
import os
from datetime import datetime
from typing import Optional, Dict, List
from pathlib import Path
import logging

from .models import AgentConfig

logger = logging.getLogger(__name__)


class AgentStore:
    """Manages agent configurations with persistence."""

    def __init__(self, storage_path: Optional[str] = None):
        self._agents: Dict[str, AgentConfig] = {}
        self._storage_path = storage_path or os.path.join(
            os.path.dirname(__file__), "..", "data", "agents.json"
        )
        self._load_from_disk()

    def _load_from_disk(self) -> None:
        """Load agents from disk if available."""
        try:
            if os.path.exists(self._storage_path):
                with open(self._storage_path, "r") as f:
                    data = json.load(f)
                    for agent_data in data.get("agents", []):
                        agent = AgentConfig(**agent_data)
                        self._agents[agent.id] = agent
                logger.info(f"Loaded {len(self._agents)} agents from disk")
        except Exception as e:
            logger.warning(f"Could not load agents from disk: {e}")

    def _save_to_disk(self) -> None:
        """Persist agents to disk."""
        try:
            os.makedirs(os.path.dirname(self._storage_path), exist_ok=True)
            data = {
                "agents": [agent.model_dump() for agent in self._agents.values()],
                "updated_at": datetime.utcnow().isoformat(),
            }
            with open(self._storage_path, "w") as f:
                json.dump(data, f, indent=2, default=str)
            logger.debug(f"Saved {len(self._agents)} agents to disk")
        except Exception as e:
            logger.error(f"Could not save agents to disk: {e}")

    def create(self, agent: AgentConfig) -> AgentConfig:
        """Create a new agent."""
        agent.created_at = datetime.utcnow()
        agent.updated_at = datetime.utcnow()
        self._agents[agent.id] = agent
        self._save_to_disk()
        logger.info(f"Created agent: {agent.id} - {agent.name}")
        return agent

    def get(self, agent_id: str) -> Optional[AgentConfig]:
        """Get an agent by ID."""
        return self._agents.get(agent_id)

    def update(self, agent_id: str, updates: dict) -> Optional[AgentConfig]:
        """Update an agent with partial data."""
        agent = self._agents.get(agent_id)
        if not agent:
            return None

        # Apply updates
        for key, value in updates.items():
            if hasattr(agent, key) and key not in ("id", "created_at"):
                setattr(agent, key, value)

        agent.updated_at = datetime.utcnow()
        self._save_to_disk()
        logger.info(f"Updated agent: {agent_id}")
        return agent

    def delete(self, agent_id: str) -> bool:
        """Delete an agent."""
        if agent_id in self._agents:
            del self._agents[agent_id]
            self._save_to_disk()
            logger.info(f"Deleted agent: {agent_id}")
            return True
        return False

    def list_all(self) -> List[AgentConfig]:
        """List all agents."""
        return list(self._agents.values())

    def get_count(self) -> int:
        """Get the number of agents."""
        return len(self._agents)

    def set_session(self, agent_id: str, session_id: Optional[str]) -> Optional[AgentConfig]:
        """Associate an agent with a session."""
        agent = self._agents.get(agent_id)
        if agent:
            agent.session_id = session_id
            agent.updated_at = datetime.utcnow()
            self._save_to_disk()
        return agent


# Global agent store
agent_store = AgentStore()
