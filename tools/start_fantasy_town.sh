#!/bin/bash
# start_fantasy_town.sh - Start Fantasy Town with nanobot integration
#
# This script:
# 1. Starts Ollama (if not running)
# 2. Ensures nanobot is installed
# 3. Creates agent workspaces
# 4. Starts Godot with Fantasy Town

set -e

echo "========================================"
echo "  Fantasy Town - Nanobot Integration"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check for Ollama
echo -e "${YELLOW}Checking Ollama...${NC}"
if command -v ollama &> /dev/null; then
    if ! pgrep -x ollama > /dev/null; then
        echo "Starting Ollama server..."
        ollama serve &
        sleep 2
    fi

    # Check if llama3.2 is installed
    if ollama list | grep -q "llama3.2"; then
        echo -e "${GREEN}✓ Ollama running with llama3.2${NC}"
    else
        echo -e "${YELLOW}Pulling llama3.2 model...${NC}"
        ollama pull llama3.2
        echo -e "${GREEN}✓ llama3.2 installed${NC}"
    fi
else
    echo -e "${RED}✗ Ollama not found. Please install from https://ollama.ai${NC}"
    echo "  Continuing without Ollama (agents will use fallback mode)"
fi

# Check for nanobot
echo ""
echo -e "${YELLOW}Checking nanobot...${NC}"
if command -v nanobot &> /dev/null; then
    NANOBOT_VERSION=$(nanobot --version 2>&1 | head -1)
    echo -e "${GREEN}✓ nanobot installed: $NANOBOT_VERSION${NC}"
else
    echo -e "${YELLOW}nanobot not found. Installing...${NC}"
    pip install nanobot-ai
    if command -v nanobot &> /dev/null; then
        echo -e "${GREEN}✓ nanobot installed${NC}"
    else
        echo -e "${RED}✗ Failed to install nanobot. Continuing without it.${NC}"
    fi
fi

# Create agent workspaces
echo ""
echo -e "${YELLOW}Creating agent workspaces...${NC}"
WORKSPACE_DIR="$HOME/.fantasy-town"
mkdir -p "$WORKSPACE_DIR/agents"
mkdir -p "$WORKSPACE_DIR/shared"

# Create workspaces for 10 agents
for i in {0..9}; do
    mkdir -p "$WORKSPACE_DIR/agents/$i"
done

echo -e "${GREEN}✓ Agent workspaces created at $WORKSPACE_DIR${NC}"

# Create shared memory template
SHARED_MEMORY="$WORKSPACE_DIR/shared/town_memory.json"
if [ ! -f "$SHARED_MEMORY" ]; then
    cat > "$SHARED_MEMORY" << 'EOF'
{
  "buildings": {},
  "agents": {},
  "divine_commands": [],
  "economy": {
    "total_gold": 1000,
    "prices": {
      "food": 5,
      "drink": 2,
      "comfort": 10
    }
  },
  "metadata": {
    "created": "2024-01-01T00:00:00Z",
    "version": "1.0"
  }
}
EOF
    echo -e "${GREEN}✓ Shared memory initialized${NC}"
fi

# Check for Godot
echo ""
echo -e "${YELLOW}Checking Godot...${NC}"
if command -v godot &> /dev/null; then
    GODOT_VERSION=$(godot --version 2>&1 | head -1)
    echo -e "${GREEN}✓ Godot installed: $GODOT_VERSION${NC}"
elif command -v godot4 &> /dev/null; then
    GODOT_CMD="godot4"
    GODOT_VERSION=$(godot4 --version 2>&1 | head -1)
    echo -e "${GREEN}✓ Godot4 installed: $GODOT_VERSION${NC}"
else
    echo -e "${RED}✗ Godot not found. Please install Godot 4.x${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
GODOT_PROJECT="$PROJECT_DIR/godot-test-project"

# Start Godot
echo ""
echo "========================================"
echo -e "${GREEN}Starting Fantasy Town...${NC}"
echo "========================================"
echo ""
echo "Controls:"
echo "  - Right-drag: Rotate camera"
echo "  - Scroll: Zoom"
echo "  - Left-click: Select agent"
echo "  - F12: Screenshot"
echo "  - G: Open GOD console (if available)"
echo ""

cd "$GODOT_PROJECT"

# Use godot4 if available, otherwise godot
if command -v godot4 &> /dev/null; then
    godot4 --path .
else
    godot --path .
fi
