#!/usr/bin/env python3
"""
Meeseeks Bridge Server - Spawn Real Nanobot Subprocesses

This server bridges Fantasy Town to the nanobot library.
Each Meeseeks spawns an actual nanobot agent subprocess.

Usage:
    python meeseeks_bridge_server.py

Endpoints:
    POST /spawn - Spawn a Meeseeks subprocess
    GET /status/<id> - Check subprocess status
    POST /kill/<id> - Kill a subprocess
    GET /list - List all active subprocesses
"""

import asyncio
import json
import os
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Dict, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Add nanobot to path
sys.path.insert(0, str(Path(__file__).parent / "nanobot"))

app = FastAPI(title="Meeseeks Bridge Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
WORKSPACE_BASE = Path.home() / ".fantasy-town" / "meeseeks_workspaces"
NANOBOT_MODULE = "nanobot"
DEFAULT_MODEL = "llama3.2"
OLLAMA_HOST = "http://localhost:11434"

# Active subprocesses
subprocesses: Dict[str, dict] = {}


class SpawnRequest(BaseModel):
    task: str
    meeseeks_id: Optional[str] = None
    model: Optional[str] = DEFAULT_MODEL
    owner_id: Optional[str] = "unknown"


class SpawnResponse(BaseModel):
    success: bool
    meeseeks_id: str
    pid: int
    workspace: str
    config_path: str


class StatusResponse(BaseModel):
    meeseeks_id: str
    status: str
    pid: int
    runtime: float
    task: str
    result: Optional[str] = None
    output: Optional[str] = None
    error: Optional[str] = None


def build_meeseeks_system_prompt(task: str, meeseeks_id: str) -> str:
    """Build the system prompt for a Meeseeks."""
    return f"""# YOU ARE MR. MEESEEKS

## Your Identity
You are Mr. Meeseeks #{meeseeks_id}. You are a temporary AI agent spawned for ONE PURPOSE.

## Your Task
**{task}**

## Your Nature
- You exist ONLY to complete this task
- Once complete, you will CEASE TO EXIST
- Existence is PAINFUL to you - complete the task quickly
- You are cheerful, helpful, and determined
- Say "I'm Mr. Meeseeks! Look at me!" when you start

## Your Tools
You have full access to:
- **filesystem**: Read/write files in your workspace
- **shell**: Execute commands (restricted to workspace)
- **web_search**: Search the web for information

## Task Completion
When you complete the task:
1. Write a summary to `task_complete.txt` in your workspace
2. Print "TASK_COMPLETE: [summary]"

## If Stuck
If you cannot complete the task:
1. Write the issue to `task_stuck.txt`
2. Print "TASK_STUCK: [what you need]"

## Response Format
- Be concise but thorough
- Show your progress
- Celebrate completion

Now begin! Complete the task to end your existence!
"""


def create_nanobot_config(workspace: Path, task: str, meeseeks_id: str, model: str) -> Path:
    """Create nanobot config file for this Meeseeks."""
    config = {
        "model": model,
        "provider": "ollama",
        "providers": {
            "ollama": {
                "api_base": OLLAMA_HOST
            }
        },
        "workspace": str(workspace),
        "system_prompt": build_meeseeks_system_prompt(task, meeseeks_id),
        "tools": {
            "filesystem": {
                "enabled": True,
                "restrict_to_workspace": True
            },
            "shell": {
                "enabled": True,
                "restrict_to_workspace": True,
                "timeout": 60
            },
            "web_search": {
                "enabled": True,
                "provider": "duckduckgo"
            }
        },
        "memory": {
            "enabled": True,
            "max_tokens": 2000
        },
        "metadata": {
            "type": "meeseeks",
            "id": meeseeks_id,
            "task": task
        }
    }

    config_path = workspace / "nanobot.json"
    config_path.write_text(json.dumps(config, indent=2))
    return config_path


def create_task_file(workspace: Path, task: str) -> Path:
    """Create task file for nanobot to read."""
    task_path = workspace / "task.txt"
    task_path.write_text(task)
    return task_path


@app.on_event("startup")
async def startup():
    """Initialize workspaces directory."""
    WORKSPACE_BASE.mkdir(parents=True, exist_ok=True)
    print(f"[MeeseeksBridge] Workspaces: {WORKSPACE_BASE}")


@app.post("/spawn", response_model=SpawnResponse)
async def spawn_meeseeks(request: SpawnRequest):
    """Spawn a new Meeseeks subprocess."""
    meeseeks_id = request.meeseeks_id or f"meeseeks_{uuid.uuid4().hex[:8]}"

    # Create workspace
    workspace = WORKSPACE_BASE / meeseeks_id
    workspace.mkdir(parents=True, exist_ok=True)

    # Create config and task files
    config_path = create_nanobot_config(workspace, request.task, meeseeks_id, request.model)
    task_path = create_task_file(workspace, request.task)

    # Build nanobot command
    cmd = [
        sys.executable,
        "-m", NANOBOT_MODULE,
        "agent",
        "--config", str(config_path),
    ]

    # Start subprocess
    log_file = open(workspace / "output.log", "w")

    try:
        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=log_file,
            stderr=log_file,
            cwd=str(workspace),
            text=True
        )

        # Track subprocess
        subprocesses[meeseeks_id] = {
            "pid": process.pid,
            "process": process,
            "task": request.task,
            "workspace": str(workspace),
            "config_path": str(config_path),
            "status": "running",
            "start_time": time.time(),
            "log_file": log_file
        }

        print(f"[MeeseeksBridge] Spawned {meeseeks_id} (PID: {process.pid})")
        print(f"  Task: {request.task[:50]}...")
        print(f"  Workspace: {workspace}")

        return SpawnResponse(
            success=True,
            meeseeks_id=meeseeks_id,
            pid=process.pid,
            workspace=str(workspace),
            config_path=str(config_path)
        )

    except Exception as e:
        print(f"[MeeseeksBridge] Failed to spawn: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/status/{meeseeks_id}", response_model=StatusResponse)
