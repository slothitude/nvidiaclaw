"""Configuration settings for SSH AI Bridge."""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings."""

    # Server settings
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True

    # SSH defaults
    ssh_timeout: int = 30
    ssh_keepalive_interval: int = 30

    # Session settings
    session_timeout: int = 3600  # 1 hour
    max_sessions: int = 10

    # AI CLI settings
    default_ai_cli: str = "auto"
    command_timeout: int = 300  # 5 minutes

    class Config:
        env_prefix = "BRIDGE_"
        env_file = ".env"


settings = Settings()
