#!/bin/bash

# Script to find and kill processes listening on specified TCP ports.
# Version: 1.1 (Fixed regex, added interactive kill prompt)

# --- Configuration ---
DEFAULT_PORTS=("3000" "8000") # Default ports to check if none are provided
PROMPT_TIMEOUT=5 # Seconds to wait for user confirmation

# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "'$1' command not found. Please install it to ensure full functionality."
    # Decide if this is fatal or just limits functionality
    # For core tools like lsof/ss/netstat, it might be fatal for port check
    # For kill, it's definitely fatal for the kill feature
    if [[ "$1" == "lsof" || "$1" == "ss" || "$1" == "netstat" || "$1" == "kill" ]]; then
        exit 1
    fi
    return 1
  fi
  return 0
}

# --- Main Logic ---

# Check for necessary commands
check_command "kill" || exit 1
check_command "ps" || exit 1
# Need at least one port checking tool
if ! check_command "lsof" && ! check_command "ss" && ! check_command "netstat"; then
    log_error "Cannot check ports: Requires 'lsof', 'ss', or 'netstat'."
    exit 1
fi

# Determine ports to check
ports_to_check=()
if [ $# -gt 0 ]; then
    # Use ports provided as command-line arguments
    ports_to_check=("$@")
    log_info "Checking ports provided as arguments: ${ports_to_check[*]}"
else
    # Use default ports
    ports_to_check=("${DEFAULT_PORTS[@]}")
    log_info "No ports provided, using defaults: ${ports_to_check[*]}"
fi

# Validate ports
valid_ports=()
for port in "${ports_to_check[@]}"; do
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        valid_ports+=("$port")
    else
        log_warn "Skipping invalid port number: '$port'"
    fi
done

if [ ${#valid_ports[@]} -eq 0 ]; then
    log_error "No valid ports specified."
    exit 1
fi

log_info "Ports to process: ${valid_ports[*]}"
echo "---"

# Loop through each valid port
for port in "${valid_ports[@]}"; do
    echo "[PORT $port] Checking..."
    pids_found=""
    process_info=""
    tool_used=""

    # 1. Try lsof (preferred)
    if command -v lsof &> /dev/null; then
        tool_used="lsof"
        # -t gives only PIDs, -i TCP network files, -sTCP:LISTEN filters for listening state
        # Using stdbuf to try and avoid buffering issues with process substitution/pipelines
        pids_found=$(stdbuf -oL lsof -t -i TCP:"$port" -sTCP:LISTEN 2>/dev/null)
    fi

    # 2. Try ss (if lsof failed or not found)
    if [ -z "$pids_found" ] && command -v ss &> /dev/null; then
        tool_used="ss"
        # -l listening, -t tcp, -p processes, -n numeric
        # Extract PIDs (parsing ss output) - handles multiple PIDs on one line
        pids_found=$(ss -ltnp sport = ":$port" 2>/dev/null | grep 'users:((' | sed -E 's/.*pid=([0-9]+).*/\1/' | sort -u | paste -sd ' ')
    fi

    # 3. Try netstat (last resort, often needs sudo for PIDs)
    if [ -z "$pids_found" ] && command -v netstat &> /dev/null; then
        tool_used="netstat"
        # -l listening, -t tcp, -n numeric, -p programs (requires sudo often)
        # Extract PIDs (parsing netstat output) - handles multiple PIDs
        pids_found=$(netstat -ltnp 2>/dev/null | grep ":$port " | grep LISTEN | sed -E 's|.*LISTEN\s+([0-9]+)/.*|\1|' | sort -u | paste -sd ' ')
        # --- CORRECTED REGEX CHECK ---
        if [ -n "$pids_found" ] && ! [[ "$pids_found" =~ ^[[:digit:][:space:]]+$ ]]; then # Use POSIX classes
             log_warn "[PORT $port] netstat found listeners but couldn't extract valid PIDs (try sudo?). Parsed: '$pids_found'"
             pids_found="" # Reset if parsing failed
        fi
        # -----------------------------
    fi

    # --- Process the findings ---
    if [ -n "$pids_found" ]; then
        log_warn "[PORT $port] Found process(es) listening (using $tool_used):"
        # Get process details for display
        process_details=$(ps -o pid=,user=,comm=,args= -p $pids_found)
        echo "------------------------------------"
        echo "$process_details"
        echo "------------------------------------"

        # Prompt user with timeout
        kill_choice=""
        read -t "$PROMPT_TIMEOUT" -p "Kill process(es) on port $port? (y/N, default N after $PROMPT_TIMEOUT sec): " kill_choice
        echo # Add a newline after read

        # Default to 'n' if timeout or empty input
        kill_choice=${kill_choice:-N}

        if [[ "$kill_choice" =~ ^[Yy]$ ]]; then
            log_info "[PORT $port] Attempting to kill PID(s): $pids_found..."
            killed_any=false
            failed_pids=()
            for pid in $pids_found; do
                 # Try graceful kill first
                 if kill "$pid" 2>/dev/null; then
                     log_info "  Sent SIGTERM to PID $pid."
                     killed_any=true
                     sleep 0.5 # Brief pause
                     # Check if it's still alive
                     if ps -p "$pid" > /dev/null; then
                         log_warn "  PID $pid still alive, sending SIGKILL..."
                         if kill -9 "$pid" 2>/dev/null; then
                             log_info "  Sent SIGKILL to PID $pid."
                         else
                             log_error "  Failed to send SIGKILL to PID $pid (permission error?)."
                             failed_pids+=("$pid")
                             killed_any=false # Mark overall as failed if SIGKILL fails
                         fi
                     else
                         log_info "  PID $pid terminated."
                     fi
                 else
                     log_error "  Failed to send SIGTERM to PID $pid (already stopped or permission error?)."
                     # Check if it's already gone
                     if ! ps -p "$pid" > /dev/null; then
                        log_info "  PID $pid was already stopped."
                        # Don't set killed_any=true here, as we didn't actively kill it now
                     else
                        failed_pids+=("$pid") # Failed to send signal, process still exists
                     fi
                 fi
            done

            if $killed_any && [ ${#failed_pids[@]} -eq 0 ]; then
                 log_info "[PORT $port] ✓ Kill attempt complete."
            else
                 log_error "[PORT $port] ✗ Failed to kill all processes. Problem PIDs: ${failed_pids[*]}"
            fi
        else
            log_info "[PORT $port] Skipped killing process(es)."
        fi
    else
        log_info "[PORT $port] ✓ Port appears clear (no listening TCP process found)."
    fi
    echo "---" # Separator between ports
done

log_info "Port killing process finished."
exit 0
