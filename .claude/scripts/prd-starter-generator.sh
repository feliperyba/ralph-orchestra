#!/bin/bash
#
# PRD Starter Generator - Cross-platform wrapper for Mac/Linux
#
# This script wraps the Python-based PRD Starter generator for Unix-like
# systems. It automatically detects Python and invokes the generator
# with all passed arguments.
#
# Usage:
#   ./prd-starter-generator.sh --action generate --state .claude/session/prd-starter-state.json
#   ./prd-starter-generator.sh --action validate --config .claude/session/agent-config.json
#   ./prd-starter-generator.sh --action reset
#
# Or make executable and run directly:
#   chmod +x prd-starter-generator.sh
#   ./prd-starter-generator.sh --help
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python command (can be overridden by environment variable)
PYTHON_CMD="${PYTHON_CMD:-python3}"

# Colors for output (disable if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    RED=''
    YELLOW=''
    CYAN=''
    NC=''
fi]

# Find Python executable
find_python() {
    # Try PYTHON_CMD first
    if command -v "$PYTHON_CMD" &> /dev/null; then
        echo "$PYTHON_CMD"
        return 0
    fi

    # Try other common commands
    for cmd in python3.12 python3.11 python3.10 python3.9 python3.8 python python2; do
        if command -v "$cmd" &> /dev/null; then
            echo "$cmd"
            return 0
        fi
    done

    return 1
}

# Check Python version
check_python_version() {
    local python="$1"
    local version_output

    version_output=$("$python" --version 2>&1)

    # Extract version numbers (handles "Python 3.11.0" format)
    if [[ "$version_output" =~ Python\ ([0-9]+)\.([0-9]+) ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"

        if [[ "$major" -lt 3 ]] || [[ "$major" -eq 3 && "$minor" -lt 8 ]]; then
            echo -e "${RED}Error: Python 3.8+ required. Found: $version_output${NC}" >&2
            return 1
        fi
    fi

    return 0
}

# Install missing dependencies
install_dependencies() {
    local python="$1"
    local requirements_file="$SCRIPT_DIR/prd-starter-requirements.txt"

    if [[ ! -f "$requirements_file" ]]; then
        return 0
    fi

    local missing=()

    # Check for jinja2
    if ! "$python" -c "import jinja2" 2>/dev/null; then
        missing+=("jinja2")
    fi

    # Check for pyyaml
    if ! "$python" -c "import yaml" 2>/dev/null; then
        missing+=("pyyaml")
    fi

    # Check for jsonschema
    if ! "$python" -c "import jsonschema" 2>/dev/null; then
        missing+=("jsonschema")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Installing missing Python packages: ${missing[*]}${NC}" >&2
        "$python" -m pip install -r "$requirements_file"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Error: Failed to install required packages.${NC}" >&2
            echo -e "${CYAN}Please run manually:${NC}" >&2
            echo "  pip install -r $requirements_file" >&2
            exit 1
        fi
    fi
}

# Main script
main() {
    # Find Python
    PYTHON=$(find_python)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: Python not found. Please install Python 3.8+ to use PRD Starter.${NC}" >&2
        echo -e "${CYAN}Download from: https://www.python.org/downloads/${NC}" >&2
        exit 1
    fi

    # Check Python version
    if ! check_python_version "$PYTHON"; then
        exit 1
    fi

    # Install dependencies if needed
    install_dependencies "$PYTHON"

    # Path to Python script (now in prd-starter subdirectory)
    SCRIPT_PATH="$SCRIPT_DIR/prd-starter/prd-starter-generator.py"

    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}Error: Generator script not found: $SCRIPT_PATH${NC}" >&2
        exit 1
    fi

    # Run the Python script with all arguments
    exec "$PYTHON" "$SCRIPT_PATH" "$@"
}

# Run main
main "$@"