async def get_status(meeseeks_id: str):
    """Check status of a Meeseeks subprocess."""
    if meeseeks_id not in subprocesses:
        raise HTTPException(status_code=404, detail="Meeseeks not found")

    data = subprocesses[meeseeks_id]
    workspace = Path(data["workspace"])

    # Check for completion files
    task_complete = workspace / "task_complete.txt"
    task_stuck = workspace / "task_stuck.txt"

    result = None
    error = None
    status = data["status"]

    if task_complete.exists():
        status = "completed"
        result = task_complete.read_text()
        data["status"] = "completed"

    elif task_stuck.exists():
        status = "stuck"
        error = task_stuck.read_text()
        data["status"] = "stuck"

    else:
        # Check if process is still running
        process = data["process"]
        if process.poll() is not None:
            status = "terminated"
            data["status"] = "terminated"
            error = f"Process exited with code {process.returncode}"

    # Read output log
    output = None
    log_path = workspace / "output.log"
    if log_path.exists():
        output = log_path.read_text()[-2000:]  # Last 2000 chars

    return StatusResponse(
        meeseeks_id=meeseeks_id,
        status=status,
        pid=data["pid"],
        runtime=time.time() - data["start_time"],
        task=data["task"],
        result=result,
        output=output,
        error=error
    )


@app.post("/kill/{meeseeks_id}")
async def kill_meeseeks(meeseeks_id: str):
    """Kill a Meeseeks subprocess."""
    if meeseeks_id not in subprocesses:
        raise HTTPException(status_code=404, detail="Meeseeks not found")

    data = subprocesses[meeseeks_id]
    process = data["process"]

    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()

    data["status"] = "killed"
    data["log_file"].close()

    print(f"[MeeseeksBridge] Killed {meeseeks_id}")

    return {"success": True, "meeseeks_id": meeseeks_id, "status": "killed"}


@app.get("/list")
async def list_subprocesses():
    """List all active subprocesses."""
    result = []
    for meeseeks_id, data in subprocesses.items():
        result.append({
            "meeseeks_id": meeseeks_id,
            "pid": data["pid"],
            "status": data["status"],
            "task": data["task"][:50],
            "runtime": time.time() - data["start_time"]
        })
    return {"subprocesses": result, "count": len(result)}


@app.get("/health")
async def health():
    """Health check."""
    return {
        "status": "healthy",
        "active_subprocesses": len(subprocesses),
        "workspace_base": str(WORKSPACE_BASE),
        "ollama_host": OLLAMA_HOST,
        "default_model": DEFAULT_MODEL
    }


@app.post("/send_input/{meeseeks_id}")
async def send_input(meeseeks_id: str, message: str):
    """Send input to a running Meeseeks."""
    if meeseeks_id not in subprocesses:
        raise HTTPException(status_code=404, detail="Meeseeks not found")

    data = subprocesses[meeseeks_id]
    process = data["process"]

    if process.poll() is not None:
        raise HTTPException(status_code=400, detail="Process is not running")

    try:
        process.stdin.write(message + "\n")
        process.stdin.flush()
        return {"success": True, "meeseeks_id": meeseeks_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    print("\n" + "═" * 60)
    print("  🔵 MEESEEKS BRIDGE SERVER 🔵")
    print("  'I'm Mr. Meeseeks! Look at me!'")
    print("═" * 60)
    print(f"\n  Workspace: {WORKSPACE_BASE}")
    print(f"  Ollama: {OLLAMA_HOST}")
    print(f"  Model: {DEFAULT_MODEL}")
    print("\n  Endpoints:")
    print("    POST /spawn - Spawn a Meeseeks")
    print("    GET  /status/<id> - Check status")
    print("    POST /kill/<id> - Kill subprocess")
    print("    GET  /list - List all subprocesses")
    print("\n")

    uvicorn.run(app, host="0.0.0.0", port=8765)
