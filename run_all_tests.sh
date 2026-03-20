#!/bin/bash
# run_all_tests.sh
# Combined test script for Python backend and Godot addon

set -e

echo "=== SSH AI Bridge Test Suite ==="
echo ""

# Check if we're in the right directory
if [ ! -f "main.py" ]; then
    echo "Error: Please run this script from the ssh-ai-bridge directory"
    exit 1
fi

# Run Python tests
echo "=== Running Python Tests ==="
echo ""

if command -v pytest &> /dev/null; then
    pytest --cov=. --cov-report=term -v
    PYTHON_EXIT=$?
else
    echo "pytest not found, installing..."
    pip install pytest pytest-asyncio pytest-cov httpx
    pytest --cov=. --cov-report=term -v
    PYTHON_EXIT=$?
fi

echo ""
echo "Python tests completed with exit code: $PYTHON_EXIT"
echo ""

# Check if Godot tests exist
GODOT_PROJECT="../godot-addons/ai_chat"
if [ -d "$GODOT_PROJECT" ]; then
    echo "=== Running Godot Tests ==="
    echo ""

    if command -v godot &> /dev/null; then
        # Check if GUT is installed
        if [ -d "$GODOT_PROJECT/addons/gut" ]; then
            godot --headless --path "$GODOT_PROJECT" -s addons/gut/gut_cmdln.gd
            GODOT_EXIT=$?
        else
            echo "GUT (Godot Unit Test) not found in project"
            echo "Skipping Godot tests"
            GODOT_EXIT=0
        fi
    else
        echo "Godot not found in PATH"
        echo "Skipping Godot tests"
        GODOT_EXIT=0
    fi
else
    echo "Godot project not found at $GODOT_PROJECT"
    echo "Skipping Godot tests"
    GODOT_EXIT=0
fi

echo ""
echo "=== Test Results ==="
echo "Python tests: $PYTHON_EXIT"
echo "Godot tests: $GODOT_EXIT"
echo ""

# Exit with error if any tests failed
if [ $PYTHON_EXIT -ne 0 ] || [ $GODOT_EXIT -ne 0 ]; then
    echo "Some tests failed!"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
