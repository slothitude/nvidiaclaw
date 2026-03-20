"""Agent template system - agents as markdown files."""
import os
import re
import json
from datetime import datetime
from typing import Optional, Dict, List
from pathlib import Path
import logging

from .models import AgentConfig, AICLIType, ExecutionMode

logger = logging.getLogger(__name__)


class AgentTemplate:
    """Represents an agent defined as a markdown file.

    ## Agent Markdown Format

    ```markdown
    # 🤖 Agent Name

    > Description of what this agent does

    ## Configuration

    - **AI CLI:** claude | goose | auto
    - **Execution:** remote | local
    - **Temperature:** 0.7

    ## Skills

    - code-review
    - debugging

    ## Tools

    - file_read
    - file_write
    - shell_execute

    ## System Prompt

    You are an expert developer assistant...

    ## Behaviors

    - Always run tests before committing
    - Use conventional commits
    ```
    """

    # Regex patterns for parsing
    NAME_PATTERN = re.compile(r'^#\s*([^\s]+)\s+(.+)$', re.MULTILINE)
    DESC_PATTERN = re.compile(r'^>\s*(.+)$', re.MULTILINE)
    CONFIG_PATTERN = re.compile(r'-\s*\*\*([^*]+):\*\*\s*(.+)$', re.MULTILINE)
    LIST_PATTERN = re.compile(r'^-\s*(.+)$', re.MULTILINE)

    @staticmethod
    def parse_markdown(content: str) -> Dict:
        """Parse a markdown file into agent configuration."""
        data = {
            "name": "",
            "description": "",
            "icon": "🤖",
            "ai_cli": "auto",
            "execution_mode": "remote",
            "temperature": 0.7,
            "skills": [],
            "tools": [],
            "system_prompt": "",
        }

        lines = content.split('\n')
        current_section = None
        section_content = []

        for line in lines:
            # Check for heading
            heading_match = re.match(r'^##\s*(.+)$', line)
            if heading_match:
                # Save previous section
                if current_section and section_content:
                    data = AgentTemplate._process_section(
                        data, current_section, section_content
                    )

                current_section = heading_match.group(1).lower().strip()
                section_content = []
                continue

            # Check for title (H1)
            title_match = re.match(r'^#\s*(.+)$', line)
            if title_match:
                title = title_match.group(1).strip()
                # Extract icon (first emoji) and name
                icon_match = re.match(r'^([^\w\s]+)\s*(.+)$', title)
                if icon_match:
                    data["icon"] = icon_match.group(1)
                    data["name"] = icon_match.group(2)
                else:
                    data["name"] = title
                continue

            # Check for blockquote (description)
            desc_match = re.match(r'^>\s*(.+)$', line)
            if desc_match:
                data["description"] = desc_match.group(1)
                continue

            # Add to section content
            if current_section:
                section_content.append(line)

        # Process final section
        if current_section and section_content:
            data = AgentTemplate._process_section(data, current_section, section_content)

        return data

    @staticmethod
    def _process_section(data: Dict, section: str, content: List[str]) -> Dict:
        """Process a section of the markdown."""
        content_text = '\n'.join(content).strip()

        if section == "configuration":
            # Parse key-value pairs
            for match in AgentTemplate.CONFIG_PATTERN.finditer(content_text):
                key = match.group(1).lower().strip()
                value = match.group(2).strip()

                if key == "ai cli":
                    data["ai_cli"] = value.lower()
                elif key == "execution":
                    data["execution_mode"] = value.lower()
                elif key == "temperature":
                    try:
                        data["temperature"] = float(value)
                    except ValueError:
                        pass

        elif section == "skills":
            # Parse list items
            for match in AgentTemplate.LIST_PATTERN.finditer(content_text):
                skill_id = match.group(1).strip()
                if skill_id:
                    data["skills"].append(skill_id)

        elif section == "tools":
            # Parse list items
            for match in AgentTemplate.LIST_PATTERN.finditer(content_text):
                tool_id = match.group(1).strip()
                if tool_id:
                    data["tools"].append(tool_id)

        elif section in ("system prompt", "prompt"):
            # Raw content
            data["system_prompt"] = content_text

        elif section == "behaviors":
            # Append to system prompt
            if data["system_prompt"]:
                data["system_prompt"] += "\n\n"
            data["system_prompt"] += "## Behaviors\n\n"
            for match in AgentTemplate.LIST_PATTERN.finditer(content_text):
                data["system_prompt"] += "- " + match.group(1) + "\n"

        return data

    @staticmethod
    def to_markdown(config: AgentConfig) -> str:
        """Convert an agent configuration to markdown format."""
        lines = [
            f"# {config.icon} {config.name}",
            "",
            f"> {config.description}",
            "",
            "## Configuration",
            "",
            f"- **AI CLI:** {config.ai_cli}",
            f"- **Execution:** {config.execution_mode}",
            f"- **Temperature:** {config.temperature}",
            "",
            "## Skills",
            "",
        ]

        for skill_id in config.skills:
            lines.append(f"- {skill_id}")

        lines.extend([
            "",
            "## Tools",
            "",
        ])

        for tool_id in config.tools:
            lines.append(f"- {tool_id}")

        lines.extend([
            "",
            "## System Prompt",
            "",
            config.system_prompt if config.system_prompt else "*No custom prompt*",
            "",
        ])

        return "\n".join(lines)

    @staticmethod
    def load_from_file(filepath: str) -> Optional[AgentConfig]:
        """Load an agent from a markdown file."""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            data = AgentTemplate.parse_markdown(content)
            config = AgentConfig(**data)
            logger.info(f"Loaded agent from {filepath}: {config.name}")
            return config

        except Exception as e:
            logger.error(f"Failed to load agent from {filepath}: {e}")
            return None

    @staticmethod
    def save_to_file(config: AgentConfig, directory: str) -> str:
        """Save an agent to a markdown file."""
        os.makedirs(directory, exist_ok=True)

        # Generate filename from name
        filename = config.name.lower().replace(' ', '-').replace('_', '-')
        filename = re.sub(r'[^a-z0-9-]', '', filename)
        filepath = os.path.join(directory, f"{filename}.md")

        content = AgentTemplate.to_markdown(config)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

        logger.info(f"Saved agent to {filepath}")
        return filepath


