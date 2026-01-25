# PowerShell helper for Ralph agents running in Bash
# Usage: source ./.claude/scripts/pwsh-helper.sh
#
# This script provides wrapper functions to call PowerShell message queue functions
# from bash. It uses mq-ops.ps1 for bash-safe execution (avoids Git Bash parsing issues).
#
# Why this approach:
# - Git Bash intercepts redirect operators (2>, >, |) before PowerShell sees them
# - Using -File script.ps1 instead of -Command "..." avoids bash metacharacter issues
# - All PowerShell code lives in .ps1 files, bash only calls them with simple params

# Find the project root by searching for .claude directory
_find_project_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "" ]]; do
        if [[ -d "$current_dir/.claude" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="${current_dir%/*}"
    done
    echo "Project root not found!" >&2
    return 1
}

# Cache the project root
PROJECT_ROOT="$(_find_project_root)"
export PROJECT_ROOT

# Path to the mq-ops.ps1 script
MQ_SCRIPT="$PROJECT_ROOT/.claude/scripts/mq-ops.ps1"

# Helper: Run mq-ops.ps1 and output result
# Usage: _mq_run <operation> <output_var> [args...]
_mq_run() {
    local op="$1"
    local output_file="$2"
    shift 2

    # Build arguments for PowerShell
    local args=("-Operation" "$op")

    case "$op" in
        get-pending|list)
            [[ -n "$1" ]] && args+=("-Agent" "$1")
            ;;
        send)
            [[ -n "$1" ]] && args+=("-From" "$1")
            [[ -n "$2" ]] && args+=("-To" "$2")
            [[ -n "$3" ]] && args+=("-Type" "$3")
            [[ -n "$4" ]] && args+=("-PayloadJson" "$4")
            ;;
        remove)
            [[ -n "$1" ]] && args+=("-Agent" "$1")
            [[ -n "$2" ]] && args+=("-MessageId" "$2")
            ;;
        global-state)
            # No additional params needed
            ;;
    esac

    args+=("-OutputFile" "$output_file")

    # Call PowerShell script - Bash-safe because we use -File with simple string args
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$MQ_SCRIPT" \
        "${args[@]}"
}

# Get global message state (shows all messages across all agents)
pq-global-state() {
    local output="$PROJECT_ROOT/.claude/session/pq-global-$$.json"
    _mq_run "global-state" "$output"
    cat "$output"
    rm "$output" 2>/dev/null
}

# Get pending messages for an agent
pq-get() {
    local agent="$1"
    if [[ -z "$agent" ]]; then
        echo "Error: Agent name required" >&2
        return 1
    fi
    local output="$PROJECT_ROOT/.claude/session/pq-get-$$.json"
    _mq_run "get-pending" "$output" "$agent"
    cat "$output"
    rm "$output" 2>/dev/null
}

# Send agent message
pq-send() {
    local from="$1"
    local to="$2"
    local type="$3"
    local payload="$4"  # Optional: JSON payload string

    if [[ -z "$from" ]] || [[ -z "$to" ]] || [[ -z "$type" ]]; then
        echo "Error: from, to, and type are required" >&2
        return 1
    fi

    local output="$PROJECT_ROOT/.claude/session/pq-send-$$.json"
    _mq_run "send" "$output" "$from" "$to" "$type" "$payload"
    cat "$output"
    rm "$output" 2>/dev/null
}

# Remove agent message
pq-remove() {
    local agent="$1"
    local msgId="$2"

    if [[ -z "$agent" ]] || [[ -z "$msgId" ]]; then
        echo "Error: agent and msgId are required" >&2
        return 1
    fi

    local output="$PROJECT_ROOT/.claude/session/pq-remove-$$.json"
    _mq_run "remove" "$output" "$agent" "$msgId"
    cat "$output"
    rm "$output" 2>/dev/null
}

# List all messages for an agent (filenames only)
pq-list() {
    local agent="$1"
    if [[ -z "$agent" ]]; then
        echo "Error: Agent name required" >&2
        return 1
    fi
    local output="$PROJECT_ROOT/.claude/session/pq-list-$$.json"
    _mq_run "list" "$output" "$agent"
    cat "$output"
    rm "$output" 2>/dev/null
}

# Initialize message queue (usually not needed - other pq-* functions auto-initialize)
pq-init() {
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$MQ_SCRIPT" \
        -Operation "global-state" \
        -OutputFile "$PROJECT_ROOT/.claude/session/pq-init-$$.json"
    rm "$PROJECT_ROOT/.claude/session/pq-init-$$.json" 2>/dev/null
}

# Helper: Read message file directly (more reliable than PowerShell calls)
pq-read-message() {
    local agent="$1"
    local msg_file="$2"
    cat "$PROJECT_ROOT/.claude/session/messages/$agent/$msg_file"
}

# Helper: Check if message directory exists for an agent
pq-check-inbox() {
    local agent="$1"
    local msg_dir="$PROJECT_ROOT/.claude/session/messages/$agent"
    if [[ -d "$msg_dir" ]]; then
        echo "Inbox exists: $msg_dir"
        ls -1 "$msg_dir"/msg-*.json 2>/dev/null | wc -l | xargs -I {} echo "{} message(s)"
    else
        echo "Inbox not found: $msg_dir"
        return 1
    fi
}
