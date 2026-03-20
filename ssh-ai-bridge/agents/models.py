"""Agent configuration models."""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum
import uuid


class AICLIType(str, Enum):
    """Supported AI CLI types."""
    CLAUDE = "claude"
    GOOSE = "goose"
    AUTO = "auto"


class ExecutionMode(str, Enum):
    """Agent execution mode."""
    REMOTE = "remote"  # Execute via SSH on remote server
    LOCAL = "local"    # Execute locally (future support)


class AgentSkill(BaseModel):
    """A predefined skill that an agent can have."""
    id: str = Field(..., description="Unique skill identifier")
    name: str = Field(..., description="Display name")
    description: str = Field(..., description="What this skill does")
    icon: str = Field(default="🔧", description="Emoji icon for UI")
    category: str = Field(default="general", description="Skill category")
    prompt_template: Optional[str] = Field(None, description="Template to append to system prompt")


class AgentTool(BaseModel):
    """A tool that an agent can use."""
    id: str = Field(..., description="Unique tool identifier")
    name: str = Field(..., description="Display name")
    description: str = Field(..., description="What this tool does")
    icon: str = Field(default="⚡", description="Emoji icon for UI")
    enabled: bool = Field(default=True, description="Whether tool is enabled by default")
    requires_confirmation: bool = Field(default=False, description="Whether tool requires user confirmation")


class AgentConfig(BaseModel):
    """Full agent configuration."""
    id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8], description="Unique agent ID")
    name: str = Field(..., description="Agent display name")
    description: str = Field(default="", description="Agent description")
    icon: str = Field(default="🤖", description="Emoji icon for agent")

    # AI CLI Configuration
    ai_cli: AICLIType = Field(default=AICLIType.AUTO, description="AI CLI to use")
    execution_mode: ExecutionMode = Field(default=ExecutionMode.REMOTE, description="Where to execute")

    # Skills and Tools
    skills: List[str] = Field(default_factory=list, description="Skill IDs this agent has")
    tools: List[str] = Field(default_factory=list, description="Tool IDs this agent can use")

    # Prompt Configuration
    system_prompt: str = Field(default="", description="Custom system prompt")
    temperature: float = Field(default=0.7, ge=0.0, le=2.0, description="AI temperature")

    # Metadata
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Session association (when agent is active)
    session_id: Optional[str] = Field(None, description="Active session ID if connected")

    def to_markdown(self) -> str:
        """Export agent config as markdown."""
        lines = [
            f"# {self.icon} {self.name}",
            "",
            f"**Description:** {self.description}",
            "",
            "## Configuration",
            "",
            f"- **AI CLI:** {self.ai_cli.value}",
            f"- **Execution:** {self.execution_mode.value}",
            f"- **Temperature:** {self.temperature}",
            "",
            "## Skills",
            "",
        ]
        for skill_id in self.skills:
            lines.append(f"- {skill_id}")

        lines.extend([
            "",
            "## Tools",
            "",
        ])
        for tool_id in self.tools:
            lines.append(f"- {tool_id}")

        lines.extend([
            "",
            "## System Prompt",
            "",
            self.system_prompt if self.system_prompt else "*No custom prompt*",
            "",
        ])

        return "\n".join(lines)