class AgentTemplateManager:
    """Manages a collection of agent templates."""

    def __init__(self, templates_dir: str = None):
        self.templates_dir = templates_dir or os.path.join(
            os.path.dirname(__file__), "..", "data", "agent_templates"
        )
        self._templates: Dict[str, AgentConfig] = {}
        self._load_templates()

    def _load_templates(self) -> None:
        """Load all templates from the templates directory."""
        if not os.path.exists(self.templates_dir):
            os.makedirs(self.templates_dir, exist_ok=True)
            self._create_default_templates()
            return

        for filename in os.listdir(self.templates_dir):
            if filename.endswith('.md'):
                filepath = os.path.join(self.templates_dir, filename)
                config = AgentTemplate.load_from_file(filepath)
                if config:
                    self._templates[config.id] = config

        logger.info(f"Loaded {len(self._templates)} agent templates")

    def _create_default_templates(self) -> None:
        """Create default agent templates."""
        defaults = [
            AgentConfig(
                id="code-reviewer",
                name="Code Reviewer",
                description="Expert code review and quality analysis",
                icon="📝",
                ai_cli=AICLIType.AUTO,
                skills=["code-review", "security"],
                tools=["file_read", "grep_search"],
                system_prompt="You are an expert code reviewer. Analyze code for bugs, security issues, and best practices.",
            ),
            AgentConfig(
                id="debugger",
                name="Debugger",
                description="Identify and fix bugs in code",
                icon="🔧",
                ai_cli=AICLIType.AUTO,
                skills=["debugging"],
                tools=["file_read", "file_write", "shell_execute"],
                system_prompt="You are a debugging specialist. Identify root causes and suggest specific fixes.",
            ),
            AgentConfig(
                id="architect",
                name="Architect",
                description="Design and review system architecture",
                icon="🏗️",
                ai_cli=AICLIType.AUTO,
                skills=["architecture"],
                tools=["file_read", "file_write"],
                system_prompt="You are a software architect. Design scalable, maintainable systems.",
            ),
        ]

        for config in defaults:
            AgentTemplate.save_to_file(config, self.templates_dir)
            self._templates[config.id] = config

    def get_all(self) -> List[AgentConfig]:
        """Get all available templates."""
        return list(self._templates.values())

    def get(self, template_id: str) -> Optional[AgentConfig]:
        """Get a template by ID."""
        return self._templates.get(template_id)

    def import_template(self, filepath: str) -> Optional[AgentConfig]:
        """Import a template from a file."""
        config = AgentTemplate.load_from_file(filepath)
        if config:
            # Save to templates directory
            AgentTemplate.save_to_file(config, self.templates_dir)
            self._templates[config.id] = config
        return config

    def export_template(self, template_id: str, output_dir: str) -> Optional[str]:
        """Export a template to a file."""
        config = self._templates.get(template_id)
        if config:
            return AgentTemplate.save_to_file(config, output_dir)
        return None


# Global template manager
template_manager = AgentTemplateManager()
