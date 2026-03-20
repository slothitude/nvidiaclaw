"""Agent CRUD API routes."""
from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
import logging

from .models import (
    AgentConfig,
    AgentSkill,
    AgentTool,
    SkillRegistry,
    ToolRegistry,
    AICLIType,
    ExecutionMode,
)
from .store import agent_store

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/agents", tags=["agents"])


# === Agent CRUD ===


@router.get("", response_model=List[AgentConfig])
async def list_agents():
    """List all configured agents."""
    return agent_store.list_all()


@router.post("", response_model=AgentConfig)
async def create_agent(agent: AgentConfig):
    """Create a new agent."""
    # Validate skills
    for skill_id in agent.skills:
        if not SkillRegistry.get_by_id(skill_id):
            raise HTTPException(
                status_code=400,
                detail=f"Unknown skill: {skill_id}"
            )

    # Validate tools
    for tool_id in agent.tools:
        if not ToolRegistry.get_by_id(tool_id):
            raise HTTPException(
                status_code=400,
                detail=f"Unknown tool: {tool_id}"
            )

    return agent_store.create(agent)


@router.get("/{agent_id}", response_model=AgentConfig)
async def get_agent(agent_id: str):
    """Get a specific agent by ID."""
    agent = agent_store.get(agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    return agent


@router.patch("/{agent_id}", response_model=AgentConfig)
async def update_agent(agent_id: str, updates: dict):
    """Update an agent with partial data."""
    agent = agent_store.update(agent_id, updates)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    return agent


@router.delete("/{agent_id}")
async def delete_agent(agent_id: str):
    """Delete an agent."""
    if not agent_store.delete(agent_id):
        raise HTTPException(status_code=404, detail="Agent not found")
    return {"status": "deleted", "agent_id": agent_id}


@router.get("/{agent_id}/export")
async def export_agent(agent_id: str):
    """Export agent configuration as markdown."""
    agent = agent_store.get(agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")

    return {
        "agent_id": agent_id,
        "markdown": agent.to_markdown(),
        "filename": f"{agent.name.lower().replace(' ', '-')}.md"
    }


# === Skills Registry ===


@router.get("/registry/skills", response_model=List[AgentSkill])
async def list_skills():
    """List all available skills."""
    return SkillRegistry.get_all()


@router.get("/registry/skills/{skill_id}", response_model=AgentSkill)
async def get_skill(skill_id: str):
    """Get a specific skill by ID."""
    skill = SkillRegistry.get_by_id(skill_id)
    if not skill:
        raise HTTPException(status_code=404, detail="Skill not found")
    return skill


# === Tools Registry ===


@router.get("/registry/tools", response_model=List[AgentTool])
async def list_tools():
    """List all available tools."""
    return ToolRegistry.get_all()


@router.get("/registry/tools/{tool_id}", response_model=AgentTool)
async def get_tool(tool_id: str):
    """Get a specific tool by ID."""
    tool = ToolRegistry.get_by_id(tool_id)
    if not tool:
        raise HTTPException(status_code=404, detail="Tool not found")
    return tool


# === Agent Session Management ===


@router.post("/{agent_id}/connect")
async def connect_agent(agent_id: str, ssh_config: dict):
    """Connect an agent to an SSH session.

    ssh_config should contain:
    - host: SSH server hostname
    - username: SSH username
    - ssh_key or password: Authentication
    - port: SSH port (default 22)
    """
    agent = agent_store.get(agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")

    # This will be implemented with the existing SSH manager
    # For now, return placeholder
    return {
        "status": "pending",
        "agent_id": agent_id,
        "message": "Use /api/v1/connect with the agent's AI CLI preference"
    }


@router.post("/{agent_id}/disconnect")
async def disconnect_agent(agent_id: str):
    """Disconnect an agent from its session."""
    agent = agent_store.get(agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")

    if agent.session_id:
        agent_store.set_session(agent_id, None)
        return {"status": "disconnected", "agent_id": agent_id}

    return {"status": "not_connected", "agent_id": agent_id}