# Predefined Skills Registry
SKILLS: Dict[str, AgentSkill] = {
    "code-review": AgentSkill(
        id="code-review",
        name="Code Review",
        description="Review code for quality, patterns, and best practices",
        icon="📝",
        category="development",
        prompt_template="You are an expert code reviewer. Analyze code for:\n- Bugs and errors\n- Security vulnerabilities\n- Performance issues\n- Code style and best practices\n- Maintainability",
    ),
    "debugging": AgentSkill(
        id="debugging",
        name="Debugging",
        description="Identify and fix bugs in code",
        icon="🔧",
        category="development",
        prompt_template="You are a debugging specialist. When analyzing issues:\n- Identify root causes systematically\n- Suggest specific fixes\n- Explain why the bug occurred\n- Recommend prevention strategies",
    ),
    "git-workflow": AgentSkill(
        id="git-workflow",
        name="Git Workflow",
        description="Manage git operations, branches, and commits",
        icon="📋",
        category="development",
        prompt_template="You are a git expert. Follow best practices:\n- Use conventional commits\n- Create meaningful branch names\n- Write clear commit messages\n- Handle merge conflicts carefully",
    ),
    "testing": AgentSkill(
        id="testing",
        name="Testing",
        description="Write and run tests, analyze test results",
        icon="🧪",
        category="development",
        prompt_template="You are a testing specialist. Focus on:\n- Unit and integration tests\n- Test coverage analysis\n- Edge case identification\n- Clear test descriptions",
    ),
    "documentation": AgentSkill(
        id="documentation",
        name="Documentation",
        description="Write and maintain project documentation",
        icon="📚",
        category="development",
        prompt_template="You are a documentation expert. Create:\n- Clear and concise documentation\n- Proper formatting with markdown\n- Code examples where helpful\n- API documentation",
    ),
    "refactoring": AgentSkill(
        id="refactoring",
        name="Refactoring",
        description="Improve code structure without changing behavior",
        icon="🔄",
        category="development",
        prompt_template="You are a refactoring expert. Focus on:\n- Improving code readability\n- Reducing complexity\n- Following SOLID principles\n- Maintaining existing behavior",
    ),
    "architecture": AgentSkill(
        id="architecture",
        name="Architecture",
        description="Design and review system architecture",
        icon="🏗️",
        category="development",
        prompt_template="You are a software architect. Consider:\n- Scalability and performance\n- Security best practices\n- Maintainability\n- Design patterns",
    ),
    "security": AgentSkill(
        id="security",
        name="Security",
        description="Analyze and improve security posture",
        icon="🔒",
        category="security",
        prompt_template="You are a security specialist. Focus on:\n- OWASP Top 10 vulnerabilities\n- Input validation\n- Authentication and authorization\n- Secure coding practices",
    ),
}

# Predefined Tools Registry
TOOLS: Dict[str, AgentTool] = {
    "file_read": AgentTool(
        id="file_read",
        name="File Read",
        description="Read file contents from disk",
        icon="📂",
        enabled=True,
        requires_confirmation=False,
    ),
    "file_write": AgentTool(
        id="file_write",
        name="File Write",
        description="Write or edit files on disk",
        icon="✏️",
        enabled=True,
        requires_confirmation=True,
    ),
    "shell_execute": AgentTool(
        id="shell_execute",
        name="Shell Execute",
        description="Run shell commands",
        icon="🖥️",
        enabled=True,
        requires_confirmation=True,
    ),
    "grep_search": AgentTool(
        id="grep_search",
        name="Grep Search",
        description="Search for patterns in files",
        icon="🔍",
        enabled=True,
        requires_confirmation=False,
    ),
    "web_search": AgentTool(
        id="web_search",
        name="Web Search",
        description="Search the web for information",
        icon="🌐",
        enabled=False,
        requires_confirmation=False,
    ),
    "data_analysis": AgentTool(
        id="data_analysis",
        name="Data Analysis",
        description="Analyze data files and generate insights",
        icon="📊",
        enabled=False,
        requires_confirmation=False,
    ),
}


class SkillRegistry:
    """Registry for available skills."""

    @staticmethod
    def get_all() -> List[AgentSkill]:
        """Get all available skills."""
        return list(SKILLS.values())

    @staticmethod
    def get_by_id(skill_id: str) -> Optional[AgentSkill]:
        """Get a skill by ID."""
        return SKILLS.get(skill_id)

    @staticmethod
    def get_by_category(category: str) -> List[AgentSkill]:
        """Get skills by category."""
        return [s for s in SKILLS.values() if s.category == category]


class ToolRegistry:
    """Registry for available tools."""

    @staticmethod
    def get_all() -> List[AgentTool]:
        """Get all available tools."""
        return list(TOOLS.values())

    @staticmethod
    def get_by_id(tool_id: str) -> Optional[AgentTool]:
        """Get a tool by ID."""
        return TOOLS.get(tool_id)

    @staticmethod
    def get_enabled() -> List[AgentTool]:
        """Get all enabled tools."""
        return [t for t in TOOLS.values() if t.enabled]
