"""AI CLI adapters package."""
from .base import AICLIPlugin
from .claude import ClaudeCodePlugin
from .goose import GoosePlugin

# Plugin registry
PLUGINS = {
    "claude": ClaudeCodePlugin,
    "goose": GoosePlugin,
}


def get_plugin(name: str) -> type[AICLIPlugin]:
    """Get a plugin class by name."""
    if name in PLUGINS:
        return PLUGINS[name]
    raise ValueError(f"Unknown AI CLI: {name}. Available: {list(PLUGINS.keys())}")


__all__ = ["AICLIPlugin", "ClaudeCodePlugin", "GoosePlugin", "PLUGINS", "get_plugin"]
