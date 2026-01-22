#!/bin/bash
# Block edits that add @ts-ignore
# Usage: Called by PreToolUse hook before Edit/Write operations

# Read JSON input from stdin
INPUT=$(cat)

# Extract file content if present
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_content // .tool_input.content // empty' 2>/dev/null)

# If no content found, allow (might be a different operation)
if [[ -z "$CONTENT" ]]; then
    exit 0
fi

# Check if content would add @ts-ignore or @ts-expect-error
if echo "$CONTENT" | grep -i "@ts-ignore\|@ts-expect-error" > /dev/null 2>&1; then
    echo "Blocked: Cannot add @ts-ignore or @ts-expect-error to code" >&2
    echo "Use proper TypeScript typing instead" >&2
    exit 2  # Block with custom message
fi

exit 0  # Allow
