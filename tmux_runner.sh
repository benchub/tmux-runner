#!/usr/bin/env bash

# tmux_runner.sh - Run commands in tmux windows and capture output
# Bash version of tmux_runner.rb for better performance

set -euo pipefail

# Debug mode - set TMUX_RUNNER_DEBUG=1 to enable
DEBUG="${TMUX_RUNNER_DEBUG:-0}"

# --- Helper Functions ---

# Run a tmux command and check for errors
run_tmux_command() {
    local socket_arg=()

    if [[ -n "${SOCKET_PATH:-}" ]]; then
        socket_arg=(-S "$SOCKET_PATH")
    fi

    local output
    if ! output=$(tmux "${socket_arg[@]}" "$@" 2>&1); then
        local status=$?
        echo "--- TMUX COMMAND FAILED ---" >&2
        echo "COMMAND: tmux ${socket_arg[*]} $*" >&2
        echo "EXIT CODE: $status" >&2
        echo "OUTPUT:" >&2
        echo "$output" >&2
        echo "---------------------------" >&2

        # Try to clean up the window if it was created
        for arg in "$@"; do
            if [[ "$arg" == *"-t"* ]]; then
                local window_target
                window_target=$(echo "$*" | grep -oP '(?<=-t )[^ ]+' | head -1)
                tmux "${socket_arg[@]}" kill-window -t "$window_target" 2>/dev/null || true
                break
            fi
        done
        exit 1
    fi

    echo "$output"
}

# Try a tmux command without failing
try_tmux_command() {
    local socket_arg=()

    if [[ -n "${SOCKET_PATH:-}" ]]; then
        socket_arg=(-S "$SOCKET_PATH")
    fi

    tmux "${socket_arg[@]}" "$@" 2>&1 || true
}

