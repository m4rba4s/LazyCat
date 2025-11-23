#!/bin/bash
# lib/logger.sh

# Ensure log file is set
LOG_FILE="${LOG_FILE:-/dev/null}"

log_info() {
    local msg="$1"
    local timestamp=$(date +'%T')
    echo -e "${BLUE}[INFO] ${timestamp} - ${msg}${NC}"
    echo "[INFO] ${timestamp} - ${msg}" >> "$LOG_FILE" 2>/dev/null
}

log_success() {
    local msg="$1"
    local timestamp=$(date +'%T')
    echo -e "${GREEN}[OK]   ${timestamp} - ${msg}${NC}"
    echo "[OK]   ${timestamp} - ${msg}" >> "$LOG_FILE" 2>/dev/null
}

log_warn() {
    local msg="$1"
    local timestamp=$(date +'%T')
    echo -e "${YELLOW}[WARN] ${timestamp} - ${msg}${NC}"
    echo "[WARN] ${timestamp} - ${msg}" >> "$LOG_FILE" 2>/dev/null
}

log_crit() {
    local msg="$1"
    local timestamp=$(date +'%T')
    echo -e "${RED}[CRIT] ${timestamp} - ${msg}${NC}" >&2
    echo "[CRIT] ${timestamp} - ${msg}" >> "$LOG_FILE" 2>/dev/null
}

log_debug() {
    if [[ "${DEBUG:-0}" -eq 1 ]]; then
        local msg="$1"
        local timestamp=$(date +'%T')
        echo -e "${PURPLE}[DEBUG] ${timestamp} - ${msg}${NC}"
        echo "[DEBUG] ${timestamp} - ${msg}" >> "$LOG_FILE"
    fi
}
