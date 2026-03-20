"""SSH AI Bridge - FastAPI application entry point."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from api.routes import router as api_router
from agents.routes import router as agents_router
from ssh.manager import ssh_manager

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    logger.info("SSH AI Bridge starting up...")
    yield
    # Cleanup on shutdown
    logger.info("Closing all SSH connections...")
    await ssh_manager.close_all()
    logger.info("SSH AI Bridge shut down complete.")


app = FastAPI(
    title="SSH AI Bridge",
    description="Bridge for connecting to remote AI CLIs via SSH and exposing them through HTTP API",
    version="0.1.0",
    lifespan=lifespan,
)

# Enable CORS for Godot clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router, prefix="/api/v1")
app.include_router(agents_router, prefix="/api/v1")


@app.get("/")
async def root():
    """Root endpoint with API info."""
    return {
        "name": "SSH AI Bridge",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/api/v1/health",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
