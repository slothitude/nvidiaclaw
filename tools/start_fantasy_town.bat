@echo off
REM start_fantasy_town.bat - Start Fantasy Town with nanobot integration (Windows)
REM
REM This script:
REM 1. Starts Ollama (if not running)
REM 2. Ensures nanobot is installed
REM 3. Creates agent workspaces
REM 4. Starts Godot with Fantasy Town

echo ========================================
echo   Fantasy Town - Nanobot Integration
echo ========================================
echo.

REM Check for Ollama
echo Checking Ollama...
where ollama >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Ollama found

    REM Check if llama3.2 is installed
    ollama list | findstr "llama3.2" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [OK] llama3.2 model available
    ) else (
        echo Pulling llama3.2 model...
        ollama pull llama3.2
        echo [OK] llama3.2 installed
    )
) else (
    echo [WARNING] Ollama not found. Please install from https://ollama.ai
    echo          Continuing without Ollama (agents will use fallback mode)
)

echo.
REM Check for nanobot
echo Checking nanobot...
where nanobot >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] nanobot installed
) else (
    echo nanobot not found. Installing...
    pip install nanobot-ai
    if %ERRORLEVEL% EQU 0 (
        echo [OK] nanobot installed
    ) else (
        echo [WARNING] Failed to install nanobot. Continuing without it.
    )
)

echo.
REM Create agent workspaces
echo Creating agent workspaces...
set WORKSPACE_DIR=%USERPROFILE%\.fantasy-town
if not exist "%WORKSPACE_DIR%\agents" mkdir "%WORKSPACE_DIR%\agents"
if not exist "%WORKSPACE_DIR%\shared" mkdir "%WORKSPACE_DIR%\shared"

REM Create workspaces for 10 agents
for /L %%i in (0,1,9) do (
    if not exist "%WORKSPACE_DIR%\agents\%%i" mkdir "%WORKSPACE_DIR%\agents\%%i"
)

echo [OK] Agent workspaces created at %WORKSPACE_DIR%

REM Create shared memory template
set SHARED_MEMORY=%WORKSPACE_DIR%\shared\town_memory.json
if not exist "%SHARED_MEMORY%" (
    echo {"buildings": {},"agents": {},"divine_commands": [],"economy": {"total_gold": 1000,"prices": {"food": 5,"drink": 2,"comfort": 10}},"metadata": {"created": "2024-01-01T00:00:00Z","version": "1.0"}} > "%SHARED_MEMORY%"
    echo [OK] Shared memory initialized
)

echo.
REM Check for Godot
echo Checking Godot...
where godot >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Godot found
) else (
    where godot4 >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [OK] Godot4 found
    ) else (
        echo [ERROR] Godot not found. Please install Godot 4.x
        exit /b 1
    )
)

echo.
echo ========================================
echo Starting Fantasy Town...
echo ========================================
echo.
echo Controls:
echo   - Right-drag: Rotate camera
echo   - Scroll: Zoom
echo   - Left-click: Select agent
echo   - F12: Screenshot
echo   - G: Open GOD console (if available)
echo.

REM Get script directory
set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set GODOT_PROJECT=%PROJECT_DIR%\godot-test-project

cd /d "%GODOT_PROJECT%"

REM Try godot4 first, then godot
where godot4 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    godot4 --path .
) else (
    godot --path .
)