# Find delimiter in buffer, handling tmux line wrapping
# Returns position via global variables: DELIM_START, DELIM_END
find_delimiter_with_wrapping() {
    local buffer="$1"
    local delimiter="$2"

    DELIM_START=-1
    DELIM_END=-1

    # First try exact match (fast path)
    # Look for delimiter at start of line using grep with line numbers
    if echo "$buffer" | grep -n "^${delimiter}$" | tail -1 | grep -q .; then
        local line_num=$(echo "$buffer" | grep -n "^${delimiter}$" | tail -1 | cut -d: -f1)
        # Calculate byte position
        DELIM_START=$(echo "$buffer" | head -n $((line_num - 1)) | wc -c)
        DELIM_END=$((DELIM_START + ${#delimiter}))
        return 0
    fi

    # If exact match failed, try with line wrapping
    # Build a pattern that allows optional newlines and spaces between characters
    local pattern=""
    local i
    for ((i=0; i<${#delimiter}; i++)); do
        local char="${delimiter:$i:1}"
        # Escape special regex characters
        case "$char" in
            '.'|'*'|'['|']'|'^'|'$'|'\'|'/') char="\\$char" ;;
        esac
        pattern="${pattern}${char}(\n ?)?"
    done

    # Try to find the pattern in the buffer
    # This is approximate - we'll find the last occurrence
    local found_at=$(echo "$buffer" | grep -boP "$pattern" 2>/dev/null | tail -1 | cut -d: -f1 || echo "")

    if [[ -n "$found_at" ]]; then
        DELIM_START=$found_at
        DELIM_END=$((found_at + ${#delimiter}))
        return 0
    fi

    return 1
}

# --- 1. Validate Environment ---

# Get socket path from environment variable or use default
SOCKET_PATH="${TMUX_SOCKET_PATH:-/tmp/shared-session}"

# If socket path is explicitly set to empty string, use default tmux behavior (no socket)
if [[ -z "$SOCKET_PATH" ]]; then
    unset SOCKET_PATH
fi

# Validate socket access if a socket path is specified
if [[ -n "${SOCKET_PATH:-}" ]]; then
    if [[ ! -e "$SOCKET_PATH" ]] || [[ ! -w "$SOCKET_PATH" ]]; then
        echo "Error: Cannot access tmux socket at $SOCKET_PATH." >&2
        echo "Please ensure the socket exists and you have write permissions." >&2
        exit 1
    fi
fi

# Get the current session name or use the first available session
socket_arg=""
if [[ -n "${SOCKET_PATH:-}" ]]; then
    socket_arg="-S $SOCKET_PATH"
fi

if ! session_list=$(tmux $socket_arg list-sessions 2>&1); then
    socket_msg="using default tmux session"
    [[ -n "${SOCKET_PATH:-}" ]] && socket_msg="on socket $SOCKET_PATH"
    echo "Error: Cannot list tmux sessions $socket_msg" >&2
    echo "$session_list" >&2
    exit 1
fi

session_name=$(echo "$session_list" | head -1 | cut -d: -f1)
if [[ -z "$session_name" ]]; then
    socket_msg="using default tmux session"
    [[ -n "${SOCKET_PATH:-}" ]] && socket_msg="on socket $SOCKET_PATH"
    echo "Error: No tmux sessions found $socket_msg" >&2
    exit 1
fi

# --- 2. Get Command from Arguments ---
window_prefix="${TMUX_WINDOW_PREFIX:-tmux_runner}"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command to run in new window>" >&2
    echo "Example: $0 'ls -l && echo Done.'" >&2
    echo "" >&2
    echo "Optional: Set TMUX_WINDOW_PREFIX env var to customize window name" >&2
    echo "Example: TMUX_WINDOW_PREFIX=myapp $0 'command'" >&2
    exit 1
fi

command_to_run="$*"

# --- 3. Create a New Tmux Window ---
unique_id="$$_$(date +%s)"
window_name="${window_prefix}_${unique_id}"
window_target="${session_name}:=${window_name}"

echo "Creating new tmux window: $window_target"
run_tmux_command new-window -d -t "${session_name}:" -n "$window_name" >/dev/null
sleep 0.2

# --- 4. Send Command and Wait for Signal ---
channel_name="tmux_runner_chan_${unique_id}"
start_delimiter="===START_${unique_id}==="
end_delimiter="===END_${unique_id}==="

# Build the full command with delimiters and wait-for signal
if [[ -n "${SOCKET_PATH:-}" ]]; then
    tmux_wait_cmd="tmux -S $SOCKET_PATH wait-for -S $channel_name"
else
    tmux_wait_cmd="tmux wait-for -S $channel_name"
fi

# Build the full command
# tmux send-keys will interpret this as a single command
full_command="echo '$start_delimiter'; $command_to_run 2>&1; EXIT_CODE=\$?; echo ${end_delimiter}\$EXIT_CODE; $tmux_wait_cmd"

run_tmux_command send-keys -t "$window_target" "$full_command" C-m >/dev/null

echo "Running command and waiting for completion..."
sleep 0.2

# --- 5. Poll for Completion ---
max_retries=600
retries=0
found_end_once=0

while true; do
    # Capture pane content
    pane_content=$(try_tmux_command capture-pane -p -J -S - -E - -t "$window_target")

    if [[ -z "$pane_content" ]]; then
        ((retries++))
        if [[ $retries -ge $max_retries ]]; then
            echo "Error: Command timed out after 60 seconds" >&2
            break
        fi
        sleep 0.1
        continue
    fi

    # Look for end delimiter
    if echo "$pane_content" | grep -qF "$end_delimiter"; then
        if [[ $DEBUG -eq 1 ]] && [[ $found_end_once -eq 0 ]]; then
            echo "DEBUG: Found end delimiter" >&2
            found_end_once=1
        fi
        break
    fi

    ((retries++))
    if [[ $retries -ge $max_retries ]]; then
        echo "Error: Command timed out after 60 seconds" >&2
        break
    fi

    sleep 0.1
done

if [[ $DEBUG -eq 1 ]]; then
    echo "DEBUG: Loop finished after $retries iterations" >&2
    if [[ $found_end_once -eq 1 ]]; then
        echo "DEBUG: End delimiter was found" >&2
    else
        echo "DEBUG: End delimiter was NOT FOUND" >&2
    fi
fi

# Wait for the signal to ensure everything is complete
if [[ $retries -lt $max_retries ]]; then
    run_tmux_command wait-for "$channel_name" >/dev/null
fi

# --- 6. Retrieve Output and Exit Code ---
pane_content=$(run_tmux_command capture-pane -p -J -S - -E - -t "$window_target")

output=""
exit_code=-1

# Find start delimiter (with newline after it)
start_line=$(echo "$pane_content" | grep -n "^${start_delimiter}$" | tail -1 | cut -d: -f1 || echo "")

# Find end delimiter
end_line=$(echo "$pane_content" | grep -n "^${end_delimiter}" | tail -1 | cut -d: -f1 || echo "")

if [[ -n "$start_line" ]] && [[ -n "$end_line" ]]; then
    # Verify delimiters are in correct order
    if [[ $start_line -ge $end_line ]]; then
        echo "" >&2
        echo "Error: Start delimiter found after end delimiter. This shouldn't happen." >&2
        echo "Start line: $start_line, End line: $end_line" >&2
        echo "" >&2
        echo "Dumping buffer:" >&2
        echo "$pane_content" >&2
        exit_code=-1
        output="$pane_content"
    else
        # Extract output between delimiters
        # If start and end are adjacent (no lines between them), output should be empty
        if [[ $((start_line + 1)) -gt $((end_line - 1)) ]]; then
            output=""
        else
            output=$(echo "$pane_content" | sed -n "$((start_line + 1)),$((end_line - 1))p" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        fi

        # Extract exit code (comes right after end delimiter on same line)
        exit_code_str=$(echo "$pane_content" | sed -n "${end_line}p" | sed "s/^${end_delimiter}//")

        if [[ "$exit_code_str" =~ ^[0-9]+$ ]]; then
            exit_code=$exit_code_str
        else
            echo "" >&2
            echo "Warning: Could not parse exit code from: ${exit_code_str:0:50}" >&2
            exit_code=-1
        fi

        # Debug output for empty output
        if [[ -z "$output" ]] && [[ $DEBUG -eq 1 ]]; then
            echo "" >&2
            echo "Note: Command completed but produced no output between delimiters." >&2
            echo "This usually means the command ran successfully but had no stdout/stderr." >&2
            echo "" >&2
            echo "Full buffer dump for debugging:" >&2
            echo "================================================================================" >&2
            echo "$pane_content" >&2
            echo "================================================================================" >&2
            echo "" >&2
            echo "Delimiter positions:" >&2
            echo "  Start delimiter at line: $start_line" >&2
            echo "  End delimiter at line: $end_line" >&2
        fi
    fi
else
    # Safety net
    echo "" >&2
    echo "Error: Command finished, but could not parse output. Delimiters not found." >&2
    echo "Expected start marker: $start_delimiter" >&2
    echo "Expected end marker: $end_delimiter" >&2
    [[ -n "$start_line" ]] && echo "Start marker found: YES" >&2 || echo "Start marker found: NO" >&2
    [[ -n "$end_line" ]] && echo "End marker found: YES" >&2 || echo "End marker found: NO" >&2
    echo "" >&2
    echo "Dumping the entire buffer for debugging:" >&2
    echo "$pane_content" >&2
    output="$pane_content"
fi

# --- 7. Display Results ---
echo ""
echo "----------- COMMAND OUTPUT -----------"
[[ -n "$output" ]] && echo "$output"
echo "------------------------------------"
echo "Exit Code: $exit_code"
echo "------------------------------------"

# --- 8. Clean Up ---
if [[ $exit_code -eq 0 ]]; then
    echo "Command succeeded. Closing window '$window_target'."
    run_tmux_command kill-window -t "$window_target" >/dev/null
else
    echo "Command failed or script error occurred. Leaving window '$window_target' open for inspection."
    close_cmd="tmux kill-window -t $window_target"
    [[ -n "${SOCKET_PATH:-}" ]] && close_cmd="tmux -S $SOCKET_PATH kill-window -t $window_target"
    echo "To close it manually, run: $close_cmd"
fi

exit $exit_code
